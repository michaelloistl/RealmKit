//
//  RealmJSONSerializerProtocol.swift
//  RealmKit
//
//  Created by Michael Loistl on 20/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmFetchObjectCompletionBlock = (request: NSURLRequest!, response: NSHTTPURLResponse!, success: Bool, responseObject: AnyObject?, realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void

public typealias RealmFetchObjectsCompletionBlock = (request: NSURLRequest!, response: NSHTTPURLResponse!, success: Bool, responseObject: AnyObject?, realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void

public protocol RealmFetchable {

    static func realmFetchBaseURL() -> NSURL!
    static func realmFetchPath() -> String!
    static func realmFetchParameters() -> [String: AnyObject]?
    static func realmFetchResponseObjectKeyForPath(path: String, identifier: String?) -> String?
    
    // Serializing
    
    static func realmFetchWillSerializeJSON(json: AnyObject, mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?, inRealm realm: Realm, completion: () -> Void)

    static func realmFetchDidSerializeJSON(json: AnyObject, realmObjectInfos: [RealmObjectInfo]?, mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?, inRealm realm: Realm, completion: () -> Void)
    
    // Networking
    
    static func realmRequestWithBaseURL(baseURL: NSURL, path: String, parameters: [String: AnyObject]?, method: RealmKit.Method, completion: (success: Bool, request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError?) -> Void)

    static func handleRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError!, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
    
    static func handleSuccessfulRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError!, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
    
    static func handleFailedRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError!, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
}

public protocol RealmSyncable {
    
    func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus)
    
    func realmSyncOperations() -> [RealmSyncOperation]
    func realmSyncOperationMethod() -> RealmKit.Method!
    func realmSyncOperationPathForMethod(method: RealmKit.Method) -> String?
    func realmSyncOperationParametersForMethod(method: RealmKit.Method) -> [String: AnyObject]?
    
    static func realmSyncOperation(sender: RealmSyncOperation, responseObjectKeyForMethod method: RealmKit.Method, identifier: String?) -> String?
    static func realmSyncOperationDidSync(sender: RealmSyncOperation, inRealm realm: Realm, oldPrimaryKey: String?, newPrimaryKey: String?, completion: () -> Void)
    
    // Networking
    
    static func realmRequestWithBaseURL(baseURL: NSURL, path: String, parameters: [String: AnyObject]?, method: RealmKit.Method, completion: (success: Bool, request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError?) -> Void)
    
    static func handleRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError!, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
    
    static func handleSuccessfulRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError!, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
    
    static func handleFailedRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, responseObject: AnyObject?, error: NSError!, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
}

public protocol RealmJSONSerializable {

    // Properties
    
    var id: String { get set }
    var syncStatus: String { get set }
    var deletedAt: NSTimeInterval { get set }
    
    var server_id: String { get set }
    var server_deletedAt: NSTimeInterval { get set }
    
    // Methods
    
    func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus)
    static func primaryKey() -> String?
    static func defaultPropertyValues() -> [String: AnyObject]
    static func JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier: String?, identifier: String?) -> [String : String]!
    static func JSONTransformerForKey(key: String!, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer!

    static func classForParsingJSONDictionary(JSONDictionary: NSDictionary) -> Object.Type
    static func keyValueDictionaryWithPrimaryKeyValue(primaryKeyValue: String) -> [String : String]?
    
    static func didCreateOrUpdateRealmObjectInRealm(realm: Realm, withPrimaryKey newPrimaryKey: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?)
    
    static func keyValueDictionaryForRealmObjectWithType<T: Object>(type: T.Type, withJSONDictionary dictionary: NSDictionary, keyValueDictionary: [String: AnyObject], mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?, inRealm realm: Realm) -> [String: AnyObject]
}

public extension RealmFetchable where Self: RealmJSONSerializable {

