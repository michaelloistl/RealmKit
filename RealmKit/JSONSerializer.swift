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
    
    public let syncOperation: SyncOperation?
//    public let fetchOperation: FetchOperation?
    public let fetchRequest: FetchRequest?
    
    public init(
        realm: Realm,
        method: Alamofire.HTTPMethod? = nil,
        userInfo: [String: Any] = [String: Any](),
        oldPrimaryKey: String? = nil,
        syncOperation: SyncOperation? = nil,
//        fetchOperation: FetchOperation? = nil,
        fetchRequest: FetchRequest? = nil
        ) {
            self.realm = realm
            self.method = method
            self.userInfo = userInfo
            self.oldPrimaryKey = oldPrimaryKey
            self.newPrimaryKey = newPrimaryKey
            self.syncOperation = syncOperation
//            self.fetchOperation = fetchOperation
            self.fetchRequest = fetchRequest
    }
}

/// Used to return result of serialization.
@available(OSX 10.10, *)
public struct SerializationResult {
    
    enum SerializedObjects {
        case none
        case persisted(objectInfos: [ObjectInfo])
        case transient(objects: [Object])
    }
    
    // MARK: Required
    public let serializationRequest: SerializationRequest
    
    // MARK: Optional
    public let jsonDictionary: [String: Any]?
    public let serializedObjects: SerializedObjects
    public let error: RKError?
    
    public init(
        serializationRequest: SerializationRequest,
        jsonDictionary: [String: Any]?,
        serializedObjects: SerializedObjects,
        error: RKError?
        ) {
        self.serializationRequest = serializationRequest
        self.jsonDictionary = jsonDictionary
        self.serializedObjects = serializedObjects
        self.error = error
    }
}

/// Used to store all data associated with a realm object created/updated during serialization.
public struct ObjectInfo {
    public let type: Object.Type
    public let primaryKey: String
    
