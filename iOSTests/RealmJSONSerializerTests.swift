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
//@testable import RealmKit
//
//class RealmJSONSerializerTests: RealmTestCase {
//    
//    var syncManager: RealmSyncManager?
//    
//    override func setUp() {
//        super.setUp()
//        
//        syncManager = RealmSyncManager.sharedManager
//    }
//    
//    override func tearDown() {
//        
//        //
//        
//        super.tearDown()
//    }
//    
//    // MARK: - Helpers
//    
//    func jsonRespondWithFilename(_ filename: String) -> [String : AnyObject]! {
//        let path = Bundle(for: RealmJSONSerializerTests.self).path(forResource: filename, ofType: "json")
//        let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path!), options: .mappedIfSafe)
//        
//        return (try! JSONSerialization.jsonObject(with: jsonData!, options: JSONSerialization.ReadingOptions.mutableContainers)) as! [String : AnyObject]
//    }
//    
//    // MARK: - Tests
//    
////    func testRealmObjectWithType() {
////        let jsonDictionary = jsonRespondWithFilename("User")
////        
////        let user = User()
////        XCTAssertNotNil(user as! RealmSyncable)
////        
////        if let realm = try? Realm() {
////            var object: Object?
////            
////            do {
////                try realm.write({ () -> Void in
////                    object = User.realmObjectWithType(User.self, inRealm: realm, withJSONDictionary: jsonDictionary, mappingIdentifier: nil, identifier: nil)
////                })
////            } catch {
////                
////            }
////            
////            XCTAssertNotNil(object, "\(object)")
////            XCTAssertTrue(object is User, "\(object)")
////            
////            if let object = object {
////                let id = object.valueForKey("id") as? String
////                let name = object.valueForKey("name") as? String
////                
////                XCTAssert(id == "1", "\(id)")
////                XCTAssert(name == "User 1", "\(id)")
////            }
////        }
////        
////    }
//}
