//
//  RealmSync.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

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
    
    static func realmSyncJSONResponseKey(method: RealmKit.Method, userInfo: [String: AnyObject]?) -> String?
    
    // MARK: Optional
    
    func addSyncIdentifier(syncIdentifier: String)
    func removeSyncIdentifier(syncIdentifier: String)
    func syncIdentifiers() -> [String]

    static func realmSyncOperationDidSync(sender: RealmSyncOperation, inRealm realm: Realm, oldPrimaryKey: String?, newPrimaryKey: String?)
}
