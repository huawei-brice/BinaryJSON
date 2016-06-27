//
//  swift
//  BSON
//
//  Created by Alsey Coleman Miller on 12/13/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

@_exported import C7
@_exported import CLibbson
import Foundation

/// [Binary JSON](http://bsonspec.org)
public enum BSON {
    case null
    case array([BSON])
    case document([String:BSON])
    case int(Int)
    case double(Double)
    case bool(Bool)
    case string(String)
    case date(NSDate)
    case timestamp(Timestamp)
    case binary(Binary)
    case code(Code)
    case objectID(ObjectID)
    case regularExpression(RegularExpression)
    case key(Key)
}

extension BSON: Equatable {}

public func ==(lhs: BSON, rhs: BSON) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null): return true
    case let (.array(lhs), .array(rhs)): return lhs == rhs
    case let (.document(lhs), .document(rhs)): return lhs == rhs
    case let (.int(lhs), .int(rhs)): return lhs == rhs
    case let (.double(lhs), .double(rhs)): return lhs == rhs
    case let (.bool(lhs), .bool(rhs)): return lhs == rhs
    case let (.string(lhs), .string(rhs)): return lhs == rhs
    case let (.date(lhs), .date(rhs)):
        // Float32 because NSDate is more accurate than MongoDB
        return Float32(lhs.timeIntervalSince1970) == Float32(rhs.timeIntervalSince1970)
    case let (.timestamp(lhs), .timestamp(rhs)): return lhs == rhs
    case let (.binary(lhs), .binary(rhs)): return lhs == rhs
    case let (.code(lhs), .code(rhs)): return lhs == rhs
    case let (.objectID(lhs), .objectID(rhs)): return lhs == rhs
    case let (.regularExpression(lhs), .regularExpression(rhs)): return lhs == rhs
    case let (.key(lhs), .key(rhs)): return lhs == rhs
    default: return false
    }
}

public extension BSON {
    public var arrayValue: [BSON]? {
        return try? get()
    }
    
    public var documentValue: [String:BSON]? {
        return try? get()
    }
    
    public var intValue: Int? {
        return try? get()
    }
    
    public var doubleValue: Double? {
        return try? get()
    }
    
    public var boolValue: Bool? {
        return try? get()
    }
    
    public var stringValue: Swift.String? {
        return try? get()
    }
    
    public var dateValue: NSDate? {
        return try? get()
    }
    
    public var timestampValue: Timestamp? {
        return try? get()
    }
    
    public var binaryValue: Binary? {
        return try? get()
    }
    
    public var codeValue: Code? {
        return try? get()
    }
    
    public var objectIDValue: ObjectID? {
        return try? get()
    }
    
    public var regularExpressionValue: RegularExpression? {
        return try? get()
    }
    
    public var keyValue: Key? {
        return try? get()
    }
}

public extension BSON {
    public enum FetchingError: ErrorProtocol {
        case incompatibleType
    }

    public func get<T>() throws -> T {
        switch self {
        case .array(let value as T):
            return value
        case .document(let value as T):
            return value
        case .int(let value as T):
            return value
        case .double(let value as T):
            return value
        case .bool(let value as T):
            return value
        case .string(let value as T):
            return value
        case .date(let value as T):
            return value
        case .timestamp(let value as T):
            return value
        case .binary(let value as T):
            return value
        case .code(let value as T):
            return value
        case .objectID(let value as T):
            return value
        case .regularExpression(let value as T):
            return value
        case .key(let value as T):
            return value
        default:
            throw FetchingError.incompatibleType
        }
    }

    public func get<T>(_ key: String) throws -> T {
        if let value = self[key] {
            return try value.get()
        }

        throw FetchingError.incompatibleType
    }
}

public extension BSON {
    public subscript(index: Int) -> BSON? {
        get {
            guard let array = arrayValue where array.indices ~= index else { return nil }
            return array[index]
        }

        set(bson) {
            guard var array = arrayValue where array.indices ~= index else { return }
            array[index] = bson ?? .null
            self = .array(array)
        }
    }

    public subscript(key: String) -> BSON? {
        get {
            return documentValue?[key]
        }

        set(bson) {
            guard var document = documentValue else { return }
            document[key] = bson
            self = .document(document)
        }
    }
}

public extension BSON {
    public static func infer(_ value: Bool) -> BSON {
        return .bool(value)
    }
    
    public static func infer(_ value: Double) -> BSON {
        return .double(value)
    }
    
    public static func infer(_ value: Int) -> BSON {
        return .int(value)
    }
    
    public static func infer(_ value: String) -> BSON {
        return .string(value)
    }
    
    public static func infer(_ value: [BSON]) -> BSON {
        return .array(value)
    }

    public static func infer(_ value: [String:BSON]) -> BSON {
        return .document(value)
    }

    public static func infer(_ value: NSDate) -> BSON {
        return .date(value)
    }

    public static func infer(_ value: Timestamp) -> BSON {
        return .timestamp(value)
    }

    public static func infer(_ value: Binary) -> BSON {
        return .binary(value)
    }

    public static func infer(_ value: Code) -> BSON {
        return .code(value)
    }

    public static func infer(_ value: ObjectID) -> BSON {
        return .objectID(value)
    }

    public static func infer(_ value: RegularExpression) -> BSON {
        return .regularExpression(value)
    }

