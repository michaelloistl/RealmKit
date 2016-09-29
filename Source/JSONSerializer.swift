//
//  RealmJSONSerializer.swift
//  RealmKit
//
//  Created by Michael Loistl on 28/11/2014.
//  Copyright (c) 2014 Michael Loistl. All rights reserved.
//

import Foundation
import RealmSwift
import Alamofire

/// Used to provide info for the serialization.
@available(OSX 10.10, *)
public struct SerializationRequest {
    
    // MARK: Required
    public let realm: Realm
    
    // MARK: Optional
    public let httpMethod: Alamofire.HTTPMethod?
    public let userInfo: [String: Any]
    
    public let oldPrimaryKey: String?
    
    public let persist: Bool
    
    public let syncOperation: SyncOperation?
    public let fetchRequest: FetchRequest?
    
    public init(
        realm: Realm,
        httpMethod: Alamofire.HTTPMethod? = nil,
        userInfo: [String: Any] = [String: Any](),
        oldPrimaryKey: String? = nil,
        persist: Bool = true,
        syncOperation: SyncOperation? = nil,
        fetchRequest: FetchRequest? = nil
        ) {
            self.realm = realm
            self.httpMethod = httpMethod
            self.userInfo = userInfo
            self.oldPrimaryKey = oldPrimaryKey
            self.persist = persist
            self.syncOperation = syncOperation
            self.fetchRequest = fetchRequest
    }
}

/// Used to return result of serialization.
@available(OSX 10.10, *)
public struct SerializationResult {
    
    public enum SerializedObjects {
        case none
        case persisted(objectInfos: [ObjectInfo])
        case transient(objects: [RKObject])
    }
    
    // MARK: Required
    public let serializationRequest: SerializationRequest
    
    // MARK: Optional
    public let json: Any?
    public let serializedObjects: SerializedObjects
    public let error: RKError?
    
    public init(
        serializationRequest: SerializationRequest,
        json: Any?,
        serializedObjects: SerializedObjects,
        error: RKError?
        ) {
        self.serializationRequest = serializationRequest
        self.json = json
        self.serializedObjects = serializedObjects
        self.error = error
    }
}

/// Used to store all data associated with a realm object created/updated during serialization.
public struct ObjectInfo {
    public let type: RKObject.Type
    public let primaryKey: String
    
    public init(
        type: RKObject.Type,
        primaryKey: String
        ) {
            self.type = type
            self.primaryKey = primaryKey
    }
}

// MARK: - Extension for method implementations

@available(OSX 10.10, *)
public extension JSONSerializable  {

    // MARK: - Methods
    
    // MARK: Optional defaults
    
    public static func modifyKeyValues(_ keyValues: [String: AnyObject]) -> [String: AnyObject]? {
        return nil
    }

    public static func modifyObject(_ object: RKObject) -> RKObject? {
        return nil
    }
    
    public static func didSerializeObjects(_ objects: [RKObject]) -> () {
        
    }
    
    // MARK: Helpers

    /// Helper method to check if type has valid primaryKey set.
    fileprivate static func hasPrimaryKey() -> Bool {
        if let primaryKey = primaryKey() , primaryKey.characters.count > 0 {
            return true
        }
        return false
    }
    
    /// Create or update objects with JSON Array.
    ///
    /// - parameter modifyObject: Optional closure to modify the object after ccreation/update within the same write transaction.
    /// - parameter didSerializeObjects: Optional closure to include optional code after serializing all objects within the same write transaction.
    public static func serializeObjects(with jsonArray: NSArray,
                               serializationRequest: SerializationRequest,
                               modifyKeyValues: (([String: AnyObject]) -> [String: AnyObject])? = nil,
                               modifyObject: ((RKObject) -> RKObject)? = nil,
                               didSerializeObjects: (([RKObject]) -> ())? = nil,
                               completion: @escaping (SerializationResult) -> Void) {
        if hasPrimaryKey() {
            var _objectInfos = [ObjectInfo]()
            var _objects = [RKObject]()
            var _error: RKError?
            
            // Begin write transaction
            let _ = try? serializationRequest.realm.write({ () -> Void in
                jsonArray.forEach({ (object) in
                    if let jsonDictionary = object as? NSDictionary {
                        let type = typeToSerialize(jsonDictionary)
                        
                        var _object: RKObject?
                        
                        let (object, error) = self.object(type.self,
                                    jsonDictionary: jsonDictionary,
                                    serializationRequest: serializationRequest,
                                    modifyKeyValues: modifyKeyValues)
                        
                        _object = object
                        _error = error
                        
                        // Optionaly modify object
                        if let object = _object, let modifiedObject = self.modifyObject(object) {
                            _object = modifiedObject
                        }
                        if let object = _object, let modifiedObject = modifyObject?(object) {
                            _object = modifiedObject
                        }
                        
                        // ObjectInfo
                        if let primaryKey = type.primaryKey() {
                            if let primaryKey = _object?.value(forKey: primaryKey) as? String {
                                let objectInfo = ObjectInfo(type: type.self, primaryKey: primaryKey)
                                _objectInfos.append(objectInfo)
                            }
                        }
                        
                        if let object = _object {
                            _objects.append(object)
                        }
                    }
                })
                
                // Hook after serializing objects
                self.didSerializeObjects(_objects)
                didSerializeObjects?(_objects)
            })
            // End write transaction
            
            let serializedObjects = (serializationRequest.persist) ? SerializationResult.SerializedObjects.persisted(objectInfos: _objectInfos) : SerializationResult.SerializedObjects.transient(objects: _objects)
            
            let result = SerializationResult(serializationRequest: serializationRequest, json: jsonArray, serializedObjects: serializedObjects, error: _error)
            
            completion(result)
        } else {
            let error = RKError.JSONSerilizerFailure(reason: .invalidPrimaryKey)
            let serializedObjects = SerializationResult.SerializedObjects.none
            
            let result = SerializationResult(serializationRequest: serializationRequest, json: nil, serializedObjects: serializedObjects, error: error)
            
            completion(result)
        }
    }
    
