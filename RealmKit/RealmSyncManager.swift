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
public let RealmSyncOperationDidCompleteNotification = "com.aplo.RealmSyncOperationDidCompleteNotification"

// MARK: - RealmSyncManagerDelegate

public protocol RealmSyncManagerDelegate {
    func realmSyncManager(sender: RealmSyncManager, shouldStartWithSyncOperation syncOperation: RealmSyncOperation) -> Bool
}

// MARK: - RealmSync

public class RealmSyncManager {
    
    public enum SyncStatus: String {
        case Sync = "sync"
        case Syncing = "syncing"
        case Synced = "synced"
        case Failed = "failed"
    }
    
    var registeredTypes = [Object.Type]()
    
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
    
    public func registerTypes(types: [Object.Type]) {
        for type in types {
            registerType(type)
        }
    }

    public func registerType(type: Object.Type) {
        registeredTypes.append(type)
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
//                            NSLog("syncObject: \(syncObject)")
                            
                            if let syncObject = syncObject as? RealmSyncable {
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
                            if operation.method.rawValue == syncOperation.method.rawValue {
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
    public let type: Object.Type
    public let oldPrimaryKey: String
    public let newPrimaryKey: String
    
    init(type: Object.Type, oldPrimaryKey: String, newPrimaryKey: String) {
        self.type = type
        self.oldPrimaryKey = oldPrimaryKey
        self.newPrimaryKey = newPrimaryKey
    }
}

// MARK: - RealmSyncOperation

public class RealmSyncOperation: NSOperation {
    
    public let objectType: Object.Type
    public let primaryKey: String
    
    public let method: RealmKit.Method
    public let baseURL: NSURL
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
    
    public init(objectType: Object.Type, primaryKey: String, baseURL: NSURL, path: String, parameters: [String : AnyObject]?, method: RealmKit.Method) {
        self.objectType = objectType
        self.primaryKey = primaryKey
        
        self.baseURL = baseURL
        self.path = path
        self.parameters = parameters
        self.method = method
        
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
        var completionRequest: NSURLRequest!
        var completionResponse: NSHTTPURLResponse!
        var completionResponseObject: AnyObject?
        var completionError: NSError?
        
        var realmSyncUserInfo: [String: AnyObject]?
        
        // Start asynchronous API
        dispatch_group_enter(dispatchSessionGroup)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in

            if let syncType = self.objectType as? RealmSyncable.Type {
            
                dispatch_group_enter(dispatchSessionGroup)
                
                // Set lastSyncedAt in userInfo
                realmSyncUserInfo = ["RealmKit": ["lastSyncedAt": NSDate()]]
                
                syncType.realmRequestWithBaseURL(self.baseURL, path: self.path, parameters: self.parameters, method: self.method, completion: { (success, request, response, responseObject, error) -> Void in
                    
                    completionSuccess = success
                    completionRequest = request
                    completionResponse = response
                    completionResponseObject = responseObject
                    completionError = error
                    
                    dispatch_group_leave(dispatchSessionGroup)
                })
            }
            
            dispatch_group_leave(dispatchSessionGroup)
        })
    
        // Completion
        dispatch_group_notify(dispatchSessionGroup, dispatch_get_main_queue(), {
            
            // Debug logging
            if RealmKit.sharedInstance.debugLogs {
                NSLog("PATH: \(self.path) PARAMETERS: \(self.parameters) HTTPMETHOD: \(self.method.rawValue) STATUSCODE: \(completionResponse?.statusCode) RESPONSE: \(completionResponseObject)")
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
                        if let objectDictionary = self.objectDictionaryFromResponseObject(completionResponseObject, withMethod: self.method, identifier: self.identifier) {
                            dispatch_group_enter(dispatchCompletionGroup)
                            
                            // Create new Object with ObjectDictionary
                            if let syncType = self.objectType as? RealmSyncable.Type, serializeType = self.objectType as? RealmJSONSerializable.Type {
                                serializeType.realmObjectInRealm(realm, withJSONDictionary: objectDictionary, mappingIdentifier: nil, identifier: nil, userInfo: realmSyncUserInfo, replacingObjectWithPrimaryKey: self.primaryKey, completion: { (realmObjectInfo, error) -> Void in
                                    
                                    // Update Realm
                                    realm.refresh()
                                    
                                    // realmSyncOperationDidSync to process client side
                                    syncType.realmSyncOperationDidSync(self, inRealm: realm, oldPrimaryKey: self.primaryKey, newPrimaryKey: realmObjectInfo?.primaryKey)
                                    
                                    // Delete temp object
                                    if let newPrimaryKey = realmObjectInfo?.primaryKey {
                                        if self.primaryKey != newPrimaryKey {
                                            if let tempRealmObject = realm.objectForPrimaryKey(self.objectType, key: self.primaryKey) {
                                                let realmSyncObjectInfo = RealmSyncObjectInfo(type: self.objectType, oldPrimaryKey: self.primaryKey, newPrimaryKey: newPrimaryKey)
                                                
                                                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                                    NSNotificationCenter.defaultCenter().postNotificationName(RealmSyncOperationWillDeleteObjectNotification, object:realmSyncObjectInfo)
                                                })
                                                
                                                do {
                                                    try realm.write({ () -> Void in
                                                        realm.delete(tempRealmObject)
                                                    })
                                                } catch { }
                                            }
                                        }
                                    } else {
                                        if let realmObject = realm.objectForPrimaryKey(self.objectType, key: self.primaryKey) as? RealmSyncable {
                                            do {
                                                try realm.write({ () -> Void in
                                                    realmObject.setSyncStatus(.Synced)
                                                })
                                            } catch { }
                                        }
                                    }
                                    
                                    dispatch_group_leave(dispatchCompletionGroup)
                                })
                            }
                        } else {
                            if let realmObject = realm.objectForPrimaryKey(self.objectType, key: self.primaryKey) as? RealmSyncable {
                                do {
                                    try realm.write({ () -> Void in
                                        realmObject.setSyncStatus(.Synced)
                                    })
                                } catch { }
                            }
                        }
                    }
                    
                    // Handle Request
                    if let objectType = self.objectType as? RealmSyncable.Type {
                        objectType.handleRequest(completionRequest, response: completionResponse, responseObject: completionResponseObject, error: completionError, syncOperation: self, inRealm: realm)
                    }
                }
                
                dispatch_group_notify(dispatchCompletionGroup, dispatch_get_main_queue(), {
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(RealmSyncOperationDidCompleteNotification, object:self)
                    
                    // Set NSOperation status
                    self.executing = false
                    self.finished = true
                })
            })
        })
    }
    
    // MARK: - Methods
    
    
    
    // MARK: Networking
    
    func objectDictionaryFromResponseObject(responseObject: AnyObject?, withMethod method: RealmKit.Method?, identifier: String?) -> NSDictionary? {
        if let responseObject = responseObject as? NSDictionary {
            if let method = method, syncType = objectType as? RealmSyncable.Type {
                if let responseObjectKey = syncType.realmSyncOperation(self, responseObjectKeyForMethod: method, identifier: identifier) {
                    return responseObject.objectForKey(responseObjectKey) as? NSDictionary
                } else {
                    return responseObject
                }
            }
        }
        
        return nil
    }
}

extension Object {
    
    
}