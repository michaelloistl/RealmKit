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

@available(OSX 10.10, *)
public struct SerializationInfo {
    
    // MARK: Required
    
    public let realm: Realm
    
    // MARK: Optional
    
    public let method: RealmKit.Method?
    public var userInfo: [String: AnyObject]
    
    public var json: [String: AnyObject]?
    
    public let oldPrimaryKey: String?
    public var newPrimaryKey: String?
    
    public let syncOperation: RealmSyncOperation?
    public let fetchOperation: RealmFetchOperation?
    public let fetchRequest: FetchRequest?
    
    public init(
        realm: Realm,
        method: RealmKit.Method? = nil,
        userInfo: [String: AnyObject] = [String: AnyObject](),
        oldPrimaryKey: String? = nil,
        newPrimaryKey: String? = nil,
        syncOperation: RealmSyncOperation? = nil,
        fetchOperation: RealmFetchOperation? = nil,
        fetchRequest: FetchRequest? = nil
        ) {
            self.realm = realm
            self.method = method
            self.userInfo = userInfo
            self.oldPrimaryKey = oldPrimaryKey
            self.newPrimaryKey = newPrimaryKey
            self.syncOperation = syncOperation
            self.fetchOperation = fetchOperation
            self.fetchRequest = fetchRequest
    }
}

public struct RealmObjectInfo {
    public let type: Object.Type
    public let primaryKey: String
    public var indexPath: NSIndexPath?
    
    public init(
        type: Object.Type,
        primaryKey: String,
        indexPath: NSIndexPath? = nil
        ) {
            self.type = type
            self.primaryKey = primaryKey
    }
}

@available(OSX 10.10, *)
public protocol RealmJSONSerializable: RealmSyncable, RealmFetchable {
    
    // MARK: - Methods
    
    // MARK: Required
    
    static func JSONKeyPathsByPropertyKey(serializationInfo: SerializationInfo) -> [String : String]!
    static func JSONTransformerForKey(key: String!, serializationInfo: SerializationInfo) -> NSValueTransformer!
    
    static func classForParsingJSONDictionary(JSONDictionary: NSDictionary) -> Object.Type
    
    // MARK: Optional
    
    static func keyValueDictionaryWithPrimaryKeyValue(primaryKeyValue: String) -> [String : String]?

    /*
    This function executes within the transaction block of realmObjectInRealm()
    Override to modify initial and new RealmObject within the same transaction block
    */
    
    static func didCreateOrUpdateRealmObject(serializationInfo: SerializationInfo?)
    
    static func keyValueDictionaryForRealmObjectWithType<T: Object>(type: T.Type, withJSONDictionary dictionary: NSDictionary, keyValueDictionary: [String: AnyObject], serializationInfo: SerializationInfo) -> [String: AnyObject]
    
    static func modifiedRealmObject(realmObject: Object, withJSONDictionary dictionary: NSDictionary, keyValueDictionary: [String: AnyObject], serializationInfo: SerializationInfo) -> Object?
    
    static func shouldCreateOrUpdateRealmObjectWithType<T: Object>(type: T.Type, primaryKey: String, withJSONDictionary dictionary: NSDictionary, keyValueDictionary: [String: AnyObject], serializationInfo: SerializationInfo) -> Bool
}

// MARK: - Extension for method implementations

@available(OSX 10.10, *)
public extension RealmJSONSerializable  {
    
    static func hasPrimaryKey() -> Bool {
        if let primaryKey = primaryKey() where primaryKey.characters.count > 0 {
            return true
        }
        return false
    }
    
    // MARK: CreateOrUpdate objects with JSON Array
    
