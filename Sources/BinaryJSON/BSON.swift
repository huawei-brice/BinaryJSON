//
//  BSON.swift
//  BSON
//
//  Created by Alsey Coleman Miller on 12/13/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

/// [Binary JSON](http://bsonspec.org)
public struct BSON {
    
    public class Null {}
    
    /// BSON Array
    public typealias Array = [BSON.Value]
    
    /// BSON Document
    public typealias Document = [String: BSON.Value]
    
    /// BSON value type. 
    public enum Value: RawRepresentable, Equatable, CustomStringConvertible {
        
        case null
        
        case array(BSON.Array)
        
        case document(BSON.Document)
        
        case number(BSON.Number)
        
        case string(Swift.String)
        
        case date(DateValue)
        
        case timestamp(BSON.Timestamp)
        
        case binary(BSON.Binary)
        
        case code(BSON.Code)
        
        case objectID(BSON.ObjectID)
        
        case regularExpression(BSON.RegularExpression)
        
        case maxMinKey(BSON.Key)
    }
    
    public enum Number: Equatable {
        
        case boolean(Bool)
        
        case integer32(Int32)
        
        case integer64(Int64)
        
        case double(Swift.Double)
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
        }
        
        public var data: Data
        
        public var subtype: Subtype
        
        public init(data: Data, subtype: Subtype = .generic) {
            
            self.data = data
            self.subtype = subtype
        }
    }
    
    /// Represents a string of Javascript code.
    public struct Code: Equatable {
        
        public var code: String
        
        public var scope: BSON.Document?
        
        public init(_ code: String, scope: BSON.Document? = nil) {
            
            self.code = code
            self.scope = scope
        }
    }
    
    /// BSON maximum and minimum representable types.
    public enum Key {
        
        case minimum
        case maximum
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
}

public typealias DateValue = Date

// MARK: - RawRepresentable

public extension BSON.Value {
    
    var rawValue: Any {
        
        switch self {
            
        case .null: return BSON.Null()
            
        case let .array(array):
            
            let rawValues = array.map { (value) in return value.rawValue }
            
            return rawValues
            
        case let .document(document):
            
            var rawObject: [Swift.String:Any] = [:]
            
            for (key, value) in document {
                
                rawObject[key] = value.rawValue
            }
            
            return rawObject
            
        case let .number(number): return number.rawValue
            
        case let .date(date): return date
            
        case let .timestamp(timestamp): return timestamp
            
        case let .binary(binary): return binary
            
        case let .string(string): return string
            
        case let .maxMinKey(key): return key
            
        case let .code(code): return code
            
        case let .objectID(objectID): return objectID
            
        case let .regularExpression(regularExpression): return regularExpression
        }
    }
    
    init?(rawValue: Any) {
        
        guard (rawValue as? BSON.Null) == nil else {
            
            self = .null
            return
        }
        
        if let key = rawValue as? BSON.Key {
            
            self = .maxMinKey(key)
            return
        }
        
        if let string = rawValue as? Swift.String {
            
            self = .string(string)
            return
        }
        
        if let date = rawValue as? DateValue {
            
            self = .date(date)
            return
        }
        
        if let timestamp = rawValue as? BSON.Timestamp {
            
            self = .timestamp(timestamp)
            return
        }
        
        if let binary = rawValue as? BSON.Binary {
            
            self = .binary(binary)
            return
        }
        
        if let number = BSON.Number(rawValue: rawValue) {
            
            self = .number(number)
            return
        }
        
        if let rawArray = rawValue as? [Any] {
            
            var jsonArray: [BSON.Value] = []
            for val in rawArray {
                guard let json = BSON.Value(rawValue: val) else { return nil }
                jsonArray.append(json)
            }
            self = .array(jsonArray)
            return
        }
        
        if let rawDictionary = rawValue as? [Swift.String: Any] {
            
            var document = BSON.Document()
            
            for (key, rawValue) in rawDictionary {
                
                guard let bsonValue = BSON.Value(rawValue: rawValue) else { return nil }
                
                document[key] = bsonValue
            }
            
            self = .document(document)
            return
        }
        
        if let code = rawValue as? BSON.Code {
            
            self = .code(code)
            return
        }
        
        if let objectID = rawValue as? BSON.ObjectID {
            
            self = .objectID(objectID)
            return
        }
        
        if let regularExpression = rawValue as? BSON.RegularExpression {
            
            self = .regularExpression(regularExpression)
            return
        }
        
        return nil
    }
}

extension BSON.Value {
    public var nullValue: BSON.Null? {
        switch self {
        case .null: return BSON.Null()
        default: return nil
        }
    }

    public var arrayValue: BSON.Array? {
        switch self {
        case .array(let arr): return arr
        default: return nil
        }
    }

    public var documentValue: BSON.Document? {
        switch self {
        case .document(let doc): return doc
        default: return nil
        }
    }

    public var numberValue: BSON.Number? {
        switch self {
        case .number(let num): return num
        default: return nil
        }
    }

