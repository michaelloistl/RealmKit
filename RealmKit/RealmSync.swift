//
//  RealmSync.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public struct SyncResult {
    
    public let request: NSURLRequest!
    public let response: NSHTTPURLResponse!
    public let success: Bool
    public let jsonResponse: AnyObject?
    public let realmObjectInfos: [RealmObjectInfo]?
    public let error: NSError?
    public let userInfo: [String: AnyObject]
    
    public let oldPrimaryKey: String?
    public let newPrimaryKey: String?
    
    public init(
        request: NSURLRequest!,
        response: NSHTTPURLResponse!,
        success: Bool,
        jsonResponse: AnyObject? = nil,
        realmObjectInfos: [RealmObjectInfo]? = nil,
        oldPrimaryKey: String,
        newPrimaryKey: String? = nil,
        error: NSError? = nil,
        userInfo: [String: AnyObject] = [String: AnyObject]()
        ) {
        self.request = request
        self.response = response
        self.success = success
        self.jsonResponse = jsonResponse
        self.realmObjectInfos = realmObjectInfos
        self.oldPrimaryKey = oldPrimaryKey
        self.newPrimaryKey = newPrimaryKey
        self.error = error
        self.userInfo = userInfo
    }
}

public protocol RealmSyncable: RealmKitObjectProtocol {
    
    // MARK: - Properties
    
    var lastSyncedAt: NSDate? { get set }
    var syncStatus: String { get set }
    var syncIdentifier: String? { get set }

    // MARK: - Methods
    
    // MARK: Required
    
    func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus)
    
    func realmSyncOperations() -> [RealmSyncOperation]
    func realmSyncMethod() -> RealmKit.Method!
    func realmSyncPath(method: RealmKit.Method) -> String?
    func realmSyncParameters(method: RealmKit.Method) -> [String: AnyObject]?
    
    static func realmSyncJSONResponseKey(method: RealmKit.Method, userInfo: [String: AnyObject]) -> String?
    
    // MARK: Optional
    
    func addSyncIdentifier(syncIdentifier: String)
    func removeSyncIdentifier(syncIdentifier: String)
    func syncIdentifiers() -> [String]

    static func realmSyncWillSerializeJSON(json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm)
    static func realmSyncShouldSerializeJSON(json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm) -> Bool
    static func realmSyncDidSerializeJSON(json: AnyObject, serializationInfo: SerializationInfo, syncResult: SyncResult!, inRealm realm: Realm)
    
    static func realmSyncOperationDidSync(sender: RealmSyncOperation, syncResult: SyncResult!, inRealm realm: Realm)
}
