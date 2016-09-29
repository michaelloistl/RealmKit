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
open class RKObject: Object, RKObjectProtocol, JSONSerializable, Requestable, Fetchable, FetchPagable, Syncable {
    
    // MARK: - Protocols
    
    // MARK: RKObjectProtocol
    
    public dynamic var id: String = UUID().uuidString
    public dynamic var deletedAt: TimeInterval = 0
    
    public dynamic var server_id: String?
    public dynamic var server_deletedAt: TimeInterval = 0

    /// Primary key for local realm objects needs to be "id".
    open override class func primaryKey() -> String? {
        return "id"
    }
    
    /// Primary key for local realm objects needs to be "id".
    public class func serverKey() -> String? {
        print("# RealmKit: Please override serverKey in \(self)")
        return nil
    }
    
    open class func defaultPropertyValues() -> [String: AnyObject] {
        return [
            "id": UUID().uuidString as AnyObject,
            "deletedAt": 0 as AnyObject,
            "server_id": NSNull() as AnyObject,
            "server_deletedAt": 0 as AnyObject,
            "syncStatus": SyncStatus.Synced.rawValue as AnyObject
        ]
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
    open class func typeToSerialize(_ jsonDictionary: NSDictionary) -> RKObject.Type {
        return self
    }
    
    /// Allows to modify keyValues before being used to create/update object during serialization.
    open class func modifyKeyValues(_ keyValues: [String: AnyObject]) -> [String: AnyObject]? {
        return nil
    }
    
    /// Allows to modify object after serialization in same write transaction as it was created/updated.
    open class func modifyObject(_ object: RKObject) -> RKObject? {
        return nil
    }
    
    /// Used as hook after object serilization in same write transaction as it was created/updated.
    open class func didSerializeObjects(_ objects: [RKObject]) -> () {
        
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
    
    // MARK: Fetchable
    
    public dynamic var lastFetchedAt: NSDate?
    
    open class func fetchDidComplete(_ fetchResult: FetchResult?) {
        
    }
    
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
    
    // MARK: Syncable
    
    public dynamic var lastSyncedAt: NSDate?
    public dynamic var syncStatus: String = SyncStatus.Synced.rawValue
    
    open func setSyncStatus(_ syncStatus: SyncStatus, serializationRequest: SerializationRequest?) {
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
    
    open func syncOperations() -> [SyncOperation] {
        var syncOperations = [SyncOperation]()

        let objectType = type(of: self)
        let primaryKey = id
        let serverKey = server_id
        let httpMethod = syncHTTPMethod()
        let baseURL = objectType.baseURL()
        let parameters = syncParameters(httpMethod!)
        let path = syncPath(httpMethod!)

        if let path = path, let httpMethod = httpMethod, let baseURL = baseURL {
            let operation = SyncOperation(objectType: objectType, primaryKey: primaryKey, serverKey: serverKey, baseURL: baseURL, path: path, parameters: parameters, httpMethod: httpMethod)

            syncOperations.append(operation)
        }
        
        return syncOperations
    }
    
    open func syncHTTPMethod() -> Alamofire.HTTPMethod! {
        if deletedAt > 0 {
            return .delete
        } else {
            if let _ = server_id {
                return .post
            } else {
                return .put
            }
        }
    }
    
    open func syncPath(_ httpMethod: Alamofire.HTTPMethod!) -> String? {
        print("# RealmKit: Please override syncPath: in \(self)")
        return nil
    }
    
    open func syncParameters(_ httpMethod: Alamofire.HTTPMethod!) -> [String: Any]? {
        print("# RealmKit: Please override syncParameters: in \(self)")
        return nil
    }
    
    open class func syncJSONResponseKey(_ httpMethod: Alamofire.HTTPMethod!, userInfo: [String: Any]) -> String? {
        print("# RealmKit: Please override syncJSONResponseKey:userInfo: in \(self)")
        return nil
    }
    
    open class func syncOperation(_ sender: SyncOperation, didSync syncResult: SyncResult) {
        
    }
    
}
