//
//  RealmFetchManager.swift
//  RealmKit
//
//  Created by Michael Loistl on 23/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public let RealmFetchOperationProgressDidChangeNotification = "com.aplo.RealmFetchOperationProgressDidChangeNotification"
public let RealmFetchOperationDidStartNotification = "com.aplo.RealmFetchOperationDidStartNotification"
public let RealmFetchOperationDidFinishNotification = "com.aplo.RealmFetchOperationDidFinishNotification"

public protocol RealmFetchManagerDelegate {
    func realmFetchManager(sender: RealmFetchManager, shouldStartWithFetchOperation fetchOperation: RealmFetchOperation) -> Bool
}

public class RealmFetchManager {
    
    var syncQueue: dispatch_queue_t = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    
    var resumeTimer: NSTimer?
    
    var totalFetchOperations: Int = 0
    
    public var delegate: RealmFetchManagerDelegate?
    
    public class var sharedManager: RealmFetchManager {
        struct Singleton {
            static let instance = RealmFetchManager()
        }
        
        return Singleton.instance
    }
    
    public var progress: Double {
        let remainingCount = Double(self.fetchOperationQueue.operationCount)
        
        if self.totalFetchOperations > 0 {
            return 1 - remainingCount / Double(self.totalFetchOperations)
        }
        
        return 0
    }
    
    public lazy var fetchOperationQueue: NSOperationQueue = {
        var _operationQueue = NSOperationQueue()
        _operationQueue.name = "Fetch queue"
        _operationQueue.maxConcurrentOperationCount = 1
        
        return _operationQueue
    }()
    
    // MARK: Initializers
    
