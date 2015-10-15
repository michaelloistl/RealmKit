//
//  RealmJSONSerializerTests.swift
//  ContextiOSTests
//
//  Created by Michael Loistl on 09/01/2015.
//  Copyright (c) 2015 aplo. All rights reserved.
//

import UIKit
import XCTest
import RealmSwift
@testable import RealmKit

class RealmJSONSerializerTests: RealmTestCase {
    
    var syncManager: RealmSyncManager?
    
    override func setUp() {
        super.setUp()
        
        syncManager = RealmSyncManager.sharedManager
    }
    
    override func tearDown() {
        
        //
        
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    func jsonRespondWithFilename(filename: String) -> [String : AnyObject]! {
        let path = NSBundle(forClass: RealmJSONSerializerTests.self).pathForResource(filename, ofType: "json")
        let jsonData = try? NSData(contentsOfFile: path!, options: .DataReadingMappedIfSafe)
        
        return (try! NSJSONSerialization.JSONObjectWithData(jsonData!, options: NSJSONReadingOptions.MutableContainers)) as! [String : AnyObject]
    }
    
    // MARK: - Tests
    
    func testRealmObjectWithType() {
        let jsonDictionary = jsonRespondWithFilename("User")
        
        let user = User()
        XCTAssertNotNil(user as RealmSyncProtocol)
        
        if let realm = try? Realm() {
            var object: Object?
            
            do {
                try realm.write({ () -> Void in
                    object = User.realmObjectWithType(User.self, inRealm: realm, withJSONDictionary: jsonDictionary, mappingIdentifier: nil, identifier: nil)
                })
            } catch {
                
            }
            
            XCTAssertNotNil(object, "\(object)")
            XCTAssertTrue(object is User, "\(object)")
            
            if let object = object {
                let id = object.valueForKey("id") as? String
                let name = object.valueForKey("name") as? String
                
                XCTAssert(id == "1", "\(id)")
                XCTAssert(name == "User 1", "\(id)")
            }
        }
        
    }
}