    public init(
        type: Object.Type,
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
    
    open static func modifyKeyValues(_ keyValues: [String: AnyObject]) -> [String: AnyObject]? {
        return nil
    }

    open static func modifyObject(_ object: Object) -> Object? {
        return nil
    }
    
    open static func didSerializeObjects(_ objects: [Object]) -> () {
        
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
    public static func objects(with jsonArray: NSArray,
                               serializationRequest: SerializationRequest,
                               persist: Bool = true,
                               modifyKeyValues: @escaping (([String: AnyObject]) -> [String: AnyObject])? = nil,
                               modifyObject: @escaping ((Object) -> Object)? = nil,
                               didSerializeObjects: @escaping (([Object]) -> ())? = nil,
                               completion: @escaping (SerializationResult) -> Void) {
        if hasPrimaryKey() {
            var _objectInfos = [ObjectInfo]()
            var _objects = [Object]()
            
            // Begin write transaction
            let _ = try? serializationRequest.realm.write({ () -> Void in
                jsonArray.forEach({ (object) in
                    if let jsonDictionary = object as? NSDictionary {
                        let type = typeToSerialize(dictionary)
                        
                        var _object: Object?
                        self.object(type.self,
                                    jsonDictionary: jsonDictionary,
                                    serializationRequest: serializationRequest,
                                    persist: persist,
                                    modifyKeyValues: modifyKeyValues,
                                    shouldUseKeyValues: shouldUseKeyValues,
                                    completion: { object, error in
                            
                                        _object = object
                                        
                                        // Optionaly modify object
                                        if let modifiedObject = self.modifyObject(object) {
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
                            })
                    }
                })
                
                // Hook after serializing objects
                if let objects = _objects {
                    self.didSerializeObjects(objects)
                    didSerializeObjects?(objects)
                }
            })
            // End write transaction
            
            let serializedObjects = (persist) ? SerializedObjects.persisted(_objectInfos) : SerializedObjects.transient(_objects)
            let result = SerializationResult(serializationRequest: serializationRequest, jsonDictionary: jsonDictionary as? [String: Any], serializedObjects: serializedObjects, error: nil)
            
            completion(result)
        } else {
            let result = SerializationResult(serializationRequest: serializationRequest, jsonDictionary: nil, serializedObjects: SerializedObjects.none, error: RKError.JSONSerilizerFailureReason.invalidPrimaryKey)
            
            completion(result)
        }
    }
    
    /// Create or update object with JSON Dictionary.
    ///
    /// - parameter modifyObject: Optional closure to modify the object after ccreation/update within the same write transaction.
    /// - parameter didSerializeObject: Optional closure to include optional code after serializing object within the same write transaction.
    public static func object(with jsonDictionary: NSDictionary,
                              serializationRequest: SerializationRequest,
                              persist: Bool = true,
                              modifyKeyValues: @escaping (([String: AnyObject]) -> [String: AnyObject])? = nil,
                              modifyObject: @escaping ((Object) -> Object)? = nil,
                              didSerializeObjects: @escaping (([Object]) -> ())? = nil,
                              completion: @escaping (SerializationResult) -> Void) {
        if hasPrimaryKey() {
            var _objectInfos = [ObjectInfo]()
            var _objects = [Object]()
            
            // Begin write transaction
            let _ = try? serializationRequest.realm.write({ () -> Void in
                let type = typeToSerialize(dictionary)
            
                var _object: Object?
                self.object(type.self,
                            jsonDictionary: jsonDictionary,
                            serializationRequest: serializationRequest,
                            persist: persist,
                            modifyKeyValues: modifyKeyValues,
                            shouldUseKeyValues: shouldUseKeyValues,
                            completion: { object, error in
                      
                                _object = object
                                
                                // Optionaly modify object
                                if let modifiedObject = self.modifyObject(object) {
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
            })
            // End write transaction
            
            let serializedObjects = (persist) ? SerializedObjects.persisted(_objectInfos) : SerializedObjects.transient(_objects)
            let result = SerializationResult(serializationRequest: serializationRequest, jsonDictionary: jsonDictionary as? [String: Any], serializedObjects: serializedObjects, error: nil)
            
            completion(result)
        } else {
            let result = SerializationResult(serializationRequest: serializationRequest, jsonDictionary: nil, serializedObjects: SerializedObjects.none, error: RKError.JSONSerilizerFailureReason.invalidPrimaryKey)
            
            completion(result)
        }
    }
    
    /// Create or update object with mapping.
    ///
    /// Object key -> JSON keyPath
    ///
    /// - warning: This method may only be called during a write transaction.
    public static func object<T: Object>(_ type: T.Type,
                              jsonDictionary: NSDictionary,
                              serializationRequest: SerializationRequest,
                              persist: Bool = true,
                              modifyKeyValues: @escaping (([String: AnyObject]) -> [String: AnyObject])? = nil,
                              completion: @escaping (Object?, RKError?) -> ()) {
        var _object: Object?
        var _error: RKError?
        
        if let mappingDictionary = (type as JSONSerializable.Type).jsonKeyPathsByPropertyKey(with: serializationRequest) {
            var keyValues = [String: AnyObject]()
            
            for (key, keyPath) in mappingDictionary {
                if let jsonValue = jsonDictionary.value(forKeyPath: keyPath) as AnyObject? {
                    if let _ = jsonValue as? NSNull {
                        
                        // Default Value if it's not primary key
                        if let primaryKey = (type as Object.Type).primaryKey() {
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
            if let modifyKeyValues = (type as JSONSerializable.Type).modifyKeyValues(keyValues) {
                keyValues = modifyKeyValues
            }
            if let modifyKeyValues = modifyKeyValues?(keyValues) {
                keyValues = modifyKeyValues
            }
            
            // Set lastFetchedAt
            if let _type = type as? Fetchable, let method = serializationRequest.method, method == .get {
                keyValues["lastFetchedAt"] = NSDate()
            }
            
            // Set lastSyncedAt
            if let _type = type as? Syncable, let method = serializationRequest.method, method != .get {
                keyValues["lastSyncedAt"] = NSDate()
            }
            
            if let serverKey = (type as ObjectProtocol).serverKey(), let serverKeyValue = keyValues[serverKey] as? String { // "id" = "1"
                
                // Check if object with serverKeyValue exists
                if let existingObject = serializationRequest.realm.objects(type.self).filter(NSPredicate(format: "server_id == %@", serverKeyValue)).first {
                    
                    // Set primary id on keyValues to make sure to update the existing object
                    keyValues["id"] = existingObject.id

                    // Set _object in case there is a local unsynced object in order to avoid updating
                    if let httpMethod = serializationRequest.httpMethod, httpMethod == .get {
                        if existingObject.syncStatus != SyncStatus.Synced.rawValue {
                            _object = existingObject
                        }
                    }
                }
                
                // Create/update object
                if _object == nil {
                    _object = serializationRequest.realm.create(type.self, value: keyValues, update: true)
                }
            } else {
                _error = RKError.JSONSerilizerFailureReason.noPrimaryKeyValue(type, jsonDictionary as? [String: Any], mappingDictionary, keyValues)
                
                if RealmKit.sharedInstance.debugLogs {
                    print("# RealmKit: There is a serialization issue with the primary key for Type: \(type) JSON Dictionary: \(jsonDictionary) MappingDictionary: \(mappingDictionary) KeyValues: \(keyValues)" as Any)
                }
            }
        } else {
            _error = RKError.JSONSerilizerFailureReason.noJsonKeyPathsByPropertyKey(type)
            
            if RealmKit.sharedInstance.debugLogs {
                print("# RealmKit: There is no jsonKeyPathsByPropertyKey: defined for type: \(type)")
            }
        }
        
        completion(_object, _error)
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
    
    public class func JSONDictionaryTransformerWithObjectType<T: Object>(_ type: T.Type, serializationRequest: Serializationrequest) -> ValueTransformer! {
        return reversibleTransformerWithForwardBlock({ (value) -> AnyObject? in
            
            // TODO: Direct value for primary key
            
            if let dictionary = value as? NSDictionary {
                return (type as? JSONSerializable.Type)?.realmObject(type, jsonDictionary: dictionary, serializationRequest: serializationRequest)
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
    
    public class func JSONArrayTransformerWithObjectType<T: Object>(_ type: T.Type, serializationRequest: SerializationRequest) -> ValueTransformer! {
        let dictionaryTransformer = JSONDictionaryTransformerWithObjectType(type, serializationRequest: serializationRequest)
        
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
