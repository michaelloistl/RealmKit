//
//  RealmSyncProtocol.swift
//  ContextiOS
//
//  Created by Michael Loistl on 09/10/2015.
//  Copyright © 2015 aplo. All rights reserved.
//

import Foundation
import RealmSwift

// MARK: - RealmSyncOperationProtocol

public protocol RealmSyncProtocol {
    
    // MARK: - Model
    
    var id: String {get set}
    var syncStatus: String {get set}
    var deletedAt: NSTimeInterval {get set}
    var server_id: String {get set}
    var server_deletedAt: NSTimeInterval {get set}
    
    // MARK: - JSONSerializer
    
    static func primaryKey() -> String?
    
    static func defaultPropertyValues() -> [String: AnyObject]
    static func classForParsingJSONDictionary(JSONDictionary: NSDictionary) -> RealmSyncProtocol.Type
    static func JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier: String?, identifier: String?) -> [String : String]!
    static func JSONTransformerForKey(key: String!, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer!
    static func keyValueDictionaryWithPrimaryKeyValue(primaryKeyValue: String) -> [String : String]?
    
    func realmObjectInRealm(realm: Realm, didCreateOrUpdateRealmObjectWithPrimaryKey newPrimaryKey: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?)
    
    // MARK: - Sync
    
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
