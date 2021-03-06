//
//  HMUpsertableType.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 31/7/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

/// Classes that implement this protocol must provide the required information
/// to identify its instances in a DB.
public protocol HMIdentifiableType {
    
    /// Get a uniquely identifiable key to perform database lookup for existing
    /// records.
    ///
    /// - Returns: A String value.
    func primaryKey() -> String
    
    /// Get the corresponding value for the primary key.
    ///
    /// - Returns: A String value.
    func primaryValue() -> String?
}

public extension HMIdentifiableType {
    
    /// Check if the current identifiable object is identifiable as another
    /// identifiable object.
    ///
    /// - Parameter object: A HMIdentifiableType instance.
    /// - Returns: A Bool value.
    public func identifiable(as object: HMIdentifiableType) -> Bool {
        return primaryKey() == object.primaryKey() && primaryValue() == object.primaryValue()
    }
}
