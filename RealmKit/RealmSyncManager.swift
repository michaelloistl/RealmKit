//
//  RealmSyncManager.swift
//  RealmKit
//
//  Created by Michael Loistl on 28/11/2014.
//  Copyright (c) 2014 Michael Loistl. All rights reserved.
//

import Foundation
import RealmSwift

public let RealmSyncOperationWillDeleteObjectNotification = NSNotification.Name(rawValue: "com.aplo.RealmSyncOperationWillDeleteObjectNotification")
public let RealmSyncOperationDidCompleteNotification = NSNotification.Name(rawValue: "com.aplo.RealmSyncOperationDidCompleteNotification")

// MARK: - RealmSyncManagerDelegate

@available(OSX 10.10, *)
public protocol RealmSyncManagerDelegate {
    func realmSyncManager(_ sender: RealmSyncManager, shouldStartWithSyncOperation syncOperation: RealmSyncOperation) -> Bool
}

// MARK: - RealmSync

@available(OSX 10.10, *)
open class RealmSyncManager {
    
    public enum SyncStatus: String {
        case Sync = "sync"
        case Syncing = "syncing"
        case Synced = "synced"
        case Failed = "failed"
    }
    
    var registeredTypes = [Object.Type]()
    
    var syncQueue: DispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
    
    var addingPendingSyncOperations = false
    
    open var delegate: RealmSyncManagerDelegate?
    
    open class var sharedManager: RealmSyncManager {
        struct Singleton {
            static let instance = RealmSyncManager()
        }
        
        return Singleton.instance
    }
    
    open lazy var syncOperationQueue: OperationQueue = {
        var _syncOperationQueue = OperationQueue()
        _syncOperationQueue.name = "Sync queue"
        _syncOperationQueue.maxConcurrentOperationCount = 1
        
        return _syncOperationQueue
        }()
    
    // MARK: Initializers
    
