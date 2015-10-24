//
//  RealmJSONSerializerProtocol.swift
//  RealmKit
//
//  Created by Michael Loistl on 20/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public protocol RealmSyncable {
    
    static func realmSyncOperation(sender: RealmSyncOperation, responseObjectKeyForHTTPMethod httpMethod: RealmSyncOperation.HTTPMethod, identifier: String?) -> String?
    static func realmSyncOperationDidSync(sender: RealmSyncOperation, inRealm realm: Realm, oldPrimaryKey: String?, newPrimaryKey: String?, completion: () -> Void)
    
    func realmSyncOperations() -> [RealmSyncOperation]
    func realmSyncOperationHTTPMethod() -> RealmSyncOperation.HTTPMethod!
    func realmSyncOperationPathForHTTPMethod(httpMethod: RealmSyncOperation.HTTPMethod) -> String?
    func realmSyncOperationParametersForHTTPMethod(httpMethod: RealmSyncOperation.HTTPMethod) -> [String: AnyObject]?
    
    func realmSyncOperationResultWithPath(path: String, parameters: [String: AnyObject]?, httpMethod: RealmSyncOperation.HTTPMethod, completion: (success: Bool, request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError?) -> Void)
    func setSyncStatus(syncStatus: RealmKit.SyncStatus)
    
    func handleFailedRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, error: NSError!, primaryKey: String, inRealm realm: Realm)
}

public protocol RealmJSONSerializable {

    // Properties
    
    var id: String { get set }
    var syncStatus: String { get set }
    var deletedAt: NSTimeInterval { get set }
    
    var server_id: String { get set }
    var server_deletedAt: NSTimeInterval { get set }
    
    // Methods
    
    func setSyncStatus(syncStatus: RealmKit.SyncStatus)
    static func primaryKey() -> String?
    static func defaultPropertyValues() -> [String: AnyObject]
    static func JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier: String?, identifier: String?) -> [String : String]!
    static func JSONTransformerForKey(key: String!, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer!

    static func classForParsingJSONDictionary(JSONDictionary: NSDictionary) -> Object.Type
    static func keyValueDictionaryWithPrimaryKeyValue(primaryKeyValue: String) -> [String : String]?
    
    static func didCreateOrUpdateRealmObjectInRealm(realm: Realm, withPrimaryKey newPrimaryKey: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?)
    
    static func keyValueDictionaryForRealmObjectWithType<T: Object>(type: T.Type, withJSONDictionary dictionary: NSDictionary, keyValueDictionary: [String: AnyObject], mappingIdentifier: String?, identifier: String?, inRealm realm: Realm) -> [String: AnyObject]
}

public extension RealmJSONSerializable {
    
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
                                        
                                        // Did create RealmObject in transactionWithBlock
                                        didCreateOrUpdateRealmObjectInRealm(realm, withPrimaryKey: primaryKey, replacingObjectWithPrimaryKey: nil)
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
                                didCreateOrUpdateRealmObjectInRealm(realm, withPrimaryKey: newPrimaryKey, replacingObjectWithPrimaryKey: oldPrimaryKey)
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
            
            keyValueDictionary = keyValueDictionaryForRealmObjectWithType(type, withJSONDictionary: dictionary, keyValueDictionary: keyValueDictionary, mappingIdentifier: mappingIdentifier, identifier: identifier, inRealm: realm)
            
            if let primaryKey = (type as Object.Type).primaryKey(), _ = keyValueDictionary[primaryKey] as? String {
                let realmObject = realm.create(type.self, value: keyValueDictionary, update: true)
                
//                NSLog("JSONDictionary: \(type) => \(dictionary) => \(keyValueDictionary)")
                
                return realmObject
            }
        }
        
        return nil
    }
}