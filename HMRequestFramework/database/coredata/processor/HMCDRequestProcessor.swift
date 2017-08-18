//
//  HMCDRequestProcessor.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 20/7/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift
import SwiftUtilities

/// CoreData request processor class. We skip the handler due to CoreData
/// design limitations. This way, casting is done at the database level.
public struct HMCDRequestProcessor {
    fileprivate var manager: HMCDManager?
    fileprivate var rqMiddlewareManager: HMMiddlewareManager<Req>?
    
    fileprivate init() {}
    
    public func coreDataManager() -> HMCDManager {
        if let manager = self.manager {
            return manager
        } else {
            fatalError("CoreData manager cannot be nil")
        }
    }
}

extension HMCDRequestProcessor: HMCDRequestProcessorType {
    public typealias Req = HMCDRequest
    
    /// Override this method to provide default implementation.
    ///
    /// - Returns: A HMMiddlewareManager instance.
    public func requestMiddlewareManager() -> HMMiddlewareManager<Req>? {
        return rqMiddlewareManager
    }
}

public extension HMCDRequestProcessor {
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if no context is available.
    public func executeTyped<Val>(_ request: Req) throws -> Observable<Try<[Val]>>
        where Val: NSFetchRequestResult
    {
        let operation = try request.operation()
        
        switch operation {
        case .fetch:
            return try executeFetch(request, Val.self)
            
        default:
            throw Exception("Please use normal execute for \(operation)")
        }
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    public func execute(_ request: Req) throws -> Observable<Try<Void>> {
        let operation = try request.operation()
        
        switch operation {
        case .deleteData:
            return try executeDelete(request)
            
        case .deleteBatch:
            return try executeDeleteWithRequest(request)
            
        case .persistLocally:
            return try executePersistToFile(request)
            
        case .fetch, .saveData, .upsert:
            throw Exception("Please use typed execute for \(operation)")
        }
    }
    
    /// Overwrite this method to provide default implementation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the operation fails.
    public func executeTyped(_ request: Req) throws -> Observable<Try<[HMCDResult]>> {
        let operation = try request.operation()
        
        switch operation {
        case .saveData:
            return try executeSaveData(request)
            
        case .upsert:
            return try executeUpsert(request)
            
        default:
            throw Exception("Please use normal execute for \(operation)")
        }
    }
}

public extension HMCDRequestProcessor {
    
    /// Perform a CoreData get request.
    ///
    /// - Parameters:
    ///   - request: A Req instance.
    ///   - cls: The Val class type.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executeFetch<Val>(_ request: Req, _ cls: Val.Type) throws
        -> Observable<Try<[Val]>>
        where Val: NSFetchRequestResult
    {
        let manager = coreDataManager()
        let cdRequest = try request.fetchRequest(Val.self)
        let context = manager.disposableObjectContext()
    
        return manager.rx.fetch(context, cdRequest)
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
}

public extension HMCDRequestProcessor {
    
    /// Perform a CoreData saveData operation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executeSaveData(_ request: Req) throws -> Observable<Try<[HMCDResult]>> {
        let manager = coreDataManager()
        let insertedData = try request.insertedData()
        let context = manager.disposableObjectContext()
        
        return manager.rx.save(context, insertedData)
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
}

public extension HMCDRequestProcessor {
    
    /// Perform a CoreData data persistence operation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executePersistToFile(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        
        return manager.rx.persistLocally()
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
}

public extension HMCDRequestProcessor {
    
    /// Perform a CoreData upsert operation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executeUpsert(_ request: Req) throws -> Observable<Try<[HMCDResult]>> {
        let manager = coreDataManager()
        let data = try request.upsertedData()
        let entityName = try request.entityName()
        
        // If the data requires versioning, we call updateVersionn.
        let versionables = data.flatMap({$0 as? HMCDVersionableType})
        let nonVersionables = data.filter({!($0 is HMCDVersionableType)})
        let updateRequests = try request.updateRequest(versionables)
        let context1 = manager.disposableObjectContext()
        let context2 = manager.disposableObjectContext()
        
        return Observable
            .concat(
                manager.rx.updateVersion(context1, entityName, updateRequests),
                manager.rx.upsert(context2, entityName, nonVersionables)
            )
            .reduce([], accumulator: +)
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
}

public extension HMCDRequestProcessor {
    
    /// Perform a CoreData delete operation. This operation detects identifiable
    /// objects and treat those objects differently.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executeDelete(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        let context = manager.disposableObjectContext()
        let entityName = try request.entityName()
        let data = try request.deletedData()
        
