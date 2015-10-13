//
//  RealmSyncManager.swift
//  RealmKit
//
//  Created by Michael Loistl on 28/11/2014.
//  Copyright (c) 2014 Michael Loistl. All rights reserved.
//

import Foundation
import RealmSwift

public let RealmSyncOperationWillDeleteObjectNotification = "com.aplo.RealmSyncOperationWillDeleteObjectNotification"

// MARK: - RealmSyncManagerDelegate

public protocol RealmSyncManagerDelegate {
    func realmSyncManager(sender: RealmSyncManager, shouldStartWithSyncOperation syncOperation: RealmSyncOperation) -> Bool
}

// MARK: - RealmSyncManager

public class RealmSyncManager {
    
    public enum SyncStatus: String {
        case Sync = "sync"
        case Syncing = "syncing"
        case Synced = "synced"
        case Failed = "failed"
    }
    
    var registeredTypes = [RealmSyncObject.Type]()
    
    var syncQueue: dispatch_queue_t = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    
    var addingPendingSyncOperations = false
    
    public var delegate: RealmSyncManagerDelegate?
    
    public class var sharedManager: RealmSyncManager {
        struct Singleton {
            static let instance = RealmSyncManager()
        }
        
        return Singleton.instance
    }
    
    public lazy var syncOperationQueue: NSOperationQueue = {
        var _syncOperationQueue = NSOperationQueue()
        _syncOperationQueue.name = "Sync queue"
        _syncOperationQueue.maxConcurrentOperationCount = 1
        
        return _syncOperationQueue
        }()
    
    // MARK: Initializers
    