    public static func realmFetchObjectsInRealm(realm: Realm, userInfo: [String: AnyObject]? = nil, completion: RealmFetchObjectsCompletionBlock) {
        if let baseURL = realmFetchBaseURL(), path = realmFetchPath() {
            let parameters = realmFetchParameters()
            
            realmFetchObjectsWithBaseURL(baseURL, path: path, parameters: parameters, mappingIdentifier: nil, identifier: nil, userInfo: userInfo, inRealm: realm, completion: { (request, response, success, responseObject, realmObjectInfos, error) -> Void in
                
                completion(request: request, response: response, success: success, responseObject: responseObject, realmObjectInfos: realmObjectInfos, error: error)
            })
        }
    }
    
    public static func realmFetchObjectWithBaseURL(baseURL: NSURL, path: String, parameters: [String: AnyObject]?, mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?, inRealm realm: Realm, completion: RealmFetchObjectCompletionBlock) {
        
        realmFetchObjectsWithBaseURL(baseURL, path: path, parameters: parameters, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo, inRealm: realm) { (request, response, success, responseObject, realmObjectInfos, error) -> Void in
         
            completion(request: request, response: response, success: success, responseObject: responseObject, realmObjectInfo: realmObjectInfos?.first, error: error)
        }
    }
    
    public static func realmFetchObjectsWithBaseURL(baseURL: NSURL, path: String, parameters: [String: AnyObject]?, mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?, inRealm realm: Realm, completion: RealmFetchObjectsCompletionBlock) {

        let dispatchGroup = dispatch_group_create()
        
        var completionSuccess = false
        var completionRequest: NSURLRequest?
        var completionResponse: NSHTTPURLResponse?
        var completionResponseObject: AnyObject?
        var completionRealmObjectInfos: [RealmObjectInfo]?
        var completionError: NSError?
        
        dispatch_group_enter(dispatchGroup)
        realmRequestWithBaseURL(baseURL, path: path, parameters: parameters, method: .GET) { (success, request, response, responseObject, error) -> Void in
            completionSuccess = success
            completionRequest = request
            completionResponse = response
            completionResponseObject = responseObject
            completionError = error
            
            var json: AnyObject?
            
            // responseObject - [String: AnyObject]
            if let responseDictionary = responseObject as? [String: AnyObject] {
                if let responseObjectKey = self.realmFetchResponseObjectKeyForPath(path, identifier: identifier) {
                    json = responseDictionary[responseObjectKey]
                } else {
                    json = responseDictionary
                }
            }
            
            // responseObject - [AnyObject]
            else if let responseArray = responseObject as? [AnyObject] {
                json = responseArray
            }

            if let json = json {                
                dispatch_group_enter(dispatchGroup)
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), { () -> Void in
                    var realm: Realm!
                    
                    do {
                        try realm = Realm()
                    } catch let error as NSError {
                        NSLog("Realm error: \(error)")
                    }
                    
                    if let realm = realm {
                        
                        // Will Serialize
                        dispatch_group_enter(dispatchGroup)
                        realmFetchWillSerializeJSON(json, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo, inRealm: realm, completion: { () -> Void in
                            dispatch_group_leave(dispatchGroup)
                        })
                        
                        // Array
                        if let jsonArray = json as? NSArray {
                            dispatch_group_enter(dispatchGroup)
                            realmObjectsInRealm(realm, withJSONArray: jsonArray, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo, completion: { (realmObjectInfos, error) -> Void in
                                
                                completionRealmObjectInfos = realmObjectInfos
                                
                                // Did Serialize
                                dispatch_group_enter(dispatchGroup)
                                realmFetchDidSerializeJSON(json, realmObjectInfos: realmObjectInfos, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo, inRealm: realm, completion: { () -> Void in
                                    
                                    dispatch_group_leave(dispatchGroup)
                                })
                                
                                dispatch_group_leave(dispatchGroup)
                            })
                        }
                        
                        // Dictionary
                        if let jsonDictionary = json as? NSDictionary {
                            dispatch_group_enter(dispatchGroup)
                            self.realmObjectInRealm(realm, withJSONDictionary: jsonDictionary, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo, replacingObjectWithPrimaryKey: nil, completion: { (realmObjectInfo, error) -> Void in
                                
                                if let realmObjectInfo = realmObjectInfo {
                                    completionRealmObjectInfos = [realmObjectInfo]
                                }
                                
                                // Did Serialize
                                dispatch_group_enter(dispatchGroup)
                                realmFetchDidSerializeJSON(json, realmObjectInfos: completionRealmObjectInfos, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo, inRealm: realm, completion: { () -> Void in
                                    
                                    dispatch_group_leave(dispatchGroup)
                                })
                                
                                dispatch_group_leave(dispatchGroup)
                            })
                        }
                    }
                    
                    dispatch_group_leave(dispatchGroup)
                })
            }
            
