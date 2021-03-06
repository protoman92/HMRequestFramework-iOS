//
//  HMCDRequest.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 20/7/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import SwiftUtilities

/// Use this struct whenever concrete HMCDRequestType objects are required.
public struct HMCDRequest {
    fileprivate var cdOperation: HMCDOperation?
    fileprivate var cdOperationMode: HMCDOperationMode
    
    fileprivate var cdEntityName: String?
    fileprivate var nsPredicate: NSPredicate?
    fileprivate var nsSortDescriptors: [NSSortDescriptor]
    fileprivate var cdFetchResultType: NSFetchRequestResultType?
    fileprivate var cdFetchProperties: [Any]
    fileprivate var cdFetchGroupBy: [Any]
    fileprivate var cdFetchLimit: Int?
    fileprivate var cdFetchOffset: Int
    fileprivate var cdFetchBatchSize: Int
    fileprivate var cdInsertedData: [HMCDObjectConvertibleType]
    fileprivate var cdUpsertedData: [HMCDUpsertableType]
    fileprivate var cdDeletedData: [HMCDObjectConvertibleType]
    fileprivate var cdVCStrategy: VersionConflict.Strategy?
    fileprivate var cdFrcSectionName: String?
    fileprivate var cdFrcCacheName: String?
    fileprivate var cdMWFilters: [MiddlewareFilter]
    fileprivate var retryCount: Int
    fileprivate var retryDelayIntv: TimeInterval
    fileprivate var middlewaresEnabled: Bool
    fileprivate var rqDescription: String?
    
    fileprivate init() {
        cdOperationMode = .queued
        cdFetchOffset = 0
        cdFetchBatchSize = 0
        cdFetchProperties = []
        cdFetchGroupBy = []
        cdInsertedData = []
        cdUpsertedData = []
        cdDeletedData = []
        nsSortDescriptors = []
        cdMWFilters = []
        retryCount = 1
        retryDelayIntv = 0
        middlewaresEnabled = true
    }
}

extension HMCDRequest: HMBuildableType {
    public static func builder() -> Builder {
        return Builder()
    }
    
    public final class Builder {
        fileprivate var request: Buildable
        
        fileprivate init() {
            request = Buildable()
        }
        
        /// Set the entity name.
        ///
        /// - Parameter entityName: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(entityName: String?) -> Self {
            request.cdEntityName = entityName
            return self
        }
        