    /// Create or update object with JSON Dictionary.
    ///
    /// - parameter modifyObject: Optional closure to modify the object after ccreation/update within the same write transaction.
    /// - parameter didSerializeObject: Optional closure to include optional code after serializing object within the same write transaction.
    public static func serializeObject(with jsonDictionary: NSDictionary,
                              serializationRequest: SerializationRequest,
                              modifyKeyValues: (([String: AnyObject]) -> [String: AnyObject])? = nil,
                              modifyObject: ((RKObject) -> RKObject)? = nil,
                              didSerializeObjects: (([RKObject]) -> ())? = nil,
                              completion: @escaping (SerializationResult) -> Void) {
        if hasPrimaryKey() {
            var _objectInfos = [ObjectInfo]()
            var _objects = [RKObject]()
            var _error: RKError?
            
            // Begin write transaction
            let _ = try? serializationRequest.realm.write({ () -> Void in
                let type = typeToSerialize(jsonDictionary)
            
                var _object: RKObject?
                let (object, error) = self.object(type.self,
                            jsonDictionary: jsonDictionary,
                            serializationRequest: serializationRequest,
                            modifyKeyValues: modifyKeyValues)
                    
                _object = object
                _error = error
                    
                    // Optionaly modify object
                if let object = _object, let modifiedObject = self.modifyObject(object) {
                    _object = modifiedObject
                }
                if let object = _object, let modifiedObject = modifyObject?(object) {
                    _object = modifiedObject
                }
                
                // Set ObjectInfo
                if let primaryKey = type.primaryKey() {
                    if let primaryKey = _object?.value(forKey: primaryKey) as? String {
                        let objectInfo = ObjectInfo(type: type.self, primaryKey: primaryKey)
                        _objectInfos.append(objectInfo)
                    }
                }
                
                if let object = _object {
                    _objects.append(object)
                }
                
                // Hook after serializing objects
                if let object = _object {
                    self.didSerializeObjects([object])
                    didSerializeObjects?([object])
                }
            })
            // End write transaction
            
            let serializedObjects = (serializationRequest.persist) ? SerializationResult.SerializedObjects.persisted(objectInfos: _objectInfos) : SerializationResult.SerializedObjects.transient(objects: _objects)
            
            let result = SerializationResult(serializationRequest: serializationRequest, json: jsonDictionary as? [String: Any], serializedObjects: serializedObjects, error: _error)
            
            completion(result)
        } else {
            let serializedObjects = SerializationResult.SerializedObjects.none
            let error = RKError.JSONSerilizerFailure(reason: .invalidPrimaryKey)
            
            let result = SerializationResult(serializationRequest: serializationRequest, json: nil, serializedObjects: serializedObjects, error: error)
            
            completion(result)
        }
    }
    
