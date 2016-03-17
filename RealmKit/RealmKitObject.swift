//
//  RealmKitObject.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public protocol RealmKitObjectProtocol {

    // MARK: - Properties
    
    var id: String { get set }
    var deletedAt: NSTimeInterval { get set }
    
    var server_id: String { get set }
    var server_deletedAt: NSTimeInterval { get set }

    // MARK: - Methods
    
    // MARK: Required
    
    static func primaryKey() -> String?
    
    static func defaultPropertyValues() -> [String: AnyObject]
    
    static func baseURL() -> NSURL!
    
    static func requestWithBaseURL(baseURL: NSURL, path: String, parameters: [String: AnyObject]?, method: RealmKit.Method, completion: (success: Bool, request: NSURLRequest!, response: NSHTTPURLResponse!, jsonResponse: AnyObject?, error: NSError?) -> Void) -> NSURLSessionTask?
    
    static func handleRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, jsonResponse: AnyObject?, error: NSError!, fetchOperation: RealmFetchOperation?, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
}

public class RealmKitObject: Object, RealmKitObjectProtocol, RealmJSONSerializable, RealmFetchable, RealmFetchPagable, RealmSyncable {
    
    // MARK: - Properties
    
    // MARK: RealmKitObjectProtocol
    
    public dynamic var id: String = NSUUID().UUIDString
    public dynamic var deletedAt: NSTimeInterval = 0
    
    public dynamic var server_id: String = ""
    public dynamic var server_deletedAt: NSTimeInterval = 0
    
    // MARK: RealmFetchable
    
    public dynamic var lastFetchedAt: NSDate?
    
    // MARK: RealmSyncable
    
    public dynamic var lastSyncedAt: NSDate?
    public dynamic var syncStatus: String = RealmSyncManager.SyncStatus.Synced.rawValue
    public dynamic var syncIdentifier: String?
    
    // MARK: - Protocols
    
    // MARK: RealmKitObjectProtocol
    
    public override class func primaryKey() -> String? {
        return "id"
    }
    
    public class func defaultPropertyValues() -> [String: AnyObject] {
        return [
            "id": NSUUID().UUIDString,
            "deletedAt": 0,
            "server_id": "",
            "server_deletedAt": 0,
            
            "syncStatus": RealmSyncManager.SyncStatus.Synced.rawValue,
            "syncIdentifier": ""
        ]
    }
    
    public class func baseURL() -> NSURL! {
        print("# RealmKit: Please override baseURL in \(self)")
        
        return nil
    }
    
    public class func requestWithBaseURL(baseURL: NSURL, path: String, parameters: [String: AnyObject]?, method: RealmKit.Method, completion: (success: Bool, request: NSURLRequest!, response: NSHTTPURLResponse!, jsonResponse: AnyObject?, error: NSError?) -> Void) -> NSURLSessionTask? {

        print("# RealmKit: Please override requestWithBaseURL:path:parameters:method:completion: in \(self)")
        
        return nil
    }
    
    public class func handleRequest(request: NSURLRequest!, response: NSHTTPURLResponse!, jsonResponse: AnyObject?, error: NSError!, fetchOperation: RealmFetchOperation?, syncOperation: RealmSyncOperation?, inRealm realm: Realm?) {
        
        print("# RealmKit: Please override handleRequest:response:jsonResponse:error:fetchOperation:syncOperation:inRealm: in \(self)")
    }
    
    // MARK: RealmJSONSerializable
    
    public class func JSONKeyPathsByPropertyKey(serializationInfo: SerializationInfo) -> [String : String]! {
        print("# RealmKit: Please override JSONKeyPathsByPropertyKey: in \(self)")
        
        return nil
    }
    
    public class func JSONTransformerForKey(key: String!, serializationInfo: SerializationInfo) -> NSValueTransformer! {
        print("# RealmKit: Please override JSONTransformerForKey: in \(self)")
        
        return nil
    }
    
    // Optional
    public class func classForParsingJSONDictionary(JSONDictionary: NSDictionary) -> Object.Type {
        return self
    }
    
