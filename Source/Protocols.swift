//
//  Protocols.swift
//  RealmKit
//
//  Created by Michael Loistl on 27/09/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift
import Alamofire

@available(OSX 10.10, *)
public protocol RKObjectProtocol {
    
    // MARK: - Properties
    var id: String { get set }
    var deletedAt: TimeInterval { get set }
    
    var serverId: String? { get set }
    var serverDeletedAt: TimeInterval { get set }
    
    // MARK: - Methods
    
    // MARK: Required
    
    ///
    static func primaryKey() -> String?
    static func serverKey() -> String?
    static func ignoredProperties() -> [String]
    
    static func defaultPropertyValues() -> [String: Any]
}

@available(OSX 10.10, *)
public protocol Requestable {
    
    // MARK: - Methods
    
    // MARK: Required
    
    /// Returns the base URL that is used for fetch & sync requests.
    static func baseURL() -> URL!
    
    /// Returns the headers (e.g. authentication) that is used for fetch & sync requests.
    static func headers(_ completion: @escaping (_ headers: [String: String]?) -> Void)
    
    /// Handle networking response.
    static func handle(_ response: Alamofire.DataResponse<Any>, fetchRequest: FetchRequest?, syncOperation: SyncOperation?)
}

@available(OSX 10.10, *)
public protocol JSONSerializable: Syncable, Fetchable {
    
    // MARK: - Methods
    
    // MARK: Required
    
    /// Returns the json keyPath for a given object property key (mapping).
    static func jsonKeyPathsByPropertyKey(with serializationRequest: SerializationRequest) -> [String : String]
    
    /// Returns the ValueTransformer for a given object property key.
    static func jsonTransformerForKey(_ key: String!, jsonDictionary: NSDictionary, serializationRequest: SerializationRequest) -> ValueTransformer!
    
    // MARK: Optional
    
    /// Allows to modify keyValues before being used to create/update object during serialization.
    static func modifyKeyValues(_ keyValues: [String: Any], jsonDictionary: NSDictionary?, serializationRequest: SerializationRequest) -> [String: Any]?
    
    /// Allows to modify object after serialization in same write transaction as it was created/updated.
    static func modify<T: RKObject>(_ type: T.Type ,object: T) -> T?
    
    /// Used as hook after object serilization in same write transaction as it was created/updated.
    static func didSerialize<T: RKObject>(_ type: T.Type ,objects: [T], serializationRequest: SerializationRequest) -> Void
}

@available(OSX 10.10, *)
public protocol Fetchable: RKObjectProtocol, Requestable {
    
    // MARK: - Properties
    var lastFetchedAt: NSDate? { get set }
    
    // MARK: Optional
    static func fetchDidComplete(_ fetchResult: FetchResult?)
}

@available(OSX 10.10, *)
public protocol FetchPagable: RKObjectProtocol, Requestable {
    
    // MARK: Required
    static func pageInfo(from fetchResult: FetchResult?) -> PageInfo?
    static func pagingParameters(from pageInfo: PageInfo, pageType: PageInfo.PageType) -> [String: Any]?
    
    // MARK: Optional
    static func fetchPagedDidFetch(_ fetchPagedResult: FetchPagedResult)
    static func fetchPagedDidComplete(_ fetchPagedResult: FetchPagedResult)
}


@available(OSX 10.10, *)
public protocol Syncable: RKObjectProtocol, Requestable {
    
    // MARK: - Properties
    var lastSyncedAt: NSDate? { get set }
    var syncStatus: String { get set }
    
    // MARK: - Methods
    
    // MARK: Required
    func setSyncStatus(_ syncStatus: SyncStatus, serializationRequest: SerializationRequest?)
    
    func syncOperations() -> [SyncOperation]
    func syncHTTPMethod() -> Alamofire.HTTPMethod
    func syncPath(_ httpMethod: Alamofire.HTTPMethod) -> String?
    func syncParameters(_ httpMethod: Alamofire.HTTPMethod) -> [String: Any]?
    
    static func syncJSONResponseKey(_ httpMethod: Alamofire.HTTPMethod, userInfo: [String: Any]) -> String?
    
    // MARK: Optional
//    static func syncOperation(_ sender: SyncOperation, willSerializeJSON json: Any, serializationRequest: SerializationRequest)
//    static func syncOperation(_ sender: SyncOperation, shouldSerializeJSON json: Any, serializationRequest: SerializationRequest) -> Bool
//    static func syncOperation(_ sender: SyncOperation, didSerializeJSON json: Any, serializationRequest: SerializationRequest, syncResult: SyncResult!)
    
    static func syncOperation(_ sender: SyncOperation, didSync syncResult: SyncResult)
    
}
