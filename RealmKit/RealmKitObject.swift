//
//  RealmKitObject.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

@available(OSX 10.10, *)
public protocol RealmKitObjectProtocol {

    // MARK: - Properties
    
    var id: String { get set }
    var deletedAt: TimeInterval { get set }
    
    var server_id: String { get set }
    var server_deletedAt: TimeInterval { get set }

    // MARK: - Methods
    
    // MARK: Required
    
    static func primaryKey() -> String?
    
    static func defaultPropertyValues() -> [String: Any]
    
    static func baseURL() -> URL!
    
    static func requestWithBaseURL(_ baseURL: URL, path: String, parameters: [String: Any]?, method: RealmKit.Method, completion: (_ success: Bool, _ request: URLRequest?, _ response: HTTPURLResponse?, _ jsonResponse: AnyObject?, _ error: NSError?) -> Void) -> URLSessionTask?
    
    static func handleRequest(_ request: URLRequest!, response: HTTPURLResponse!, jsonResponse: AnyObject?, error: NSError!, fetchOperation: RealmFetchOperation?, syncOperation: RealmSyncOperation?, inRealm realm: Realm?)
}

@available(OSX 10.10, *)
open class RealmKitObject: Object, RealmKitObjectProtocol, RealmJSONSerializable, RealmFetchable, RealmFetchPagable, RealmSyncable {
    
    // MARK: - Properties
    
    // MARK: RealmKitObjectProtocol
    
    open dynamic var id: String = UUID().uuidString
    open dynamic var deletedAt: TimeInterval = 0
    
    open dynamic var server_id: String = ""
    open dynamic var server_deletedAt: TimeInterval = 0
    
    // MARK: RealmFetchable
    
    open dynamic var lastFetchedAt: Date?
    
    // MARK: RealmSyncable
    
    open dynamic var lastSyncedAt: Date?
    open dynamic var syncStatus: String = RealmSyncManager.SyncStatus.Synced.rawValue
    
    // MARK: - Protocols
    
    // MARK: RealmKitObjectProtocol
    
    open override class func primaryKey() -> String? {
        return "id"
    }
    
    open class func defaultPropertyValues() -> [String: Any] {
        return [
            "id": UUID().uuidString as AnyObject,
            "deletedAt": 0 as AnyObject,
            "server_id": "" as AnyObject,
            "server_deletedAt": 0 as AnyObject,
            
            "syncStatus": RealmSyncManager.SyncStatus.Synced.rawValue as AnyObject,
        ]
    }
    
    open class func baseURL() -> URL! {
        print("# RealmKit: Please override baseURL in \(self)")
        
        return nil
    }
    
    open class func requestWithBaseURL(_ baseURL: URL, path: String, parameters: [String: Any]?, method: RealmKit.Method, completion: (_ success: Bool, _ request: URLRequest?, _ response: HTTPURLResponse?, _ jsonResponse: AnyObject?, _ error: NSError?) -> Void) -> URLSessionTask? {

        print("# RealmKit: Please override requestWithBaseURL:path:parameters:method:completion: in \(self)")
        
        return nil
    }
    
    open class func handleRequest(_ request: URLRequest!, response: HTTPURLResponse!, jsonResponse: AnyObject?, error: NSError!, fetchOperation: RealmFetchOperation?, syncOperation: RealmSyncOperation?, inRealm realm: Realm?) {
        
        print("# RealmKit: Please override handleRequest:response:jsonResponse:error:fetchOperation:syncOperation:inRealm: in \(self)")
    }
    
    // MARK: RealmJSONSerializable
    
    open class func jsonKeyPathsByPropertyKey(with serializationInfo: SerializationInfo) -> [String : String]! {
        print("# RealmKit: Please override JSONKeyPathsByPropertyKey: in \(self)")
        
        return nil
    }
    
    open class func jsonTransformerForKey(_ key: String!, serializationInfo: SerializationInfo) -> ValueTransformer!{
        print("# RealmKit: Please override JSONTransformerForKey: in \(self)")
        
        return nil
    }
    
    // Optional
    open class func classForParsing(_ jsonDictionary: NSDictionary) -> Object.Type {
        return self
    }
    
    open class func didCreateOrUpdateRealmObject(with serializationInfo: SerializationInfo?) {
        if let newPrimaryKey = serializationInfo?.newPrimaryKey, let oldPrimaryKey = serializationInfo?.oldPrimaryKey, let realm = serializationInfo?.realm {
            
            // Old and New Objects are the same (PUT, DELETE)
            if newPrimaryKey == oldPrimaryKey {
                if let newObject = realm.object(ofType: self, forPrimaryKey: newPrimaryKey) as? RealmJSONSerializable {
                    newObject.setSyncStatus(.Synced, serializationInfo: serializationInfo)
                }
            }
                
            // Old and New Objects are different (POST)
            else {
                
                // Set SyncStatus to "Synced" for initial (old) object
                if var oldObject = realm.object(ofType:self, forPrimaryKey: oldPrimaryKey) as? RealmJSONSerializable {
                    oldObject.setSyncStatus(.Synced, serializationInfo: serializationInfo)
                    
                    let realmSyncObjectInfo = RealmSyncObjectInfo(type: self, oldPrimaryKey: oldPrimaryKey, newPrimaryKey: newPrimaryKey)

                    DispatchQueue.main.async(execute: { () -> Void in
                        NotificationCenter.default.post(name: RealmSyncOperationWillDeleteObjectNotification, object:realmSyncObjectInfo)
                    })

                    // Mark temp object deleted
                    oldObject.deletedAt = Date().timeIntervalSince1970
                }
                
                // Set SyncStatus to "Synced" for new object
                if let newObject = realm.object(ofType: self, forPrimaryKey: newPrimaryKey) as? RealmJSONSerializable {
                    newObject.setSyncStatus(.Synced, serializationInfo: serializationInfo)
                }
            }
        }
    }
    
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
    
    // MARK: RealmFetchable
    
    open class func realmFetchWillSerialize(_ json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm) {
        
    }
    
    open class func realmFetchShouldSerialize(_ json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm) -> Bool {
        return true
    }
    
    open class func realmFetchDidSerialize(_ json: AnyObject, fetchRequest: FetchRequest, fetchResult: FetchResult!, inRealm realm: Realm) {
        
    }
    
    // MARK: RealmFetchPagable
    
    open class func fetchPagingParameters(for realmFetchPaged: RealmFetchPaged) -> [String: Any]? {
        print("# RealmKit: Please override fetchPagingParametersFor:realmFetchPaged in \(self)")
        
        return nil
    }
    
    open class func fetchPageInfo( from fetchResult: FetchResult?) -> PageInfo? {
        print("# RealmKit: Please override fetchPageInfoFrom:fetchResult in \(self)")
        
        return nil
    }
    
    open class func fetchPagedDidProcess(_ realmFetchPaged: RealmFetchPaged) {
        
    }
    
    open class func fetchPagedDidComplete(_ realmFetchPaged: RealmFetchPaged) {
        
    }
    
    // MARK: RealmSyncable
    
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
    
    open func realmSyncMethod() -> RealmKit.Method! {
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
    
    open func realmSyncPath(_ method: RealmKit.Method) -> String? {
        print("# RealmKit: Please override realmSyncPath: in \(self)")
        
        return nil
    }
    
    open func realmSyncParameters(_ method: RealmKit.Method) -> [String: Any]? {
        print("# RealmKit: Please override realmSyncParameters: in \(self)")
        
        return nil
    }
    
    open class func realmSyncJSONResponseKey(_ method: RealmKit.Method, userInfo: [String: Any]) -> String? {
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
