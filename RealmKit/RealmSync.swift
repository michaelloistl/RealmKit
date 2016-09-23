//
//  RealmSync.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmSyncCompletionBlock = (_ syncResult: SyncResult?) -> Void

public struct SyncResult {
    
    public let request: URLRequest!
    public let response: HTTPURLResponse!
    public let success: Bool
    public let jsonResponse: AnyObject?
    public let realmObjectInfos: [RealmObjectInfo]?
    public let oldPrimaryKey: String?
    public let newPrimaryKey: String?
    public let error: NSError?
    public let userInfo: [String: Any]
    
    public init(
        request: URLRequest!,
        response: HTTPURLResponse!,
        success: Bool,
        jsonResponse: AnyObject? = nil,
        realmObjectInfos: [RealmObjectInfo]? = nil,
        oldPrimaryKey: String? = nil,
        newPrimaryKey: String? = nil,
        error: NSError? = nil,
        userInfo: [String: Any] = [String: Any]()
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
    
    var lastSyncedAt: Date? { get set }
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