    /// Create or update object with mapping.
    ///
    /// Object key -> JSON keyPath
    ///
    /// - warning: This method may only be called during a write transaction.
    public static func object<T: RKObject>(_ type: T.Type,
                              jsonDictionary: NSDictionary,
                              serializationRequest: SerializationRequest,
                              modifyKeyValues: (([String: AnyObject]) -> [String: AnyObject])? = nil) -> (object: RKObject?, error: RKError?) {
        var _object: RKObject?
        var _error: RKError?
        
        if let mappingDictionary = type.jsonKeyPathsByPropertyKey(with: serializationRequest) {
            var keyValues = [String: AnyObject]()
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue = jsonDictionary.value(forKeyPath: keyPath) as AnyObject? {
                    if let _ = jsonValue as? NSNull {
                        
                        // Default Value if it's not primary key
                        if let primaryKey = (type as RKObject.Type).primaryKey() {
                            if key != primaryKey {
                                if let defaultValue = self.defaultPropertyValues()[key] {
                                    keyValues[key] = defaultValue
                                }
                            }
                        }
                    } else {
                        
                        // ValueTransformer
                        if let valueTransformer = jsonTransformerForKey(key, serializationRequest: serializationRequest) {
                            if let value: AnyObject = valueTransformer.transformedValue(jsonValue) as AnyObject? {
                                keyValues[key] = value
                            }
                        } else {
                            
                            // JSON Value
                            keyValues[key] = jsonValue
                        }
                    }
                }
            }
            
            // TODO: Still set object with just primary key if if shouldn't map ...
            
            // Modify keyValues (optional) before being used to create/update an object
            if let modifyKeyValues = type.modifyKeyValues(keyValues) {
                keyValues = modifyKeyValues
            }
            if let modifyKeyValues = modifyKeyValues?(keyValues) {
                keyValues = modifyKeyValues
            }
            
            // Set lastFetchedAt
            if let httpMethod = serializationRequest.httpMethod, httpMethod == .get {
                keyValues["lastFetchedAt"] = NSDate()
            }
            
            // Set lastSyncedAt
            if let httpMethod = serializationRequest.httpMethod, httpMethod != .get {
                keyValues["lastSyncedAt"] = NSDate()
            }
            
            if let serverKey = type.serverKey(), let serverKeyValue = keyValues[serverKey] as? String { // "id" = "1"
                
                // Check if object with serverKeyValue exists
                if let existingObject = serializationRequest.realm.objects(type.self).filter(NSPredicate(format: "server_id == %@", serverKeyValue)).first {
                    
                    // Set primary id on keyValues to make sure to update the existing object
                    keyValues["id"] = existingObject.id as AnyObject

                    // Set _object in case there is a local unsynced object in order to avoid updating
                    if let httpMethod = serializationRequest.httpMethod, httpMethod == .get {
                        if existingObject.syncStatus != SyncStatus.Synced.rawValue {
                            _object = existingObject
                        }
                    }
                }
                
                // Create/update object
                if _object == nil {
                    if serializationRequest.persist {
                        _object = serializationRequest.realm.create(type.self, value: keyValues, update: true)
                    } else {
                        _object = type.init()
                        keyValues.forEach({ (key, value) in
                            _object?.setValue(value, forKey: key)
                        })
                    }
                }
            } else {
                _error = RKError.JSONSerilizerFailure(reason: .noPrimaryKeyValue(type: type, jsonDictionary: jsonDictionary as? [String: Any], jsonKeyPathsByPropertyKey: mappingDictionary, keyValues: keyValues))
                
                if RealmKit.sharedInstance.debugLogs {
                    print("# RealmKit: There is a serialization issue with the primary key for Type: \(type) JSON Dictionary: \(jsonDictionary) MappingDictionary: \(mappingDictionary) KeyValues: \(keyValues)" as Any)
                }
            }
        } else {
            _error = RKError.JSONSerilizerFailure(reason: .noJsonKeyPathsByPropertyKey(type: type))
            
            if RealmKit.sharedInstance.debugLogs {
                print("# RealmKit: There is no jsonKeyPathsByPropertyKey: defined for type: \(type)")
            }
        }
        
        return (_object, _error)
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
    
    public class func JSONDictionaryTransformerWithObjectType<T: RKObject>(_ type: T.Type, serializationRequest: SerializationRequest) -> ValueTransformer! {
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            
            // TODO: Direct value for primary key
            
            if let dictionary = value as? NSDictionary {
                return (type as JSONSerializable.Type).object(type, jsonDictionary: dictionary, serializationRequest: serializationRequest).object
            } else {
                return nil
            }
            }, reverseClosure: { (value) -> AnyObject? in
                if let _ = value as? RKObject {
                    // TODO: Implement JSONDictionaryFromRealmObject:
                    return nil
                } else {
                    return nil
                }
        })
    }
    
    public class func JSONArrayTransformerWithObjectType<T: RKObject>(_ type: T.Type, serializationRequest: SerializationRequest) -> ValueTransformer! {
        let dictionaryTransformer = JSONDictionaryTransformerWithObjectType(type, serializationRequest: serializationRequest)
        
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            if let dictionaryArray = value as? [NSDictionary] {
                let list = List<T>()
                for dictionary in dictionaryArray {
                    if let object = dictionaryTransformer?.transformedValue(dictionary) as? T {
                        list.append(object)
                    }
                }
                return list
            }
            else if let stringArray = value as? [String] { // Assuming that string is the serverKey
                let list = List<T>()
                for serverKeyValue in stringArray {
                    var keyValues = ["server_id": serverKeyValue]
                    
                    // Check if object with serverKeyValue exists
                    if let existingObject = serializationRequest.realm.objects(type.self).filter(NSPredicate(format: "server_id == %@", serverKeyValue)).first {
                        
                        // Set primary id on keyValues to make sure to update the existing object
                        keyValues["id"] = existingObject.id
                    }
                    
                    // Create/update object
                    let object = serializationRequest.realm.create(type.self, value: keyValues, update: true)
                    list.append(object)
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
