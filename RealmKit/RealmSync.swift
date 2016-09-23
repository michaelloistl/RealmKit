//
//  RealmSync.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmSyncCompletionBlock = (syncResult: SyncResult!) -> Void

public struct SyncResult {
    
    public let request: NSURLRequest!
    public let response: NSHTTPURLResponse!
    public let success: Bool
    public let jsonResponse: AnyObject?
    public let realmObjectInfos: [RealmObjectInfo]?
    public let oldPrimaryKey: String?
    public let newPrimaryKey: String?
    public let error: NSError?
    public let userInfo: [String: AnyObject]
    
    public init(
        request: NSURLRequest!,
        response: NSHTTPURLResponse!,
        success: Bool,
        jsonResponse: AnyObject? = nil,
        realmObjectInfos: [RealmObjectInfo]? = nil,
        oldPrimaryKey: String? = nil,
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

@available(OSX 10.10, *)
public protocol RealmSyncable: RealmKitObjectProtocol {
    
    // MARK: - Properties
    
    var lastSyncedAt: NSDate? { get set }
    var syncStatus: String { get set }

    // MARK: - Methods
    
    // MARK: Required
    
    func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus, serializationInfo: SerializationInfo?)
    
    func realmSyncOperations() -> [RealmSyncOperation]
    func realmSyncMethod() -> RealmKit.Method!
    func realmSyncPath(method: RealmKit.Method) -> String?
    func realmSyncParameters(method: RealmKit.Method) -> [String: AnyObject]?
    
    static func realmSyncJSONResponseKey(method: RealmKit.Method, userInfo: [String: AnyObject]) -> String?
    
    // MARK: Optional
    
    static func realmSyncOperation(sender: RealmSyncOperation, willSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm)
    static func realmSyncOperation(sender: RealmSyncOperation, shouldSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, inRealm realm: Realm) -> Bool
    static func realmSyncOperation(sender: RealmSyncOperation, didSerializeJSON json: AnyObject, serializationInfo: SerializationInfo, syncResult: SyncResult!, inRealm realm: Realm)
    
    static func realmSyncOperation(sender: RealmSyncOperation, didSync syncResult: SyncResult!, inRealm realm: Realm)

}
