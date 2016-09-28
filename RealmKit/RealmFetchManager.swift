//
//  RealmFetchManager.swift
//  RealmKit
//
//  Created by Michael Loistl on 23/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

//public let RealmFetchOperationProgressDidChangeNotification = "com.aplo.RealmFetchOperationProgressDidChangeNotification"
//public let RealmFetchOperationDidStartNotification = "com.aplo.RealmFetchOperationDidStartNotification"
//public let RealmFetchOperationDidFinishNotification = "com.aplo.RealmFetchOperationDidFinishNotification"
//
//@available(OSX 10.10, *)
//public protocol RealmFetchManagerDelegate {
//    func realmFetchManager(_ sender: RealmFetchManager, shouldStartWithFetchOperation fetchOperation: RealmFetchOperation) -> Bool
//}
//
//@available(OSX 10.10, *)
//open class RealmFetchManager {
//    
//    var fetchQueue: DispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
//    
//    var resumeTimer: Timer?
//    
//    var totalFetchOperations: Int = 0
//    
//    open var delegate: RealmFetchManagerDelegate?
//    
//    open class var sharedManager: RealmFetchManager {
//        struct Singleton {
//            static let instance = RealmFetchManager()
//        }
//        
//        return Singleton.instance
//    }
//    
//    open var progress: Double {
//        let remainingCount = Double(self.fetchOperationQueue.operationCount)
//        
//        if self.totalFetchOperations > 0 {
//            return 1 - remainingCount / Double(self.totalFetchOperations)
//        }
//        
//        return 0
//    }
//    
//    open lazy var fetchOperationQueue: OperationQueue = {
//        var _operationQueue = OperationQueue()
//        _operationQueue.name = "Fetch queue"
//        _operationQueue.maxConcurrentOperationCount = 1
//        
//        return _operationQueue
//    }()
//    
//    // MARK: Initializers
//    
//    init() {
//        
//    }
//    
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
//    
//    // MARK: - Methods
//    
//    open func addFetchOperation(_ fetchOperation: RealmFetchOperation) {
//        
//        // Check if a fetchOperation with same identifier is already queued
//        if fetchOperationIsQueued(fetchOperation) == false {
//            
//            // SyncOperation completion block
//            fetchOperation.completionBlock = {
//                if self.fetchOperationQueue.operationCount == 0 {
//                    self.totalFetchOperations = 0
//                }
//                
//                DispatchQueue.main.async { () -> Void in
//                    NotificationCenter.default.post(name: Notification.Name(rawValue: RealmFetchOperationProgressDidChangeNotification), object: nil)
//                }
//            }
//            
//            // Add SyncOperation to queue
//            fetchOperationQueue.addOperation(fetchOperation)
//            
//            totalFetchOperations = totalFetchOperations + 1
//        }
//    }
//    
//    open func fetchOperationIsQueued(_ fetchOperation: RealmFetchOperation) -> Bool {
//        var isQueued = false
//        
//        for operation in self.fetchOperationQueue.operations {
//            if let operation = operation as? RealmFetchOperation {
//                if fetchOperation.identifier == operation.identifier {
//                    
//                    // Validate and Increase queuePriority
//                    if fetchOperation.queuePriority.rawValue > operation.queuePriority.rawValue {
//                        operation.queuePriority = fetchOperation.queuePriority
//                    }
//                    
//                    isQueued = true
//                    break
//                }
//            }
//        }
//        
//        return isQueued
//    }
//    
//    open func suspendAndResumeAfter(_ resumeAfter: TimeInterval) {
//        fetchOperationQueue.isSuspended = true
//        
//        setTimerWithDuration(resumeAfter)
//    }
//    
//    fileprivate func setTimerWithDuration(_ duration: TimeInterval) {
//        resumeTimer?.invalidate()
//        resumeTimer = nil
//        
//        if duration > 0 {
//            resumeTimer = Timer(timeInterval: duration, target: RealmFetchManager.sharedManager, selector: #selector(RealmFetchManager.resumeFetchOperations), userInfo: nil, repeats: false)
//            if let resumeTimer = resumeTimer {
//                RunLoop.main.add(resumeTimer, forMode: RunLoopMode.commonModes)
//            }
//        }
//    }
//    
//    open func resumeFetchOperations() {
//        fetchOperationQueue.isSuspended = false
//    }
//    
//    @objc open class func resumeFetchOperations() {
//        sharedManager.fetchOperationQueue.isSuspended = false
//    }
//}
//
//// MARK: - RealmFetchOperation
//
//@available(OSX 10.10, *)
//open class RealmFetchOperation: Operation {
//    
//    public typealias BeforeFetchClosure = (_ completion: (_ beforeData: [String: Any]?) -> Void) -> Void
//    public typealias FetchClosure = (_ completion: (_ fetchResult: FetchResult) -> Void) -> URLSessionTask?
//    public typealias AfterFetchClosure = (_ beforeData: [String: Any]?, _ fetchResult: FetchResult?, _ completion: (_ afterData: [String: Any]?) -> Void) -> Void
//    
//    open let objectType: Object.Type
//    open let beforeFetchClosure: BeforeFetchClosure
//    open let fetchClosure: FetchClosure
//    open let afterFetchClosure: AfterFetchClosure
//    open let identifier: String
//    
//    var beforeData: [String: Any]?
//    var fetchResult: FetchResult?
//    var afterData: [String: Any]?
//    
//    open var sessionTask: URLSessionTask?
//    
//    fileprivate var _executing: Bool = false
//    override open var isExecuting: Bool {
//        get {
//            return _executing
//        }
//        set {
//            if _executing != newValue {
//                willChangeValue(forKey: "isExecuting")
//                _executing = newValue
//                didChangeValue(forKey: "isExecuting")
//            }
//        }
//    }
//    
//    fileprivate var _finished: Bool = false;
//    override open var isFinished: Bool {
//        get {
//            return _finished
//        }
//        set {
//            if _finished != newValue {
//                willChangeValue(forKey: "isFinished")
//                _finished = newValue
//                didChangeValue(forKey: "isFinished")
//            }
//        }
//    }
//    
//    override open var isAsynchronous: Bool {
//        return true
//    }
//    
//    // Initializers
//    
//    public init<T: Object>(type: T.Type, beforeFetchClosure: @escaping BeforeFetchClosure, fetchClosure: @escaping FetchClosure, afterFetchClosure: @escaping AfterFetchClosure, queuePriority: Operation.QueuePriority = .normal, identifier: String) {
//        self.objectType = type
//        self.beforeFetchClosure = beforeFetchClosure
//        self.fetchClosure = fetchClosure
//        self.afterFetchClosure = afterFetchClosure
//        self.identifier = identifier
//        
//        super.init()
//        
//        self.queuePriority = queuePriority
//    }
//    
//    // MARK: - Methods
//    
//    // MARK: NSOperation
//    
//    override open func start() {
//        if Thread.isMainThread == false {
//            DispatchQueue.main.async(execute: { () -> Void in
//                self.start()
//            })
//            return
//        }
//        
//        if self.isCancelled {
//            return
//        }
//        
//        // Set NSOperation status
//        isExecuting = true
//        isFinished = false
//        
//        DispatchQueue.main.async(execute: { () -> Void in
//            NotificationCenter.default.post(name: Notification.Name(rawValue: RealmFetchOperationDidStartNotification), object: self)
//        })
//        
//        let dispatchBeforeFetchGroup = DispatchGroup()
//        let dispatchFetchObjectsGroup = DispatchGroup()
//        let dispatchAfterFetchGroup = DispatchGroup()
//        
//        if self.isCancelled == false {
//            
//            // Before Fetch
//            dispatchBeforeFetchGroup.enter()
//            RealmFetchManager.sharedManager.fetchQueue.async(execute: { () -> Void in
//                
//                if self.isCancelled == false {
//                    dispatchBeforeFetchGroup.enter()
//                    self.beforeFetchClosure({ (beforeData) in
//                        self.beforeData = beforeData
//
//                        dispatchBeforeFetchGroup.leave()
//                    })
//                }
//
//                dispatchBeforeFetchGroup.leave()
//            })
//
//            // Fetch
//            dispatchFetchObjectsGroup.enter()
//            dispatchBeforeFetchGroup.notify(queue: RealmFetchManager.sharedManager.fetchQueue, execute: {
//                
//                if self.isCancelled == false {
//                    dispatchFetchObjectsGroup.enter()
//                    self.sessionTask = self.fetchClosure({ (fetchResult) in
//                        self.fetchResult = fetchResult
//                        
//                        dispatchFetchObjectsGroup.leave()
//                    })
//                }
//                
//                dispatchFetchObjectsGroup.leave()
//            })
//            
//            // After Fetch
//            dispatchAfterFetchGroup.enter()
//            dispatchFetchObjectsGroup.notify(queue: RealmFetchManager.sharedManager.fetchQueue, execute: {
//
//                if self.isCancelled == false {
//                    dispatchAfterFetchGroup.enter()
//                    self.afterFetchClosure(self.beforeData, self.fetchResult, { (afterData) in
//                        self.afterData = afterData
//
//                        dispatchAfterFetchGroup.leave()
//                    })
//                }
//                
//                dispatchAfterFetchGroup.leave()
//            })
//        }
//        
//        dispatchAfterFetchGroup.notify(queue: DispatchQueue.main) {
//            if self.isCancelled == false {
//                if let realmKitType = self.objectType as? RealmKitObject.Type {
//                    realmKitType.handleRequest(self.fetchResult?.request, response: self.fetchResult?.response, jsonResponse: self.fetchResult?.jsonResponse, error: self.fetchResult?.error, fetchOperation: self, syncOperation: nil, inRealm: nil)
//                }
//                
//                NotificationCenter.default.post(name: Notification.Name(rawValue: RealmFetchOperationDidFinishNotification), object: self)
//            }
//            
//            // Set NSOperation status
//            self.isExecuting = false
//            self.isFinished = true
//        }
//    }
//}
