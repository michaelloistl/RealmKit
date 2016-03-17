//
//  RealmFetchPaged.swift
//  RealmKit
//
//  Created by Michael Loistl on 17/03/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmFetchPagedCompletionBlock = (realmFetchPaged: RealmFetchPaged) -> Void

public struct PageInfo {
    
    public enum PageType {
        case Next
        case Previous
        case None
    }
    
    public let currentPage: Int
    public let totalPages: Int
    public let totalItems: Int
    public let previousPageURL: NSURL?
    public let nextPageURL: NSURL?
    
    public let jsonResponse: AnyObject?
    
    public var description: String {
        return "currentPage: \(currentPage); totalPages: \(totalPages); totalItems: \(totalItems); previousPageURL: \(previousPageURL); nextPageURL: \(nextPageURL)"
    }
    
    public init(
        currentPage: Int,
        totalPages: Int,
        totalItems: Int,
        previousPageURL: NSURL?,
        nextPageURL: NSURL?,
        jsonResponse: AnyObject?
        ) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.totalItems = totalItems
        self.previousPageURL = previousPageURL
        self.nextPageURL = nextPageURL
        self.jsonResponse = jsonResponse
    }
}

public protocol RealmFetchPagable: RealmKitObjectProtocol {
    
    // MARK: Required
    
    static func pagingParametersForFetchRequest(fetchRequest: FetchRequest, pageType: PageInfo.PageType) -> [String: AnyObject]?
    static func realmFetchPageInfoFromResponse(response: NSHTTPURLResponse?, jsonResponse: AnyObject?) -> PageInfo?
}

public class RealmFetchPaged {
    
    let type: Object.Type
    let fetchRequest: FetchRequest
    let pageType: PageInfo.PageType
    let from: NSTimeInterval?
    let lastSyncedFallback: NSTimeInterval
    
    var pageLimit = 1
    var pageInfo: PageInfo? {
        didSet {
            var requestStarted = false
            if let pageInfo = pageInfo {
                if success && (pageLimit == 0 || pageInfo.currentPage < pageLimit) && pageInfo.currentPage < pageInfo.totalPages {
                    startRequest()
                    requestStarted = true
                }
            }
            
            if !requestStarted {
                completion(realmFetchPaged: self)
            }
        }
    }
    
    var completion: RealmFetchPagedCompletionBlock
    var success = true
    var realmObjectInfos = [RealmObjectInfo]()
    var error: NSError?
    
    // MARK: - Initializers
    
    public required init(type: Object.Type, fetchRequest: FetchRequest, pageType: PageInfo.PageType, from: NSTimeInterval? = nil, lastSyncedFallback: NSTimeInterval = 0, completion: RealmFetchPagedCompletionBlock) {
        self.type = type
        self.fetchRequest = fetchRequest
        self.pageType = pageType
        self.completion = completion
        self.from = from
        self.lastSyncedFallback = lastSyncedFallback
    }
    
    // MARK: - Methods
    
    private func parametersFromPageInfo(pageInfo: PageInfo, pageType: PageInfo.PageType) -> [String: AnyObject]? {
        var url: NSURL?
        if pageType == .Next {
            url = pageInfo.nextPageURL
        } else if pageType == .Previous {
            url = pageInfo.previousPageURL
        }
        
        if let url = url {
            let urlComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
            if let queryItems = urlComponents?.queryItems {
                var parameters = [String: AnyObject]()
                for queryItem in queryItems {
                    parameters[queryItem.name] = queryItem.value
                }
                
                return parameters
            }
        }
        
        return nil
    }
    
    public func startRequest() {
        var parameters = self.fetchRequest.parameters ?? [String: AnyObject]()
        
        if let pageInfo = pageInfo, parametersFromPageInfo = parametersFromPageInfo(pageInfo, pageType: pageType) {
            for (key, value) in parametersFromPageInfo {
                parameters[key] = value
            }
        } else if let pagingParameters = (type as? RealmFetchPagable.Type)?.pagingParametersForFetchRequest(self.fetchRequest, pageType: pageType) {
            pagingParameters.forEach({ (key, value) in
                parameters[key] = value
            })
        }
        
        let fetchRequest = FetchRequest(baseURL: self.fetchRequest.baseURL, path: self.fetchRequest.path, parameters: parameters, userInfo: self.fetchRequest.userInfo)
        
        if let fetchableType = type as? RealmFetchable.Type, serializableType = fetchableType as? RealmJSONSerializable.Type {
            serializableType.realmFetch(fetchRequest) { (fetchResult) in
                self.success = fetchResult.success
                self.error = fetchResult.error
                
                if let realmObjectInfos = fetchResult.realmObjectInfos {
                    self.realmObjectInfos += realmObjectInfos
                }
                
                self.pageInfo = (self.type as? RealmFetchPagable.Type)?.realmFetchPageInfoFromResponse(fetchResult.response, jsonResponse: fetchResult.jsonResponse)
            }
        }
    }
    
    func startRequestWithCompletion(completion: RealmFetchPagedCompletionBlock) {
        startRequest()
    }
}
