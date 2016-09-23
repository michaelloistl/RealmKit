//
//  RealmFetchPaged.swift
//  RealmKit
//
//  Created by Michael Loistl on 17/03/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

@available(OSX 10.10, *)
public typealias RealmFetchPagedCompletionBlock = (realmFetchPaged: RealmFetchPaged!, completed: Bool) -> Void

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
    
    public var description: String {
        return "currentPage: \(currentPage); totalPages: \(totalPages); totalItems: \(totalItems); previousPageURL: \(previousPageURL); nextPageURL: \(nextPageURL)"
    }
    
    public init(
        currentPage: Int,
        totalPages: Int,
        totalItems: Int,
        previousPageURL: NSURL?,
        nextPageURL: NSURL?
        ) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.totalItems = totalItems
        self.previousPageURL = previousPageURL
        self.nextPageURL = nextPageURL
    }
}

@available(OSX 10.10, *)
public protocol RealmFetchPagable: RealmKitObjectProtocol {
    
    // MARK: Required
    static func fetchPagingParametersForRealmFetchPaged(realmFetchPaged: RealmFetchPaged) -> [String: AnyObject]?
    static func fetchPageInfoFromFetchResult(fetchResult: FetchResult?) -> PageInfo?
    
    // MARK: Optional
    static func fetchPagedDidProcess(realmFetchPaged: RealmFetchPaged)
    static func fetchPagedDidComplete(realmFetchPaged: RealmFetchPaged)
}

@available(OSX 10.10, *)
public class RealmFetchPaged {
    
    public let type: Object.Type
    public let pageType: PageInfo.PageType
    public let from: NSTimeInterval?
    public let lastSyncedFallback: NSTimeInterval
    public let usePagingParameter: Bool
    
    public var fetchRequest: FetchRequest
    public var pageLimit = 1
    public var pageInfo: PageInfo? {
        didSet {
            var requestStarted = false
            if let pageInfo = pageInfo {
                if fetchResult?.success == true && (pageLimit == 0 || pageInfo.currentPage < pageLimit) && pageInfo.currentPage < pageInfo.totalPages {
                    completion(realmFetchPaged: self, completed: false)
                    
                    (type as? RealmFetchPagable.Type)?.fetchPagedDidProcess(self)
                    
                    startRequest()
                    requestStarted = true
                }
            }
            
            if !requestStarted {
                completion(realmFetchPaged: self, completed: true)
                
                (type as? RealmFetchPagable.Type)?.fetchPagedDidComplete(self)
            }
        }
    }
    
    var completion: RealmFetchPagedCompletionBlock
    
    public var fetchResult: FetchResult?
    public var realmObjectInfos = [RealmObjectInfo]()
    
    public var success: Bool {
        return fetchResult?.success ?? false
    }
    
    // MARK: - Initializers
    
    public required init(type: Object.Type, fetchRequest: FetchRequest, pageType: PageInfo.PageType, from: NSTimeInterval? = nil, lastSyncedFallback: NSTimeInterval = 0, usePagingParameter: Bool = true, completion: RealmFetchPagedCompletionBlock) {
        self.type = type
        self.fetchRequest = fetchRequest
        self.pageType = pageType
        self.from = from
        self.lastSyncedFallback = lastSyncedFallback
        self.usePagingParameter = usePagingParameter
        
        self.completion = completion
    }
    
    // MARK: - Methods
    
    public func startRequest(addPagingParameters: Bool = true) -> NSURLSessionTask? {
        var parameters = fetchRequest.parameters ?? [String: AnyObject]()
        
        if let pagingParameters = (type as? RealmFetchPagable.Type)?.fetchPagingParametersForRealmFetchPaged(self) where addPagingParameters {
            pagingParameters.forEach({ (key, value) in
                parameters[key] = value
            })
        }
        
        fetchRequest = FetchRequest(baseURL: self.fetchRequest.baseURL, path: self.fetchRequest.path, parameters: parameters, jsonResponseKey: self.fetchRequest.jsonResponseKey, userInfo: self.fetchRequest.userInfo)
        
        if let fetchableType = type as? RealmFetchable.Type, serializableType = fetchableType as? RealmJSONSerializable.Type {
            return serializableType.fetch(fetchRequest) { (fetchResult) in
                self.fetchResult = fetchResult
                
                if let realmObjectInfos = fetchResult.realmObjectInfos {
                    self.realmObjectInfos += realmObjectInfos
                }
                
                self.pageInfo = (self.type as? RealmFetchPagable.Type)?.fetchPageInfoFromFetchResult(fetchResult)
            }
        }
        
        return nil
    }
    
    public func startRequestWithCompletion(addPagingParameters: Bool = true, completion: RealmFetchPagedCompletionBlock) -> NSURLSessionTask? {
        self.completion = completion
        
        return startRequest(addPagingParameters)
    }
}
