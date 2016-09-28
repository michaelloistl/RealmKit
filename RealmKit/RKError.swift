//
//  RKError.swift
//  RealmKit
//
//  Created by Michael Loistl on 23/09/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public enum RKError: Error {
    
    // JSONSerilizer
    public enum JSONSerilizerFailureReason {
        case invalidPrimaryKey
        case noJsonKeyPathsByPropertyKey(type: Object.Type)
        case noPrimaryKeyValue(type: Object.Type?, jsonDictionary: [String: Any]?, jsonKeyPathsByPropertyKey: [String : String]?, keyValues: [String: AnyObject]?)
    }
    
    //
    
    // Fetch
    public enum FetchFailureReason {
        
    }
    
    // Sync
    public enum SyncFailureReason {
        
    }
    
}

// MARK: - Error Descriptions

extension RKError.JSONSerilizerFailureReason {
    var localizedDescription: String {
        switch self {
        case .invalidPrimaryKey:
            return "Type doesn't define a valid primaryKey."
        case .noJsonKeyPathsByPropertyKey(type):
            return "Type \(type) doesn't define valid jsonKeyPathsByPropertyKey."
        case .noPrimaryKeyValue(type, jsonDictionary, jsonKeyPathsByPropertyKey, keyValues):
            return "Type \(type) has no primary key value; jsonDictionary: \(jsonDictionary) jsonKeyPathsByPropertyKey: \(jsonKeyPathsByPropertyKey) keyValues: \(keyValues)."
        }
    }
}
