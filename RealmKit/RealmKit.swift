//
//  RealmKit.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation

public class RealmKit {
    
//    /// Used to store all data associated with an json-serialized response of a data or upload request.
//    public struct RequestResult {
//        /// The URL request sent to the server.
//        public let request: URLRequest?
//        
//        /// The server's response to the URL request.
//        public let response: HTTPURLResponse?
//        
//        /// The data returned by the server.
//        public let json: Any?
//        
//        /// The error encountered while executing or validating the request.
//        public let error: AFError?
//        
//        init(request: URLRequest?, response: HTTPURLResponse?, json: Any?, error: AFError?) {
//            self.request = request
//            self.response = response
//            self.json = json
//            self.error = error
//        }
//    }
    
    
    
    /// Returns shared instance
    public class var sharedInstance: RealmKit {
        struct Singleton {
            static let instance = RealmKit()
        }
        
        return Singleton.instance
    }
    
    public var debugLogs = false

}
