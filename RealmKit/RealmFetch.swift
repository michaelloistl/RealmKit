//
//  RealmFetch.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmFetchCompletionBlock = (_ fetchResult: FetchResult?) -> Void

public struct FetchRequest {
    
    // MARK: Required
    
    public let baseURL: URL
    public let path: String
    
    // MARK: Optional
    
    public let parameters: [String: AnyObject]?
    public let jsonResponseKey: String?
    public let userInfo: [String: AnyObject]
    
    public init(
        baseURL: URL,
        path: String,
        parameters: [String: AnyObject]? = nil,
        jsonResponseKey: String? = nil,
        userInfo: [String: AnyObject] = [String: AnyObject]()
        ) {
        self.baseURL = baseURL
        self.path = path
        self.parameters = parameters
        self.jsonResponseKey = jsonResponseKey
        self.userInfo = userInfo
    }
}

public struct FetchResult {

    public let request: URLRequest!
    public let response: HTTPURLResponse!
    public let success: Bool
    public let jsonResponse: AnyObject?
    public let realmObjectInfos: [RealmObjectInfo]?
    public let error: NSError?
    public let userInfo: [String: AnyObject]

    public init(
        request: URLRequest!,
        response: HTTPURLResponse!,
        success: Bool,
        jsonResponse: AnyObject? = nil,
        realmObjectInfos: [RealmObjectInfo]? = nil,
        error: NSError? = nil,
        userInfo: [String: AnyObject] = [String: AnyObject]()
        ) {
        self.request = request
        self.response = response
        self.success = success
        self.jsonResponse = jsonResponse
        self.realmObjectInfos = realmObjectInfos
        self.error = error
        self.userInfo = userInfo
    }
}

public protocol RealmFetchable: RealmKitObjectProtocol {
    
    // MARK: - Properties
    
    var lastFetchedAt: Date? { get set }
    
    // MARK: - Methods
    
    // MARK: Optional
    
    static func realmFetchWillSerialize(_ json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm)
    static func realmFetchShouldSerialize(_ json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm) -> Bool
    static func realmFetchDidSerialize(_ json: AnyObject, fetchRequest: FetchRequest, fetchResult: FetchResult!, inRealm realm: Realm)
}

// MARK: - Extension for method implementations

@available(OSX 10.10, *)
public extension RealmFetchable where Self: RealmJSONSerializable {
    
    public static func fetch(_ fetchRequest: FetchRequest!, serialize: Bool = true, completion: @escaping RealmFetchCompletionBlock) -> URLSessionTask? {
        let dispatchGroup = DispatchGroup()
    
        var sessionTask: URLSessionTask?
        var fetchResult: FetchResult?
        
        // Fecth
        if let fetchRequest = fetchRequest {
            dispatchGroup.enter()
            
            sessionTask = requestWithBaseURL(fetchRequest.baseURL, path: fetchRequest.path, parameters: fetchRequest.parameters, method: .GET) { (success, request, response, jsonResponse, error) -> Void in
                
                // Set fetchResult before serializing
                fetchResult = FetchResult(request: request, response: response, success: success, jsonResponse: jsonResponse, realmObjectInfos: nil, error: error, userInfo: fetchRequest.userInfo)
                
                var json: AnyObject? = jsonResponse
                
                // jsonResponse - [String: AnyObject]
                if let jsonDictionary = jsonResponse as? [String: AnyObject] {
                    if let jsonObjectKey = fetchRequest.jsonResponseKey {
                        json = jsonDictionary[jsonObjectKey]
                    }
                }
                
                if let json = json {
                    dispatchGroup.enter()
                    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async(execute: { () -> Void in
                        if let realm = try? Realm() {
                            if serialize && realmFetchShouldSerialize(json, fetchRequest: fetchRequest, inRealm: realm) {
                                let serializationInfo = SerializationInfo(realm: realm, method: .GET, userInfo: fetchRequest.userInfo, fetchRequest: fetchRequest)
                                
                                // Will Serialize
                                realmFetchWillSerialize(json, fetchRequest: fetchRequest, inRealm: realm)
                                
                                // Array
                                if let jsonArray = json as? NSArray {
                                    dispatchGroup.enter()
                                    
                                    realmObjectsWithJSONArray(jsonArray, serializationInfo: serializationInfo, completion: { (realmObjectInfos, error) -> Void in
                                        
                                        // Set fetchResult again  after serializing
                                        fetchResult = FetchResult(request: request, response: response, success: success, jsonResponse: jsonResponse, realmObjectInfos: realmObjectInfos, error: error, userInfo: fetchRequest.userInfo)
                                        
                                        // Did Serialize
                                        realmFetchDidSerialize(json, fetchRequest: fetchRequest, fetchResult: fetchResult, inRealm: realm)
                                        
                                        dispatchGroup.leave()
                                    })
                                }
                                
                                // Dictionary
                                if let jsonDictionary = json as? NSDictionary {
                                    dispatchGroup.enter()
                                    
                                    realmObjectWithJSONDictionary(jsonDictionary, serializationInfo: serializationInfo, completion: { (realmObjectInfo, error) -> Void in
                                        
                                        // Set fetchResult again  after serializing
                                        if let realmObjectInfo = realmObjectInfo {
                                            fetchResult = FetchResult(request: request, response: response, success: success, jsonResponse: jsonResponse, realmObjectInfos: [realmObjectInfo], error: error, userInfo: fetchRequest.userInfo)
                                        }
                                        
                                        // Did Serialize
                                        realmFetchDidSerialize(json, fetchRequest: fetchRequest, fetchResult: fetchResult, inRealm: realm)
                                        
                                        dispatchGroup.leave()
                                    })
                                }
                            }
                        }
                        
                        dispatchGroup.leave()
                    })
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main, execute: {
            handleRequest(fetchResult?.request, response: fetchResult?.response, jsonResponse: fetchResult?.jsonResponse, error: fetchResult?.error, fetchOperation: nil, syncOperation: nil, inRealm: nil)
            
            completion(fetchResult)
        })
        
        return sessionTask
    }
}
