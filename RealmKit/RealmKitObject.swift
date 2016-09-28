//
//  RealmKitObject.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift
import Alamofire



@available(OSX 10.10, *)
open class RealmKitObject: Object, ObjectProtocol, JSONSerializable, Fetchable, FetchPagable, Syncable {
    
    // MARK: - Properties
    
    // MARK: ObjectProtocol
    
    open dynamic var id: String = UUID().uuidString
    open dynamic var deletedAt: TimeInterval = 0
    
    open dynamic var server_id: String?
    open dynamic var server_deletedAt: TimeInterval = 0
    
    // MARK: Fetchable
    
    open dynamic var lastFetchedAt: Date?
    
    // MARK: Syncable
    
    open dynamic var lastSyncedAt: Date?
    open dynamic var syncStatus: String = RealmSync.SyncStatus.Synced.rawValue
    
    // MARK: - Protocols
    
    // MARK: ObjectProtocol
    
    /// Primary key for local realm objects needs to be "id".
    public override class func primaryKey() -> String? {
        return "id"
    }
    
    open override class func serverKey() -> String? {
        print("# RealmKit: Please override serverKey in \(self)")
        return nil
    }
    
    open class func defaultPropertyValues() -> [String: AnyObject] {
        return [
            "id": UUID().uuidString,
            "deletedAt": 0,
            "server_id": NSNull(),
            "server_deletedAt": 0,
            "syncStatus": RealmSyncManager.SyncStatus.Synced.rawValue
        ]
    }
    
    // MARK: Requestable
    
    /// Returns the base URL that is used for fetch & sync requests.
    open class func baseURL() -> URL! {
        print("# RealmKit: Please override baseURL in \(self)")
        return nil
    }
    
    /// Returns the headers (e.g. authentication) that is used for fetch & sync requests.
    open class func headers() -> [String: String]? {
        print("# RealmKit: Please override headers in \(self)")
        return nil
    }
    
    // MARK: JSONSerializable
    
    /// Returns the json keyPath for a given object property key (mapping).
    open class func jsonKeyPathsByPropertyKey(with serializationRequest: SerializationRequest) -> [String : String]! {
        print("# RealmKit: Please override jsonKeyPathsByPropertyKey: in \(self)")
        return nil
    }
    
    /// Returns the ValueTransformer for a given object property key.
    open class func jsonTransformerForKey(_ key: String!, serializationRequest: SerializationRequest) -> ValueTransformer! {
        print("# RealmKit: Please override jsonTransformerForKey:serializationRequest: in \(self)")
        return nil
    }
    
    /// Returns the type for the realm object to be created/updated during serialization.
    open class func typeToSerialize(_ jsonDictionary: NSDictionary) -> Object.Type {
        return self
    }
    
    // MARK: Fetchable
    
    // MARK: FetchPagable
    
    open class func pageInfo(from fetchResult: FetchResult?) -> PageInfo? {
        print("# RealmKit: Please override pageInfo: in \(self)")
        return nil
    }

    open class func pagingParameters(from pageInfo: PageInfo) -> [String: Any]? {
        print("# RealmKit: Please override pagingParameters: in \(self)")
        return nil
    }
    
    open class func fetchPagedDidFetch(_ fetchPagedResult: FetchPagedResult) {
        
    }
    
    open class func fetchPagedDidComplete(_ fetchPagedResult: FetchPagedResult) {
        
    }
    
    
    
    
    
    
    
    
    
    

    

    
//    open class func didCreateOrUpdateRealmObject(with serializationInfo: SerializationInfo?) {
//        if let newPrimaryKey = serializationInfo?.newPrimaryKey, let oldPrimaryKey = serializationInfo?.oldPrimaryKey, let realm = serializationInfo?.realm {
//            
//            // Old and New Objects are the same (PUT, DELETE)
//            if newPrimaryKey == oldPrimaryKey {
//                if let newObject = realm.object(ofType: self, forPrimaryKey: newPrimaryKey) as? JSONSerializable {
//                    newObject.setSyncStatus(.Synced, serializationInfo: serializationInfo)
//                }
//            }
//                
//            // Old and New Objects are different (POST)
//            else {
//                
//                // Set SyncStatus to "Synced" for initial (old) object
//                if var oldObject = realm.object(ofType:self, forPrimaryKey: oldPrimaryKey) as? JSONSerializable {
//                    oldObject.setSyncStatus(.Synced, serializationInfo: serializationInfo)
//                    
//                    let realmSyncObjectInfo = RealmSyncObjectInfo(type: self, oldPrimaryKey: oldPrimaryKey, newPrimaryKey: newPrimaryKey)
//
//                    DispatchQueue.main.async(execute: { () -> Void in
//                        NotificationCenter.default.post(name: RealmSyncOperationWillDeleteObjectNotification, object:realmSyncObjectInfo)
//                    })
//
//                    // Mark temp object deleted
//                    oldObject.deletedAt = Date().timeIntervalSince1970
//                }
//                
//                // Set SyncStatus to "Synced" for new object
//                if let newObject = realm.object(ofType: self, forPrimaryKey: newPrimaryKey) as? JSONSerializable {
//                    newObject.setSyncStatus(.Synced, serializationInfo: serializationInfo)
//                }
//            }
//        }
//    }
    
