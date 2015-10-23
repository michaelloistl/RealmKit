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
    public let type: Object.Type
    public let primaryKey: String
    public var indexPath: NSIndexPath? = nil
    
    init(type: Object.Type, primaryKey: String) {
        self.type = type
        self.primaryKey = primaryKey
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
    public class func transformerWithClosure(closure: (value: AnyObject?) -> AnyObject?) -> NSValueTransformer! {
        return RealmValueTransformer(forwardClosure: closure, reverseClosure: nil)
    }
    
    // Returns a transformer which transforms values using the given closure, for
    // forward or reverse transformations.
    public class func reversibleTransformerWithClosure(closure: (value: AnyObject?) -> AnyObject?) -> NSValueTransformer! {
        return reversibleTransformerWithForwardBlock(closure, reverseClosure: closure)
    }
    
    // Returns a transformer which transforms values using the given closures.
    public class func reversibleTransformerWithForwardBlock(forwardClosure: (value: AnyObject?) -> AnyObject?, reverseClosure: (value: AnyObject?) -> AnyObject?) -> NSValueTransformer! {
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

    public class func JSONDictionaryTransformerWithObjectType<T: Object>(type: T.Type, inRealm realm: Realm) -> NSValueTransformer! {
        return JSONDictionaryTransformerWithObjectType(type, inRealm: realm, mappingIdentifier: nil, identifier: nil)
    }
    
    public class func JSONDictionaryTransformerWithObjectType<T: Object>(type: T.Type, inRealm realm: Realm, mappingIdentifier: String?, identifier: String?) -> NSValueTransformer! {
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            
            // TODO: Direct value for primary key
            
            if let dictionary = value as? NSDictionary, _type = type as? RealmJSONSerializable.Type {
                return _type.realmObjectWithType(type, inRealm: realm, withJSONDictionary: dictionary, mappingIdentifier: mappingIdentifier, identifier: identifier)
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
    
    public class func JSONArrayTransformerWithObjectType<T: Object>(type: T.Type, inRealm realm: Realm) -> NSValueTransformer! {
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
            } else if let stringArray = value as? [String] { // Assuming that string is the primary Key
                let list = List<T>()
                for string in stringArray {
                    if let primaryKey = (type as Object.Type).primaryKey() {
                        
                        // Type specific property mapping
                        if let _type = type as? RealmJSONSerializable.Type {
                            var keyValueDictionary = _type.keyValueDictionaryWithPrimaryKeyValue(string)

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
