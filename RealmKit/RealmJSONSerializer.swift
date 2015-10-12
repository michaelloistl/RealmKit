//
//  RealmJSONSerializer.swift
//  RealmKit
//
//  Created by Michael Loistl on 28/11/2014.
//  Copyright (c) 2014 Michael Loistl. All rights reserved.
//

import Foundation
import RealmSwift

let RealmJSONSerializerErrorDomain = "com.aplo.ErrorDomain.RealmJSONObjectMapping"

public class RealmObjectInfo {
    let type: Object.Type
    let primaryKey: String
    let indexPath: NSIndexPath? = nil
    
    init(type: Object.Type, primaryKey: String) {
        self.type = type
        self.primaryKey = primaryKey
    }
}

public extension Object {
    
    // MARK: CreateOrUpdate objects with JSON Array
    
    public class func realmObjectsInRealm(realm: Realm,  withJSONArray array: NSArray, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        realmObjectsInRealm(realm, withJSONArray: array, mappingIdentifier: nil, identifier: nil) { (realmObjectInfos, error) -> Void in
            
            completion(realmObjectInfos: realmObjectInfos, error: error)
        }
    }
    
    public class func realmObjectsInRealm(realm: Realm,  withJSONArray array: NSArray, mappingIdentifier: String?, identifier: String?, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfos = [RealmObjectInfo]()
            
            realm.write({ () -> Void in
                for object in array {
                    if let dictionary = object as? NSDictionary, syncType = self as? RealmSyncProtocol.Type {
                        let type = syncType.classForParsingJSONDictionary(dictionary)
                        
                        if let realmObject = self.realmObjectWithType(self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                            
                            if let primaryKey = type.primaryKey() {
                                if let primaryKey = realmObject.valueForKey(primaryKey) as? String {
                                    let realmObjectInfo = RealmObjectInfo(type: self, primaryKey: primaryKey)
                                    completionRealmObjectInfos.append(realmObjectInfo)
                                }
                            }
                        }
                    }
                }
            })
            
            completion(realmObjectInfos: completionRealmObjectInfos, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfos: nil, error: error)
        }
    }
    
    // MARK: CreateOrUpdate object with JSON Dictionary
    
    public class func realmObjectInRealm(realm: Realm, withJSONDictionary dictionary: NSDictionary, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        realmObjectInRealm(realm, withJSONDictionary: dictionary, mappingIdentifier: nil, identifier: nil, replaceObjectWithPrimaryKey: nil) { (realmObjectInfo, error) -> Void in
            completion(realmObjectInfo: realmObjectInfo, error: error)
        }
    }
    
    public class func realmObjectInRealm(realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?, replaceObjectWithPrimaryKey oldPrimaryKey: String?, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfo: RealmObjectInfo?
            
            realm.write({ () -> Void in
                if let syncType = self as? RealmSyncProtocol.Type {
                    let type = syncType.classForParsingJSONDictionary(dictionary)
                    
                    if let realmObject = self.realmObjectWithType(self, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                        
                        if let primaryKey = type.primaryKey() {
                            if let newPrimaryKey = realmObject.valueForKey(primaryKey) as? String {
                                let realmObjectInfo = RealmObjectInfo(type: self, primaryKey: newPrimaryKey)
                                completionRealmObjectInfo = realmObjectInfo
                                
                                // Did create RealmObject in transactionWithBlock
                                if let syncType = self as? RealmSyncProtocol {
                                    syncType.realmObjectInRealm(realm, didCreateOrUpdateRealmObjectWithPrimaryKey: newPrimaryKey, replacingObjectWithPrimaryKey: newPrimaryKey)
                                }
                            }
                        }
                    }
                }
            })
            
            completion(realmObjectInfo: completionRealmObjectInfo, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfo: nil, error: error)
        }
    }
    
    // This function executes within the transaction block of realmObjectInRealm()
    // Override to modify initial and new RealmObject within the same transaction block
    public class func realmObjectInRealm(realm: Realm, didCreateOrUpdateRealmObjectWithPrimaryKey newPrimaryKey: String?, replacingObjectWithPrimaryKey oldPrimaryKey: String?) {
        
    }
    
    // CreateOrUpdate RealmObject with mapping
    public class func realmObjectWithType<T>(type: T.Type, inRealm realm: Realm, withJSONDictionary dictionary: NSDictionary, mappingIdentifier: String?, identifier: String?) -> Object? {
        
        // Object key -> JSON keyPath
        if let objectType = type as? Object.Type, syncType = type as? RealmSyncProtocol.Type, mappingDictionary = syncType.JSONKeyPathsByPropertyKeyWithIdentifier(mappingIdentifier, identifier: identifier) {
            var keyValueDictionary = [String: AnyObject]()
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue: AnyObject = dictionary.valueForKeyPath(keyPath) {
                    if let _ = jsonValue as? NSNull {
                        
                        // Default Value if it's not primary key
                        if let primaryKey = objectType.primaryKey() {
                            if key != primaryKey {
                                let defaultPropertyValues = syncType.defaultPropertyValues()
                                if let defaultValue: AnyObject = defaultPropertyValues[key] {
                                    keyValueDictionary[key] = defaultValue
                                }
                            }
                        }
                    } else {
                        
                        // ValueTransformer
                        if let valueTransformer = syncType.JSONTransformerForKey(key, inRealm: realm, mappingIdentifier: mappingIdentifier, identifier: identifier) {
                            if let value: AnyObject = valueTransformer.transformedValue(jsonValue) {
                                keyValueDictionary[key] = value
                            }
                        } else {
                            
                            // JSON Value
                            keyValueDictionary[key] = jsonValue
                        }
                    }
                }
            }
            
            if let primaryKey = objectType.primaryKey(), _ = keyValueDictionary[primaryKey] as? String {
                return realm.create(objectType, value: keyValueDictionary, update: true)
            }
        }
        
        return nil
    }
    
    // MARK: - Methods
    
    public class func hasPrimaryKey() -> Bool {
        if let primaryKey = primaryKey() where primaryKey.characters.count > 0 {
            return true
        }
        return false
    }
}

