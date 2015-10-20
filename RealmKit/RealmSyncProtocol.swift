//
//  RealmSyncProtocol.swift
//  ContextiOS
//
//  Created by Michael Loistl on 09/10/2015.
//  Copyright © 2015 aplo. All rights reserved.
//

import Foundation
import RealmSwift

public protocol RealmSyncProtocol {
    
    static func realmSyncOperation(sender: RealmSyncOperation, responseObjectKeyForHTTPMethod httpMethod: RealmSyncOperation.HTTPMethod, identifier: String?) -> String?
    static func realmSyncOperationDidSync(sender: RealmSyncOperation, inRealm realm: Realm, oldPrimaryKey: String?, newPrimaryKey: String?, completion: () -> Void)

    func realmSyncOperations() -> [RealmSyncOperation]
    func realmSyncOperationHTTPMethod() -> RealmSyncOperation.HTTPMethod!
    func realmSyncOperationPathForHTTPMethod(httpMethod: RealmSyncOperation.HTTPMethod) -> String?
    func realmSyncOperationParametersForHTTPMethod(httpMethod: RealmSyncOperation.HTTPMethod) -> [String: AnyObject]?
    func realmSyncOperationSessionDataTaskWithPath(path: String, parameters: [String: AnyObject]?, httpMethod: RealmSyncOperation.HTTPMethod, completion: (success: Bool, sessionDataTask: NSURLSessionDataTask!, responseObject: AnyObject!, error: NSError!) -> Void)

    func setSyncStatus(syncStatus: RealmSyncManager.SyncStatus)
    
    func handleFailedSessionDataTask(sessionDataTask: NSURLSessionDataTask!, error: NSError!, primaryKey: String, inRealm realm: Realm)
}