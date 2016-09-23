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
        case options = "OPTIONS"
        case get     = "GET"
        case head    = "HEAD"
        case post    = "POST"
        case put     = "PUT"
        case patch   = "PATCH"
        case delete  = "DELETE"
        case trace   = "TRACE"
        case connect = "CONNECT"
    }
    
    /// Used to store all data associated with an json-serialized response of a data or upload request.
    public struct JSONResponse {
        /// The URL request sent to the server.
        public let request: URLRequest?
        
        /// The server's response to the URL request.
        public let response: HTTPURLResponse?
        
        /// The data returned by the server.
        public let json: Any?
        
        /// The error encountered while executing or validating the request.
        public let error: Error?
        
        init(request: URLRequest?, response: HTTPURLResponse?, json: Any?, error: Error?) {
            self.request = request
            self.response = response
            self.json = json
            self.error = error
        }
    }
    
    open class var sharedInstance: RealmKit {
        struct Singleton {
            static let instance = RealmKit()
        }
        
        return Singleton.instance
    }
    
    open var debugLogs = false

}
