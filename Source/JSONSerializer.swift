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
    public var userInfo: [String: Any]
    
    public let primaryId: String?
    
    public let persist: Bool
    
    public let syncOperation: SyncOperation?
    public let fetchRequest: FetchRequest?
    
    public init(
        realm: Realm = try! Realm(),
        httpMethod: Alamofire.HTTPMethod? = nil,
        userInfo: [String: Any] = [String: Any](),
        primaryId: String? = nil,
        persist: Bool = true,
        syncOperation: SyncOperation? = nil,
        fetchRequest: FetchRequest? = nil
        ) {
            self.realm = realm
            self.httpMethod = httpMethod
            self.userInfo = userInfo
            self.primaryId = primaryId
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
    
    public var objectInfos: [ObjectInfo] {
        switch serializedObjects {
        case .persisted(let objectInfos):
            return objectInfos
        default:
            return [ObjectInfo]()
        }
    }
    
    public var objects: [RKObject] {
        switch serializedObjects {
        case .transient(let objects):
            return objects
        default:
            return [RKObject]()
        }
    }
    
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
    public let serverKey: String?
    
    public init(
        ofType type: RKObject.Type,
        primaryKey: String,
        serverKey: String?
        ) {
            self.type = type
            self.primaryKey = primaryKey
            self.serverKey = serverKey
    }
}

// MARK: - Extension for method implementations

@available(OSX 10.10, *)
public extension JSONSerializable  {

    // MARK: - Methods
    
    // MARK: Optional defaults
    
    public static func modifyKeyValues(_ keyValues: [String: Any]) -> [String: Any]? {
        return nil
    }

    public static func modify<T: RKObject>(_ type: T.Type ,object: T) -> T? {
        return nil
    }
    
    public static func didSerialize<T: RKObject>(_ type: T.Type ,objects: [T]) -> Void {
        
    }
    