    // Optional
    public class func didCreateOrUpdateRealmObject(serializationInfo: SerializationInfo?) {
        if let newPrimaryKey = serializationInfo?.newPrimaryKey, oldPrimaryKey = serializationInfo?.oldPrimaryKey, realm = serializationInfo?.realm {
            
            // Setting syncIdentifier on newObject
            if var newObject = realm.objectForPrimaryKey(self, key: newPrimaryKey) as? RealmJSONSerializable, oldObject = realm.objectForPrimaryKey(self, key: oldPrimaryKey) as? RealmJSONSerializable {
                
                newObject.syncIdentifier = oldObject.syncIdentifier
            }
            
            // Old and New Objects are the same (PUT, DELETE)
            if newPrimaryKey == oldPrimaryKey {
                if let newObject = realm.objectForPrimaryKey(self, key: newPrimaryKey) as? RealmJSONSerializable {
                    
                    // Update syncIdentifier
                    if let syncIdentifier = serializationInfo?.syncOperation?.syncIdentifier {
                        newObject.removeSyncIdentifier(syncIdentifier)
                    }
                    
                    // setSyncStatus only if there is no syncIdentifier left
                    if newObject.syncIdentifiers().count == 0 {
                        newObject.setSyncStatus(.Synced)
                    }
                }
            }
                
            // Old and New Objects are different (POST)
            else {
                
                // Set SyncStatus to "Synced" for initial (old) object
                if var oldObject = realm.objectForPrimaryKey(self, key: oldPrimaryKey) as? RealmJSONSerializable {
                    
                    // Update syncIdentifier
                    if let syncIdentifier = serializationInfo?.syncOperation?.syncIdentifier {
                        oldObject.removeSyncIdentifier(syncIdentifier)
                    }
                    
                    // setSyncStatus only if there is no syncIdentifier left
                    if oldObject.syncIdentifiers().count == 0 {
                        oldObject.setSyncStatus(.Synced)
                    }
                    
                    // Mark temp object deleted
                    oldObject.deletedAt = NSDate().timeIntervalSince1970
                }
                
                // Set SyncStatus to "Synced" for new object
                if let newObject = realm.objectForPrimaryKey(self, key: newPrimaryKey) as? RealmJSONSerializable {
                    
                    // Update syncIdentifier
                    if let syncIdentifier = serializationInfo?.syncOperation?.syncIdentifier {
                        newObject.removeSyncIdentifier(syncIdentifier)
                    }
                    
                    // setSyncStatus only if there is no syncIdentifier left
                    if newObject.syncIdentifiers().count == 0 {
                        newObject.setSyncStatus(.Synced)
                    }
                }
            }
        }
    }
    
    public class func keyValueDictionaryWithPrimaryKeyValue(primaryKeyValue: String) -> [String : String]? {
        return nil
    }
    
    public class func keyValueDictionaryForRealmObjectWithType<T: Object>(type: T.Type, withJSONDictionary dictionary: NSDictionary, keyValueDictionary: [String: AnyObject], serializationInfo: SerializationInfo?) -> [String: AnyObject] {
        return keyValueDictionary
    }
    
    public class func modifiedRealmObject(realmObject: Object, withJSONDictionary dictionary: NSDictionary, keyValueDictionary: [String: AnyObject], serializationInfo: SerializationInfo?) -> Object? {
        return realmObject
    }
    
    public class func shouldCreateOrUpdateRealmObjectWithType<T: Object>(type: T.Type, primaryKey: String, serializationInfo: SerializationInfo?) -> Bool {
        return true
    }
    
    // MARK: RealmFetchable
    
    public class func realmFetchWillSerializeJSON(json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm) {
        
    }
    
    public class func realmFetchDidSerializeJSON(json: AnyObject, fetchRequest: FetchRequest, jsonResponse: AnyObject?, realmObjectInfos: [RealmObjectInfo]?, inRealm realm: Realm) {
        
    }
    
    // MARK: RealmFetchPagable
    
    public class func pagingParametersForFetchRequest(fetchRequest: FetchRequest, pageType: PageInfo.PageType) -> [String: AnyObject]? {
        print("# RealmKit: Please override pagingParametersForFetchRequest:pageType: in \(self)")
        