    public static func infer(_ value: BinaryJSON.Key) -> BSON {
        return .key(value)
    }
}

/// Represents a string of Javascript code.
public struct Code: Equatable {
    
    public var code: String
    
    public var scope: [String:BSON]?
    
    public init(_ code: String, scope: [String:BSON]? = nil) {
        
        self.code = code
        self.scope = scope
    }
}

public struct Binary: Equatable {
    
    public enum Subtype: Byte {
        
        case generic    = 0x00
        case function   = 0x01
        case old        = 0x02
        case uuidOld    = 0x03
        case uuid       = 0x04
        case md5        = 0x05
        case user       = 0x80

        var cValue: bson_subtype_t {
            switch self {
            case .generic: return BSON_SUBTYPE_BINARY
            case .function: return BSON_SUBTYPE_FUNCTION
            case .old: return BSON_SUBTYPE_BINARY_DEPRECATED
            case .uuidOld: return BSON_SUBTYPE_UUID_DEPRECATED
            case .uuid: return BSON_SUBTYPE_UUID
            case .md5: return BSON_SUBTYPE_MD5
            case .user: return BSON_SUBTYPE_USER
            }
        }

        init(cValue: bson_subtype_t) {
            switch cValue {
            case BSON_SUBTYPE_BINARY: self = .generic
            case BSON_SUBTYPE_FUNCTION: self = .function
            case BSON_SUBTYPE_BINARY_DEPRECATED: self = .old
            case BSON_SUBTYPE_UUID_DEPRECATED: self = .uuidOld
            case BSON_SUBTYPE_UUID: self = .uuid
            case BSON_SUBTYPE_MD5: self = .md5
            case BSON_SUBTYPE_USER: self = .user
            default: self = .user
            }
        }
    }
    
    public var data: C7.Data
    
    public var subtype: Subtype
    
    public init(data: C7.Data, subtype: Subtype = .generic) {
        
        self.data = data
        self.subtype = subtype
    }
}

/// BSON maximum and minimum representable types.
public enum Key {
    case min
    case max
}

public struct Timestamp: Equatable {
    
    /// Seconds since the Unix epoch.
    public var time: UInt32
    
    /// Prdinal for operations within a given second.
    public var oridinal: UInt32
    
    public init(time: UInt32, oridinal: UInt32) {
        
        self.time = time
        self.oridinal = oridinal
    }
}

public struct RegularExpression: Equatable {
    
    public var pattern: String
    
    public var options: String
    
    public init(_ pattern: String, options: String) {
        
        self.pattern = pattern
        self.options = options
    }
}

/// BSON Object Identifier.
public struct ObjectID: RawRepresentable, Equatable, Hashable, CustomStringConvertible {
    
    // MARK: - Properties
    
    public typealias ByteValue = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    
    public var byteValue: ByteValue {
        
        get { return self.internalValue.bytes }
        
        set { self.internalValue.bytes = newValue }
    }

    // MARK: - Private Properties

    internal var internalValue: bson_oid_t

    // MARK: - Initialization
    
    /// Default initializer.
    ///
    /// Creates a new BSON ObjectID from the specified context, or the default context if none is specified.
    public init(context: Context? = nil) {
        
        var objectID = bson_oid_t()
        
        bson_oid_init(&objectID, context?.internalPointer ?? nil)
        
        self.internalValue = objectID
    }
    
    public init(byteValue: ByteValue) {
        
        self.internalValue = bson_oid_t(bytes: byteValue)
    }
    
    public init?(rawValue: String) {
        
        // must be 24 characters
        guard rawValue.utf8.count == 24 &&
            bson_oid_is_valid(rawValue, rawValue.utf8.count)
            else { return nil }
        
        var objectID = bson_oid_t()
        
        bson_oid_init_from_string(&objectID, rawValue)
        
        self.internalValue = objectID
    }
    
    public var rawValue: String {
        let stringPointer = UnsafeMutablePointer<CChar>(allocatingCapacity:25)
        
        var objectID = internalValue
        
        bson_oid_to_string(&objectID, stringPointer)
        
        return String(cString:stringPointer)
    }
    
    public var description: String {
        return rawValue
    }
    
    public var hashValue: Int {
        var objectID = internalValue
        
        let hash = bson_oid_hash(&objectID)
        
        return Int(hash)
    }
}

public func ==(lhs: ObjectID, rhs: ObjectID) -> Bool {
    var oid1 = lhs.internalValue
    var oid2 = rhs.internalValue
    return bson_oid_equal(&oid1, &oid2)
}

public func ==(lhs: Timestamp, rhs: Timestamp) -> Bool {
    return lhs.time == rhs.time && lhs.oridinal == rhs.oridinal
}

public func ==(lhs: Binary, rhs: Binary) -> Bool {
    return lhs.data == rhs.data && lhs.subtype == rhs.subtype
}

public func ==(lhs: Code, rhs: Code) -> Bool {
    guard lhs.code == rhs.code else {
        return false
    }

    switch (lhs.scope, rhs.scope) {
    case let (lscope?, rscope?) where lscope == rscope:
        return true
    case (.none, .none):
        return true
    default:
        return false
    }
}

public func ==(lhs: RegularExpression, rhs: RegularExpression) -> Bool {
    return lhs.pattern == rhs.pattern && lhs.options == rhs.options
}
