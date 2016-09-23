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
    
    public let method: RealmKit.HTTPMethod?
    public var userInfo: [String: Any]
    
    public var json: [String: Any]?
    
    public let oldPrimaryKey: String?
    public var newPrimaryKey: String?
    
    public let syncOperation: RealmSyncOperation?
    public let fetchOperation: RealmFetchOperation?
    public let fetchRequest: FetchRequest?
    
    public init(
        realm: Realm,
        method: RealmKit.HTTPMethod? = nil,
        userInfo: [String: Any] = [String: Any](),
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
    public var indexPath: IndexPath?
    
    public init(
        type: Object.Type,
        primaryKey: String,
        indexPath: IndexPath? = nil
        ) {
            self.type = type
            self.primaryKey = primaryKey
    }
}

@available(OSX 10.10, *)
public protocol RealmJSONSerializable: RealmSyncable, RealmFetchable {
    
    // MARK: - Methods
    
    // MARK: Required
    
    static func jsonKeyPathsByPropertyKey(with serializationInfo: SerializationInfo) -> [String : String]!
    static func jsonTransformerForKey(_ key: String!, serializationInfo: SerializationInfo) -> ValueTransformer!
    
    static func classForParsing(_ jsonDictionary: NSDictionary) -> Object.Type
    
    // MARK: Optional
    
    static func keyValueDictionary(with primaryKeyValue: String) -> [String : String]?

    /*
    This function executes within the transaction block of realmObjectInRealm()
    Override to modify initial and new RealmObject within the same transaction block
    */
    
    static func didCreateOrUpdateRealmObject(with serializationInfo: SerializationInfo?)
    
    static func keyValueDictionary<T: Object>(for type: T.Type, jsonDictionary: NSDictionary, keyValueDictionary: [String: Any], serializationInfo: SerializationInfo) -> [String: Any]
    
    static func modifiedRealmObject(_ realmObject: Object, jsonDictionary: NSDictionary, keyValueDictionary: [String: Any], serializationInfo: SerializationInfo) -> Object?
    
    static func shouldCreateOrUpdate<T: Object>(_ type: T.Type, primaryKey: String, jsonDictionary: NSDictionary, keyValueDictionary: [String: Any], serializationInfo: SerializationInfo) -> Bool
}

// MARK: - Extension for method implementations

@available(OSX 10.10, *)
public extension RealmJSONSerializable  {
    
    static func hasPrimaryKey() -> Bool {
        if let primaryKey = primaryKey() , primaryKey.characters.count > 0 {
            return true
        }
        return false
    }
    
    // MARK: CreateOrUpdate objects with JSON Array
    
