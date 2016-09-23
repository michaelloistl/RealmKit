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
public typealias RealmFetchPagedCompletionBlock = (RealmFetchPaged?, Bool) -> Void

public struct PageInfo {
    
    public enum PageType {
        case next
        case previous
        case none
    }
    
    public let currentPage: Int
    public let totalPages: Int
    public let totalItems: Int
    public let previousPageURL: URL?
    public let nextPageURL: URL?
    
    public var description: String {
        return "currentPage: \(currentPage); totalPages: \(totalPages); totalItems: \(totalItems); previousPageURL: \(previousPageURL); nextPageURL: \(nextPageURL)"
    }
    
    public init(
        currentPage: Int,
        totalPages: Int,
        totalItems: Int,
        previousPageURL: URL?,
        nextPageURL: URL?
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
    static func fetchPagingParameters(for realmFetchPaged: RealmFetchPaged) -> [String: AnyObject]?
    static func fetchPageInfo(from fetchResult: FetchResult?) -> PageInfo?
    
    // MARK: Optional
    static func fetchPagedDidProcess(_ realmFetchPaged: RealmFetchPaged)
    static func fetchPagedDidComplete(_ realmFetchPaged: RealmFetchPaged)
}

@available(OSX 10.10, *)
open class RealmFetchPaged {
    
    open let type: Object.Type
    open let pageType: PageInfo.PageType
    open let from: TimeInterval?
    open let lastSyncedFallback: TimeInterval
    open let usePagingParameter: Bool
    
    open var fetchRequest: FetchRequest
    open var pageLimit = 1
    open var pageInfo: PageInfo? {
        didSet {
            var requestStarted = false
            if let pageInfo = pageInfo {
                if fetchResult?.success == true && (pageLimit == 0 || pageInfo.currentPage < pageLimit) && pageInfo.currentPage < pageInfo.totalPages {
                    completion(self, false)
                    
                    (type as? RealmFetchPagable.Type)?.fetchPagedDidProcess(self)
                    
                    let _ = startRequest()
                    requestStarted = true
                }
            }
            
            if !requestStarted {
                completion(self, true)
                
                (type as? RealmFetchPagable.Type)?.fetchPagedDidComplete(self)
            }
        }
    }
    
    var completion: RealmFetchPagedCompletionBlock
    
    open var fetchResult: FetchResult?
    open var realmObjectInfos = [RealmObjectInfo]()
    
    open var success: Bool {
        return fetchResult?.success ?? false
    }
    
    // MARK: - Initializers
    
    public required init(type: Object.Type, fetchRequest: FetchRequest, pageType: PageInfo.PageType, from: TimeInterval? = nil, lastSyncedFallback: TimeInterval = 0, usePagingParameter: Bool = true, completion: @escaping RealmFetchPagedCompletionBlock) {
        self.type = type
        self.fetchRequest = fetchRequest
        self.pageType = pageType
        self.from = from
        self.lastSyncedFallback = lastSyncedFallback
        self.usePagingParameter = usePagingParameter
        
        self.completion = completion
    }
    
    // MARK: - Methods
    
    open func startRequest(_ addPagingParameters: Bool = true) -> URLSessionTask? {
        var parameters = fetchRequest.parameters ?? [String: AnyObject]()
        
        if let pagingParameters = (type as? RealmFetchPagable.Type)?.fetchPagingParameters(for: self) , addPagingParameters {
            pagingParameters.forEach({ (key, value) in
                parameters[key] = value
            })
        }
        
        fetchRequest = FetchRequest(baseURL: self.fetchRequest.baseURL, path: self.fetchRequest.path, parameters: parameters, jsonResponseKey: self.fetchRequest.jsonResponseKey, userInfo: self.fetchRequest.userInfo)
        
        if let fetchableType = type as? RealmFetchable.Type, let serializableType = fetchableType as? RealmJSONSerializable.Type {
            return serializableType.fetch(fetchRequest) { (fetchResult) in
                self.fetchResult = fetchResult
                
                if let realmObjectInfos = fetchResult?.realmObjectInfos {
                    self.realmObjectInfos += realmObjectInfos
                }
                
                self.pageInfo = (self.type as? RealmFetchPagable.Type)?.fetchPageInfo(from: fetchResult)
            }
        }
        
        return nil
    }
    
    open func startRequestWithCompletion(_ addPagingParameters: Bool = true, completion: @escaping RealmFetchPagedCompletionBlock) -> URLSessionTask? {
        self.completion = completion
        
        return startRequest(addPagingParameters)
    }
}
