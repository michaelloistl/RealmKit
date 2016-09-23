//
//  RealmKit.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation

open class RealmKit {
    
    public enum HTTPMethod: String {
        case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
    }
    
    open class var sharedInstance: RealmKit {
        struct Singleton {
            static let instance = RealmKit()
        }
        
        return Singleton.instance
    }
    
    open var debugLogs = false

}
