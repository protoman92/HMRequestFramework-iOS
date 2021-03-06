//
//  HMCDManager+Upsert+Rx.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 11/8/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift
import SwiftUtilities

// Private extension utility here.
fileprivate extension NSManagedObject {

  /// Update inner properties using a HMCDKeyValueUpdatableType.
  ///
  /// - Parameter obj: A HMCDKeyValueRepresentableType instance.
  fileprivate func update(from obj: HMCDKeyValueRepresentableType) {
    let dict = obj.updateDictionary()

    for (key, value) in dict {
      setValue(value, forKey: key)
    }
  }
}

public extension HMCDManager {

  /// Update upsertables and get results, including those from new object
  /// insertions.
  ///
  /// - Parameters:
  ///   - context: A Context instance.
  ///   - entityName: A String value. representing the entity's name.
  ///   - upsertables: A Sequence of upsertable objects.
  /// - Returns: An Array of HMResult.
  /// - Throws: Exception if the conversion fails.
  func convert<S>(_ context: Context,
                  _ entityName: String,
                  _ upsertables: S) throws -> [HMCDResult] where
    S: Sequence, S.Element == HMCDUpsertableType
  {
    let upsertables = upsertables.sorted(by: {$0.compare(against: $1)})
    let ids: [HMCDIdentifiableType] = upsertables
    var objects = try blockingFetchIdentifiables(context, entityName, ids)
    var results: [HMCDResult] = []

    // We need an Array here to keep track of the objects that do not exist
    // in DB yet.
    var nonExisting: [HMCDObjectConvertibleType] = []

    for upsertable in upsertables {
      if
        let index = objects.index(where: upsertable.identifiable),
        let item = objects.element(at: index)
      {
        let representation = upsertable.stringRepresentationForResult()
        item.update(from: upsertable)
        results.append(HMCDResult.just(representation))
        objects.remove(at: index)
      } else {
        nonExisting.append(upsertable)
      }
    }

    // In the conversion step, the NSManagedObject instances are
    // reconstructed and inserted into the specified context. When
    // we call context.save(), they will also be committed to
    // memory.
    results.append(contentsOf: self.convert(context, nonExisting))

    return results
  }

  /// Update upsertables and get results, including those from new object
  /// insertions.
  ///
  /// - Parameters:
  ///   - context: A Context instance.
  ///   - entityName: A String value. representing the entity's name.
  ///   - upsertables: A Sequence of upsertable objects.
  /// - Returns: An Array of HMResult.
  /// - Throws: Exception if the conversion fails.
  func convert<U,S>(_ context: Context,
                    _ entityName: String,
                    _ upsertables: S) throws -> [HMCDResult] where
    U: HMCDUpsertableType,
    S: Sequence, S.Element == U
  {
    let upsertables = upsertables.map({$0 as HMCDUpsertableType})
    return try self.convert(context, entityName, upsertables)
  }
}

public extension HMCDManager {

  /// Perform an upsert operation for some upsertable data. For items that
  /// do not exist in the DB yet, we simply insert them.
  ///
  /// This method does not attemp to perform any version control - it is
  /// assumed that the data that are passed in do not require such feature.
  ///
  /// - Parameters:
  ///   - context: A Context instance.
  ///   - entityName: A String value. representing the entity's name.
  ///   - upsertables: A Sequence of upsertable objects.
  ///   - opMode: A HMCDOperationMode instance.
  ///   - obs: An ObserverType instance.
  /// - Returns: A Disposable instance.
  func upsert<S,O>(_ context: Context,
                   _ entityName: String,
                   _ upsertables: S,
                   _ opMode: HMCDOperationMode,
                   _ obs: O) -> Disposable where
    S: Sequence,
    S.Element == HMCDUpsertableType,
    O: ObserverType,
    O.E == [HMCDResult]
  {
    Preconditions.checkNotRunningOnMainThread(upsertables)

    performOperation(opMode, {
      let upsertables = upsertables.map({$0})

      if !upsertables.isEmpty {
        do {
          let results = try self.convert(context, entityName, upsertables)
          try self.saveUnsafely(context)
          obs.onNext(results)
          obs.onCompleted()
        } catch let e {
          obs.onError(e)
        }
      } else {
        obs.onNext([])
        obs.onCompleted()
      }
    })

    return Disposables.create()
  }

  /// Perform an upsert operation for some upsertable data. For items that
  /// do not exist in the DB yet, we simply insert them.
  ///
  /// - Parameters:
  ///   - context: A Context instance.
  ///   - entityName: A String value. representing the entity's name.
  ///   - upsertables: A Sequence of upsertable objects.
  ///   - opMode: A HMCDOperationMode instance.
  ///   - obs: An ObserverType instance.
  /// - Returns: A Disposable instance.
  func upsert<U,S,O>(_ context: Context,
                     _ entityName: String,
                     _ upsertables: S,
                     _ opMode: HMCDOperationMode,
                     _ obs: O) -> Disposable where
    U: HMCDUpsertableType,
    S: Sequence,
    S.Element == U,
    O: ObserverType,
    O.E == [HMCDResult]
  {
    let upsertables = upsertables.map({$0 as HMCDUpsertableType})
    return upsert(context, entityName, upsertables, opMode, obs)
  }
}

extension Reactive where Base == HMCDManager {

  /// Perform an upsert request on a Sequence of upsertable objects.
  ///
  /// - Parameters:
  ///   - context: A Context instance.
  ///   - entityName: A String value. representing the entity's name.
  ///   - upsertables: A Sequence of upsertable objects.
  ///   - opMode: A HMCDOperationMode instance.
  /// - Returns: An Observable instane.
  func upsert<S>(_ context: HMCDManager.Context,
                 _ entityName: String,
                 _ upsertables: S,
                 _ opMode: HMCDOperationMode = .queued)
    -> Observable<[HMCDResult]> where
    S: Sequence, S.Element == HMCDUpsertableType
  {
    return Observable.create({
      self.base.upsert(context, entityName, upsertables, opMode, $0)
    })
  }

  /// Perform an upsert request on a Sequence of upsertable objects.
  ///
  /// - Parameters:
  ///   - context: A Context instance.
  ///   - entityName: A String value. representing the entity's name.
  ///   - upsertables: A Sequence of upsertable objects.
  ///   - opMode: A HMCDOperationMode instance.
  /// - Returns: An Observable instane.
  func upsert<U,S>(_ context: HMCDManager.Context,
                   _ entityName: String,
                   _ upsertables: S,
                   _ opMode: HMCDOperationMode = .queued)
    -> Observable<[HMCDResult]> where
    U: HMCDUpsertableType,
    S: Sequence,
    S.Element == U
  {
    return upsert(context,
                  entityName,
                  upsertables.map({$0 as HMCDUpsertableType}),
                  opMode)
  }
}