        return nil
        
//        if pageType == .Next {
//            var lastSynced: NSTimeInterval = 0
//            if let pageableType = type as? RealmFetchPagable.Type, lastSyncedTimeInterval = pageableType.lastSyncedTimeIntervalForFetchRequest(fetchRequest) {
//                lastSynced = lastSyncedTimeInterval
//            }
//            let lastSyncedTimeInterval = (lastSynced > 0) ? lastSynced : lastSyncedFallback
//            let timeInterval = from ?? lastSyncedTimeInterval
//            
//            parameters["timestamp"] = NSNumber(double: timeInterval)
//            
//            //                NSLog("startRequest .Next path: \(self.fetchInfo.path) lastSynced: \(lastSynced) parameters: \(parameters)")
//        } else if pageType == .Previous {
//            let timeInterval = from ?? NSDate().timeIntervalSince1970
//            parameters["backwards_from"] = NSNumber(double: timeInterval)
//            
//            //                NSLog("startRequest .Previous path: \(self.fetchInfo.path) parameters: \(parameters)")
//        }

    }
    
    public class func realmFetchPageInfoFromResponse(response: NSHTTPURLResponse?, jsonResponse: AnyObject?) -> PageInfo? {
        print("# RealmKit: Please override realmFetchPageInfoFromResponse:jsonResponse: in \(self)")
        
        return nil
        
//        if let jsonDictionary = jsonResponse as? [String: AnyObject], pageInfo = jsonDictionary["page_info"] as? [String: AnyObject] {
//            
//            let currentPageNumber = pageInfo["current_page"] as? NSNumber
//            let currentPage = currentPageNumber?.integerValue ?? 0
//            
//            let totalPagesNumber = pageInfo["total_pages"] as? NSNumber
//            let totalPages = totalPagesNumber?.integerValue ?? 0
//            
//            let totalItemsNumber = pageInfo["total_items"] as? NSNumber
//            let totalItems = totalItemsNumber?.integerValue ?? 0
//            
//            var previousPageURL: NSURL?
//            if let previousPageUrl = pageInfo["previous_page_url"] as? String {
//                previousPageURL = NSURL(string: previousPageUrl)
//            }
//            
//            var nextPageURL: NSURL?
//            if let nextPageUrl = pageInfo["next_page_url"] as? String {
//                nextPageURL = NSURL(string: nextPageUrl)
//            }
//            
//            return PageInfo(currentPage: currentPage, totalPages: totalPages, totalItems: totalItems, previousPageURL: previousPageURL, nextPageURL: nextPageURL, jsonResponse: jsonResponse as? [String: AnyObject])
//        }

    }
    
    // MARK: RealmSyncable
    
    public func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus) {
        if !invalidated {
            self.syncStatus = syncStatus.rawValue
        }
    }
    
    public func realmSyncOperations() -> [RealmSyncOperation] {
        var syncOperations = [RealmSyncOperation]()
        
        let objectType = self.dynamicType
        let primaryKey = id
        let method = realmSyncMethod()
        let baseURL = objectType.baseURL()
        let parameters = realmSyncParameters(method)
        let path = realmSyncPath(method)
        
        if let path = path {
            let syncOperation = RealmSyncOperation(objectType: objectType, primaryKey: primaryKey, baseURL: baseURL, path: path, parameters: parameters, method: method)
            
            syncOperations.append(syncOperation)
        }
        
        return syncOperations
    }
    
    public func realmSyncMethod() -> RealmKit.Method! {
        if deletedAt > 0 {
            return .DELETE
        } else {
            if id == server_id {
                return .PUT
            } else {
                return .POST
            }
        }
    }
    
    public func realmSyncPath(method: RealmKit.Method) -> String? {
        print("# RealmKit: Please override realmSyncPath: in \(self)")
        
        return nil
    }
    
    public func realmSyncParameters(method: RealmKit.Method) -> [String: AnyObject]? {
        print("# RealmKit: Please override realmSyncParameters: in \(self)")
        
        return nil
    }
    
    public class func realmSyncJSONResponseKey(method: RealmKit.Method, identifier: String? = nil) -> String? {
        print("# RealmKit: Please override realmSyncJSONResponseKey:identifier: in \(self)")
        
        return nil
    }
    
    public func addSyncIdentifier(syncIdentifier: String) {
        
    }
    
    public func removeSyncIdentifier(syncIdentifier: String) {
        
    }
    
    public func syncIdentifiers() -> [String] {
        return syncIdentifier?.componentsSeparatedByString(",") ?? [String]()
    }
    
    public class func realmSyncOperationDidSync(sender: RealmSyncOperation, inRealm realm: Realm, oldPrimaryKey: String?, newPrimaryKey: String?) {
        
    }
}