// MARK: - ValueTransformers

public class RealmValueTransformer: NSValueTransformer {
    
    var forwardClosure: ((value: AnyObject?) -> AnyObject?)?
    var reverseClosure: ((value: AnyObject?) -> AnyObject?)?
    
    // MARK: Initializers
    
    override init() {
        super.init()
    }
    
    convenience init(forwardClosure: ((value: AnyObject?) -> AnyObject?)?, reverseClosure: ((value: AnyObject?) -> AnyObject?)?) {
        self.init()
        
        self.forwardClosure = forwardClosure
        self.reverseClosure = reverseClosure
    }
    
    // MARK: Class Functions
    
    // Returns a transformer which transforms values using the given closure.
    // Reverse transformations will not be allowed.
    class func transformerWithClosure(closure: (value: AnyObject?) -> AnyObject?) -> NSValueTransformer! {
        return RealmValueTransformer(forwardClosure: closure, reverseClosure: nil)
    }
    
    // Returns a transformer which transforms values using the given closure, for
    // forward or reverse transformations.
    class func reversibleTransformerWithClosure(closure: (value: AnyObject?) -> AnyObject?) -> NSValueTransformer! {
        return reversibleTransformerWithForwardBlock(closure, reverseClosure: closure)
    }
    
    // Returns a transformer which transforms values using the given closures.
    class func reversibleTransformerWithForwardBlock(forwardClosure: (value: AnyObject?) -> AnyObject?, reverseClosure: (value: AnyObject?) -> AnyObject?) -> NSValueTransformer! {
        return RealmReversibleValueTransformer(forwardClosure: forwardClosure, reverseClosure: reverseClosure)
    }
    
    // MARK: ValueTransformer
    
    override public class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    override public class func transformedValueClass() -> AnyClass {
        return NSObject.self
    }
    
    override public func transformedValue(value: AnyObject?) -> AnyObject? {
        if let forwardClosure = forwardClosure {
            return forwardClosure(value: value)
        }
        return nil
    }
    
}

// MARK: - Predefined ValueTransformers

public extension RealmValueTransformer {

    public class func JSONDictionaryTransformerWithObjectType(type: Object.Type, inRealm realm: Realm) -> NSValueTransformer! {
        return JSONDictionaryTransformerWithObjectType(type, inRealm: realm, mappingIdentifier: nil, identifier: nil)
    }
    
    public class func JSONDictionaryTransformerWithObjectType(type: Object.Type, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer! {
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            
            // TODO: Direct value for primary key
            
            if let dictionary = value as? NSDictionary {
                return type.realmObjectWithType(type, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier)
            } else {
                return nil
            }
            }, reverseClosure: { (value) -> AnyObject? in
                if let _ = value as? Object {
                    // TODO: Implement JSONDictionaryFromRealmObject:
                    return nil
                } else {
                    return nil
                }
        })
    }
    
    public class func JSONArrayTransformerWithObjectType(type: Object.Type, inRealm realm: Realm) -> NSValueTransformer! {
        return JSONArrayTransformerWithObjectType(type, inRealm: realm, mappingIdentifier: nil, identifier: nil)
    }
    
    public class func JSONArrayTransformerWithObjectType<T: Object>(type: T.Type, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer! {
        let dictionaryTransformer = JSONDictionaryTransformerWithObjectType(type, inRealm: realm, mappingIdentifier: mappingIdentifier, identifier: identifier)
        
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            if let dictionaryArray = value as? [NSDictionary] {
                let list = List<T>()
                for dictionary in dictionaryArray {
                    if let realmObject = dictionaryTransformer.transformedValue(dictionary) as? T {
                        list.append(realmObject)
                    }
                }
                return list
            } else if let syncType = type as? RealmSyncProtocol.Type, stringArray = value as? [String] { // Assuming that string is the primary Key
                let list = List<T>()
                for string in stringArray {
                    if let primaryKey = type.primaryKey() {
                        
                        // Type specific property mapping
                        var keyValueDictionary = syncType.keyValueDictionaryWithPrimaryKeyValue(string)
                        
                        // Default fallback
                        if keyValueDictionary == nil {
                            keyValueDictionary = [primaryKey: string]
                        }
                        
                        if let keyValueDictionary = keyValueDictionary {
                            if let _: AnyObject = keyValueDictionary[primaryKey] {
                                let realmObject = realm.create(T.self, value: keyValueDictionary, update: true)
                                list.append(realmObject)
                            }
                        }
                    }
                }
                return list
            } else {
                return nil
            }
            }, reverseClosure: { (value) -> AnyObject? in
                if let _ = value as? List {
                    // TODO: Implement JSONDictionaryFromRealmArray:
                    return nil
                } else {
                    return nil
                }
        })
    }
}

public class RealmReversibleValueTransformer: RealmValueTransformer {
    
    // MARK: ValueTransformer
    
    override public class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override public func reverseTransformedValue(value: AnyObject?) -> AnyObject? {
        if let reverseClosure = reverseClosure {
            return reverseClosure(value: value)
        }
        return nil
    }
    
}