    public static func realmObjectsWithJSONArray(array: NSArray, serializationInfo: SerializationInfo, completion: (realmObjectInfos: [RealmObjectInfo]?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfos = [RealmObjectInfo]()
            do {
                try serializationInfo.realm.write({ () -> Void in
                    for object in array {
                        if let dictionary = object as? NSDictionary {
                            let type = classForParsingJSONDictionary(dictionary)
                            
                            if let realmObject = self.realmObjectWithType(type.self, withJSONDictionary: dictionary, serializationInfo: serializationInfo) {
                                if let primaryKey = type.primaryKey() {
                                    if let primaryKey = realmObject.valueForKey(primaryKey) as? String {
                                        let realmObjectInfo = RealmObjectInfo(type: type.self, primaryKey: primaryKey)
                                        completionRealmObjectInfos.append(realmObjectInfo)
                                        
                                        // Did create RealmObject in transactionWithBlock
                                        var serializationInfo = serializationInfo
                                        serializationInfo.newPrimaryKey = primaryKey
                                        
                                        didCreateOrUpdateRealmObject(serializationInfo)
                                    }
                                }
                            }
                        }
                    }
                })
            } catch {
                
            }
            
            completion(realmObjectInfos: completionRealmObjectInfos, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfos: nil, error: error)
        }
    }
    
    // MARK: CreateOrUpdate object with JSON Dictionary
    