        // Since both CoreData and PureObject can implement HMCDObjectConvertibleType,
        // we can convert them all to NSManagedObject and delete them based on
        // whether they are identifiable or not.
        //
        // We delete NSManagedObject using their ObjectID. If not, we construct
        // the managed objects using a disposable context, and see if any of
        // these objects is identifiable.
        let aliases = data.flatMap({$0 as? NSManagedObject})
        
        let nonAliases = data.filter({!($0 is NSManagedObject)})
            .flatMap({try? $0.asManagedObject(context)})
        
        let objects = [aliases, nonAliases].flatMap({$0})
        
        // We deal with identifiables and normal managed objects differently.
        // For identifiables, we need to fetch their counterparts in the DB
        // first before deleting.
        let identifiables = objects.flatMap({$0 as? HMCDIdentifiableType})
        let nonIdentifiables = objects.filter({!($0 is HMCDIdentifiableType)})
        let context1 = manager.disposableObjectContext()
        let context2 = manager.disposableObjectContext()
        
        return Observable
            .concat(
                manager.rx.delete(context1, entityName, identifiables),
                manager.rx.delete(context2, nonIdentifiables)
            )
            .reduce((), accumulator: {_ in ()})
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
}

public extension HMCDRequestProcessor {
    
    /// We need this check because batch delete does not work for InMemory store.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executeDeleteWithRequest(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        
        if manager.isMainStoreTypeSQLite() {
            return try executeBatchDelete(request)
        } else {
            return try executeFetchAndDelete(request)
        }
    }
    
    /// Perform a batch delete operation. This only works for SQLite stores.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executeBatchDelete(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        let deleteRequest = try request.untypedFetchRequest()
        let context = manager.disposableObjectContext()
        
        return manager.rx.delete(context, deleteRequest)
            .map(toVoid)
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
    
    /// Fetch some data from DB then delete them. This should only be used
    /// when we want to batch-delete data but the store type is not SQLite.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    fileprivate func executeFetchAndDelete(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        let fetchContext = manager.disposableObjectContext()
        let deleteContext = manager.disposableObjectContext()
        let fetchRequest = try request.fetchRequest(NSManagedObject.self)
        
        return manager.rx.fetch(fetchContext, fetchRequest)
            .flatMap({manager.rx.delete(deleteContext, $0)})
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
}

public extension HMCDRequestProcessor {
    
    /// Get a DB request to fetch all items for an entity.
    ///
    /// - Parameter cls: The PureObject class type.
    /// - Returns: A DBReq instance.
    func fetchAllRequest<PO>(_ cls: PO.Type) -> Req where PO: HMCDPureObjectType {
        return Req.builder()
            .with(operation: .fetch)
            .with(poType: cls)
            .with(predicate: NSPredicate(value: true))
            .shouldApplyMiddlewares()
            .build()
    }
    
    /// Fetch all data of a type from DB, then convert them to pure objects.
    ///
    /// - Parameters:
    ///   - previous: The result of the previous request.
    ///   - cls: The PureObject class type.
    /// - Returns: An Observable instance.
    public func fetchAllDataFromDB<Prev,PO>(_ previous: Try<Prev>, _ cls: PO.Type)
        -> Observable<Try<[PO]>> where
        PO: HMCDPureObjectType,
        PO.CDClass: HMCDPureObjectConvertibleType,
        PO.CDClass.PureObject == PO
    {
        let request = fetchAllRequest(cls)
        let generator = HMRequestGenerators.forceGenerateFn(request, Prev.self)
        return process(previous, generator, cls)
    }
}

public extension HMCDRequestProcessor {
    
    /// Get a database request to save some objects to memory.
    ///
    /// - Parameter data: A Sequence of CD.
    /// - Returns: A Req instance.
    func saveToMemoryRequest<CD,S>(_ data: S) -> Req where
        CD: HMCDObjectType,
        CD: HMCDObjectConvertibleType,
        S: Sequence,
        S.Iterator.Element == CD
    {
        return Req.builder()
            .with(cdType: CD.self)
            .with(operation: .saveData)
            .with(insertedData: data)
            .with(requestDescription: "Save \(CD.self) to memory")
            .build()
    }
    
    /// Save some data to memory by constructing them and then saving the
    /// resulting managed objects.
    ///
    /// - Parameter previous: The result of the previous operation.
    /// - Returns: An Observable instance.
    public func saveToMemory<S,PO>(_ previous: Try<S>) -> Observable<Try<Void>> where
        PO: HMCDPureObjectType,
        PO.CDClass: HMCDObjectConvertibleType,
        PO.CDClass: HMCDObjectBuildableType,
        PO.CDClass.Builder.PureObject == PO,
        S: Sequence,
        S.Iterator.Element == PO
    {
        let cdManager = coreDataManager()
        let context = cdManager.disposableObjectContext()
        
        let generator: HMRequestGenerator<S,Req> =
            HMRequestGenerators.forceGenerateFn(generator: {
                cdManager.rx.construct(context, $0).map(self.saveToMemoryRequest)
            })
        
        return processResult(previous, generator).map({$0.map(toVoid)})
    }
}

public extension HMCDRequestProcessor {