    init() {
        
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Methods
    
    public func addFetchOperation(fetchOperation: RealmFetchOperation) {
        
        // Check if a fetchOperation with same identifier is already queued
        if fetchOperationIsQueued(fetchOperation) == false {
            
            // SyncOperation completion block
            fetchOperation.completionBlock = {
                if self.fetchOperationQueue.operationCount == 0 {
                    self.totalFetchOperations = 0
                }
                
                dispatch_async(dispatch_get_main_queue()) { () -> Void in
                    NSNotificationCenter.defaultCenter().postNotificationName(RealmFetchOperationProgressDidChangeNotification, object: nil)
                }
            }
            
            // Add SyncOperation to queue
            fetchOperationQueue.addOperation(fetchOperation)
            
            totalFetchOperations = totalFetchOperations + 1
        }
    }
    
    public func fetchOperationIsQueued(fetchOperation: RealmFetchOperation) -> Bool {
        var isQueued = false
        
        for operation in self.fetchOperationQueue.operations {
            if let operation = operation as? RealmFetchOperation {
                if fetchOperation.identifier == operation.identifier {
                    
                    // Validate and Increase queuePriority
                    if fetchOperation.queuePriority.rawValue > operation.queuePriority.rawValue {
                        operation.queuePriority = fetchOperation.queuePriority
                    }
                    
                    isQueued = true
                    break
                }
            }
        }
        
        return isQueued
    }
    
    public func suspendAndResumeAfter(resumeAfter: NSTimeInterval) {
        NSLog("suspendAndResumeAfter: \(resumeAfter)")
        fetchOperationQueue.suspended = true
        
        setTimerWithDuration(resumeAfter)
    }
    
    private func setTimerWithDuration(duration: NSTimeInterval) {
        resumeTimer?.invalidate()
        resumeTimer = nil
        
        if duration > 0 {
            resumeTimer = NSTimer(timeInterval: duration, target: RealmFetchManager.sharedManager, selector: #selector(RealmFetchManager.resumeFetchOperations), userInfo: nil, repeats: false)
            if let resumeTimer = resumeTimer {
                NSRunLoop.mainRunLoop().addTimer(resumeTimer, forMode: NSRunLoopCommonModes)
            }
        }
    }
    
    public func resumeFetchOperations() {
        fetchOperationQueue.suspended = false
    }
    
    @objc public class func resumeFetchOperations() {
        sharedManager.fetchOperationQueue.suspended = false
    }
}

// MARK: - RealmFetchOperation

public class RealmFetchOperation: NSOperation {
    
    public typealias OrpandObjectsClosure = (completion: OrpandObjectsCompletionBlock) -> Void
    public typealias FetchClosure = (completion: (fetchResult: FetchResult) -> Void) -> NSURLSessionTask?
    
    public typealias OrpandObjectsCompletionBlock = (realmObjectInfos: [RealmObjectInfo]?) -> Void
    
    public let objectType: Object.Type
    public let orpandObjectsClosure: OrpandObjectsClosure
    public let fetchClosure: FetchClosure
    public let identifier: String
    
    public var sessionTask: NSURLSessionTask?
    
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
    
    public init<T: Object>(type: T.Type, orpandObjectsClosure: OrpandObjectsClosure, fetchClosure: FetchClosure, identifier: String) {
        self.objectType = type
        self.orpandObjectsClosure = orpandObjectsClosure
        self.fetchClosure = fetchClosure
        self.identifier = identifier
        
        super.init()
    }
    
    // MARK: - Methods
    
    // MARK: NSOperation
    
    override public func start() {
        if NSThread.isMainThread() == false {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.start()
            })
            return
        }
        
        if self.cancelled {
            return
        }
        
        // Set NSOperation status
        executing = true
        finished = false
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            NSNotificationCenter.defaultCenter().postNotificationName(RealmFetchOperationDidStartNotification, object: self)
        })
        
        let dispatchOrpandObjectsGroup = dispatch_group_create()
        let dispatchFetchObjectsGroup = dispatch_group_create()
        
        var orpandRealmObjectInfos: [RealmObjectInfo]?
        var fetchClosureResult: FetchResult?
        
        if self.cancelled == false {
            
            // Orpand Objects
            dispatch_group_enter(dispatchOrpandObjectsGroup)
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), { () -> Void in
                
                dispatch_group_enter(dispatchOrpandObjectsGroup)
                self.orpandObjectsClosure(completion: { (realmObjectInfos) -> Void in
                    orpandRealmObjectInfos = realmObjectInfos
                    
                    dispatch_group_leave(dispatchOrpandObjectsGroup)
                })
                
                dispatch_group_leave(dispatchOrpandObjectsGroup)
            })

            // Fetch Objects
            dispatch_group_enter(dispatchFetchObjectsGroup)
            dispatch_group_notify(dispatchOrpandObjectsGroup, dispatch_get_main_queue(), {
                
                dispatch_group_enter(dispatchFetchObjectsGroup)
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), { () -> Void in
                    
                    if self.cancelled == false {
                        dispatch_group_enter(dispatchFetchObjectsGroup)
                        self.sessionTask = self.fetchClosure(completion: { (fetchResult) in
                            fetchClosureResult = fetchResult
                            
                            dispatch_group_leave(dispatchFetchObjectsGroup)
                        })
                    }
                    
                    dispatch_group_leave(dispatchFetchObjectsGroup)
                })
                
                dispatch_group_leave(dispatchFetchObjectsGroup)
            })
        }
        
        dispatch_group_notify(dispatchFetchObjectsGroup, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), {
            let success = fetchClosureResult?.response?.statusCode >= 200 && fetchClosureResult?.response?.statusCode < 300
            
            var realm: Realm?
            
            do {
                realm = try Realm()
            } catch { }
            
            if success && self.cancelled == false {
                // TODO: There might be an issue when response is paged...
                
                if let orpandRealmObjectInfos = orpandRealmObjectInfos, fetchedRealmObjectInfos = fetchClosureResult?.realmObjectInfos {
                    var deleteOrpandRealmObjectInfos = [RealmObjectInfo]()
                    for orpandRealmObjectInfo in orpandRealmObjectInfos {
                        if fetchedRealmObjectInfos.contains({ $0.primaryKey == orpandRealmObjectInfo.primaryKey }) == false {
                            deleteOrpandRealmObjectInfos.append(orpandRealmObjectInfo)
                        }
                    }
                    
                    do {
                        try realm?.write({ () -> Void in
                            for realmObjectInfo in deleteOrpandRealmObjectInfos {
                                if let realmObject = realm?.objectForPrimaryKey(realmObjectInfo.type, key: realmObjectInfo.primaryKey) as? RealmKitObject {
                                    realmObject.deletedAt = NSDate().timeIntervalSince1970
                                }
                            }
                        })
                    } catch { }
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if self.cancelled == false {
                    if let realmKitType = self.objectType as? RealmKitObject.Type {
                        realmKitType.handleRequest(fetchClosureResult?.request, response: fetchClosureResult?.response, jsonResponse: fetchClosureResult?.jsonResponse, error: fetchClosureResult?.error, fetchOperation: self, syncOperation: nil, inRealm: nil)
                    }
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(RealmFetchOperationDidFinishNotification, object: self)
                }
                
                // Set NSOperation status
                self.executing = false
                self.finished = true
            })
        })
    }
}