    open class func keyValueDictionary(with primaryKeyValue: String) -> [String : String]? {
        return nil
    }
    
    open class func keyValueDictionary<T: Object>(for type: T.Type, jsonDictionary: NSDictionary, keyValueDictionary: [String: Any], serializationInfo: SerializationInfo) -> [String: Any] {
        return keyValueDictionary
    }
    
    open class func modifiedRealmObject(_ realmObject: Object, jsonDictionary: NSDictionary, keyValueDictionary: [String: Any], serializationInfo: SerializationInfo) -> Object? {
        return realmObject
    }
    
    open class func shouldCreateOrUpdate<T: Object>(_ type: T.Type, primaryKey: String, jsonDictionary: NSDictionary, keyValueDictionary: [String: Any], serializationInfo: SerializationInfo) -> Bool {
        return true
    }
    
//    // MARK: Fetchable
//    
//    open class func realmFetchWillSerialize(_ json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm) {
//        
//    }
//    
//    open class func realmFetchShouldSerialize(_ json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm) -> Bool {
//        return true
//    }
//    
//    open class func realmFetchDidSerialize(_ json: AnyObject, fetchRequest: FetchRequest, fetchResult: FetchResult!, inRealm realm: Realm) {
//        
//    }
    

    
    // MARK: Syncable
    
    open func setSyncStatus(_ syncStatus: RealmSyncManager.SyncStatus, serializationInfo: SerializationInfo? = nil) {
        if !isInvalidated {
            var inWriteTransaction = false
            if realm?.isInWriteTransaction == false {
                realm?.beginWrite()
                inWriteTransaction = true
            }
            
            self.syncStatus = syncStatus.rawValue
            
            if inWriteTransaction {
                do {
                    try realm?.commitWrite()
                } catch {}
            }
        }
    }
    
    open func realmSyncOperations() -> [RealmSyncOperation] {
        var syncOperations = [RealmSyncOperation]()
        
        let objectType = type(of: self)
        let primaryKey = id
        let method = realmSyncMethod()
        let baseURL = objectType.baseURL()
        let parameters = realmSyncParameters(method!)
        let path = realmSyncPath(method!)
        
        if let path = path, let method = method, let baseURL = baseURL {
            let syncOperation = RealmSyncOperation(objectType: objectType, primaryKey: primaryKey, baseURL: baseURL, path: path, parameters: parameters, method: method)
            
            syncOperations.append(syncOperation)
        }
        
        return syncOperations
    }
    
    open func realmSyncMethod() -> RealmKit.HTTPMethod! {
        if deletedAt > 0 {
            return .delete
        } else {
            if id == server_id {
                return .put
            } else {
                return .post
            }
        }
    }
    
    open func realmSyncPath(_ method: RealmKit.HTTPMethod) -> String? {
        print("# RealmKit: Please override realmSyncPath: in \(self)")
        
        return nil
    }
    
    open func realmSyncParameters(_ method: RealmKit.HTTPMethod) -> [String: Any]? {
        print("# RealmKit: Please override realmSyncParameters: in \(self)")
        
        return nil
    }
    
    open class func realmSyncJSONResponseKey(_ method: RealmKit.HTTPMethod, userInfo: [String: Any]) -> String? {
        print("# RealmKit: Please override realmSyncJSONResponseKey:userInfo: in \(self)")
        
        return nil
    }
    
    open class func realmSyncOperation(_ sender: RealmSyncOperation, willSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm) {
        
    }
    
    open class func realmSyncOperation(_ sender: RealmSyncOperation, shouldSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm) -> Bool {
        return true
    }
    
    open class func realmSyncOperation(_ sender: RealmSyncOperation, didSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, syncResult: SyncResult!, inRealm realm: Realm) {
        
    }
    
    open class func realmSyncOperation(_ sender: RealmSyncOperation, didSync syncResult: SyncResult!, inRealm realm: Realm) {
        
    }
}