    /// Get a database request to upsert some data.
    ///
    /// - Parameters:
    ///   - data: A Sequence of U.
    ///   - strategy: A VersionConflict.Strategy instance.
    /// - Returns: A Req instance.
    func upsertRequest<U,S>(_ data: S, _ strategy: VersionConflict.Strategy) -> Req where
        U: HMCDObjectType,
        U: HMCDUpsertableType,
        S: Sequence,
        S.Iterator.Element == U
    {
        return Req.builder()
            .with(cdType: U.self)
            .with(operation: .upsert)
            .with(insertedData: data.map({$0 as HMCDUpsertableType}))
            .with(vcStrategy: strategy)
            .with(requestDescription: "Upsert \(U.self) in memory")
            .build()
    }
    
    /// Perform an upsert operation with some upsertable data.
    ///
    /// - Parameters:
    ///   - previous: The result of the previous request.
    ///   - strategy: A VersionConflict.Strategy instance.
    /// - Returns: An Observable instance.
    public func upsertInMemory<U,S>(_ previous: Try<S>,
                                    _ strategy: VersionConflict.Strategy)
        -> Observable<Try<[HMCDResult]>> where
        U: HMCDObjectType,
        U: HMCDUpsertableType,
        S: Sequence,
        S.Iterator.Element == U
    {
        let generator: HMRequestGenerator<S,Req> =
            HMRequestGenerators.forceGenerateFn(generator: {
                Observable.just(self.upsertRequest($0, strategy))
            })
        
        return processResult(previous, generator)
    }
    
    /// Perform an upsert operation with some pure objects by constructing
    /// managed objects and then upserting them afterwards.
    ///
    /// - Parameters:
    ///   - data: A Sequence of PO.
    ///   - strategy: A VersionConflict.Strategy instance.
    /// - Returns: An Observable instance.
    public func upsertInMemory<PO,S>(_ data: S, _ strategy: VersionConflict.Strategy)
        -> Observable<Try<[HMCDResult]>> where
        PO: HMCDPureObjectType,
        PO.CDClass: HMCDUpsertableType,
        PO.CDClass: HMCDObjectBuildableType,
        PO.CDClass.Builder.PureObject == PO,
        S: Sequence,
        S.Iterator.Element == PO
    {
        let cdManager = coreDataManager()
        let context = cdManager.disposableObjectContext()
        
        return cdManager.rx.construct(context, data)
            .map(Try.success)
            .flatMap({self.upsertInMemory($0, strategy)})
            .catchErrorJustReturn(Try.failure)
    }
}

public extension HMCDRequestProcessor {
    func persistToDBRequest() -> Req {
        return Req.builder()
            .with(operation: .persistLocally)
            .with(requestDescription: "Persist all data to DB")
            .shouldApplyMiddlewares()
            .build()
    }
    
    /// Persist all data to DB.
    ///
    /// - Parameter previous: The result of the previous request.
    /// - Returns: An Observable instance.
    public func persistToDB<Prev>(_ previous: Try<Prev>) -> Observable<Try<Void>> {
        let request = persistToDBRequest()
        let generator = HMRequestGenerators.forceGenerateFn(request, Prev.self)
        return processVoid(previous, generator)
    }
}

extension HMCDRequestProcessor: HMBuildableType {
    public static func builder() -> Builder {
        return Builder()
    }
    
    public final class Builder {
        public typealias Req = HMCDRequestProcessor.Req
        fileprivate var processor: Buildable
        
        fileprivate init() {
            processor = Buildable()
        }
        
        /// Set the manager instance.
        ///
        /// - Parameter manager: A HMCDManager instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(manager: HMCDManager) -> Self {
            processor.manager = manager
            return self
        }
        
        /// Set the request middleware manager.
        ///
        /// - Parameter rqMiddlewareManager: A HMMiddlewareManager instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(rqMiddlewareManager: HMMiddlewareManager<Req>?) -> Self {
            processor.rqMiddlewareManager = rqMiddlewareManager
            return self
        }
    }
}

extension HMCDRequestProcessor.Builder: HMBuilderType {
    public typealias Buildable = HMCDRequestProcessor
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter buildable: A Buildable instance.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(buildable: Buildable) -> Self {
        return self
            .with(manager: buildable.coreDataManager())
            .with(rqMiddlewareManager: buildable.requestMiddlewareManager())
    }
    
    
    public func build() -> Buildable {
        return processor
    }
}
