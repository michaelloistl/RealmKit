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

    public init(
        request: NSURLRequest!,
        response: NSHTTPURLResponse!,
        success: Bool,
        jsonResponse: AnyObject? = nil,
        realmObjectInfos: [RealmObjectInfo]? = nil,
        error: NSError? = nil
        ) {
        self.request = request
        self.response = response
        self.success = success
        self.jsonResponse = jsonResponse
        self.realmObjectInfos = realmObjectInfos
        self.error = error
    }
}

public protocol RealmFetchable: RealmKitObjectProtocol {
    
    // MARK: - Properties
    
    var lastFetchedAt: NSDate? { get set }
    
    // MARK: - Methods
    
    static func fetchRequestWithId(id: String?, userInfo: [String: AnyObject]) -> FetchRequest?
    
    // MARK: Optional
    
    static func realmFetchWillSerializeJSON(json: AnyObject, fetchRequest: FetchRequest, inRealm realm: Realm)
    static func realmFetchDidSerializeJSON(json: AnyObject, fetchRequest: FetchRequest, jsonResponse: AnyObject?, realmObjectInfos: [RealmObjectInfo]?, inRealm realm: Realm)
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
    
    public static func fetch(fetchRequest: FetchRequest!, completion: RealmFetchCompletionBlock) -> NSURLSessionTask? {
        let dispatchGroup = dispatch_group_create()
    
        var completionSuccess = false
        var completionRequest: NSURLRequest?
        var completionResponse: NSHTTPURLResponse?
        var completionJSONResponse: AnyObject?
        var completionRealmObjectInfos: [RealmObjectInfo]?
        var completionError: NSError?
        var sessionTask: NSURLSessionTask?
        
        // Fecth
        if let fetchRequest = fetchRequest {
            dispatch_group_enter(dispatchGroup)
            
            sessionTask = requestWithBaseURL(fetchRequest.baseURL, path: fetchRequest.path, parameters: fetchRequest.parameters, method: .GET) { (success, request, response, jsonResponse, error) -> Void in
                completionSuccess = success
                completionRequest = request
                completionResponse = response
                completionJSONResponse = jsonResponse
                completionError = error
                
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
                            let serializationInfo = SerializationInfo(realm: realm, method: .GET, userInfo: fetchRequest.userInfo)
                            
                            // Will Serialize
                            realmFetchWillSerializeJSON(json, fetchRequest: fetchRequest, inRealm: realm)
                            
                            // Array
                            if let jsonArray = json as? NSArray {
                                dispatch_group_enter(dispatchGroup)
                                
                                realmObjectsWithJSONArray(jsonArray, serializationInfo: serializationInfo, completion: { (realmObjectInfos, error) -> Void in
                                    completionRealmObjectInfos = realmObjectInfos
                                    
                                    // Did Serialize
                                    realmFetchDidSerializeJSON(json, fetchRequest: fetchRequest, jsonResponse: jsonResponse, realmObjectInfos: realmObjectInfos, inRealm: realm)
                                    
                                    dispatch_group_leave(dispatchGroup)
                                })
                            }
                            
                            // Dictionary
                            if let jsonDictionary = json as? NSDictionary {
                                dispatch_group_enter(dispatchGroup)
                                
                                realmObjectWithJSONDictionary(jsonDictionary, serializationInfo: serializationInfo, completion: { (realmObjectInfo, error) -> Void in
                                    
                                    if let realmObjectInfo = realmObjectInfo {
                                        completionRealmObjectInfos = [realmObjectInfo]
                                    }
                                    
                                    // Did Serialize
                                    realmFetchDidSerializeJSON(json, fetchRequest: fetchRequest, jsonResponse: jsonResponse, realmObjectInfos: completionRealmObjectInfos, inRealm: realm)
                                    
                                    dispatch_group_leave(dispatchGroup)
                                })
                            }
                        }
                        
                        dispatch_group_leave(dispatchGroup)
                    })
                }
                
                dispatch_group_leave(dispatchGroup)
            }
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), {
            handleRequest(completionRequest, response: completionResponse, jsonResponse: completionJSONResponse, error: completionError, fetchOperation: nil, syncOperation: nil, inRealm: nil)
            
            let fetchResult = FetchResult(request: completionRequest, response: completionResponse, success: completionSuccess, jsonResponse: completionJSONResponse, realmObjectInfos: completionRealmObjectInfos, error: completionError)
            
            completion(fetchResult: fetchResult)
        })
        
        return sessionTask
    }
}
