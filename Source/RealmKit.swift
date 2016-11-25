//
//  RealmKit.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation
import Alamofire

public extension NSNotification.Name {
    
    // Fetch
    
    // Sync
    static let SyncOperationDidStart = NSNotification.Name("com.aplo.RealmKit.SyncOperationDidStart")
    static let SyncOperationDidComplete = NSNotification.Name("com.aplo.RealmKit.SyncOperationDidComplete")
}

public class RealmKit {
    
    /// Returns shared instance
    public class var shared: RealmKit {
        struct Singleton {
            static let instance = RealmKit()
        }
        
        return Singleton.instance
    }
    
    public var debugLogs = false

    lazy var sessionManager: Alamofire.SessionManager = {
        let configuration = URLSessionConfiguration.default
//        configuration.httpMaximumConnectionsPerHost = 10
        let _sessionManager = Alamofire.SessionManager(configuration: configuration)
        return _sessionManager
    }()
    
}