        /// Set the entityName using a HMCDObjectType subtype.
        ///
        /// - Parameter cdType: A CD class type.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<CD>(cdType: CD.Type) -> Self where CD: HMCDObjectType {
            return with(entityName: try? cdType.entityName())
        }
        
        /// Set the entityName using a HMCDPureObjectType subtype.
        ///
        /// - Parameter poType: A PO class type.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<PO>(poType: PO.Type) -> Self where PO: HMCDPureObjectType {
            return with(cdType: poType.CDClass.self)
        }
        
        /// Set the predicate.
        ///
        /// - Parameter predicate: A NSPredicate instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(predicate: NSPredicate?) -> Self {
            request.nsPredicate = predicate
            return self
        }
        
        /// Transform the predicate if it is available.
        ///
        /// - Parameter predicateFn: A predicate transform function.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(predicateFn: (NSPredicate) throws -> NSPredicate?) -> Self {
            if let predicate = request.nsPredicate {
                do {
                    let newPredicate = try predicateFn(predicate)
                    return self.with(predicate: newPredicate)
                } catch {
                    return self
                }
            } else {
                return self
            }
        }
        
        /// Transform the predicate to include some other predicates with a
        /// logical connector.
        ///
        /// - Parameters:
        ///   - predicates: A Sequence of predicates.
        ///   - type: A predicate connector.
        /// - Returns: The current Builder instance.
        public func with<SP>(predicates: SP, type: NSCompoundPredicate.LogicalType)
            -> Self where SP: Sequence, SP.Element == NSPredicate
        {
            return with(predicateFn: {
                NSCompoundPredicate(type: type, subpredicates: [$0] + predicates)
            })
        }
        
        /// Transform the predicate to include some other predicates with a
        /// logical connector.
        ///
        /// - Parameters:
        ///   - type: A predicate connector.
        ///   - predicates: Varargs of predicates.
        /// - Returns: The current Builder instance.
        public func with(type: NSCompoundPredicate.LogicalType,
                         predicates: NSPredicate...) -> Self {
            return with(predicates: predicates, type: type)
        }
        
        /// Transform the predicate to include some other predicates with AND
        /// connector.
        ///
        /// - Parameter predicates: A Sequence of predicates.
        /// - Returns: The current Builder instance.
        public func with<SP>(andPredicates predicates: SP) -> Self where
            SP: Sequence, SP.Element == NSPredicate
        {
            return with(predicates: predicates, type: .and)
        }
        
        /// Transform the predicate to include some other predicates with AND
        /// connector.
        ///
        /// - Parameter predicates: Varargs of predicates.
        /// - Returns: The current Builder instance.
        public func with(andPredicates predicates: NSPredicate...) -> Self {
            return with(andPredicates: predicates)
        }
        
        /// Transform the predicate to include some other predicates with OR
        /// connector.
        ///
        /// - Parameter predicates: A Sequence of predicates.
        /// - Returns: The current Builder instance.
        public func with<SP>(orPredicates predicates: SP) -> Self where
            SP: Sequence, SP.Element == NSPredicate
        {
            return with(predicates: predicates, type: .or)
        }
        
        /// Transform the predicate to include some other predicates with OR
        /// connector.
        ///
        /// - Parameter predicates: Varargs of predicates.
        /// - Returns: The current Builder instance.
        public func with(orPredicates predicates: NSPredicate...) -> Self {
            return with(orPredicates: predicates)
        }
        
        /// Transform the predicate to include some other predicates with NOT
        /// connector.
        ///
        /// - Parameter predicates: A Sequence of predicates.
        /// - Returns: The current Builder instance.
        public func with<SP>(notPredicates predicates: SP) -> Self where
            SP: Sequence, SP.Element == NSPredicate
        {
            return with(predicates: predicates, type: .not)
        }
        
        /// Transform the predicate to include some other predicates with NOT
        /// connector.
        ///
        /// - Parameter predicates: Varargs of predicates.
        /// - Returns: The current Builder instance.
        public func with(notPredicates predicates: NSPredicate...) -> Self {
            return with(notPredicates: predicates)
        }
        
        /// Set the sort descriptors.
        ///
        /// - Parameter sortDescriptors: A Sequence of NSSortDescriptor.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(sortDescriptors: S?) -> Self where
            S: Sequence, S.Element == NSSortDescriptor
        {
            if let descriptors = sortDescriptors {
                request.nsSortDescriptors.append(contentsOf: descriptors)
            }
            
            return self
        }
        
        /// Set the sort descriptors.
        ///
        /// - Parameter sortDescriptors: A Sequence of NSSortDescriptor.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(sortDescriptors: S?) -> Self where
            S: Sequence, S.Element: NSSortDescriptor
        {
            return with(sortDescriptors: sortDescriptors?.map({$0 as NSSortDescriptor}))
        }
        
        /// Set the sort descriptors.
        ///
        /// - Parameter sortDescriptors: Varargs of NSSortDescriptor.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(sortDescriptors: NSSortDescriptor...) -> Self {
            return with(sortDescriptors: sortDescriptors.map({$0}))
        }
        
        /// Set the sort descriptors.
        ///
        /// - Parameter sortDescriptors: Varargs of NSSortDescriptor.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<SD>(sortDescriptors: SD...) -> Self where SD: NSSortDescriptor {
            return with(sortDescriptors: sortDescriptors.map({$0 as NSSortDescriptor}))
        }
        
        /// Add a sort descriptor.
        ///
        /// - Parameter sortDescriptor: A NSSortDescriptor instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func add(sortDescriptor: NSSortDescriptor) -> Self {
            request.nsSortDescriptors.append(sortDescriptor)
            return self
        }
        
        /// Add an ascending sort descriptor.
        ///
        /// - Parameter key: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func add(ascendingSortWithKey key: String) -> Self {
            return add(sortDescriptor: NSSortDescriptor(key: key, ascending: true))
        }
        
        /// Add a descending sort descriptor.
        ///
        /// - Parameter key: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func add(descendingSortWithKey key: String) -> Self {
            return add(sortDescriptor: NSSortDescriptor(key: key, ascending: false))
        }
        
        /// Set the operation.
        ///
        /// - Parameter operation: A HMCDOperation instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(operation: HMCDOperation?) -> Self {
            request.cdOperation = operation
            return self
        }
        
        /// Set the operation mode.
        ///
        /// - Parameter operationMode: A HMCDOperationMode instance.
        /// - Returns: The current Builder instance.
        public func with(operationMode: HMCDOperationMode) -> Self {
            request.cdOperationMode = operationMode
            return self
        }
        
        /// Set the fetch result type.
        ///
        /// - Parameter fetchResultType: A NSFetchRequestResultType instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(fetchResultType: NSFetchRequestResultType?) -> Self {
            request.cdFetchResultType = fetchResultType
            return self
        }
        
        /// Set the fetch properties.
        ///
        /// - Parameter fetchProperties: An Sequence of Any.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(fetchProperties: S?) -> Self where
            S: Sequence, S.Element == Any
        {
            request.cdFetchProperties = fetchProperties?.map({$0}) ?? []
            return self
        }
        
        /// Set the fetch properties.
        ///
        /// - Parameter fetchProperties: An Sequence of Any.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(fetchProperties: S?) -> Self where
            S: Sequence, S.Element: Any
        {
            return with(fetchProperties: fetchProperties?.map({$0 as Any}))
        }
        
        /// Add a fetch property.
        ///
        /// - Parameter fetchProperty: An Any object.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func add(fetchProperty: Any) -> Self {
            request.cdFetchProperties.append(fetchProperty)
            return self
        }
        
        /// Set the fetch group by properties.
        ///
        /// - Parameter fetchGroupBy: An Array of Any.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(fetchGroupBy: S?) -> Self where
            S: Sequence, S.Element == Any
        {
            request.cdFetchGroupBy = fetchGroupBy?.map({$0}) ?? []
            return self
        }
        
        /// Set the fetch group by properties.
        ///
        /// - Parameter fetchGroupBy: An Array of Any.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(fetchGroupBy: S?) -> Self where
            S: Sequence, S.Element: Any
        {
            return with(fetchGroupBy: fetchGroupBy?.map({$0 as Any}))
        }
        
        /// Add a fetch group by property.
        ///
        /// - Parameter fetchProperty: An Any object.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func add(fetchGroupBy: Any) -> Self {
            request.cdFetchGroupBy.append(fetchGroupBy)
            return self
        }
        
        /// Set the fetchLimit.
        ///
        /// - Parameter fetchLimit: An Int value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(fetchLimit: Int?) -> Self {
            request.cdFetchLimit = fetchLimit
            return self
        }
        
        /// Set the fetch offset.
        ///
        /// - Parameter fetchOffset: An Int value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(fetchOffset: Int) -> Self {
            request.cdFetchOffset = fetchOffset
            return self
        }
        
        /// Set the fetch batch size.
        ///
        /// - Parameter fetchBatchSize: An Int value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(fetchBatchSize: Int) -> Self {
            request.cdFetchBatchSize = fetchBatchSize
            return self
        }
        
        /// Set the data to insert.
        ///
        /// - Parameter insertedData: A Sequence of HMCDConvertibleType.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(insertedData: S?) -> Self where
            S: Sequence, S.Element == HMCDObjectConvertibleType
        {
            if let data = insertedData {
                request.cdInsertedData.append(contentsOf: data)
            }
            
            return self
        }
        
        /// Set the data to insert.
        ///
        /// - Parameter insertedData: A Sequence of HMCDConvertibleType.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(insertedData: S?) -> Self where
            S: Sequence, S.Element: HMCDObjectConvertibleType
        {
            return with(insertedData: insertedData?.map({$0 as HMCDObjectConvertibleType}))
        }
        
        /// Set the data to upsert.
        ///
        /// - Parameter upsertedData: A Sequence of HMCDConvertibleType.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(upsertedData: S?) -> Self where
            S: Sequence, S.Element == HMCDUpsertableType
        {
            if let data = upsertedData {
                request.cdUpsertedData.append(contentsOf: data)
            }
            
            return self
        }
        
        /// Set the data to upsert.
        ///
        /// - Parameter upsertedData: A Sequence of HMCDConvertibleType.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(upsertedData: S?) -> Self where
            S: Sequence, S.Element: HMCDUpsertableType
        {
            return with(upsertedData: upsertedData?.map({$0 as HMCDUpsertableType}))
        }
        
        /// Set the data to delete.
        ///
        /// - Parameter deletedData: A Sequence of NSManagedObject.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(deletedData: S?) -> Self where
            S: Sequence, S.Element == HMCDObjectConvertibleType
        {
            if let data = deletedData {
                request.cdDeletedData.append(contentsOf: data)
            }
            
            return self
        }
        
        /// Set the data to delete.
        ///
        /// - Parameter deletedData: A Sequence of NSManagedObject.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with<S>(deletedData: S?) -> Self where
            S: Sequence, S.Element: HMCDObjectConvertibleType
        {
            return with(deletedData: deletedData?.map({$0 as HMCDObjectConvertibleType}))
        }
        
        /// Set the version conflict strategy.
        ///
        /// - Parameter vcStrategy: A VersionConflict.Strategy instance.
        /// - Returns: The current Builder instance.
        public func with(vcStrategy: VersionConflict.Strategy?) -> Self {
            request.cdVCStrategy = vcStrategy
            return self
        }
        
        /// Set the FRC section name.
        ///
        /// - Parameter frcSectionName: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(frcSectionName: String?) -> Self {
            request.cdFrcSectionName = frcSectionName
            return self
        }
        
        /// Set the FRC cache name.
        ///
        /// - Parameter frcCacheName: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(frcCacheName: String?) -> Self {
            request.cdFrcCacheName = frcCacheName
            return self
        }
    }
}