    public var intValue: Int? {
        guard let num = self.numberValue else { return nil }

        switch num {
        case .integer32(let i): return Int(i)
        case .integer64(let i): return Int(i)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        guard let num = self.numberValue else { return nil }

        switch num {
        case .double(let d): return d
        default: return nil
        }
    }

    public var boolValue: Bool? {
        guard let num = self.numberValue else { return nil }

        switch num {
        case .boolean(let b): return b
        default: return nil
        }
    }

    public var stringValue: Swift.String? {
        switch self {
        case .string(let str): return str
        default: return nil
        }
    }

    public var dateValue: DateValue? {
        switch self {
        case .date(let date): return date
        default: return nil
        }
    }

    public var timestampValue: BSON.Timestamp? {
        switch self {
        case .timestamp(let stamp): return stamp
        default: return nil
        }
    }

    public var binaryValue: BSON.Binary? {
        switch self {
        case .binary(let binary): return binary
        default: return nil
        }
    }

    public var codeValue: BSON.Code? {
        switch self {
        case .code(let code): return code
        default: return nil
        }
    }

    public var objectIDValue: BSON.ObjectID? {
        switch self {
        case .objectID(let id): return id
        default: return nil
        }
    }

    public var regularExpressionValue: BSON.RegularExpression? {
        switch self {
        case .regularExpression(let regex): return regex
        default: return nil
        }
    }

    public var keyValue: BSON.Key? {
        switch self {
        case .maxMinKey(let key): return key
        default: return nil
        }
    }
}

public extension BSON.Number {
    
    public var rawValue: Any {
        
        switch self {
        case .boolean(let value): return value
        case .integer32(let value): return value
        case .integer64(let value): return value
        case .double(let value):  return value
        }
    }
    
    public init?(rawValue: Any) {
        
        if let value = rawValue as? Bool            { self = .boolean(value) }
        if let value = rawValue as? Int32           { self = .integer32(value) }
        if let value = rawValue as? Int64           { self = .integer64(value) }
        if let value = rawValue as? Swift.Double    { self = .double(value) }

        // use Int32 as a default - maybe check type of IntMax (Int32/Int64)?
        if let value = rawValue as? Int             { self = .integer32(Int32(value)) }

        return nil
    }
}

// MARK: - CustomStringConvertible

public extension BSON.Value {
    
    public var description: Swift.String { return "\(rawValue)" }
}

public extension BSON.Number {
    
    public var description: Swift.String { return "\(rawValue)" }
}

// MARK: Equatable

public func ==(lhs: BSON.Value, rhs: BSON.Value) -> Bool {
    
    switch (lhs, rhs) {
        
    case (.null, .null): return true
        
    case let (.string(leftValue), .string(rightValue)): return leftValue == rightValue
        
    case let (.number(leftValue), .number(rightValue)): return leftValue == rightValue
        
    case let (.array(leftValue), .array(rightValue)): return leftValue == rightValue
        
    case let (.document(leftValue), .document(rightValue)): return leftValue == rightValue
        
    case let (.date(leftValue), .date(rightValue)): return leftValue == rightValue
        
    case let (.timestamp(leftValue), .timestamp(rightValue)): return leftValue == rightValue
        
    case let (.binary(leftValue), .binary(rightValue)): return leftValue == rightValue
        
    case let (.code(leftValue), .code(rightValue)): return leftValue == rightValue
        
    case let (.objectID(leftValue), .objectID(rightValue)): return leftValue == rightValue
        
    case let (.regularExpression(leftValue), .regularExpression(rightValue)): return leftValue == rightValue
        
    case let (.maxMinKey(leftValue), .maxMinKey(rightValue)): return leftValue == rightValue
        
    default: return false
    }
}

public func ==(lhs: BSON.Number, rhs: BSON.Number) -> Bool {
    
    switch (lhs, rhs) {
        
    case let (.boolean(leftValue), .boolean(rightValue)): return leftValue == rightValue
        
    case let (.integer32(leftValue), .integer32(rightValue)): return leftValue == rightValue
        
    case let (.integer64(leftValue), .integer64(rightValue)): return leftValue == rightValue
        
    case let (.double(leftValue), .double(rightValue)): return leftValue == rightValue
        
    default: return false
    }
}

public func ==(lhs: BSON.Timestamp, rhs: BSON.Timestamp) -> Bool {
    
    return lhs.time == rhs.time && lhs.oridinal == rhs.oridinal
}

public func ==(lhs: BSON.Binary, rhs: BSON.Binary) -> Bool {
    
    return lhs.data == rhs.data && lhs.subtype == rhs.subtype
}

public func ==(lhs: BSON.Code, rhs: BSON.Code) -> Bool {
    
    if let leftScope = lhs.scope {
        
        guard let rightScope = rhs.scope, rightScope == leftScope
            else { return false }
    }
    
    return lhs.code == rhs.code
}

public func ==(lhs: BSON.RegularExpression, rhs: BSON.RegularExpression) -> Bool {
    
    return lhs.pattern == rhs.pattern && lhs.options == rhs.options
}

