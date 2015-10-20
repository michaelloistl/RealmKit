//
//  RealmTestCase.swift
//  RealmKitTests
//
//  Created by Michael Loistl on 03/12/2014.
//  Copyright (c) 2014 aplo. All rights reserved.
//

import XCTest
import RealmSwift
@testable import RealmKit

class RealmTestCase: XCTestCase {
    
    var realm: Realm!
    
    override func setUp() {
        super.setUp()

        let config = Realm.Configuration(path: nil, inMemoryIdentifier: "RealmKitTest", encryptionKey: nil, readOnly: false, schemaVersion: 0, migrationBlock: { (migration, oldSchemaVersion) -> Void in
            
            }, objectTypes: nil)
        
        Realm.Configuration.defaultConfiguration = config
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
}

class RealmObject: Object {
    
}

class User: RealmObject {
    
}

class Item: RealmObject {
    
}