extension HMCDRequest.Builder: HMRequestBuilderType {
    public typealias Buildable = HMCDRequest

    /// Override this method to provide default implementation.
    ///
    /// - Parameter mwFilters: An Array of filters.
    /// - Returns: The current Builder instance.
    public func with<S>(mwFilters: S) -> Self where
        S: Sequence, S.Element == HMMiddlewareFilter<Buildable>
    {
        request.cdMWFilters = mwFilters.map({$0})
        return self
    }

    /// Override this method to provide default implementation.
    ///
    /// - Parameter mwFilter: A filter instance..
    /// - Returns: The current Builder instance.
    public func add(mwFilter: HMMiddlewareFilter<Buildable>) -> Self {
        request.cdMWFilters.append(mwFilter)
        return self
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter retries: An Int value.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(retries: Int) -> Self {
        request.retryCount = retries
        return self
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter retries: An Int value.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(retryDelay: TimeInterval) -> Self {
        request.retryDelayIntv = retryDelay
        return self
    }

    /// Override this method to provide default implementation.
    ///
    /// - Parameter applyMiddlewares: A Bool value.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(applyMiddlewares: Bool) -> Self {
        request.middlewaresEnabled = applyMiddlewares
        return self
    }

    /// Override this method to provide default implementation.
    ///
    /// - Parameter description: A String value.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(description: String?) -> Self {
        request.rqDescription = description
        return self
    }