    public static func realmObjectsWithJSONArray(_ array: NSArray, serializationInfo: SerializationInfo, completion: (_ realmObjectInfos: [RealmObjectInfo]?, _ error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfos = [RealmObjectInfo]()
            do {
                try serializationInfo.realm.write({ () -> Void in
                    for object in array {
                        if let dictionary = object as? NSDictionary {
                            let type = classForParsing(dictionary)
                            
                            if let realmObject = self.realmObject(type.self, jsonDictionary: dictionary, serializationInfo: serializationInfo) {
                                if let primaryKey = type.primaryKey() {
                                    if let primaryKey = realmObject.value(forKey: primaryKey) as? String {
                                        let realmObjectInfo = RealmObjectInfo(type: type.self, primaryKey: primaryKey)
                                        completionRealmObjectInfos.append(realmObjectInfo)
                                        
                                        // Did create RealmObject in transactionWithBlock
                                        var serializationInfo = serializationInfo
                                        serializationInfo.newPrimaryKey = primaryKey
                                        
                                        didCreateOrUpdateRealmObject(with: serializationInfo)
                                    }
                                }
                            }
                        }
                    }
                })
            } catch {
                
            }
            
            completion(completionRealmObjectInfos, nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(nil, error)
        }
    }
    
    // MARK: CreateOrUpdate object with JSON Dictionary
    
    public static func realmObjectWithJSONDictionary(_ dictionary: NSDictionary, serializationInfo: SerializationInfo, completion: (_ realmObjectInfo: RealmObjectInfo?, _ error: NSError?) -> Void) {
        
        if hasPrimaryKey() {
            var completionRealmObjectInfo: RealmObjectInfo?
            
            do {
                try serializationInfo.realm.write({ () -> Void in
                    let type = classForParsing(dictionary)
                    
                    if let realmObject = self.realmObject(type.self, jsonDictionary: dictionary, serializationInfo: serializationInfo) {
                        if let primaryKey = type.primaryKey() {
                            if let newPrimaryKey = realmObject.value(forKey: primaryKey) as? String {
                                let realmObjectInfo = RealmObjectInfo(type: type.self, primaryKey: newPrimaryKey)
                                completionRealmObjectInfo = realmObjectInfo
                                
                                // Did create RealmObject in transactionWithBlock
                                var serializationInfo = serializationInfo
                                serializationInfo.newPrimaryKey = newPrimaryKey
                                
                                didCreateOrUpdateRealmObject(with: serializationInfo)
                            }
                        }
                    }
                })
            } catch {
                
            }
            
            completion(completionRealmObjectInfo, nil)
        } else {
            let error = NSError(domain: RealmJSONSerializerErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Class doesn't define a valid primaryKey"])
            completion(nil, error)
        }
    }
    
    // MARK: CreateOrUpdate RealmObject with mapping
    
    public static func realmObject<T: Object>(_ type: T.Type, jsonDictionary: NSDictionary, serializationInfo: SerializationInfo) -> Object? {
        
        // Object key -> JSON keyPath
        if let mappingDictionary = jsonKeyPathsByPropertyKey(with: serializationInfo) {
            var keyValueDictionary = [String: Any]()
            var serializationInfo = serializationInfo
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue: AnyObject = jsonDictionary.value(forKeyPath: keyPath) as AnyObject? {
                    if let _ = jsonValue as? NSNull {
                        
                        // Default Value if it's not primary key
                        if let primaryKey = (type as Object.Type).primaryKey() {
                            if key != primaryKey {
                                if let defaultValue = self.defaultPropertyValues()[key] {
                                    keyValueDictionary[key] = defaultValue
                                }
                            }
                        }
                    } else {
                        
                        // ValueTransformer
                        serializationInfo.json = jsonDictionary as? [String: Any]
                        if let valueTransformer = jsonTransformerForKey(key, serializationInfo: serializationInfo) {
                            if let value: AnyObject = valueTransformer.transformedValue(jsonValue) as AnyObject? {
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
            keyValueDictionary = self.keyValueDictionary(for: type, jsonDictionary: jsonDictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo)
            
            // Set lastFetchedAt / lastSyncedAt
            if let method = serializationInfo.method {
                if method == .GET {
                    keyValueDictionary["lastFetchedAt"] = Date() as AnyObject?
                } else {
                    keyValueDictionary["lastSyncedAt"] = Date() as AnyObject?
                }
            }
            
//            NSLog("__realmObjectWithType: \(type.self) __keyValueDictionary: \(keyValueDictionary) __JSON: \(dictionary)")
            
            if let primaryKey = (type as Object.Type).primaryKey(), let primaryKeyValue = keyValueDictionary[primaryKey] as? String {
                if shouldCreateOrUpdate(type, primaryKey: primaryKeyValue, jsonDictionary: jsonDictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo) {
                    let realmObject = serializationInfo.realm.create(type.self, value: keyValueDictionary, update: true)
                    return self.modifiedRealmObject(realmObject, jsonDictionary: jsonDictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo)
                } else {
                    if let realmObject = serializationInfo.realm.object(ofType: type.self, forPrimaryKey: primaryKey) {
                        return self.modifiedRealmObject(realmObject, jsonDictionary: jsonDictionary, keyValueDictionary: keyValueDictionary, serializationInfo: serializationInfo)
                    }
                }
            } else {
                if RealmKit.sharedInstance.debugLogs {
                    print("# RealmKit: There is a serialization issue with the primary key for Type: \(type) JSON Dictionary: \(jsonDictionary) MappingDictionary: \(mappingDictionary) KeyValueDictionary: \(keyValueDictionary)" as Any)
                }
            }
        }
        
        return nil
    }
}

// MARK: - ValueTransformers

open class RealmValueTransformer: ValueTransformer {
    
    var forwardClosure: ((_ value: AnyObject?) -> AnyObject?)?
    var reverseClosure: ((_ value: AnyObject?) -> AnyObject?)?
    
    // MARK: Initializers
    
    override init() {
        super.init()
    }
    
    convenience init(forwardClosure: ((_ value: AnyObject?) -> AnyObject?)?, reverseClosure: ((_ value: AnyObject?) -> AnyObject?)?) {
        self.init()
        
        self.forwardClosure = forwardClosure
        self.reverseClosure = reverseClosure
    }
    
    // MARK: Class Functions
    
    // Returns a transformer which transforms values using the given closure.
    // Reverse transformations will not be allowed.
    open class func transformerWithClosure(_ closure: @escaping (_ value: AnyObject?) -> AnyObject?) -> ValueTransformer! {
        return RealmValueTransformer(forwardClosure: closure, reverseClosure: nil)
    }
    
    // Returns a transformer which transforms values using the given closure, for
    // forward or reverse transformations.
    open class func reversibleTransformerWithClosure(_ closure: @escaping (_ value: AnyObject?) -> AnyObject?) -> ValueTransformer! {
        return reversibleTransformerWithForwardBlock(closure, reverseClosure: closure)
    }
    
    // Returns a transformer which transforms values using the given closures.
    open class func reversibleTransformerWithForwardBlock(_ forwardClosure: @escaping (_ value: AnyObject?) -> AnyObject?, reverseClosure: @escaping (_ value: AnyObject?) -> AnyObject?) -> ValueTransformer! {
        return RealmReversibleValueTransformer(forwardClosure: forwardClosure, reverseClosure: reverseClosure)
    }
    
    // MARK: ValueTransformer
    
    override open class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    override open class func transformedValueClass() -> AnyClass {
        return NSObject.self
    }
    
    override open func transformedValue(_ value: Any?) -> Any? {
        if let forwardClosure = forwardClosure {
            return forwardClosure(value as AnyObject?)
        }
        return nil
    }
    
}

// MARK: - Predefined ValueTransformers

@available(OSX 10.10, *)
public extension RealmValueTransformer {
    
    public class func JSONDictionaryTransformerWithObjectType<T: Object>(_ type: T.Type, serializationInfo: SerializationInfo) -> ValueTransformer! {
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            
            // TODO: Direct value for primary key
            
            if let dictionary = value as? NSDictionary {
                return (type as? RealmJSONSerializable.Type)?.realmObject(type, jsonDictionary: dictionary, serializationInfo: serializationInfo)
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
    
    public class func JSONArrayTransformerWithObjectType<T: Object>(_ type: T.Type, serializationInfo: SerializationInfo) -> ValueTransformer! {
        let dictionaryTransformer = JSONDictionaryTransformerWithObjectType(type, serializationInfo: serializationInfo)
        
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            if let dictionaryArray = value as? [NSDictionary] {
                let list = List<T>()
                for dictionary in dictionaryArray {
                    if let realmObject = dictionaryTransformer?.transformedValue(dictionary) as? T {
                        list.append(realmObject)
                    }
                }
                return list
            }
            else if let stringArray = value as? [String] { // Assuming that string is the primary Key
                let list = List<T>()
                for string in stringArray {
                    if let primaryKey = type.primaryKey() {
                        var keyValueDictionary = (type as? RealmJSONSerializable.Type)?.keyValueDictionary(with: string)
                        
                        // Default fallback
                        if keyValueDictionary == nil {
                            keyValueDictionary = [primaryKey: string]
                        }

                        if let keyValueDictionary = keyValueDictionary {
                            if let _: AnyObject = keyValueDictionary[primaryKey] as AnyObject? {
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

open class RealmReversibleValueTransformer: RealmValueTransformer {
    
    // MARK: ValueTransformer
    
    override open class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override open func reverseTransformedValue(_ value: Any?) -> Any? {
        if let reverseClosure = reverseClosure {
            return reverseClosure(value as AnyObject?)
        }
        return nil
    }
    
}
