//
//  RealmJSONSerializerProtocol.swift
//  RealmKit
//
//  Created by Michael Loistl on 20/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public protocol RealmJSONSerializerProtocol {

    // Properties
    
    var id: String { get set }
    var syncStatus: String { get set }
    var deletedAt: NSTimeInterval { get set }
    
    var server_id: String { get set }
    var server_deletedAt: NSTimeInterval { get set }
    
    // Methods
    
    static func primaryKey() -> String?
    
    func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus)
    static func defaultPropertyValues() -> [String: AnyObject]
    static func classForParsingJSONDictionary(JSONDictionary: NSDictionary) -> Object.Type
    static func JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier: String?, identifier: String?) -> [String : String]!
    static func JSONTransformerForKey(key: String!, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer!
    static func keyValueDictionaryWithPrimaryKeyValue(primaryKeyValue: String) -> [String : String]?
    
    static func didCreateOrUpdateRealmSyncObjectInRealm(realm: Realm, withPrimaryKey newPrimaryKey: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?)
}

public extension RealmJSONSerializerProtocol {
    
    // MARK: - Methods
    
    static func hasPrimaryKey() -> Bool {
        if let primaryKey = primaryKey() where primaryKey.characters.count > 0 {
            return true
        }
        return false
    }
    
    // MARK: CreateOrUpdate objects with JSON Array
    
    public static func realmObjectsInRealm(realm: Realm,  withJSONArray array: NSArray, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        realmObjectsInRealm(realm, withJSONArray: array, mappingIdentifier: nil, identifier: nil) { (realmObjectInfos, error) -> Void in
            
            completion(realmObjectInfos: realmObjectInfos, error: error)
        }
    }
    
    public static func realmObjectsInRealm(realm: Realm,  withJSONArray array: NSArray, mappingIdentifier: String?, identifier: String?, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfos = [RealmObjectInfo]()
            
            do {
                try realm.write({ () -> Void in
                    for object in array {
                        if let dictionary = object as? NSDictionary {
                            let type = classForParsingJSONDictionary(dictionary)
                            
                            if let realmObject = self.realmObjectWithType(type.self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                                
                                if let primaryKey = type.primaryKey() {
                                    if let primaryKey = realmObject.valueForKey(primaryKey) as? String {
                                        let realmObjectInfo = RealmObjectInfo(type: type.self, primaryKey: primaryKey)
                                        completionRealmObjectInfos.append(realmObjectInfo)
                                    }
                                }
                            }
                        }
                    }
                })
            } catch {
                
            }
            
            completion(realmObjectInfos: completionRealmObjectInfos, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfos: nil, error: error)
        }
    }
    
    // MARK: CreateOrUpdate object with JSON Dictionary
    
    public static func realmObjectInRealm(realm: Realm, withJSONDictionary dictionary: NSDictionary, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        realmObjectInRealm(realm, withJSONDictionary: dictionary, mappingIdentifier: nil, identifier: nil, replacingObjectWithPrimaryKey: nil) { (realmObjectInfo, error) -> Void in
            completion(realmObjectInfo: realmObjectInfo, error: error)
        }
    }
    
    public static func realmObjectInRealm(realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfo: RealmObjectInfo?
            
            do {
                try realm.write({ () -> Void in
                    let type = classForParsingJSONDictionary(dictionary)
                    
                    if let realmObject = self.realmObjectWithType(type.self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                        
                        if let primaryKey = type.primaryKey() {
                            if let newPrimaryKey = realmObject.valueForKey(primaryKey) as? String {
                                let realmObjectInfo = RealmObjectInfo(type: type.self, primaryKey: newPrimaryKey)
                                completionRealmObjectInfo = realmObjectInfo
                                
                                // Did create RealmObject in transactionWithBlock
                                didCreateOrUpdateRealmSyncObjectInRealm(realm, withPrimaryKey: newPrimaryKey, replacingObjectWithPrimaryKey: oldPrimaryKey)
                            }
                        }
                    }
                })
            } catch {
                
            }
            
            completion(realmObjectInfo: completionRealmObjectInfo, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfo: nil, error: error)
        }
    }
    
    // This function executes within the transaction block of realmObjectInRealm()
    // Override to modify initial and new RealmObject within the same transaction block
    public static func didCreateOrUpdateRealmSyncObjectInRealm(realm: Realm, withPrimaryKey newPrimaryKey: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?) {
        
    }
    
    // CreateOrUpdate RealmObject with mapping
    public static func realmObjectWithType<T: Object>(type: T.Type, inRealm realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?) -> Object? {
        
        // Object key -> JSON keyPath
        if let mappingDictionary = JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier, identifier: identifier) {
            var keyValueDictionary = [String: AnyObject]()
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue: AnyObject = dictionary.valueForKeyPath(keyPath) {
                    if let _ = jsonValue as? NSNull {
                        
                        // Default Value if it's not primary key
                        if let primaryKey = (type as Object.Type).primaryKey() {
                            if key != primaryKey {
                                if let defaultValue: AnyObject = self.defaultPropertyValues()[key] {
                                    keyValueDictionary[key] = defaultValue
                                }
                            }
                        }
                    } else {
                        
                        // ValueTransformer
                        if let valueTransformer = JSONTransformerForKey(key, inRealm: realm, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                            if let value: AnyObject = valueTransformer.transformedValue(jsonValue) {
                                keyValueDictionary[key] = value
                            }
                        } else {
                            
                            // JSON Value
                            keyValueDictionary[key] = jsonValue
                        }
                    }
                }
            }
            
            if let primaryKey = (type as Object.Type).primaryKey(), _ = keyValueDictionary[primaryKey] as? String {
                let realmObject = realm.create(type.self, value: keyValueDictionary, update: true)
                
//                NSLog("JSONDictionary: \(type) => \(dictionary) => \(keyValueDictionary)")
                
                return realmObject
            }
        }
        
        return nil
    }
}