    /// Override this method to provide default implementation.
    ///
    /// - Parameter buildable: A Buildable instance.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(buildable: Buildable?) -> Self {
        if let buildable = buildable {
            return self
                .with(operation: buildable.cdOperation)
                .with(operationMode: buildable.cdOperationMode)
                .with(entityName: buildable.cdEntityName)
                .with(predicate: buildable.nsPredicate)
                .with(sortDescriptors: buildable.nsSortDescriptors)
                .with(fetchResultType: buildable.cdFetchResultType)
                .with(fetchProperties: buildable.cdFetchProperties)
                .with(fetchGroupBy: buildable.cdFetchGroupBy)
                .with(fetchLimit: buildable.cdFetchLimit)
                .with(fetchOffset: buildable.cdFetchOffset)
                .with(fetchBatchSize: buildable.cdFetchBatchSize)
                .with(insertedData: buildable.cdInsertedData)
                .with(upsertedData: buildable.cdUpsertedData)
                .with(deletedData: buildable.cdDeletedData)
                .with(vcStrategy: buildable.cdVCStrategy)
                .with(frcSectionName: buildable.cdFrcSectionName)
                .with(frcCacheName: buildable.cdFrcCacheName)
                .with(mwFilters: buildable.cdMWFilters)
                .with(retries: buildable.retryCount)
                .with(retryDelay: buildable.retryDelayIntv)
                .with(applyMiddlewares: buildable.middlewaresEnabled)
                .with(description: buildable.rqDescription)
        } else {
            return self
        }
    }

    public func build() -> Buildable {
        return request
    }
}

