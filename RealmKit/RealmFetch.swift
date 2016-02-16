//
//  RealmFetch.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmFetchCompletionBlock = (request: NSURLRequest!, response: NSHTTPURLResponse!, success: Bool, jsonResponse: AnyObject?, realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void

public struct FetchInfo {
    
    // MARK: Required
    
    public let baseURL: NSURL
    public var path: String
    
    // MARK: Optional
    
    public var parameters: [String: AnyObject]?
    public var jsonResponseKey: String?
    public var identifier: String?
    public var serializationIdentifier: String?
    public var userInfo: [String: AnyObject]?
    
    public init(
        baseURL: NSURL,
        path: String!,
        parameters: [String: AnyObject]? = nil,
        jsonResponseKey: String? = nil,
        identifier: String? = nil,
        serializationIdentifier: String? = nil,
        userInfo: [String: AnyObject]? = nil
        ) {
        self.baseURL = baseURL
        self.path = path
        self.parameters = parameters
        self.jsonResponseKey = jsonResponseKey
        self.identifier = identifier
        self.serializationIdentifier = serializationIdentifier
        self.userInfo = userInfo
    }
}

public protocol RealmFetchable: RealmKitObjectProtocol {
    
    // MARK: - Properties
    
    var lastFetchedAt: NSDate? { get set }
    
    // MARK: - Methods
    
    // MARK: Required
    
    static func realmFetchPath() -> String!
    static func realmFetchParameters() -> [String: AnyObject]?
    static func realmFetchJSONResponseKey() -> String?
    
    // MARK: Optional
    
    static func realmFetchUserInfo(identifier: String?) -> [String: AnyObject]?
    
    static func realmFetchWillSerializeJSON(json: AnyObject, fetchInfo: FetchInfo, inRealm realm: Realm)
    static func realmFetchDidSerializeJSON(json: AnyObject, fetchInfo: FetchInfo, jsonResponse: AnyObject?, realmObjectInfos: [RealmObjectInfo]?, inRealm realm: Realm)
}

// MARK: - Extension for method implementations

public extension RealmFetchable where Self: RealmJSONSerializable {
    
    public static func realmFetch(completion: RealmFetchCompletionBlock) -> NSURLSessionTask? {
        let fetchInfo = FetchInfo(baseURL: baseURL(), path: realmFetchPath(), parameters: realmFetchParameters(), identifier: nil, serializationIdentifier: nil, userInfo: realmFetchUserInfo(nil))
        
        return realmFetch(fetchInfo, completion: { (request, response, success, jsonResponse, realmObjectInfos, error) -> Void in
            
            completion(request: request, response: response, success: success, jsonResponse: jsonResponse, realmObjectInfos: realmObjectInfos, error: error)
        })
    }
    
    public static func realmFetch(fetchInfo: FetchInfo, completion: RealmFetchCompletionBlock) -> NSURLSessionTask? {
        let dispatchGroup = dispatch_group_create()
    
        var completionSuccess = false
        var completionRequest: NSURLRequest?
        var completionResponse: NSHTTPURLResponse?
        var completionJSONResponse: AnyObject?
        var completionRealmObjectInfos: [RealmObjectInfo]?
        var completionError: NSError?
        var sessionTask: NSURLSessionTask?
        
        // Set lastFetchedAt in userInfo
        var userInfo = fetchInfo.userInfo
        if userInfo == nil {
            userInfo = [String: AnyObject]()
        }
        userInfo?["RealmKit"] = ["lastFetchedAt": NSDate().timeIntervalSince1970]
        
        // Fecth
        dispatch_group_enter(dispatchGroup)
        
        sessionTask = requestWithBaseURL(fetchInfo.baseURL, path: fetchInfo.path, parameters: fetchInfo.parameters, method: .GET) { (success, request, response, jsonResponse, error) -> Void in
            
            completionSuccess = success
            completionRequest = request
            completionResponse = response
            completionJSONResponse = jsonResponse
            completionError = error
            
            var json: AnyObject?
            
            // jsonResponse - [String: AnyObject]
            if let jsonDictionary = jsonResponse as? [String: AnyObject] {
                if let jsonObjectKey = fetchInfo.jsonResponseKey ?? self.realmFetchJSONResponseKey() {
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
                        let serializationInfo = SerializationInfo(realm: realm, method: .GET, identifier: fetchInfo.identifier, serializationIdentifier: fetchInfo.serializationIdentifier, userInfo: fetchInfo.userInfo)
                        
                        // Will Serialize
                        realmFetchWillSerializeJSON(json, fetchInfo: fetchInfo, inRealm: realm)
                        
                        // Array
                        if let jsonArray = json as? NSArray {
                            dispatch_group_enter(dispatchGroup)
                            
                            realmObjectsWithJSONArray(jsonArray, serializationInfo: serializationInfo, completion: { (realmObjectInfos, error) -> Void in
                                completionRealmObjectInfos = realmObjectInfos
                                
                                // Did Serialize
                                realmFetchDidSerializeJSON(json, fetchInfo: fetchInfo, jsonResponse: jsonResponse, realmObjectInfos: realmObjectInfos, inRealm: realm)
                                
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
                                realmFetchDidSerializeJSON(json, fetchInfo: fetchInfo, jsonResponse: jsonResponse, realmObjectInfos: completionRealmObjectInfos, inRealm: realm)
                                
                                dispatch_group_leave(dispatchGroup)
                            })
                        }
                    }
                    
                    dispatch_group_leave(dispatchGroup)
                })
            }
            
            dispatch_group_leave(dispatchGroup)
        }
        
        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), {
            handleRequest(completionRequest, response: completionResponse, jsonResponse: completionJSONResponse, error: completionError, fetchOperation: nil, syncOperation: nil, inRealm: nil)
            
            completion(request: completionRequest, response: completionResponse, success: completionSuccess, jsonResponse: completionJSONResponse, realmObjectInfos: completionRealmObjectInfos, error: completionError)
        })
        
        return sessionTask
    }
}