            dispatch_group_leave(dispatchGroup)
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), {
            handleRequest(completionRequest, response: completionResponse, responseObject: completionResponseObject, error: completionError, syncOperation: nil, inRealm: nil)
            
            if completionSuccess {
                handleSuccessfulRequest(completionRequest, response: completionResponse, responseObject: completionResponseObject, error: completionError, syncOperation: nil, inRealm: nil)
            } else {
                handleFailedRequest(completionRequest, response: completionResponse, responseObject: completionResponseObject, error: completionError, syncOperation: nil, inRealm: nil)
            }
            
            completion(request: completionRequest, response: completionResponse, success: completionSuccess, responseObject: completionResponseObject, realmObjectInfos: completionRealmObjectInfos, error: completionError)
        })
    }
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
        realmObjectsInRealm(realm, withJSONArray: array, mappingIdentifier: nil, identifier: nil, userInfo: nil) { (realmObjectInfos, error) -> Void in
            
            completion(realmObjectInfos: realmObjectInfos, error: error)
        }
    }
    
    public static func realmObjectsInRealm(realm: Realm,  withJSONArray array: NSArray, mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfos = [RealmObjectInfo]()
            
            do {
                try realm.write({ () -> Void in
                    for object in array {
                        if let dictionary = object as? NSDictionary {
                            let type = classForParsingJSONDictionary(dictionary)
                            
                            if let realmObject = self.realmObjectWithType(type.self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo) {
                                
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
        
        realmObjectInRealm(realm, withJSONDictionary: dictionary, mappingIdentifier: nil, identifier: nil, userInfo: nil, replacingObjectWithPrimaryKey: nil) { (realmObjectInfo, error) -> Void in
            completion(realmObjectInfo: realmObjectInfo, error: error)
        }
    }
    
    public static func realmObjectInRealm(realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?, replacingObjectWithPrimaryKey oldPrimaryKey: String?, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfo: RealmObjectInfo?
            
            do {
                try realm.write({ () -> Void in
                    let type = classForParsingJSONDictionary(dictionary)
                    
                    if let realmObject = self.realmObjectWithType(type.self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo) {
                        
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
    public static func realmObjectWithType<T: Object>(type: T.Type, inRealm realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?, userInfo: [String: AnyObject]?) -> Object? {
        
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
            
            keyValueDictionary = keyValueDictionaryForRealmObjectWithType(type, withJSONDictionary: dictionary, keyValueDictionary: keyValueDictionary, mappingIdentifier: mappingIdentifier, identifier: identifier, userInfo: userInfo, inRealm: realm)
            
            if let primaryKey = (type as Object.Type).primaryKey(), _ = keyValueDictionary[primaryKey] as? String {
                let realmObject = realm.create(type.self, value: keyValueDictionary, update: true)
                
                return realmObject
            } else {
                NSLog("RealmJSONSerializable Error - There is an issue with the primary key for Type: \(type) Dictionary: \(dictionary) MappingDictionary: \(mappingDictionary)")
            }
        }
        
        return nil
    }
}