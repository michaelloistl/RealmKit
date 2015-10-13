//
//  RealmSyncObject.swift
//  RealmKit
//
//  Created by Michael Loistl on 13/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public class RealmSyncObject: Object {
    
    // Properties
    
    public dynamic var id: String = NSUUID().UUIDString
    public dynamic var syncStatus: String = RealmSyncManager.SyncStatus.Synced.rawValue
    public dynamic var deletedAt: NSTimeInterval = 0
    
    public dynamic var server_id: String = ""
    public dynamic var server_deletedAt: NSTimeInterval = 0
    
    // MARK: - RealmSwift
    
    override public class func primaryKey() -> String? {
        return "id"
    }
    
    // MARK: - Methods
    
    public class func hasPrimaryKey() -> Bool {
        if let primaryKey = primaryKey() where primaryKey.characters.count > 0 {
            return true
        }
        return false
    }
    
    public func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus) {
        self.syncStatus = syncStatus.rawValue
    }
    
    // MARK: JSONSerializer
    
    public class func defaultPropertyValues() -> [String: AnyObject] {
        return [
            "id": NSUUID().UUIDString,
            "syncStatus": RealmSyncManager.SyncStatus.Synced.rawValue,
            "deletedAt": 0,
            "server_id": "",
            "server_deletedAt": 0
        ]
    }
    
    public class func classForParsingJSONDictionary(JSONDictionary: NSDictionary) -> RealmSyncObject.Type {
        return self
    }
    
    public class func JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier: String?, identifier: String?) -> [String : String]! {
        return nil
    }
    
    public class func JSONTransformerForKey(key: String!, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer! {
        return nil
    }
    
    public class func keyValueDictionaryWithPrimaryKeyValue(primaryKeyValue: String) -> [String : String]? {
        return nil
    }
    
    // MARK: CreateOrUpdate objects with JSON Array
    
    public class func realmObjectsInRealm(realm: Realm,  withJSONArray array: NSArray, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        realmObjectsInRealm(realm, withJSONArray: array, mappingIdentifier: nil, identifier: nil) { (realmObjectInfos, error) -> Void in
            
            completion(realmObjectInfos: realmObjectInfos, error: error)
        }
    }
    
    public class func realmObjectsInRealm(realm: Realm,  withJSONArray array: NSArray, mappingIdentifier: String?, identifier: String?, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfos = [RealmObjectInfo]()
            
            realm.write({ () -> Void in
                for object in array {
                    if let dictionary = object as? NSDictionary {
                        let type = classForParsingJSONDictionary(dictionary)
                        
                        if let realmObject = self.realmObjectWithType(type.self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                            
                            if let primaryKey = type.primaryKey() {
                                if let primaryKey = realmObject.valueForKey(primaryKey) as? String {
                                    let realmObjectInfo = RealmObjectInfo(type: self, primaryKey: primaryKey)
                                    completionRealmObjectInfos.append(realmObjectInfo)
                                }
                            }
                        }
                    }
                }
            })
            
            completion(realmObjectInfos: completionRealmObjectInfos, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfos: nil, error: error)
        }
    }
    
    // MARK: CreateOrUpdate object with JSON Dictionary
    
    public class func realmObjectInRealm(realm: Realm, withJSONDictionary dictionary: NSDictionary, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        realmObjectInRealm(realm, withJSONDictionary: dictionary, mappingIdentifier: nil, identifier: nil, replacingObjectWithPrimaryKey: nil) { (realmObjectInfo, error) -> Void in
            completion(realmObjectInfo: realmObjectInfo, error: error)
        }
    }
    
    public class func realmObjectInRealm(realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfo: RealmObjectInfo?
            
            realm.write({ () -> Void in
                let type = classForParsingJSONDictionary(dictionary)
                
                if let realmObject = self.realmObjectWithType(type.self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                    
                    if let primaryKey = type.primaryKey() {
                        if let newPrimaryKey = realmObject.valueForKey(primaryKey) as? String {
                            let realmObjectInfo = RealmObjectInfo(type: self, primaryKey: newPrimaryKey)
                            completionRealmObjectInfo = realmObjectInfo
                            
                            // Did create RealmObject in transactionWithBlock
                            didCreateOrUpdateRealmSyncObjectInRealm(realm, withPrimaryKey: newPrimaryKey, replacingObjectWithPrimaryKey: oldPrimaryKey)
                        }
                    }
                }
            })
            
            completion(realmObjectInfo: completionRealmObjectInfo, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfo: nil, error: error)
        }
    }
    
    // This function executes within the transaction block of realmObjectInRealm()
    // Override to modify initial and new RealmObject within the same transaction block
    public class func didCreateOrUpdateRealmSyncObjectInRealm(realm: Realm, withPrimaryKey newPrimaryKey: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?) {
        
    }
    
    // CreateOrUpdate RealmObject with mapping
    public class func realmObjectWithType<T: RealmSyncObject>(type: T.Type, inRealm realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?) -> RealmSyncObject? {
        
        // Object key -> JSON keyPath
        if let mappingDictionary = JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier, identifier: identifier) {
            var keyValueDictionary = [String: AnyObject]()
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue: AnyObject = dictionary.valueForKeyPath(keyPath) {
                    if let _ = jsonValue as? NSNull {
                        
                        // Default Value if it's not primary key
                        if let primaryKey = (type as RealmSyncObject.Type).primaryKey() {
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
            
            if let primaryKey = (type as RealmSyncObject.Type).primaryKey(), _ = keyValueDictionary[primaryKey] as? String {
                return realm.create(type.self, value: keyValueDictionary, update: true)
            }
        }
        
        return nil
    }
}