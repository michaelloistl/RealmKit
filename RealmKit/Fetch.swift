//
//  Fetch.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/01/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift
import Alamofire

/// Used to provide the data required to perform a fetch request.
public struct FetchRequest {
    
    // MARK: Required
    public let baseURL: URL
    public let path: String
    public let realm: Realm
    
    // MARK: Optional
    public let parameters: [String: Any]?
    public let jsonResponseKey: String?
    public let userInfo: [String: Any]
    
    public init(
        baseURL: URL,
        path: String,
        realm: Realm,
        parameters: [String: Any]? = nil,
        jsonResponseKey: String? = nil,
        userInfo: [String: Any] = [String: Any]()
        ) {
        self.baseURL = baseURL
        self.path = path
        self.realm = realm
        self.parameters = parameters
        self.jsonResponseKey = jsonResponseKey
        self.userInfo = userInfo
    }
}

/// Used to store all data associated with an json-serialized response of a data or upload request.
public struct FetchResult {
    /// The original FetchRequest
    public let fetchRequest: FetchRequest
    
    /// Alamofire's JSONSerializer response
    public let response: Alamofire.Response
    
    /// The result from the object serialization
    public let serializationResult: SerializationResult
    
    init(fetchRequest: FetchRequest, response: Alamofire.Response, serializationResult: SerializationResult) {
        self.fetchRequest = fetchRequest
        self.response = response
        self.serializationResult = serializationResult
    }
}

public struct FetchPagedResult {
    /// Array of all fetchResults
    public let fetchResults: [FetchResult]
    
    /// Array of all pageInfos
    public let pageInfos: [PageInfo]
    
    init(fetchResults: [FetchResult], pageInfos: [PageInfo]) {
        self.fetchResults = fetchResults
        self.pageInfos = pageInfos
    }
}

/// Used to ...
public struct PageInfo {
    public enum PageType {
        case next
        case previous
        case none
    }
    
    public let fetchResult: FetchResult?
    
    public let currentPage: Int
    public let totalPages: Int
    public let totalItems: Int
    public let previousPageURL: URL?
    public let nextPageURL: URL?
    
    public var description: String {
        return "currentPage: \(currentPage); totalPages: \(totalPages); totalItems: \(totalItems); previousPageURL: \(previousPageURL); nextPageURL: \(nextPageURL)"
    }
    
    public init(
        fetchResult: FetchResult?,
        currentPage: Int,
        totalPages: Int,
        totalItems: Int,
        previousPageURL: URL?,
        nextPageURL: URL?
        ) {
        self.fetchResult = fetchResult
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.totalItems = totalItems
        self.previousPageURL = previousPageURL
        self.nextPageURL = nextPageURL
    }
}

// MARK: - Extension for method implementations

@available(OSX 10.10, *)
public extension Fetchable where Self: JSONSerializable {
    
    public static func fetch(_ fetchRequest: FetchRequest,
                             persist: Bool = true,
                             modifyKeyValues: @escaping (([String: AnyObject]) -> [String: AnyObject])? = nil,
                             modifyObject: @escaping ((Object) -> Object)? = nil,
                             didSerializeObjects: @escaping (([Object]) -> ())? = nil,
                             completion: @escaping (FetchResult?) -> ()) -> URLSessionTask? {
        let dispatchGroup = DispatchGroup()
        var dispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
        
        var _sessionTask: URLSessionTask?
        var _fetchResult: FetchResult?
        
        if let url = self.baseURL()?.appendingPathComponent(fetchRequest.path) {
            dispatchGroup.enter()
            let request = Alamofire.request(url, method: .get, headers: self.headers()).responseJSON { response in
            
                var json: Any? = response.result.value
                
                if let jsonDictionary = response.result.value as? [String: Any] {
                    if let jsonObjectKey = fetchRequest.jsonResponseKey {
                        json = jsonDictionary[jsonObjectKey]
                    }
                }
                
                if let json = json {
                    dispatchGroup.enter()
                    
                    // Set dispatchQueue to main thread in order to return array with serialized objects
                    if !persist {
                        dispatchQueue = DispatchQueue.main
                    }
                    
                    dispatchGroup.enter()
                    dispatchQueue.async(execute: {
                        if let realm = try? Realm() {
                            let serializationRequest = SerializationRequest(realm: realm, httpMethod: .get, userInfo: fetchRequest.userInfo, fetchRequest: fetchRequest)
                            
                            // Array
                            if let jsonArray = json as? NSArray {
                                dispatchGroup.enter()
                                self.objects(with: jsonArray,
                                             serializationRequest: serializationRequest,
                                             persist: persist,
                                             modifyKeyValues: modifyKeyValues,
                                             modifyObject: modifyObject,
                                             didSerializeObjects: didSerializeObjects,
                                             completion: { serializationResult in
                                                
                                                _fetchResult = FetchResult(fetchRequest: fetchRequest, response: response, serializationResult: serializationResult)
                                                
                                                dispatchGroup.leave()
                                    })
                            }
                            
                            // Dictionary
                            else if let jsonDictionary = json as? NSDictionary {
                                dispatchGroup.enter()
                                self.object(with: jsonArray,
                                            serializationRequest: serializationRequest,
                                            persist: persist,
                                            modifyKeyValues: modifyKeyValues,
                                            modifyObject: modifyObject,
                                            didSerializeObjects: didSerializeObjects,
                                            completion: { serializationResult in
                                                
                                                _fetchResult = FetchResult(fetchRequest: fetchRequest, response: response, serializationResult: serializationResult)
                                                
                                                dispatchGroup.leave()
                                })
                            }
                        }
                        
                        dispatchGroup.leave()
                    })
                    
                    dispatchGroup.leave()
                }
                
                dispatchGroup.leave()
            }
            
            _sessionTask = request.task()
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main, execute: {
            self.fetchDidComplete(_fetchResult)
            
            completion(_fetchResult)
        })
        
        return _sessionTask
    }
}

