//
//  RealmFetchPaged.swift
//  RealmKit
//
//  Created by Michael Loistl on 17/03/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import RealmSwift

//@available(OSX 10.10, *)
//public typealias RealmFetchPagedCompletionBlock = (RealmFetchPaged?, Bool) -> Void

//@available(OSX 10.10, *)
//open class RealmFetchPaged {
//    
//    open let type: Object.Type
//    open let pageType: PageInfo.PageType
//    open let from: TimeInterval?
//    open let lastSyncedFallback: TimeInterval
//    open let usePagingParameter: Bool
//    
//    open var fetchRequest: FetchRequest
//    open var pageLimit = 1
//    open var pageInfo: PageInfo? {
//        didSet {
//            var requestStarted = false
//            if let pageInfo = pageInfo {
//                if fetchResult?.success == true && (pageLimit == 0 || pageInfo.currentPage < pageLimit) && pageInfo.currentPage < pageInfo.totalPages {
//                    completion(self, false)
//                    
//                    (type as? RealmFetchPagable.Type)?.fetchPagedDidProcess(self)
//                    
//                    let _ = startRequest()
//                    requestStarted = true
//                }
//            }
//            
//            if !requestStarted {
//                completion(self, true)
//                
//                (type as? RealmFetchPagable.Type)?.fetchPagedDidComplete(self)
//            }
//        }
//    }
//    
//    var completion: RealmFetchPagedCompletionBlock
//    
//    open var fetchResult: FetchResult?
//    open var realmObjectInfos = [RealmObjectInfo]()
//    
//    open var success: Bool {
//        return fetchResult?.success ?? false
//    }
//    
//    
//    
//    // MARK: - Methods
//    
//    open func startRequest(_ addPagingParameters: Bool = true) -> URLSessionTask? {
//        var parameters = fetchRequest.parameters ?? [String: Any]()
//        
//        if let pagingParameters = (type as? RealmFetchPagable.Type)?.fetchPagingParameters(for: self) , addPagingParameters {
//            pagingParameters.forEach({ (key, value) in
//                parameters[key] = value
//            })
//        }
//        
//        fetchRequest = FetchRequest(baseURL: self.fetchRequest.baseURL, path: self.fetchRequest.path, parameters: parameters, jsonResponseKey: self.fetchRequest.jsonResponseKey, userInfo: self.fetchRequest.userInfo)
//        
//        if let fetchableType = type as? RealmFetchable.Type, let serializableType = fetchableType as? JSONSerializable.Type {
//            return serializableType.fetch(fetchRequest) { (fetchResult) in
//                self.fetchResult = fetchResult
//                
//                if let realmObjectInfos = fetchResult?.realmObjectInfos {
//                    self.realmObjectInfos += realmObjectInfos
//                }
//                
//                self.pageInfo = (self.type as? RealmFetchPagable.Type)?.fetchPageInfo(from: fetchResult)
//            }
//        }
//        
//        return nil
//    }
//    
//    open func startRequestWithCompletion(_ addPagingParameters: Bool = true, completion: @escaping RealmFetchPagedCompletionBlock) -> URLSessionTask? {
//        self.completion = completion
//        
//        return startRequest(addPagingParameters)
//    }
//}
