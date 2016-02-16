//
//  RealmSync.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public struct SyncInfo {
    
    // MARK: Required
    
    public var baseURL: NSURL!
    public var path: String!
    public var method: RealmKit.Method!
    
    // MARK: Optional
    
    public var parameters: [String: AnyObject]?
    public var identifier: String?
    public var serializationIdentifier: String?
    public var userInfo: [String: AnyObject]?
    
    public init(
        baseURL: NSURL!,
        path: String!,
        method: RealmKit.Method!,
        parameters: [String: AnyObject]? = nil,
        identifier: String? = nil,
        serializationIdentifier: String? = nil,
        userInfo: [String: AnyObject]? = nil
        ) {
            self.baseURL = baseURL
            self.path = path
            self.method = method
            self.parameters = parameters
            self.identifier = identifier
            self.serializationIdentifier = serializationIdentifier
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
    
    static func realmSyncJSONResponseKey(method: RealmKit.Method, identifier: String?) -> String?
    
    // MARK: Optional
    
    func addSyncIdentifier(syncIdentifier: String)
    func removeSyncIdentifier(syncIdentifier: String)
    func syncIdentifiers() -> [String]

    static func realmSyncOperationDidSync(sender: RealmSyncOperation, inRealm realm: Realm, oldPrimaryKey: String?, newPrimaryKey: String?)
}