extension HMCDRequest: HMRequestType {
    public typealias Filterable = String
    
    public func middlewareFilters() -> [MiddlewareFilter] {
        return cdMWFilters
    }
    
    public func retries() -> Int {
        return Swift.max(retryCount, 1)
    }
    
    public func retryDelay() -> TimeInterval {
        return retryDelayIntv
    }
    
    public func applyMiddlewares() -> Bool {
        return middlewaresEnabled
    }
    
    public func requestDescription() -> String? {
        return rqDescription
    }
}

extension HMCDRequest: HMCDFetchRequestType {
    public func entityName() throws -> String {
        if let entityName = cdEntityName {
            return entityName
        } else {
            throw Exception("Entity name cannot be nil")
        }
    }
    
    public func operation() throws -> HMCDOperation {
        if let operation = cdOperation {
            return operation
        } else {
            throw Exception("Operation cannot be nil")
        }
    }
    
    public func operationMode() -> HMCDOperationMode {
        return cdOperationMode
    }
    
    public func predicate() throws -> NSPredicate {
        if let predicate = nsPredicate {
            return predicate
        } else {
            throw Exception("Predicate cannot be nil")
        }
    }
    
    public func sortDescriptors() throws -> [NSSortDescriptor] {
        return nsSortDescriptors
    }
    
    public func fetchResultType() -> NSFetchRequestResultType? {
        return cdFetchResultType
    }
    
    public func fetchProperties() -> [Any]? {
        return cdFetchProperties.isEmpty ? nil : cdFetchProperties
    }
    
    public func fetchGroupBy() -> [Any]? {
        return cdFetchGroupBy.isEmpty ? nil : cdFetchGroupBy
    }
    
    public func fetchLimit() -> Int? {
        return cdFetchLimit
    }
    
    public func fetchOffset() -> Int {
        return cdFetchOffset
    }
    
    public func fetchBatchSize() -> Int {
        return cdFetchBatchSize
    }
}

extension HMCDRequest: HMCDFetchedResultRequestType {
    public func frcCacheName() -> String? {
        return cdFrcCacheName
    }
    
    public func frcSectionName() -> String? {
        return cdFrcSectionName
    }
}

extension HMCDRequest: HMCDRequestType {
    public typealias Value = NSManagedObject
    
    public func insertedData() throws -> [HMCDObjectConvertibleType] {
        return cdInsertedData
    }
    
    public func upsertedData() throws -> [HMCDUpsertableType] {
        return cdUpsertedData
    }
    
    public func deletedData() throws -> [HMCDObjectConvertibleType] {
        return cdDeletedData
    }
    
    public func versionConflictStrategy() throws -> VersionConflict.Strategy {
        if let strategy = cdVCStrategy {
            return strategy
        } else {
            throw Exception("Version conflict strategy must not be nil")
        }
    }
}

extension HMCDRequest: CustomStringConvertible {
    public var description: String {
        var ops: String
        
        if let operation = try? self.operation() {
            ops = String(describing: operation)
            
            if
                case .fetch = operation,
                let predicate = try? self.predicate(),
                let sorts = try? self.sortDescriptors()
            {
                ops = "\(ops) with predicate \(predicate) and sort \(sorts)"
            }
        } else {
            ops = "INVALID OPERATION"
        }
        
        let description = self.requestDescription() ?? "NONE"
        return "Performing \(ops). Description: \(description)"
    }
}
