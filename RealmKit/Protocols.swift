//
//  Protocols.swift
//  RealmKit
//
//  Created by Michael Loistl on 27/09/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation

@available(OSX 10.10, *)
public protocol ObjectProtocol {
    
    // MARK: - Properties
    var id: String { get set }
    var deletedAt: TimeInterval { get set }
    
    var server_id: String { get set }
    var server_deletedAt: TimeInterval { get set }
    
    // MARK: - Methods
    
    // MARK: Required
    
    ///
    static func primaryKey() -> String?
    static func serverKey() -> String?
    
    static func defaultPropertyValues() -> [String: AnyObject]
}

@available(OSX 10.10, *)
public protocol Requestable {
    
    // MARK: - Methods
    
    // MARK: Required
    
    /// Returns the base URL that is used for fetch & sync requests.
    static func baseURL() -> URL!
    
    /// Returns the headers (e.g. authentication) that is used for fetch & sync requests.
    static func headers() -> [String: String]?
}

@available(OSX 10.10, *)
public protocol JSONSerializable: Syncable, Fetchable {
    
    // MARK: - Methods
    
    // MARK: Required
    
    /// Returns the json keyPath for a given object property key (mapping).
    static func jsonKeyPathsByPropertyKey(with serializationRequest: SerializationRequest) -> [String : String]!
    
    /// Returns the ValueTransformer for a given object property key.
    static func jsonTransformerForKey(_ key: String!, serializationRequest: SerializationRequest) -> ValueTransformer!
    
    /// Returns the type for the realm object to be created/updated during serialization.
    static func typeToSerialize(_ jsonDictionary: NSDictionary) -> Object.Type
    
    // MARK: Optional
    
    /// Allows to modify keyValues before being used to create/update object during serialization.
    static func modifyKeyValues(_ keyValues: [String: AnyObject]) -> [String: AnyObject]?
    
    /// Allows to modify object after serialization in same write transaction as it was created/updated.
    static func modifyObject(_ object: Object) -> Object?
    
    /// Used as hook after object serilization in same write transaction as it was created/updated.
    static func didSerializeObjects(_ objects: [Object]) -> ()
}

@available(OSX 10.10, *)
public protocol Fetchable: ObjectProtocol, Requestable {
    
    // MARK: - Properties
    var lastFetchedAt: NSDate? { get set }
    
    // MARK: Optional
    static func fetchDidComplete(_ fetchResult: FetchResult)
}

@available(OSX 10.10, *)
public protocol FetchPagable: ObjectProtocol, Requestable {
    
    // MARK: Required
    static func pageInfo(from fetchResult: FetchResult?) -> PageInfo?
    static func pagingParameters(from pageInfo: PageInfo) -> [String: Any]?
    
    // MARK: Optional
    static func fetchPagedDidFetch(_ fetchPagedResult: FetchPagedResult)
    static func fetchPagedDidComplete(_ fetchPagedResult: FetchPagedResult)
}


@available(OSX 10.10, *)
public protocol Syncable: ObjectProtocol, Requestable {
    
    // MARK: - Properties
    var lastSyncedAt: NSDate? { get set }
    var syncStatus: String { get set }
    
    // MARK: - Methods
    
    // MARK: Required
    func setSyncStatus(_ syncStatus: RealmSyncManager.SyncStatus, serializationInfo: SerializationInfo?)
    
    func realmSyncOperations() -> [RealmSyncOperation]
    func realmSyncMethod() -> RealmKit.HTTPMethod!
    func realmSyncPath(_ method: RealmKit.HTTPMethod) -> String?
    func realmSyncParameters(_ method: RealmKit.HTTPMethod) -> [String: Any]?
    
    static func realmSyncJSONResponseKey(_ method: RealmKit.HTTPMethod, userInfo: [String: Any]) -> String?
    
    // MARK: Optional
    static func realmSyncOperation(_ sender: RealmSyncOperation, willSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm)
    static func realmSyncOperation(_ sender: RealmSyncOperation, shouldSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm) -> Bool
    static func realmSyncOperation(_ sender: RealmSyncOperation, didSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, syncResult: SyncResult!, inRealm realm: Realm)
    
    static func realmSyncOperation(_ sender: RealmSyncOperation, didSync syncResult: SyncResult!, inRealm realm: Realm)
    
}
