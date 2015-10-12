//
//  RealmSyncManagerTests.swift
//  ContextiOSTests
//
//  Created by Michael Loistl on 09/01/2015.
//  Copyright (c) 2015 aplo. All rights reserved.
//

import UIKit
import XCTest
@testable import RealmKit

class RealmSyncManagerTests: RealmTestCase {
    
    var syncManager: RealmSyncManager?
    
    override func setUp() {
        super.setUp()
        
        syncManager = RealmSyncManager.sharedManager
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSyncOperationIsQueued() {
        let testData = [
            ["objectType": "RealmObject", "primaryKey": "1", "path": "path1", "httpMethod": RealmSyncOperation.HTTPMethod.GET.rawValue, "assert": true],
            ["objectType": "Item", "primaryKey": "1", "path": "path1", "httpMethod": RealmSyncOperation.HTTPMethod.GET.rawValue, "assert": false],
            ["objectType": "RealmObject", "primaryKey": "2", "path": "path1", "httpMethod": RealmSyncOperation.HTTPMethod.GET.rawValue, "assert": false],
            ["objectType": "RealmObject", "primaryKey": "1", "path": "path2", "httpMethod": RealmSyncOperation.HTTPMethod.GET.rawValue, "assert": false],
            ["objectType": "RealmObject", "primaryKey": "1", "path": "path1", "httpMethod": RealmSyncOperation.HTTPMethod.POST.rawValue, "assert": false]
        ]

        let syncOperation = RealmSyncOperation(objectType: RealmObject.self, primaryKey: "1", path: "path1", parameters: nil, httpMethod: .GET)
        syncManager?.syncOperationQueue.addOperation(syncOperation)

        for test in testData {
            var objectType = RealmObject.self

            if test["objectType"] as! String != "RealmObject" {
                objectType = Item.self
            }

            let primaryKey = test["primaryKey"] as! String
            let path = test["path"] as! String
            let httpMethod = RealmSyncOperation.HTTPMethod(rawValue: test["httpMethod"] as! String)
            let assert = test["assert"] as! Bool

            let testSyncOperation = RealmSyncOperation(objectType: objectType, primaryKey: primaryKey, path: path, parameters: nil, httpMethod: httpMethod!)
            let result = RealmSyncManager.syncOperationIsQueued(testSyncOperation, syncManager: self.syncManager!)
            XCTAssertEqual(assert, result, "\(assert) -> \(result) -> \(NSStringFromClass(objectType)) -> \(test.description)")
        }
    }
    
}
