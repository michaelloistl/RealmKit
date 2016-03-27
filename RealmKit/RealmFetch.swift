//
//  RealmFetch.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmFetchCompletionBlock = (fetchResult: FetchResult!) -> Void

public struct FetchRequest {
    
    // MARK: Required
    
    public let baseURL: NSURL
    public let path: String
    
    // MARK: Optional
    
    public let parameters: [String: AnyObject]?
    public let jsonResponseKey: String?
    public let userInfo: [String: AnyObject]
    
    public init(
        baseURL: NSURL,
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

    public let request: NSURLRequest!
    public let response: NSHTTPURLResponse!
    public let success: Bool
    public let jsonResponse: AnyObject?
    public let realmObjectInfos: [RealmObjectInfo]?
    public let error: NSError?
    public let userInfo: [String: AnyObject]

    public init(
        request: NSURLRequest!,
        response: NSHTTPURLResponse!,
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
    
    var lastFetchedAt: NSDate? { get set }
    
    // MARK: - Methods
    
    static func fetchRequestWithId(id: String?, userInfo: [String: AnyObject]) -> FetchRequest?
    
    // MARK: Optional
    
    static func realmFetchWillSerializeJSON(json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm)
    static func realmFetchShouldSerializeJSON(json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm) -> Bool
    static func realmFetchDidSerializeJSON(json: AnyObject, fetchRequest: FetchRequest, fetchResult: FetchResult!, inRealm realm: Realm)
}

// MARK: - Extension for method implementations

public extension RealmFetchable where Self: RealmJSONSerializable {
    
    public static func fetchId(id: String, userInfo: [String: AnyObject] = [String: AnyObject](), completion: RealmFetchCompletionBlock) -> NSURLSessionTask? {
        if let fetchRequest = fetchRequestWithId(id, userInfo: userInfo) {
            return fetch(fetchRequest) { (fetchResult) in
                completion(fetchResult: fetchResult)
            }
        } else {
            completion(fetchResult: nil)
        }
        
        return nil
    }
    
    public static func fetchPaged(pageType: PageInfo.PageType, pageLimit: Int = 1, from: NSTimeInterval? = nil, userInfo: [String: AnyObject] = [String: AnyObject](), progress: RealmFetchPagedProgressBlock, completion: RealmFetchPagedCompletionBlock) {
        if let fetchRequest = fetchRequestWithId(nil, userInfo: userInfo), type = self as? Object.Type {
            let realmFetchPaged = RealmFetchPaged(type: type, fetchRequest: fetchRequest, pageType: pageType, from: from, progress: { (realmFetchPaged) in
                
                progress(realmFetchPaged: realmFetchPaged)
                }, completion: { (realmFetchPaged) in
                    completion(realmFetchPaged: realmFetchPaged)
            })
            
            realmFetchPaged.pageLimit = pageLimit
            realmFetchPaged.startRequest()
        } else {
            completion(realmFetchPaged: nil)
        }
    }
    
    public static func fetch(fetchRequest: FetchRequest!, serialize: Bool = true, completion: RealmFetchCompletionBlock) -> NSURLSessionTask? {
        let dispatchGroup = dispatch_group_create()
    
        var sessionTask: NSURLSessionTask?
        var fetchResult: FetchResult?
        
        // Fecth
        if let fetchRequest = fetchRequest {
            dispatch_group_enter(dispatchGroup)
            
            sessionTask = requestWithBaseURL(fetchRequest.baseURL, path: fetchRequest.path, parameters: fetchRequest.parameters, method: .GET) { (success, request, response, jsonResponse, error) -> Void in
                
                // Set fetchResult before serializing
                fetchResult = FetchResult(request: request, response: response, success: success, jsonResponse: jsonResponse, realmObjectInfos: nil, error: error)
                
                var json: AnyObject?
                
                // jsonResponse - [String: AnyObject]
                if let jsonDictionary = jsonResponse as? [String: AnyObject] {
                    if let jsonObjectKey = fetchRequest.jsonResponseKey {
                        json = jsonDictionary[jsonObjectKey]
                    } else {
                        json = jsonDictionary
                    }
                }
                    
                    // jsonResponse - [AnyObject]
                else if let jsonArray = jsonResponse as? [AnyObject] {
                    json = jsonArray
                }
                
                if let json = json {
                    dispatch_group_enter(dispatchGroup)
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), { () -> Void in
                        var realm: Realm?
                        
                        do {
                            realm = try Realm()
                        } catch { }
                        
                        if let realm = realm {
                            if serialize && realmFetchShouldSerializeJSON(json, fetchRequest: fetchRequest, inRealm: realm) {
                                let serializationInfo = SerializationInfo(realm: realm, method: .GET, userInfo: fetchRequest.userInfo)
                                
                                // Will Serialize
                                realmFetchWillSerializeJSON(json, fetchRequest: fetchRequest, inRealm: realm)
                                
                                // Array
                                if let jsonArray = json as? NSArray {
                                    dispatch_group_enter(dispatchGroup)
                                    
                                    realmObjectsWithJSONArray(jsonArray, serializationInfo: serializationInfo, completion: { (realmObjectInfos, error) -> Void in
                                        
                                        // Set fetchResult again  after serializing
                                        fetchResult = FetchResult(request: request, response: response, success: success, jsonResponse: jsonResponse, realmObjectInfos: realmObjectInfos, error: error)
                                        
                                        // Did Serialize
                                        realmFetchDidSerializeJSON(json, fetchRequest: fetchRequest, fetchResult: fetchResult, inRealm: realm)
                                        
                                        dispatch_group_leave(dispatchGroup)
                                    })
                                }
                                
                                // Dictionary
                                if let jsonDictionary = json as? NSDictionary {
                                    dispatch_group_enter(dispatchGroup)
                                    
                                    realmObjectWithJSONDictionary(jsonDictionary, serializationInfo: serializationInfo, completion: { (realmObjectInfo, error) -> Void in
                                        
                                        // Set fetchResult again  after serializing
                                        if let realmObjectInfo = realmObjectInfo {
                                            fetchResult = FetchResult(request: request, response: response, success: success, jsonResponse: jsonResponse, realmObjectInfos: [realmObjectInfo], error: error)
                                        }
                                        
                                        // Did Serialize
                                        realmFetchDidSerializeJSON(json, fetchRequest: fetchRequest, fetchResult: fetchResult, inRealm: realm)
                                        
                                        dispatch_group_leave(dispatchGroup)
                                    })
                                }
                            }
                        }
                        
                        dispatch_group_leave(dispatchGroup)
                    })
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), {
            handleRequest(fetchResult?.request, response: fetchResult?.response, jsonResponse: fetchResult?.jsonResponse, error: fetchResult?.error, fetchOperation: nil, syncOperation: nil, inRealm: nil)
            
            completion(fetchResult: fetchResult)
        })
        
        return sessionTask
    }
}