    init() {

    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Methods
    
    public func registerType(type: RealmSyncObject.Type) {
        if let _ = type as? RealmSyncProtocol {
            registeredTypes.append(type)
        }
    }
    
    public func addPendingSyncOperations() {
        if addingPendingSyncOperations == false {
            addingPendingSyncOperations = true
            
            dispatch_async(syncQueue, {
                do {
                    let realm = try Realm()
                    let predicate = NSPredicate(format: "syncStatus == %@", RealmSyncManager.SyncStatus.Sync.rawValue)
                    for registeredType in self.registeredTypes {
                        let syncObjects = realm.objects(registeredType).filter(predicate)

                        for syncObject in syncObjects {
                            if let syncObject = syncObject as? RealmSyncProtocol {
                                let syncOperations = syncObject.realmSyncOperations()
                                for syncOperation in syncOperations {
                                    if self.delegate?.realmSyncManager(self, shouldStartWithSyncOperation: syncOperation) ?? true {
                                        // SyncOperation completion block
                                        syncOperation.completionBlock = {
                                            
                                        }
                                        
                                        // Add SyncOperation to queue
                                        if self.syncOperationIsQueued(syncOperation) == false {
                                            self.syncOperationQueue.addOperation(syncOperation)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch _ {
                    
                }
                
                self.addingPendingSyncOperations = false
            })
        }
    }
    
    // Test: SyncManagerTests.testSyncOperationIsQueued()
    func syncOperationIsQueued(syncOperation: RealmSyncOperation) -> Bool {
        var isQueued = false
        
        for operation in self.syncOperationQueue.operations {
            if let operation = operation as? RealmSyncOperation {
                if NSStringFromClass(operation.objectType) == NSStringFromClass(syncOperation.objectType) {
                    if operation.primaryKey == syncOperation.primaryKey {
                        if operation.path == syncOperation.path {
                            if operation.httpMethod.rawValue == syncOperation.httpMethod.rawValue {
                                isQueued = true
                            }
                        }
                    }
                }
            }
        }
        
        return isQueued
    }
}



// MARK: - RealmSyncObjectInfo

public class RealmSyncObjectInfo: NSObject {
    public let type: RealmSyncObject.Type
    public let oldPrimaryKey: String
    public let newPrimaryKey: String
    
    init(type: RealmSyncObject.Type, oldPrimaryKey: String, newPrimaryKey: String) {
        self.type = type
        self.oldPrimaryKey = oldPrimaryKey
        self.newPrimaryKey = newPrimaryKey
    }
}

// MARK: - RealmSyncOperation

public class RealmSyncOperation: NSOperation {
    
    public enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
    }
    
    public let objectType: RealmSyncObject.Type
    public let primaryKey: String
    
    public let httpMethod: HTTPMethod
    public let path: String
    public let parameters: [String : AnyObject]?
    
    public var identifier: String?
    
    private var _executing: Bool = false
    override public var executing: Bool {
        get {
            return _executing
        }
        set {
            if _executing != newValue {
                willChangeValueForKey("isExecuting")
                _executing = newValue
                didChangeValueForKey("isExecuting")
            }
        }
    }
    
    private var _finished: Bool = false;
    override public var finished: Bool {
        get {
            return _finished
        }
        set {
            if _finished != newValue {
                willChangeValueForKey("isFinished")
                _finished = newValue
                didChangeValueForKey("isFinished")
            }
        }
    }
    
    override public var asynchronous: Bool {
        return true
    }
    
    // Initializers
    
    public init(objectType: RealmSyncObject.Type, primaryKey: String, path: String, parameters: [String : AnyObject]?, httpMethod: HTTPMethod) {
        self.objectType = objectType
        self.primaryKey = primaryKey
        
        self.path = path
        self.parameters = parameters
        self.httpMethod = httpMethod
        
        super.init()
    }
    
    // Override NSOperation Functions
    
    override public func start() {
        if NSThread.isMainThread() == false {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.start()
            })
            return
        }
        
        // Set NSOperation status
        executing = true
        finished = false
        
        let dispatchSessionGroup = dispatch_group_create()
        
        var completionSuccess = false
        var completionSessionDataTask: NSURLSessionDataTask?
        var completionResponseObject: AnyObject?
        var completionError: NSError?
        
        // Start asynchronous API
        dispatch_group_enter(dispatchSessionGroup)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
            var realm: Realm?
            
            do {
                try realm = Realm()
            } catch _ {
                
            }
            
            if let realm = realm {
                if let object = realm.objectForPrimaryKey(self.objectType, key: self.primaryKey) as? RealmSyncProtocol {
                    dispatch_group_enter(dispatchSessionGroup)
                    object.realmSyncOperationSessionDataTaskWithPath(self.path, parameters: self.parameters, httpMethod: self.httpMethod, completion: { (success, sessionDataTask, responseObject, error) -> Void in
                        
                        completionSuccess = success
                        completionSessionDataTask = sessionDataTask
                        completionResponseObject = responseObject
                        completionError = error
                        
                        dispatch_group_leave(dispatchSessionGroup)
                    })
                }
            }
            
            dispatch_group_leave(dispatchSessionGroup)
        })
    
        // Completion
        dispatch_group_notify(dispatchSessionGroup, dispatch_get_main_queue(), {
            
            // Debug logging
//            let requestUrl = completionSessionDataTask?.originalRequest?.URL?.absoluteString
//            let requestBody = NSString(data: completionSessionDataTask?.originalRequest?.HTTPBody ?? NSData(), encoding: NSUTF8StringEncoding)
//            let errorResponse = completionError.userInfo[ErrorResponseObjectKey] as? NSDictionary
            
            if let httpURLResponse = completionSessionDataTask?.response as? NSHTTPURLResponse {
                let statusCode = httpURLResponse.statusCode
                NSLog("PATH: \(self.path) HTTPMETHOD: \(self.httpMethod.rawValue) STATUSCODE: \(statusCode) RESPONSE: \(completionResponseObject?.description)")
            }

            let dispatchCompletionGroup = dispatch_group_create()
            
            // 1 No GET request fired = the current realmObject is the only local instance
            
            // 2 GET request fired but not yet returned = the current realmObject is the only local instance -> WORST CASE
            
            // 3 GET request fired and returned = the current realmObject and fetched realmObject are both local instances
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
                var realm: Realm?
                
                do {
                    try realm = Realm()
                } catch _ {
                    
                }
                
                if let realm = realm {
                    if completionSuccess {
                        if let objectDictionary = self.objectDictionaryFromResponseObject(completionResponseObject, withHTTPMethod: self.httpMethod, identifier: self.identifier) {
                            
                            dispatch_group_enter(dispatchCompletionGroup)
                            
                            // Create new Object with ObjectDictionary
                            if let syncType = self.objectType as? RealmSyncProtocol.Type {
                                self.objectType.realmObjectInRealm(realm, withJSONDictionary: objectDictionary, mappingIdentifier: nil, identifier: nil, replacingObjectWithPrimaryKey: self.primaryKey, completion: { (realmObjectInfo, error) -> Void in
                                    
                                    // Update Realm
                                    realm.refresh()
                                    
                                    syncType.realmSyncOperationDidSync(self, inRealm: realm, oldPrimaryKey: self.primaryKey, newPrimaryKey: realmObjectInfo?.primaryKey, completion: { () -> Void in
                                        
                                        // Delete temp object
                                        if self.httpMethod == .POST {
                                            if let newPrimaryKey = realmObjectInfo?.primaryKey {
                                                if self.primaryKey != newPrimaryKey {
                                                    if let tempRealmObject = realm.objectForPrimaryKey(self.objectType, key: self.primaryKey) {
                                                        
                                                        let realmSyncObjectInfo = RealmSyncObjectInfo(type: self.objectType, oldPrimaryKey: self.primaryKey, newPrimaryKey: newPrimaryKey)
                                                        
                                                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                                            NSNotificationCenter.defaultCenter().postNotificationName(RealmSyncOperationWillDeleteObjectNotification, object:realmSyncObjectInfo)
                                                        })
                                                        
                                                        realm.write({ () -> Void in
                                                            realm.delete(tempRealmObject)
                                                        })
                                                    }
                                                }
                                            }
                                        }
                                        
                                        dispatch_group_leave(dispatchCompletionGroup)
                                    })
                                })
                            }
                        } else {
                            if let realmObject = realm.objectForPrimaryKey(self.objectType, key: self.primaryKey) as? RealmSyncProtocol {
                                realm.write({ () -> Void in
                                    realmObject.setSyncStatus(.Synced)
                                })
                            }
                        }
                    } else {
                        if let objectType = self.objectType as? RealmSyncProtocol {
                            objectType.handleFailedSessionDataTask(completionSessionDataTask, error: completionError, primaryKey: self.primaryKey, inRealm: realm)
                        }
                    }
                }
                
                dispatch_group_notify(dispatchCompletionGroup, dispatch_get_main_queue(), {
                    
                    // Set NSOperation status
                    self.executing = false
                    self.finished = true
                })
            })
        })
    }
    
    // MARK: - Methods
    
    
    
    // MARK: Networking
    
    func objectDictionaryFromResponseObject(responseObject: AnyObject?, withHTTPMethod httpMethod: HTTPMethod?, identifier: String?) -> NSDictionary? {
        if let responseObject = responseObject as? NSDictionary {
            if let httpMethod = httpMethod, syncType = objectType as? RealmSyncProtocol.Type {
                if let responseObjectKey = syncType.realmSyncOperation(self, responseObjectKeyForHTTPMethod: httpMethod, identifier: identifier) {
                    return responseObject.objectForKey(responseObjectKey) as? NSDictionary
                }
            }
        }
        
        return nil
    }
}

extension Object {
    
    
}