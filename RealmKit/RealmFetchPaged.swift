//
//  RealmFetchPaged.swift
//  RealmKit
//
//  Created by Michael Loistl on 17/03/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

public typealias RealmFetchPagedProgressBlock = (realmFetchPaged: RealmFetchPaged) -> Void
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
    static func pagingParametersForRealmFetchPaged(realmFetchPaged: RealmFetchPaged) -> [String: AnyObject]?
    static func realmFetchPageInfoFromResponse(response: NSHTTPURLResponse?, jsonResponse: AnyObject?) -> PageInfo?
}

public class RealmFetchPaged {
    
    public let type: Object.Type
    public let pageType: PageInfo.PageType
    public let from: NSTimeInterval?
    public let lastSyncedFallback: NSTimeInterval
    
    public var fetchRequest: FetchRequest
    public var pageLimit = 1
    public var pageInfo: PageInfo? {
        didSet {
            var requestStarted = false
            if let pageInfo = pageInfo {
                if success && (pageLimit == 0 || pageInfo.currentPage < pageLimit) && pageInfo.currentPage < pageInfo.totalPages {
                    progress(realmFetchPaged: self)
                    
                    startRequest()
                    requestStarted = true
                }
            }
            
            if !requestStarted {
                completion(realmFetchPaged: self)
            }
        }
    }
    
    var progress: RealmFetchPagedProgressBlock
    var completion: RealmFetchPagedCompletionBlock
    
    public var success = true
    public var realmObjectInfos = [RealmObjectInfo]()
    public var error: NSError?
    
    // MARK: - Initializers
    
    public required init(type: Object.Type, fetchRequest: FetchRequest, pageType: PageInfo.PageType, from: NSTimeInterval? = nil, lastSyncedFallback: NSTimeInterval = 0, progress: RealmFetchPagedProgressBlock, completion: RealmFetchPagedCompletionBlock) {
        self.type = type
        self.fetchRequest = fetchRequest
        self.pageType = pageType
        self.from = from
        self.lastSyncedFallback = lastSyncedFallback
        
        self.progress = progress
        self.completion = completion
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
        var parameters = fetchRequest.parameters ?? [String: AnyObject]()
        
        if let pageInfo = pageInfo, parametersFromPageInfo = parametersFromPageInfo(pageInfo, pageType: pageType) {
            for (key, value) in parametersFromPageInfo {
                parameters[key] = value
            }
        } else if let pagingParameters = (type as? RealmFetchPagable.Type)?.pagingParametersForRealmFetchPaged(self) {
            pagingParameters.forEach({ (key, value) in
                parameters[key] = value
            })
        }
        
        fetchRequest = FetchRequest(baseURL: self.fetchRequest.baseURL, path: self.fetchRequest.path, parameters: parameters, jsonResponseKey: self.fetchRequest.jsonResponseKey, userInfo: self.fetchRequest.userInfo)
        
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
    
    public func startRequestWithProgress(progress: RealmFetchPagedProgressBlock, completion: RealmFetchPagedCompletionBlock) {
        self.progress = progress
        self.completion = completion
        
        startRequest()
    }
}
