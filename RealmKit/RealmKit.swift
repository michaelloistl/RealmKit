//
//  RealmKit.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation

public class RealmKit {
    
    public enum Method: String {
        case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
    }
    
    public class var sharedInstance: RealmKit {
        struct Singleton {
            static let instance = RealmKit()
        }
        
        return Singleton.instance
    }
    
    public var debugLogs = false

}