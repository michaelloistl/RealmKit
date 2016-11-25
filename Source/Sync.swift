//
//  Sync.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift
import Alamofire

public enum SyncStatus: String {
    case sync = "sync"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
}

public struct SyncResult {
    /// Alamofire's JSONSerializer response
    public let response: Alamofire.DataResponse<Any>
    
    /// The result from the object serialization
    public let serializationResult: SerializationResult?
    
    /// Success based on status code
    public var isSuccess: Bool {
        let statusCode = response.response?.statusCode ?? 0
        if case 200 ..< 300 = statusCode {
            return true
        }
        return false
    }
    
    init(response: Alamofire.DataResponse<Any>, serializationResult: SerializationResult?) {
        self.response = response
        self.serializationResult = serializationResult
    }
}

// MARK: - SyncManager

@available(OSX 10.10, *)
public class RKSyncManager {
    
    public var registeredTypes = [Object.Type]()
    
    public var syncQueue: DispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
    
    public var addingPendingSyncOperations = false
    
    public class var shared: RKSyncManager {
        struct Singleton {
            static let instance = RKSyncManager()
        }
        
        return Singleton.instance
    }
    
    public var shouldStart: (_ sender: RKSyncManager, _ syncOperation: SyncOperation) -> Bool = { _ in return true }
    
    public lazy var syncOperationQueue: OperationQueue = {
        var _syncOperationQueue = OperationQueue()
        _syncOperationQueue.name = "Sync queue"
        _syncOperationQueue.maxConcurrentOperationCount = 5
        
        return _syncOperationQueue
    }()
    
    // MARK: - Initializers
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Methods
    
    public func registerTypes(_ types: [Object.Type]) {
        for type in types {
            registerType(type)
        }
    }
    
    public func registerType(_ type: Object.Type) {
        registeredTypes.append(type)
    }
    