    public static func realmObjectWithJSONDictionary(dictionary: NSDictionary, serializationInfo: SerializationInfo, completion: (realmObjectInfo: RealmObjectInfo?, error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfo: RealmObjectInfo?
            
            do {
                try serializationInfo.realm.write({ () -> Void in
                    let type = classForParsingJSONDictionary(dictionary)
                    
                    if let realmObject = self.realmObjectWithType(type.self, withJSONDictionary: dictionary, serializationInfo: serializationInfo) {
                        if let primaryKey = type.primaryKey() {
                            if let newPrimaryKey = realmObject.valueForKey(primaryKey) as? String {
                                let realmObjectInfo = RealmObjectInfo(type: type.self, primaryKey: newPrimaryKey)
                                completionRealmObjectInfo = realmObjectInfo
                                
                                // Did create RealmObject in transactionWithBlock
                                var serializationInfo = serializationInfo
                                serializationInfo.newPrimaryKey = newPrimaryKey
                                
//                                // Delete temp object in same write transaction
//                                if let oldPrimaryKey = oldPrimaryKey {
//                                    if var oldRealmObject = serializationInfo.realm.objectForPrimaryKey(type.self, key: oldPrimaryKey) as? RealmKitObjectProtocol {
//                                        let realmSyncObjectInfo = RealmSyncObjectInfo(type: type.self, oldPrimaryKey: oldPrimaryKey, newPrimaryKey: newPrimaryKey)
//                                        
//                                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                                            NSNotificationCenter.defaultCenter().postNotificationName(RealmSyncOperationWillDeleteObjectNotification, object:realmSyncObjectInfo)
//                                        })
//                                        
//                                        oldRealmObject.deletedAt = NSDate().timeIntervalSince1970
//                                        
//                                        NSLog("oldRealmObject: \(oldRealmObject)")
//                                    }
//                                }
                                
                                didCreateOrUpdateRealmObject(serializationInfo)
                            }
                        }
                    }
                })
            } catch {
                
            }
            
            completion(realmObjectInfo: completionRealmObjectInfo, error: nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(realmObjectInfo: nil, error: error)
        }
    }
    
    // MARK: CreateOrUpdate RealmObject with mapping
    
    public static func realmObjectWithType<T: Object>(type: T.Type, withJSONDictionary dictionary: NSDictionary, serializationInfo: SerializationInfo) -> Object? {
        
        // Object key -> JSON keyPath
        if let mappingDictionary = JSONKeyPathsByPropertyKey(serializationInfo) {
            var keyValueDictionary = [String: AnyObject]()
            var serializationInfo = serializationInfo
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue: AnyObject = dictionary.valueForKeyPath(keyPath) {
                    if let _ = jsonValue as? NSNull {
                        
                        // Default Value if it's not primary key
                        if let primaryKey = (type as Object.Type).primaryKey() {
                            if key != primaryKey {
                                if let defaultValue: AnyObject = self.defaultPropertyValues()[key] {
                                    keyValueDictionary[key] = defaultValue
                                }
                            }
                        }
                    } else {
                        
                        // ValueTransformer
                        serializationInfo.json = dictionary as? [String: AnyObject]
                        if let valueTransformer = JSONTransformerForKey(key, serializationInfo: serializationInfo) {
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
            
            // Modify keyValueDictionary
            keyValueDictionary = keyValueDictionaryForRealmObjectWithType(type, withJSONDictionary: dictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo)
            
            // Set lastFetchedAt / lastSyncedAt
            if let method = serializationInfo.method {
                if method == .GET {
                    keyValueDictionary["lastFetchedAt"] = NSDate()
                } else {
                    keyValueDictionary["lastSyncedAt"] = NSDate()
                }
            }
            
//            NSLog("__realmObjectWithType: \(type.self) __keyValueDictionary: \(keyValueDictionary) __JSON: \(dictionary)")
            
            if let primaryKey = (type as Object.Type).primaryKey(), primaryKeyValue = keyValueDictionary[primaryKey] as? String {
                if shouldCreateOrUpdateRealmObjectWithType(type, primaryKey: primaryKeyValue, withJSONDictionary: dictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo) {
                    let realmObject = serializationInfo.realm.create(type.self, value: keyValueDictionary, update: true)
                    return self.modifiedRealmObject(realmObject, withJSONDictionary: dictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo)
                } else {
                    if let realmObject = serializationInfo.realm.objectForPrimaryKey(type.self, key: primaryKey) {
                        return self.modifiedRealmObject(realmObject, withJSONDictionary: dictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo)
                    }
                }
            } else {
                if RealmKit.sharedInstance.debugLogs {
                    print("# RealmKit: There is a serialization issue with the primary key for Type: \(type) Dictionary: \(dictionary) MappingDictionary: \(mappingDictionary) KeyValueDictionary: \(keyValueDictionary)")
                }
            }
        }
        
        return nil
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

@available(OSX 10.10, *)
public extension RealmValueTransformer {
    
    public class func JSONDictionaryTransformerWithObjectType<T: Object>(type: T.Type, serializationInfo: SerializationInfo) -> NSValueTransformer! {
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            
            // TODO: Direct value for primary key
            
            if let dictionary = value as? NSDictionary {
                return (type as? RealmJSONSerializable.Type)?.realmObjectWithType(type, withJSONDictionary: dictionary, serializationInfo: serializationInfo)
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
    
    public class func JSONArrayTransformerWithObjectType<T: Object>(type: T.Type, serializationInfo: SerializationInfo) -> NSValueTransformer! {
        let dictionaryTransformer = JSONDictionaryTransformerWithObjectType(type, serializationInfo: serializationInfo)
        
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            if let dictionaryArray = value as? [NSDictionary] {
                let list = List<T>()
                for dictionary in dictionaryArray {
                    if let realmObject = dictionaryTransformer.transformedValue(dictionary) as? T {
                        list.append(realmObject)
                    }
                }
                return list
            }
            else if let stringArray = value as? [String] { // Assuming that string is the primary Key
                let list = List<T>()
                for string in stringArray {
                    if let primaryKey = type.primaryKey() {
                        var keyValueDictionary = (type as? RealmJSONSerializable.Type)?.keyValueDictionaryWithPrimaryKeyValue(string)
                        
                        // Default fallback
                        if keyValueDictionary == nil {
                            keyValueDictionary = [primaryKey: string]
                        }

                        if let keyValueDictionary = keyValueDictionary {
                            if let _: AnyObject = keyValueDictionary[primaryKey] {
                                let realmObject = serializationInfo.realm.create(T.self, value: keyValueDictionary, update: true)
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