    init() {

    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Methods
    
    open func registerTypes(_ types: [Object.Type]) {
        for type in types {
            registerType(type)
        }
    }

    open func registerType(_ type: Object.Type) {
        registeredTypes.append(type)
    }
    
    open func addPendingSyncOperations(_ completion: @escaping (_ operations: [RealmSyncOperation]) -> Void) {
        var operations = [RealmSyncOperation]()
        
        if addingPendingSyncOperations == false {
            addingPendingSyncOperations = true
            
            syncQueue.async(execute: {
                var realm: Realm?
                
                do {
                    realm = try Realm()
                } catch { }
                
                realm?.refresh()
                
                let predicate = NSPredicate(format: "syncStatus == %@", RealmSyncManager.SyncStatus.Sync.rawValue)
                for registeredType in self.registeredTypes {
                    if let syncObjects = realm?.objects(registeredType).filter(predicate) {
                        for syncObject in syncObjects {
                            if let syncObject = syncObject as? RealmSyncable {
                                let syncOperations = syncObject.realmSyncOperations()
                                for syncOperation in syncOperations {
                                    var shouldStart = true
                                    if let _shouldStart = self.delegate?.realmSyncManager(self, shouldStartWithSyncOperation: syncOperation) {
                                        shouldStart = _shouldStart
                                    }
                                    
                                    if shouldStart {
                                        
                                        // SyncOperation completion block
                                        syncOperation.completionBlock = {
                                            
                                        }
                                        
                                        // Add SyncOperation to queue
                                        if self.syncOperationIsQueued(syncOperation) == false {
                                            operations.append(syncOperation)
                                            self.syncOperationQueue.addOperation(syncOperation)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                self.addingPendingSyncOperations = false
                
                completion(operations)
            })
        }
    }
    
    // Test: SyncManagerTests.testSyncOperationIsQueued()
    func syncOperationIsQueued(_ syncOperation: RealmSyncOperation) -> Bool {
        var isQueued = false
        
        for operation in self.syncOperationQueue.operations {
            if let operation = operation as? RealmSyncOperation {
                if NSStringFromClass(operation.objectType) == NSStringFromClass(syncOperation.objectType) {
                    if operation.primaryKey == syncOperation.primaryKey {
                        isQueued = true
                        break
                    }
                }
            }
        }
        
        return isQueued
    }
}

// MARK: - RealmSyncObjectInfo

open class RealmSyncObjectInfo: NSObject {
    open let type: Object.Type
    open let oldPrimaryKey: String
    open let newPrimaryKey: String
    
    init(type: Object.Type, oldPrimaryKey: String, newPrimaryKey: String) {
        self.type = type
        self.oldPrimaryKey = oldPrimaryKey
        self.newPrimaryKey = newPrimaryKey
    }
}

// MARK: - RealmSyncOperation

@available(OSX 10.10, *)
open class RealmSyncOperation: Operation {
    
    open let objectType: Object.Type
    open let primaryKey: String
    
    open let method: RealmKit.Method
    open let baseURL: URL
    open let path: String
    open let parameters: [String : AnyObject]?
    
    open var userInfo = [String : AnyObject]()
    open var sessionTask: URLSessionTask?
    
    open var serializationInfo: SerializationInfo?
    open var syncResult: SyncResult?
    
    fileprivate var _executing: Bool = false
    override open var isExecuting: Bool {
        get {
            return _executing
        }
        set {
            if _executing != newValue {
                willChangeValue(forKey: "isExecuting")
                _executing = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
    }
    
    fileprivate var _finished: Bool = false;
    override open var isFinished: Bool {
        get {
            return _finished
        }
        set {
            if _finished != newValue {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }
    
    fileprivate var _cancelled: Bool = false;
    override open var isCancelled: Bool {
        get {
            return _cancelled
        }
        set {
            if _cancelled != newValue {
                willChangeValue(forKey: "isCancelled")
                _cancelled = newValue
                didChangeValue(forKey: "isCancelled")
                
                sessionTask?.cancel()
            }
        }
    }
    
    override open var isAsynchronous: Bool {
        return true
    }
    
    // Initializers
    
    public init(objectType: Object.Type, primaryKey: String, baseURL: URL, path: String, parameters: [String : AnyObject]?, method: RealmKit.Method) {
        self.objectType = objectType
        self.primaryKey = primaryKey
        
        self.baseURL = baseURL
        self.path = path
        self.parameters = parameters
        self.method = method
        
        super.init()
    }
    
    // Override NSOperation Functions
    
    override open func start() {

        if Thread.isMainThread == false {
            DispatchQueue.main.async(execute: { () -> Void in
                self.start()
            })
            return
        }
        
        // Set NSOperation status
        isExecuting = true
        isFinished = false
        
        let dispatchSessionGroup = DispatchGroup()
        
        // Start asynchronous API
        dispatchSessionGroup.enter()
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async(execute: { () -> Void in

            if let syncType = self.objectType as? RealmSyncable.Type {
            
                dispatchSessionGroup.enter()
                
                self.sessionTask = syncType.requestWithBaseURL(self.baseURL, path: self.path, parameters: self.parameters, method: self.method, completion: { (success, request, response, jsonResponse, error) -> Void in
                    
                    self.syncResult = SyncResult(request: request, response: response, success: success, jsonResponse: jsonResponse, oldPrimaryKey: self.primaryKey, error: error, userInfo: self.userInfo)
                    
                    dispatchSessionGroup.leave()
                })
            }
            
            dispatchSessionGroup.leave()
        })
    
        // Completion
        dispatchSessionGroup.notify(queue: DispatchQueue.main, execute: {
            
            // Debug logging
            if RealmKit.sharedInstance.debugLogs {
                print("PATH: \(self.path) PARAMETERS: \(self.parameters) HTTPMETHOD: \(self.method.rawValue) STATUSCODE: \(self.syncResult?.response?.statusCode) RESPONSE: \(self.syncResult?.jsonResponse)")
            }

            let dispatchCompletionGroup = DispatchGroup()
            
            // 1 No GET request fired = the current realmObject is the only local instance
            
            // 2 GET request fired but not yet returned = the current realmObject is the only local instance -> WORST CASE
            
            // 3 GET request fired and returned = the current realmObject and fetched realmObject are both local instances
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async(execute: { () -> Void in
                var realm: Realm?
                
                do {
                    realm = try Realm()
                } catch { }
                
                if let realm = realm {
                    if self.syncResult?.success == true {
                        self.serializationInfo = SerializationInfo(realm: realm, method: self.method, userInfo: self.userInfo, oldPrimaryKey: self.primaryKey, syncOperation: self)
                        
                        if let objectDictionary = self.objectDictionaryFromJSONResponse(self.syncResult?.jsonResponse, serializationInfo: self.serializationInfo!) {
                            dispatchCompletionGroup.enter()
                            
                            // Create new Object with ObjectDictionary
                            if let syncType = self.objectType as? RealmSyncable.Type, let serializeType = self.objectType as? RealmJSONSerializable.Type {
                                
                                // Should serialize?
                                if syncType.realmSyncOperation(self, shouldSerializeJSON: objectDictionary, serializationInfo: self.serializationInfo!, inRealm: realm) {
                                    
                                    // Will Serialize
                                    syncType.realmSyncOperation(self, willSerializeJSON: objectDictionary, serializationInfo: self.serializationInfo!, inRealm: realm)
                                    
                                    serializeType.realmObjectWithJSONDictionary(objectDictionary, serializationInfo: self.serializationInfo!, completion: { (realmObjectInfo, error) -> Void in
                                        
                                        realm.refresh()
                                        
                                        var realmObjectInfos = [RealmObjectInfo]()
                                        if let realmObjectInfo = realmObjectInfo {
                                            realmObjectInfos = [realmObjectInfo]
                                        }
                                        
                                        self.syncResult = SyncResult(request: self.syncResult?.request, response: self.syncResult?.response, success: self.syncResult?.success ?? false, jsonResponse: self.syncResult?.jsonResponse, realmObjectInfos: realmObjectInfos, oldPrimaryKey: self.primaryKey, newPrimaryKey: realmObjectInfo?.primaryKey, error: self.syncResult?.error, userInfo: self.userInfo)
                                        
                                        self.serializationInfo = SerializationInfo(realm: realm, method: self.method, userInfo: self.userInfo, oldPrimaryKey: self.primaryKey, newPrimaryKey: realmObjectInfo?.primaryKey, syncOperation: self)

                                        // Did Serialize
                                        syncType.realmSyncOperation(self, didSerializeJSON: objectDictionary, serializationInfo: self.serializationInfo!, syncResult: self.syncResult, inRealm: realm)
                                        
                                        // Delete temp object
                                        if realmObjectInfo?.primaryKey == nil {
                                            if let realmObject = realm.object(ofType: self.objectType, forPrimaryKey: self.primaryKey) as? RealmSyncable {
                                                do {
                                                    try realm.write({ () -> Void in
                                                        realmObject.setSyncStatus(.Synced, serializationInfo: self.serializationInfo)
                                                    })
                                                } catch { }
                                            }
                                        }
                                        
                                        // Update syncStatus & syncIdentifier
                                        
                                        dispatchCompletionGroup.leave()
                                    })
                                }
                            }
                        } else {
                            if let realmObject = realm.object(ofType: self.objectType, forPrimaryKey: self.primaryKey) as? RealmSyncable {
                                do {
                                    try realm.write({ () -> Void in
                                        realmObject.setSyncStatus(.Synced, serializationInfo: self.serializationInfo)
                                    })
                                } catch { }
                            }
                        }
                    }
                    
                    if let syncType = self.objectType as? RealmSyncable.Type {
                        
                        // Did Sync
                        syncType.realmSyncOperation(self, didSync: self.syncResult, inRealm: realm)
                        
                        // Handle Request
                        syncType.handleRequest(self.syncResult?.request, response: self.syncResult?.response, jsonResponse: self.syncResult?.jsonResponse, error: self.syncResult?.error, fetchOperation: nil, syncOperation: self, inRealm: realm)
                    }
                }
                
                dispatchCompletionGroup.notify(queue: DispatchQueue.main, execute: {
                    
                    // Set NSOperation status
                    self.isExecuting = false
                    self.isFinished = true
                    
                    NotificationCenter.default.post(name: RealmSyncOperationDidCompleteNotification, object: self)
                })
            })
        })
    }
    
    // MARK: - Methods
    
    // MARK: Networking
    
    func objectDictionaryFromJSONResponse(_ jsonResponse: AnyObject?, serializationInfo: SerializationInfo) -> NSDictionary? {
        if let jsonResponse = jsonResponse as? NSDictionary {
            if let method = serializationInfo.method, let syncType = objectType as? RealmSyncable.Type {
                if let responseObjectKey = syncType.realmSyncJSONResponseKey(method, userInfo: serializationInfo.userInfo) {
                    return jsonResponse.object(forKey: responseObjectKey) as? NSDictionary
                } else {
                    return jsonResponse
                }
            }
        }
        
        return nil
    }
}