@available(OSX 10.10, *)
public class FetchPaged<T: Object> {
    public let pageType: PageInfo.PageType
    public let fetchRequest: FetchRequest
    public let pageLimit: Int
    public let persist: Bool
    
    public let modifyKeyValues: (([String: AnyObject]) -> [String: AnyObject])?
    public let modifyObject: ((Object) -> Object)?
    public let didSerializeObjects: (([Object]) -> ())?
    public let completion: (FetchPagedResult?, Bool) -> ()
    
    public var fetchResults = [FetchResult]()
    public var pageInfos = [PageInfo]()
    
    open var pageInfo: PageInfo? {
        didSet {
            var requestStarted = false
            if let pageInfo = pageInfo {
                pageInfos.append(pageInfo)
                
                if pageInfo.fetchResult?.response.isSuccess == true && (pageLimit == 0 || pageInfo.currentPage < pageLimit) && pageInfo.currentPage < pageInfo.totalPages {
                    
                    let results = FetchPagedResult(fetchResults: fetchResults, pageInfos: pageInfos)
                    completion(results, false)
                    
                    (T.Type as? FetchPagable.Type)?.fetchPagedDidFetch(results)
                    
                    let pagingParameters = (T.Type as? FetchPagable.Type)?.pagingParameters(from: pageInfo)
                    
                    let _ = startRequest(with: pagingParameters)
                    requestStarted = true
                }
            }

            if !requestStarted {
                let results = FetchPagedResult(fetchResults: fetchResults, pageInfos: pageInfos)
                completion(results, true)
                
                (T.Type as? FetchPagable.Type)?.fetchPagedDidComplete(results)
            }
        }
    }
    
    // MARK: - Initializers
    
    public required init<T: Object>(type: T.Type,
                         fetchRequest: FetchRequest,
                         pageType: PageInfo.PageType,
                         pageLimit: Int = 1,
                         persist: Bool = true,
                         modifyKeyValues: @escaping (([String: AnyObject]) -> [String: AnyObject])? = nil,
                         modifyObject: @escaping ((Object) -> Object)? = nil,
                         didSerializeObjects: @escaping (([Object]) -> ())? = nil,
                         completion: @escaping (FetchPagedResult?, Bool) -> ()) {
        self.fetchRequest = fetchRequest
        self.pageType = pageType
        self.pageLimit = pageLimit
        self.persist = persist
        
        self.modifyKeyValues = modifyKeyValues
        self.modifyObject = modifyObject
        self.didSerializeObjects = didSerializeObjects
        self.completion = completion
    }
    
    // MARK: - Methods
    
    public func startRequest(with pagingParameters: [String: Any]?) -> URLSessionTask? {
        var parameters = fetchRequest.parameters ?? [String: Any]()
        pagingParameters.forEach({ (key, value) in
            parameters[key] = value
        })
        
        let fetchRequest = FetchRequest(baseURL: self.fetchRequest.baseURL, path: self.fetchRequest.path, parameters: parameters, jsonResponseKey: self.fetchRequest.jsonResponseKey, userInfo: self.fetchRequest.userInfo)
        
        if let fetchableType = T.Type as? Fetchable.Type, let fetchPagableType = T.Type as? FetchPagable.Type {
            return fetchableType.fetch(fetchRequest,
                                       persist: self.persist,
                                       modifyKeyValues: self.modifyKeyValues,
                                       modifyObject: self.modifyObject,
                                       didSerializeObjects: self.didSerializeObjects,
                                       completion: { fetchResult in
                                        
                                        if let fetchResult = fetchResult {
                                            self.fetchResults.append(fetchResult)
                                        }
                                        
                                        self.pageInfo = (T.Type as? FetchPagable.Type)?.pageInfo(from: fetchResult)
            })
        }
        
        return nil
    }
}