    public static func existingObject<T: RKObject>(_ type: T.Type, keyValues: [String: Any])  -> T? {
        return nil
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
    public static func serializeObjects<T: RKObject>(_ type: T.Type, jsonArray: NSArray,
                               serializationRequest: SerializationRequest,
                               modifyKeyValues: (([String: Any]) -> [String: Any])? = nil,
                               modifyObject: ((T) -> T)? = nil,
                               didSerializeObjects: (([T]) -> Void)? = nil,
                               completion: @escaping (SerializationResult) -> Void) {
        if hasPrimaryKey() {
            var _objectInfos = [ObjectInfo]()
            var _objects = [T]()
            var _error: RKError?
            
            // Begin write transaction
            let _ = try? serializationRequest.realm.write({ () -> Void in
                jsonArray.forEach({ (object) in
                    if let jsonDictionary = object as? NSDictionary {
                        var _object: T?
                        
                        let (object, error) = self.object(type.self,
                                    jsonDictionary: jsonDictionary,
                                    serializationRequest: serializationRequest,
                                    modifyKeyValues: modifyKeyValues)
                        
                        _object = object
                        _error = error
                        
                        // Optionaly modify object
                        if let object = _object, let modifiedObject = self.modify(T.self, object: object) {
                            _object = modifiedObject
                        }
                        if let object = _object, let modifiedObject = modifyObject?(object) {
                            _object = modifiedObject
                        }
                        
                        // ObjectInfo
                        if let primaryKey = type.primaryKey() {
                            if let primaryKeyValue = _object?.value(forKey: primaryKey) as? String {
                                let objectInfo = ObjectInfo(ofType: type.self, primaryKey: primaryKeyValue, serverKey: _object?.serverId)
                                _objectInfos.append(objectInfo)
                            }
                        }
                        
                        if let object = _object {
                            _objects.append(object)
                        }
                    }
                })
                
                // Hook after serializing objects
                self.didSerialize(T.self, objects: _objects, serializationRequest: serializationRequest)
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
    public static func serializeObject<T: RKObject>(_ type: T.Type, jsonDictionary: NSDictionary,
                              serializationRequest: SerializationRequest,
                              modifyKeyValues: (([String: Any]) -> [String: Any])? = nil,
                              modifyObject: ((T) -> T)? = nil,
                              didSerializeObjects: (([T]) -> Void)? = nil,
                              completion: @escaping (SerializationResult) -> Void) {
        if hasPrimaryKey() {
            var _objectInfos = [ObjectInfo]()
            var _objects = [T]()
            var _error: RKError?
            
            // Begin write transaction
            let _ = try? serializationRequest.realm.write({ () -> Void in
                var _object: T?
                let (object, error) = self.object(type.self,
                            jsonDictionary: jsonDictionary,
                            serializationRequest: serializationRequest,
                            modifyKeyValues: modifyKeyValues)
                    
                _object = object
                _error = error
                    
                // Optionaly modify object
                if let object = _object, let modifiedObject = self.modify(T.self, object: object) {
                    _object = modifiedObject
                }
                if let object = _object, let modifiedObject = modifyObject?(object) {
                    _object = modifiedObject
                }
                
                // Set ObjectInfo
                if let primaryKey = type.primaryKey() {
                    if let primaryKeyValue = _object?.value(forKey: primaryKey) as? String {
                        let objectInfo = ObjectInfo(ofType: type.self, primaryKey: primaryKeyValue, serverKey: _object?.serverId)
                        _objectInfos.append(objectInfo)
                    }
                }
                
                if let object = _object {
                    _objects.append(object)
                }
                
                // Hook after serializing objects
                if let object = _object {
                    self.didSerialize(T.self, objects: [object], serializationRequest: serializationRequest)
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
                              modifyKeyValues: (([String: Any]) -> [String: Any])? = nil) -> (object: T?, error: RKError?) {
        var _object: T?
        var _error: RKError?
        
        let mappingDictionary = type.jsonKeyPathsByPropertyKey(with: serializationRequest)
        
        if mappingDictionary.count > 0 {
            var keyValues = [String: Any]()
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue = jsonDictionary.value(forKeyPath: keyPath) as Any? {
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
                        if let valueTransformer = type.jsonTransformerForKey(key, jsonDictionary: jsonDictionary, serializationRequest: serializationRequest) {
                            if let value: Any = valueTransformer.transformedValue(jsonValue) {
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
            if let modifyKeyValues = type.modifyKeyValues(keyValues, jsonDictionary: jsonDictionary, serializationRequest: serializationRequest) {
                keyValues = modifyKeyValues
            }
            if let modifyKeyValues = modifyKeyValues?(keyValues) {
                keyValues = modifyKeyValues
            }
            
            if let primaryId = serializationRequest.primaryId {
                keyValues["id"] = primaryId
            }
            
            if let _ = type.serverKey(), let serverKeyValue = keyValues["serverId"] as? String {
                
                // Check if object exists (with serverKeyValue)
                var existingObject: T?
                
                if let _existingObject = type.existingObject(type.self, keyValues: keyValues) {
                    existingObject = _existingObject
                } else if let _existingObject = serializationRequest.realm.objects(type.self).filter(NSPredicate(format: "serverId == %@", serverKeyValue)).first {
                    existingObject = _existingObject
                }
                
                if let existingObject = existingObject {
                    
                    // TODO: Remove equal values from KeyValues
                    keyValues.forEach({ (key, value) in
                        if type.ignoredProperties().contains(key) == false {
                            let objectValue = existingObject[key]
                            var isEqual = false
                            
                            // String
                            if let objectValue = objectValue as? String, let keyValue = value as? String {
                                isEqual = (objectValue == keyValue)
                            }
                                
                                // Double
                            else if let objectValue = objectValue as? Double, let keyValue = value as? Double {
                                isEqual = (objectValue == keyValue)
                            }
                                
                                // Int
                            else if let objectValue = objectValue as? Int, let keyValue = value as? Int {
                                isEqual = (objectValue == keyValue)
                            }
                                
                                // Bool
                            else if let objectValue = objectValue as? Bool, let keyValue = value as? Bool {
                                isEqual = (objectValue == keyValue)
                            }
                                
                                // NSDate
                            else if let objectValue = objectValue as? NSDate, let keyValue = value as? NSDate {
                                isEqual = (objectValue == keyValue)
                            }
                                
                                // RKObject
                            else if let objectValue = objectValue as? RKObject, let keyValue = value as? RKObject {
                                isEqual = (objectValue.id == keyValue.id)
                            }
                            
                            if isEqual {
                                keyValues.removeValue(forKey: key)
                            }
                        }
                    })
                    
                    // Set primary id on keyValues to make sure to update the existing object
                    keyValues["id"] = existingObject.id as AnyObject

                    
                    if keyValues.count == 1 {
                        _object = existingObject
                    }
                    
                    // Set _object in case there is a local unsynced object in order to avoid updating
                    if let httpMethod = serializationRequest.httpMethod, httpMethod == .get {
                        if existingObject.syncStatus != SyncStatus.synced.rawValue {
                            _object = existingObject
                        }
                    }
                }
                
                // Create/update object
                if _object == nil {
                    
                    // Set lastFetchedAt
                    if let httpMethod = serializationRequest.httpMethod, httpMethod == .get {
                        keyValues["lastFetchedAt"] = NSDate()
                    }
                    
                    // Set lastSyncedAt
                    if let httpMethod = serializationRequest.httpMethod, httpMethod != .get {
                        keyValues["lastSyncedAt"] = NSDate()
                    }
                    
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
                
                if RealmKit.shared.debugLogs {
                    print("# RealmKit: There is a serialization issue with the primary key for Type: \(type) JSON Dictionary: \(jsonDictionary) MappingDictionary: \(mappingDictionary) KeyValues: \(keyValues)" as Any)
                }
            }
        } else {
            _error = RKError.JSONSerilizerFailure(reason: .noJsonKeyPathsByPropertyKey(type: type))
            
            if RealmKit.shared.debugLogs {
                print("# RealmKit: There is no jsonKeyPathsByPropertyKey: defined for type: \(type)")
            }
        }
        
        return (_object, _error)
    }
}

// MARK: - ValueTransformers

open class RealmValueTransformer: ValueTransformer {
    
    var forwardClosure: ((_ value: Any?) -> Any?)?
    var reverseClosure: ((_ value: Any?) -> Any?)?
    
    // MARK: Initializers
    
    override init() {
        super.init()
    }
    
    convenience init(forwardClosure: ((_ value: Any?) -> Any?)?, reverseClosure: ((_ value: Any?) -> Any?)?) {
        self.init()
        
        self.forwardClosure = forwardClosure
        self.reverseClosure = reverseClosure
    }
    
    // MARK: Class Functions
    
    // Returns a transformer which transforms values using the given closure.
    // Reverse transformations will not be allowed.
    open class func transformerWithClosure(_ closure: @escaping (_ value: Any?) -> Any?) -> ValueTransformer! {
        return RealmValueTransformer(forwardClosure: closure, reverseClosure: nil)
    }
    
    // Returns a transformer which transforms values using the given closure, for
    // forward or reverse transformations.
    open class func reversibleTransformerWithClosure(_ closure: @escaping (_ value: Any?) -> Any?) -> ValueTransformer! {
        return reversibleTransformerWithForwardBlock(closure, reverseClosure: closure)
    }
    
    // Returns a transformer which transforms values using the given closures.
    open class func reversibleTransformerWithForwardBlock(_ forwardClosure: @escaping (_ value: Any?) -> Any?, reverseClosure: @escaping (_ value: Any?) -> Any?) -> ValueTransformer! {
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
            return forwardClosure(value)
        }
        return nil
    }
    
}

// MARK: - Predefined ValueTransformers

@available(OSX 10.10, *)
public extension RealmValueTransformer {
    
    public class func jsonDictionaryTransformer<T: RKObject>(ofType type: T.Type, serializationRequest: SerializationRequest) -> ValueTransformer! {
        return reversibleTransformerWithForwardBlock({ (value) -> Any? in
            
            // TODO: Direct value for primary key
            
            if let dictionary = value as? NSDictionary {
                return (type as JSONSerializable.Type).object(type, jsonDictionary: dictionary, serializationRequest: serializationRequest).object
            } else {
                return nil
            }
            }, reverseClosure: { (value) -> Any? in
                if let _ = value as? RKObject {
                    // TODO: Implement JSONDictionaryFromRealmObject:
                    return nil
                } else {
                    return nil
                }
        })
    }
    
    public class func jsonArrayTransformer<T: RKObject>(ofType type: T.Type, serializationRequest: SerializationRequest) -> ValueTransformer! {
        let dictionaryTransformer = jsonDictionaryTransformer(ofType: type, serializationRequest: serializationRequest)
        
        return reversibleTransformerWithForwardBlock({ (value) -> Any? in
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
                    var keyValues = ["serverId": serverKeyValue]
                    
                    // Check if object with serverKeyValue exists
                    if let existingObject = serializationRequest.realm.objects(type.self).filter(NSPredicate(format: "serverId == %@", serverKeyValue)).first {
                        
                        // Set primary id on keyValues to make sure to update the existing object
                        keyValues["id"] = existingObject.id
                    }
                    
                    // Modify keyValues (optional) before being used to create/update an object
                    if let modifyKeyValues = type.modifyKeyValues(keyValues, jsonDictionary: nil, serializationRequest: serializationRequest) {
                        if let modifyKeyValues = modifyKeyValues as? [String: String] {
                            keyValues = modifyKeyValues
                        }
                    }
                    
                    // Create/update object
                    let object = serializationRequest.realm.create(type.self, value: keyValues, update: true)
                    list.append(object)
                }
                return list
            } else {
                return nil
            }
            
            }, reverseClosure: { (value) -> Any? in
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