    open func addPendingSyncOperations(_ completion: @escaping (_ operations: [SyncOperation]) -> Void) {
        var operations = [SyncOperation]()
        
        if addingPendingSyncOperations == false {
            addingPendingSyncOperations = true
            
            syncQueue.async(execute: {
                let realm = try? Realm()
                realm?.refresh()
                
                let predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.sync.rawValue)
                for registeredType in self.registeredTypes {
                    if let syncObjects = realm?.objects(registeredType).filter(predicate) {
                        for syncObject in syncObjects {
                            if let syncObject = syncObject as? Syncable {
                                let syncOperations = syncObject.syncOperations()
                                for syncOperation in syncOperations {
                                    if self.shouldStart(self, syncOperation) {
                                        
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
    func syncOperationIsQueued(_ syncOperation: SyncOperation) -> Bool {
        var isQueued = false
        
        for operation in self.syncOperationQueue.operations {
            if let operation = operation as? SyncOperation {
                if NSStringFromClass(operation.objectType) == NSStringFromClass(syncOperation.objectType) {
                    if operation.primaryId == syncOperation.primaryId {
                        isQueued = true
                        break
                    }
                }
            }
        }
        
        return isQueued
    }
}


// MARK: - SyncOperation

@available(OSX 10.10, *)
public class SyncOperation: Operation {
    
    public let objectType: RKObject.Type
    
    public let primaryId: String
    public let serverId: String?
    
    public let httpMethod: Alamofire.HTTPMethod
    
    public let baseURL: URL

    public let path: String
    public let parameters: [String : Any]?
    
    public var userInfo = [String : Any]()
    public var sessionTask: URLSessionTask?
    
    public var serializationRequest: SerializationRequest?
    public var syncResult: SyncResult?
    
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
    
    public init(objectType: RKObject.Type, primaryId: String, serverId: String?, baseURL: URL, path: String, parameters: [String : Any]?, httpMethod: Alamofire.HTTPMethod) {
        self.objectType = objectType
        
        self.primaryId = primaryId
        self.serverId = serverId
        
        self.baseURL = baseURL
        
        self.path = path
        self.parameters = parameters
        self.httpMethod = httpMethod
        
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
        
        NotificationCenter.default.post(name: .SyncOperationDidStart, object: self)
        
        // Set NSOperation status
        isExecuting = true
        isFinished = false
        
        // Start asynchronous API
        self.objectType.headers { (headers) in
            let url = self.baseURL.appendingPathComponent(self.path)
            let request = Alamofire.request(url, method: self.httpMethod, parameters: self.parameters, headers: headers).responseJSON { response in
                DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async(execute: { () -> Void in
                    let statusCode = response.response?.statusCode ?? 0
                    let isSuccess = statusCode >= 200 && statusCode < 300
                    
                    var json: Any? = response.result.value
                    
                    var _serializationResult: SerializationResult?
                    var _objectInfos = [ObjectInfo]()
                    var _error: RKError?
                    
                    if let jsonDictionary = response.result.value as? [String: Any] {
                        if let jsonObjectKey = self.objectType.syncJSONResponseKey(self.httpMethod, userInfo: self.userInfo) {
                            json = jsonDictionary[jsonObjectKey]
                        }
                    }
                    
                    if let realm = try? Realm() {
                        if let jsonDictionary = json as? NSDictionary, isSuccess {
                            let serializationRequest = SerializationRequest(realm: realm, httpMethod: self.httpMethod, userInfo: self.userInfo, primaryId: self.primaryId, syncOperation: self)
                            
                            let _ = try? realm.write {
                                let (object, error) = self.objectType.object(self.objectType,
                                                                             jsonDictionary: jsonDictionary,
                                                                             serializationRequest: serializationRequest,
                                                                             modifyKeyValues: {keyValues in
                                                                                
                                                                                // Set syncStatus to .Synced in same write transaction
                                                                                var _keyValues = keyValues
                                                                                _keyValues["syncStatus"] = SyncStatus.synced.rawValue
                                                                                
                                                                                return _keyValues
                                })
                                
                                if let object = object {
                                    _objectInfos = [ObjectInfo(ofType: self.objectType, primaryKey: object.id, serverKey: object.serverId)]
                                }
                                
                                _error = error
                            }
                            
                            _serializationResult = SerializationResult(serializationRequest: serializationRequest, json: json, serializedObjects: SerializationResult.SerializedObjects.persisted(objectInfos: _objectInfos), error: _error)
                        } else { // failed
                            let object = realm.object(ofType: self.objectType, forPrimaryKey: self.primaryId)
                            object?.setSyncStatus(.failed)
                        }
                    }
                    
                    // Debug logging
                    if RealmKit.shared.debugLogs {
                        print("PATH: \(self.path) PARAMETERS: \(self.parameters) HTTPMETHOD: \(self.httpMethod.rawValue) STATUSCODE: \(response.response?.statusCode) RESPONSE: \(json)")
                    }
                    
                    // Handle networking response
                    self.objectType.handle(response, fetchRequest: nil, syncOperation: self)
                    
                    DispatchQueue.main.async {
                        // Set NSOperation status
                        self.isExecuting = false
                        self.isFinished = true
                        
                        let syncResult = SyncResult(response: response, serializationResult: _serializationResult)
                        
                        self.objectType.syncOperation(self, didSync: syncResult)
                        
                        NotificationCenter.default.post(name: .SyncOperationDidComplete, object: self)
                    }
                })
            }
            self.sessionTask = request.task
        }
    }
}



//        if let syncType = self.objectType as? Syncable.Type {
//            dispatchSessionGroup.enter()
//
//            self.sessionTask = syncType.request(self.method, path: self.path, parameters: self.parameters, completion: { (response) in
//                let success = response.response?.statusCode >= 200 && response.response?.statusCode < 300
//                
//                
//                self.syncResult = SyncResult(request: response.request, response: response.response, success: success, jsonResponse: response.json, oldPrimaryKey: self.primaryKey, error: error, userInfo: self.userInfo)
//                
//                dispatchSessionGroup.leave()
//            })
//
//            requestWithBaseURL(self.baseURL, path: self.path, parameters: self.parameters, method: self.method, completion: { (success, request, response, jsonResponse, error) -> Void in
//                
//            })
//        }
        
        
        
        
        
//        // Completion
//        dispatchSessionGroup.notify(queue: DispatchQueue.main, execute: {
//            
//            
//            
//            let dispatchCompletionGroup = DispatchGroup()
//            
//            // 1 No GET request fired = the current realmObject is the only local instance
//            
//            // 2 GET request fired but not yet returned = the current realmObject is the only local instance -> WORST CASE
//            
//            // 3 GET request fired and returned = the current realmObject and fetched realmObject are both local instances
//            
//            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async(execute: { () -> Void in
//                var realm: Realm?
//                
//                do {
//                    realm = try Realm()
//                } catch { }
//                
//                if let realm = realm {
//                    if self.syncResult?.success == true {
//                        self.serializationInfo = SerializationInfo(realm: realm, method: self.method, userInfo: self.userInfo, oldPrimaryKey: self.primaryKey, syncOperation: self)
//                        
//                        if let objectDictionary = self.objectDictionaryFromJSONResponse(self.syncResult?.jsonResponse, serializationInfo: self.serializationInfo!) {
//                            dispatchCompletionGroup.enter()
//                            
//                            // Create new Object with ObjectDictionary
//                            if let syncType = self.objectType as? RealmSyncable.Type, let serializeType = self.objectType as? JSONSerializable.Type {
//                                
//                                // Should serialize?
//                                if syncType.realmSyncOperation(self, shouldSerializeJSON: objectDictionary, serializationInfo: self.serializationInfo!, inRealm: realm) {
//                                    
//                                    // Will Serialize
//                                    syncType.realmSyncOperation(self, willSerializeJSON: objectDictionary, serializationInfo: self.serializationInfo!, inRealm: realm)
//                                    
//                                    serializeType.realmObjectWithJSONDictionary(objectDictionary, serializationInfo: self.serializationInfo!, completion: { (realmObjectInfo, error) -> Void in
//                                        
//                                        realm.refresh()
//                                        
//                                        var realmObjectInfos = [RealmObjectInfo]()
//                                        if let realmObjectInfo = realmObjectInfo {
//                                            realmObjectInfos = [realmObjectInfo]
//                                        }
//                                        
//                                        self.syncResult = SyncResult(request: self.syncResult?.request, response: self.syncResult?.response, success: self.syncResult?.success ?? false, jsonResponse: self.syncResult?.jsonResponse, realmObjectInfos: realmObjectInfos, oldPrimaryKey: self.primaryKey, newPrimaryKey: realmObjectInfo?.primaryKey, error: self.syncResult?.error, userInfo: self.userInfo)
//                                        
//                                        self.serializationInfo = SerializationInfo(realm: realm, method: self.method, userInfo: self.userInfo, oldPrimaryKey: self.primaryKey, newPrimaryKey: realmObjectInfo?.primaryKey, syncOperation: self)
//                                        
//                                        // Did Serialize
//                                        syncType.realmSyncOperation(self, didSerializeJSON: objectDictionary, serializationInfo: self.serializationInfo!, syncResult: self.syncResult, inRealm: realm)
//                                        
//                                        // Delete temp object
//                                        if realmObjectInfo?.primaryKey == nil {
//                                            if let realmObject = realm.object(ofType: self.objectType, forPrimaryKey: self.primaryKey) as? RealmSyncable {
//                                                do {
//                                                    try realm.write({ () -> Void in
//                                                        realmObject.setSyncStatus(.Synced, serializationInfo: self.serializationInfo)
//                                                    })
//                                                } catch { }
//                                            }
//                                        }
//                                        
//                                        // Update syncStatus & syncIdentifier
//                                        
//                                        dispatchCompletionGroup.leave()
//                                    })
//                                }
//                            }
//                        } else {
//                            if let realmObject = realm.object(ofType: self.objectType, forPrimaryKey: self.primaryKey) as? RealmSyncable {
//                                do {
//                                    try realm.write({ () -> Void in
//                                        realmObject.setSyncStatus(.Synced, serializationInfo: self.serializationInfo)
//                                    })
//                                } catch { }
//                            }
//                        }
//                    }
//                    
//                    if let syncType = self.objectType as? RealmSyncable.Type {
//                        
//                        // Did Sync
//                        syncType.realmSyncOperation(self, didSync: self.syncResult, inRealm: realm)
//                        
//                        // Handle Request
//                        syncType.handleRequest(self.syncResult?.request, response: self.syncResult?.response, jsonResponse: self.syncResult?.jsonResponse, error: self.syncResult?.error, fetchOperation: nil, syncOperation: self, inRealm: realm)
//                    }
//                }
//                
//                dispatchCompletionGroup.notify(queue: DispatchQueue.main, execute: {
//                    
//                    // Set NSOperation status
//                    self.isExecuting = false
//                    self.isFinished = true
//                    
//                    NotificationCenter.default.post(name: RealmSyncOperationDidCompleteNotification, object: self)
//                })
//            })
//        })
//    }
//    
//    // MARK: - Methods
//    
//    // MARK: Networking
//    
//    func objectDictionaryFromJSONResponse(_ jsonResponse: AnyObject?, serializationInfo: SerializationInfo) -> NSDictionary? {
//        if let jsonResponse = jsonResponse as? NSDictionary {
//            if let method = serializationInfo.method, let syncType = objectType as? RealmSyncable.Type {
//                if let responseObjectKey = syncType.realmSyncJSONResponseKey(method, userInfo: serializationInfo.userInfo) {
//                    return jsonResponse.object(forKey: responseObjectKey) as? NSDictionary
//                } else {
//                    return jsonResponse
//                }
//            }
//        }
//        
//        return nil
//    }
//}
