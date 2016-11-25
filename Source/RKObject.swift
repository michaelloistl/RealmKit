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
    
    public dynamic var serverId: String?
    public dynamic var serverDeletedAt: TimeInterval = 0

    /// Primary key for local realm objects needs to be "id".
    open override class func primaryKey() -> String? {
        return "id"
    }
    
    /// Primary key for remote objects.
    open class func serverKey() -> String? {
        print("# RealmKit: Please override serverKey in \(self)")
        return nil
    }
    
    open class func defaultPropertyValues() -> [String: Any] {
        return [
            "id": UUID().uuidString,
            "deletedAt": 0,
            "serverId": NSNull(),
            "serverDeletedAt": 0,
            "syncStatus": SyncStatus.synced.rawValue
        ]
    }
    
    open override class func ignoredProperties() -> [String] {
        return []
    }
    
    // MARK: JSONSerializable

    /// Returns the json keyPath for a given object property key (mapping).
    open class func jsonKeyPathsByPropertyKey(with serializationRequest: SerializationRequest) -> [String : String] {
        print("# RealmKit: Please override jsonKeyPathsByPropertyKey: in \(self)")
        return [:]
    }
    
    /// Returns the ValueTransformer for a given object property key.
    open class func jsonTransformerForKey(_ key: String!, jsonDictionary: NSDictionary, serializationRequest: SerializationRequest) -> ValueTransformer! {
        print("# RealmKit: Please override jsonTransformerForKey:serializationRequest: in \(self)")
        return nil
    }
    
    /// Allows to modify keyValues before being used to create/update object during serialization.
    open class func modifyKeyValues(_ keyValues: [String: Any], jsonDictionary: NSDictionary?, serializationRequest: SerializationRequest) -> [String: Any]? {
        return nil
    }
    
    /// Allows to modify object after serialization in same write transaction as it was created/updated.
    open class func modify<T: RKObject>(_ type: T.Type ,object: T) -> T? {
        return nil
    }
    
    /// Used as hook after object serilization in same write transaction as it was created/updated.
    open class func didSerialize<T: RKObject>(_ type: T.Type ,objects: [T], serializationRequest: SerializationRequest) -> Void {
        
    }
    
    // MARK: Requestable
    
    /// Returns the base URL that is used for fetch & sync requests.
    open class func baseURL() -> URL! {
        print("# RealmKit: Please override baseURL in \(self)")
        return nil
    }
    
    /// Returns the headers (e.g. authentication) that is used for fetch & sync requests.
    open class func headers(_ completion: @escaping (_ headers: [String: String]?) -> Void) {
        print("# RealmKit: Please override headers in \(self)")
        completion(nil)
    }
    
    /// Handle networking response.
    open class func handle(_ response: Alamofire.DataResponse<Any>, fetchRequest: FetchRequest?, syncOperation: SyncOperation?) {
        
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
    
    open class func pagingParameters(from pageInfo: PageInfo, pageType: PageInfo.PageType) -> [String: Any]? {
        print("# RealmKit: Please override pagingParameters: in \(self)")
        return nil
    }
    
    open class func fetchPagedDidFetch(_ fetchPagedResult: FetchPagedResult) {
        
    }
    
    open class func fetchPagedDidComplete(_ fetchPagedResult: FetchPagedResult) {
        
    }
    
    // MARK: Syncable
    
    public dynamic var lastSyncedAt: NSDate?
    public dynamic var syncStatus: String = SyncStatus.synced.rawValue
    
    open func setSyncStatus(_ syncStatus: SyncStatus, serializationRequest: SerializationRequest? = nil) {
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
        let primaryId = self.id
        let serverId = self.serverId
        let httpMethod = syncHTTPMethod()
        let baseURL = objectType.baseURL()
        let parameters = syncParameters(httpMethod)
        let path = syncPath(httpMethod)

        if let path = path, let baseURL = baseURL {
            let operation = SyncOperation(objectType: objectType, primaryId: primaryId, serverId: serverId, baseURL: baseURL, path: path, parameters: parameters, httpMethod: httpMethod)

            syncOperations.append(operation)
        }
        
        return syncOperations
    }
    
    open func syncHTTPMethod() -> Alamofire.HTTPMethod {
        if deletedAt > 0 {
            return .delete
        } else {
            if let _ = serverId {
                return .put
            } else {
                return .post
            }
        }
    }
    
    open func syncPath(_ httpMethod: Alamofire.HTTPMethod) -> String? {
        print("# RealmKit: Please override syncPath: in \(self)")
        return nil
    }
    
    open func syncParameters(_ httpMethod: Alamofire.HTTPMethod) -> [String: Any]? {
        print("# RealmKit: Please override syncParameters: in \(self)")
        return nil
    }
    
    open class func syncJSONResponseKey(_ httpMethod: Alamofire.HTTPMethod, userInfo: [String: Any]) -> String? {
        print("# RealmKit: Please override syncJSONResponseKey:userInfo: in \(self)")
        return nil
    }
    
    open class func syncOperation(_ sender: SyncOperation, didSync syncResult: SyncResult) {
        
    }
    
}
