//
//  UnsafePointer.swift
//  BSON
//
//  Created by Alsey Coleman Miller on 12/13/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import CLibbson

public protocol BSONPointerContainer {
    init(bson: UnsafeMutablePointer<bson_t>)
    var pointer: UnsafeMutablePointer<bson_t> {get}
}

public extension BSONPointerContainer {
    init() {
        self.init(bson: bson_new())
    }

    init(document: [String:BSON]) throws {
        self.init()
        let appender = BSONAppender(container: self)
        try document.forEach(appender.append)
    }

    init(array: [BSON]) throws {
        self.init()
        let appender = BSONAppender(container: self)
        try array.enumerated().forEach { try appender.append(key: "\($0)", value: $1) }
    }
}

/// Carries an UnsafeMutablePointer<bson_t> and calls `bson_destroy` on it upon deinitialization.
public final class AutoReleasingBSONContainer: BSONPointerContainer {
    public let pointer: UnsafeMutablePointer<bson_t>

    public init(bson: UnsafeMutablePointer<bson_t>) {
        self.pointer = bson
    }

    deinit {
        bson_destroy(self.pointer)
    }
}

final class BSONAppender {
    enum Error: ErrorProtocol {
        case overflow
    }

    let container: BSONPointerContainer
    init(container: BSONPointerContainer) {
        self.container = container
    }

    func append(key: String, value: BSON) throws {

        let keyLength = Int32(key.utf8.count)

        // to reduce boilerplate a little, we need to have a little boilerplate
        func appender0(_ f: (UnsafeMutablePointer<bson_t>, UnsafePointer<Int8>, Int32) -> Bool) throws {
            guard f(self.container.pointer, key, keyLength) else {
                throw Error.overflow
            }
        }
        func appender1<T>(_ f: (UnsafeMutablePointer<bson_t>, UnsafePointer<Int8>, Int32, T) -> Bool, _ t: T) throws {
            guard f(self.container.pointer, key, keyLength, t) else {
                throw Error.overflow
            }
        }
        func appender2<T, U>(_ f: (UnsafeMutablePointer<bson_t>, UnsafePointer<Int8>, Int32, T, U) -> Bool, _ t: T, _ u: U) throws {
            guard f(self.container.pointer, key, keyLength, t, u) else {
                throw Error.overflow
            }
        }
        func appender3<T, U, V>(_ f: (UnsafeMutablePointer<bson_t>, UnsafePointer<Int8>, Int32, T, U, V) -> Bool, _ t: T, _ u: U, _ v: V) throws {
            guard f(self.container.pointer, key, keyLength, t, u, v) else {
                throw Error.overflow
            }
        }

        switch value {

        case .null:
            try appender0(bson_append_null)

        case let .string(string):
            try appender2(bson_append_utf8, string, Int32(string.utf8.count))

        case let .bool(value):
            try appender1(bson_append_bool, value)

        case let .int(value):
            // TODO: Don't make assumptions about 64bit
            try appender1(bson_append_int64, Int64(value))

        case let .double(value):
            try appender1(bson_append_double, value)

        // case let .date(date):
        //     var time = timeval(timeInterval: date.timeIntervalSince1970)
        //     try appender1(bson_append_timeval)(&time)

        case let .timestamp(timestamp):
            try appender2(bson_append_timestamp, timestamp.time, timestamp.oridinal)

        case let .binary(binary):
            try appender3(bson_append_binary, binary.subtype.cValue, binary.data.byteValue, UInt32(binary.data.byteValue.count))

        case let .regularExpression(regex):
            try appender2(bson_append_regex, regex.pattern, regex.options)

        case let .key(keyType):
            switch keyType {
            case .max:
                try appender0(bson_append_maxkey)
            case .min:
                try appender0(bson_append_minkey)
            }

        case let .code(code):
            switch code.scope {
            case .some(let scope):
                try appender2(bson_append_code_with_scope, code.code, AutoReleasingBSONContainer(document: scope).pointer)
            case .none:
                try appender1(bson_append_code, code.code)
            }

        case let .objectID(objectID):
            var value = objectID.internalValue
            try appender1(bson_append_oid, &value)

        case let .document(childDocument):

            let childContainer = AutoReleasingBSONContainer()

            try appender1(bson_append_document_begin, childContainer.pointer)

            let childAppender = BSONAppender(container: childContainer)
            try childDocument.forEach(childAppender.append)

            guard bson_append_document_end(container.pointer, childContainer.pointer) else {
                throw Error.overflow
            }

        case let .array(array):

            let childContainer = AutoReleasingBSONContainer()

            try appender1(bson_append_array_begin, childContainer.pointer)

            let childAppender = BSONAppender(container: childContainer)
            try array.enumerated().forEach { try childAppender.append(key: "\($0)", value: $1) }

            guard bson_append_array_end(container.pointer, childContainer.pointer) else {
                throw Error.overflow
            }
        }
    }
}

final class BSONIterator: IteratorProtocol, Sequence {
    let pointer: UnsafeMutablePointer<bson_iter_t>

    init() {
        self.pointer = UnsafeMutablePointer(allocatingCapacity: 1)
    }

    convenience init(documentPointer: UnsafeMutablePointer<bson_t>) {
        self.init()
        bson_iter_init(self.pointer, documentPointer)
    }

    init(pointer: UnsafeMutablePointer<bson_iter_t>) {
        self.pointer = pointer
    }


    deinit {
        self.pointer.deallocateCapacity(1)
    }

    func makeDocument() -> [String:BSON] {
        var document = [String:BSON]()
        for (key, value) in self {
            document[key] = value
        }
        return document
    }

    func next() -> (String, BSON)? {
        guard bson_iter_next(pointer) else {
            return nil
        }
        return nextPair()
    }

    private func nextPair() -> (String, BSON)? {

        let key = String(validatingUTF8: bson_iter_key_unsafe(pointer))!

        let type = bson_iter_type_unsafe(pointer)

        switch type {

        case BSON_TYPE_DOUBLE:
            let value = bson_iter_double_unsafe(pointer)
            return (key, value.bson)

        case BSON_TYPE_UTF8:
            let value = String(validatingUTF8: bson_iter_utf8_unsafe(pointer, nil))!
            return (key, value.bson)

        case BSON_TYPE_DOCUMENT:
            let childPointer = UnsafeMutablePointer<bson_iter_t>(nil)
            // TODO: error handling
            bson_iter_recurse(pointer, childPointer)

            let childIterator = BSONIterator(pointer: childPointer!)

            return (key, childIterator.makeDocument().bson)

        case BSON_TYPE_ARRAY:
            let childPointer = UnsafeMutablePointer<bson_iter_t>(nil)
            // TODO: error handling
            bson_iter_recurse(pointer, childPointer)

            let childIterator = BSONIterator(pointer: childPointer!)
            let childDocument = childIterator.makeDocument()

            return (key, childDocument.map { $1 }.bson)

        case BSON_TYPE_BINARY:

            let subtypePointer = UnsafeMutablePointer<bson_subtype_t>(allocatingCapacity: 1)
            defer { subtypePointer.deallocateCapacity(1) }

            let lengthPointer = UnsafeMutablePointer<UInt32>(allocatingCapacity: 1)
            defer { lengthPointer.deallocateCapacity(1) }

            let bufferPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>(allocatingCapacity: 1)
            defer { bufferPointer.deallocateCapacity(1) }

            bson_iter_binary(pointer, subtypePointer, lengthPointer, bufferPointer)

            var bytes = [UInt8](repeating: 0, count: Int(lengthPointer.pointee))

            memcpy(&bytes, bufferPointer.pointee, Int(lengthPointer.pointee))

            let binary = Binary(
                data: Data(byteValue: bytes),
                subtype: Binary.Subtype(cValue: subtypePointer.pointee)
            )

            return (key, binary.bson)

        // deprecated, no bindings
        case BSON_TYPE_DBPOINTER, BSON_TYPE_UNDEFINED, BSON_TYPE_SYMBOL:
            fatalError("Using deprecated BSON types")

        case BSON_TYPE_OID:
            // should not be freed
            // safe to unwrap
            let oidPointer = bson_iter_oid_unsafe(pointer)!
            let objectID = ObjectID(byteValue: oidPointer.pointee.bytes)
            return (key, objectID.bson)

        case BSON_TYPE_BOOL:
            let bool = bson_iter_bool_unsafe(pointer)
            return (key, bool.bson)

//        case BSON_TYPE_DATE_TIME:
//            let timePointer = UnsafeMutablePointer<timeval>(allocatingCapacity: 1)
//            defer { timePointer.deallocateCapacity(1) }
//
//            bson_iter_timeval(pointer, timePointer)
//
//            let date = Date(timeIntervalSince1970: timePointer.pointee.timeIntervalValue)
//
//            return (key, date.bson)

        case BSON_TYPE_NULL:
            return (key, .null)

        case BSON_TYPE_REGEX:
            let optionsBufferPointer = UnsafeMutablePointer<UnsafePointer<CChar>?>(allocatingCapacity:1)
            defer { optionsBufferPointer.deallocateCapacity(1) }

            // safe to unwrap
            let patternBuffer = bson_iter_regex(pointer, optionsBufferPointer)!

            // TODO: Make sure this is correct (maybe its an array of buffers?)
            // https://github.com/mongodb/libbson/blob/master/src/bson/bson-iter.c#L1113
            let optionsBuffer = optionsBufferPointer.pointee!

            let options = String(validatingUTF8: optionsBuffer)!
            let pattern = String(validatingUTF8: patternBuffer)!
            let regex = RegularExpression(pattern, options: options)

            return (key, regex.bson)

        case BSON_TYPE_CODE:
            let buffer = bson_iter_code_unsafe(pointer, nil)!
            let codeString = String(validatingUTF8: buffer)!
            let code = Code(codeString)

            return (key, code.bson)

        case BSON_TYPE_CODEWSCOPE:

            let scopeLengthPointer = UnsafeMutablePointer<UInt32>(allocatingCapacity: 1)
            defer { scopeLengthPointer.deallocateCapacity(1) }
            let scopeBuffer = UnsafeMutablePointer<UnsafePointer<UInt8>?>(allocatingCapacity:1)
            defer { scopeBuffer.deallocateCapacity(1) }

            let buffer = bson_iter_codewscope(pointer, nil, scopeLengthPointer, scopeBuffer)!
            let codeString = String(validatingUTF8: buffer)!

            let bsonPointer = bson_new()
            // TODO: Error handling
            bson_init_static(bsonPointer, scopeBuffer.pointee, Int(scopeLengthPointer.pointee))

            let scopeContainer = AutoReleasingBSONContainer(bson: bsonPointer!)
            let scopeDocument = scopeContainer.retrieveDocument()

            let code = Code(codeString, scope: scopeDocument)

            return (key, code.bson)

        case BSON_TYPE_INT32:
            let int = bson_iter_int32_unsafe(pointer)
            return (key, Int(int).bson)

        case BSON_TYPE_INT64:
            let int = bson_iter_int64_unsafe(pointer)
            return (key, Int(int).bson)

        case BSON_TYPE_TIMESTAMP:
            let timePointer = UnsafeMutablePointer<UInt32>(allocatingCapacity: 1)
            defer { timePointer.deallocateCapacity(1) }
            let incrementPointer = UnsafeMutablePointer<UInt32>(allocatingCapacity: 1)
            defer { incrementPointer.deallocateCapacity(1) }

            bson_iter_timestamp(pointer, timePointer, incrementPointer)

            let timestamp = Timestamp(time: timePointer.pointee, oridinal: incrementPointer.pointee)
            return (key, timestamp.bson)

        case BSON_TYPE_MAXKEY:
            return (key, .key(.max))

        case BSON_TYPE_MINKEY:
            return (key, .key(.min))

        default: fatalError("Case \(type) not implemented")
        }
    }
}

// Get underlying document
public extension BSONPointerContainer {
    /// Get underlying document
    func retrieveDocument() -> [String:BSON] {
        let iterator = BSONIterator(documentPointer: self.pointer)
        return iterator.makeDocument()
    }
}

//extension UnsafeMutablePointer {
//    /// Creates an unsafe pointer of a BSON document for use with the C API.
//    ///
//    /// Make sure to use ```bson_destroy``` clean up the allocated BSON document.
//    static func create(document: [String:BSON]) -> AutoReleasingCarrier? {
//
//    }
//
//    static func appendBSON(pointer: UnsafeMutablePointer<bson_t>, key: String, valueBSON) {
//
//    }
//}

///// Creates a ```[String:BSON]``` from an unsafe pointer.
/////
///// - Precondition: The ```bson_t``` must be valid.
//func documentFromUnsafePointer(pointer: UnsafePointer<bson_t>) -> [String:BSON]? {
//
//    var iterator = bson_iter_t()
//
//    guard bson_iter_init(&iterator, pointer) == true
//        else { return nil }
//
//    var document = [String:BSON]()
//
//    guard iterate(&document, iterator: &iterator) == true
//        else { return nil }
//
//    return document
//}

//
///// iterate and append values to document
//func iterate( document: inout [String:BSON], iterator: inout bson_iter_t) -> Bool {
//
//    while bson_iter_next(&iterator) {
//
//        // key char buffer should not be changed or freed
//        let keyBuffer = bson_iter_key_unsafe(&iterator)
//
//        let key = String(cString:keyBuffer)
//
//        let type = bson_iter_type_unsafe(&iterator)
//
//        var value: BSON?
//
//        switch type {
//
//        case BSON_TYPE_DOUBLE:
//
//            let double = bson_iter_double_unsafe(&iterator)
//
//            value = .Number(.Double(double))
//
//        case BSON_TYPE_UTF8:
//
//            var length = 0
//
//            let buffer = bson_iter_utf8_unsafe(&iterator, &length)
//
//            let string = String(cString:buffer)
//
//            value = .String(string)
//
//        case BSON_TYPE_DOCUMENT:
//
//            var childIterator = bson_iter_t()
//
//            var childDocument = [String:BSON]()
//
//            guard bson_iter_recurse(&iterator, &childIterator) &&
//                iterate(&childDocument, iterator: &childIterator)
//                else { return false }
//
//            value = .Document(childDocument)
//
//        case BSON_TYPE_ARRAY:
//
//            var childIterator = bson_iter_t()
//
//            var childDocument = [String:BSON]()
//
//            guard bson_iter_recurse(&iterator, &childIterator) &&
//                iterate(&childDocument, iterator: &childIterator)
//                else { return false }
//
//            let array = childDocument.map { (key, value) in return value }
//
//            value = .Array(array)
//
//        case BSON_TYPE_BINARY:
//
//            var subtype = bson_subtype_t(rawValue: 0)
//
//            var length: UInt32 = 0
//
//            let bufferPointer = UnsafeMutablePointer<UnsafePointer<UInt8>>(allocatingCapacity:1)
//
//            bson_iter_binary(&iterator, &subtype, &length, bufferPointer)
//
//            var bytes: [UInt8] = [UInt8](repeating: 0, count: Int(length))
//
//            memcpy(&bytes, bufferPointer.pointee, Int(length))
//
//            let data = Data(byteValue: bytes)
//
//            let binarySubtype: Binary.Subtype
//
//            switch subtype {
//
//            case BSON_SUBTYPE_BINARY: binarySubtype = .Generic
//            case BSON_SUBTYPE_FUNCTION: binarySubtype = .Function
//            case BSON_SUBTYPE_BINARY_DEPRECATED: binarySubtype = .Old
//            case BSON_SUBTYPE_UUID_DEPRECATED: binarySubtype = .UUIDOld
//            case BSON_SUBTYPE_UUID: binarySubtype = .UUID
//            case BSON_SUBTYPE_MD5: binarySubtype = .MD5
//            case BSON_SUBTYPE_USER: binarySubtype = .User
//
//            default: binarySubtype = .User
//            }
//
//            let binary = Binary(data: data, subtype: binarySubtype)
//
//            value = .Binary(binary)
//
//        // deprecated, no bindings
//        case BSON_TYPE_DBPOINTER, BSON_TYPE_UNDEFINED, BSON_TYPE_SYMBOL: value = nil
//
//        case BSON_TYPE_OID:
//
//            /// should not be freed
//            let oidPointer = bson_iter_oid_unsafe(&iterator)
//
//            let objectID = ObjectID(byteValue: oidPointer.pointee.bytes)
//
//            value = .ObjectID(objectID)
//
//        case BSON_TYPE_BOOL:
//
//            let boolean = bson_iter_bool_unsafe(&iterator)
//
//            value = .Number(.Boolean(boolean))
//
//        case BSON_TYPE_DATE_TIME:
//
//            var time = timeval()
//
//            bson_iter_timeval(&iterator, &time)
//
//            let date = Date(timeIntervalSince1970: time.timeIntervalValue)
//
//            value = .Date(date)
//
//        case BSON_TYPE_NULL:
//
//            value = .Null
//
//        case BSON_TYPE_REGEX:
//
//            let optionsBufferPointer = UnsafeMutablePointer<UnsafePointer<CChar>>(allocatingCapacity:1)
//
//            let patternBuffer = bson_iter_regex(&iterator, optionsBufferPointer)
//
//            let optionsBuffer = optionsBufferPointer.pointee
//
//            let options = String(cString:optionsBuffer)
//
//            let pattern = String(cString:patternBuffer)
//
//            let regex = RegularExpression(pattern, options: options)
//
//            value = .RegularExpression(regex)
//
//        case BSON_TYPE_CODE:
//
//            var length: UInt32 = 0
//
//            let buffer = bson_iter_code_unsafe(&iterator, &length)
//
//            let codeString = String(cString:buffer)
//
//            let code = Code(codeString)
//
//            value = .Code(code)
//
//        case BSON_TYPE_CODEWSCOPE:
//
//            var codeLength: UInt32 = 0
//
//            var scopeLength: UInt32 = 0
//
//            let scopeBuffer = UnsafeMutablePointer<UnsafePointer<UInt8>>(allocatingCapacity:1)
//
//            defer { scopeBuffer.deinitialize(); scopeBuffer.deallocateCapacity(1) }
//
//            let buffer = bson_iter_codewscope(&iterator, &codeLength, &scopeLength, scopeBuffer)
//
//            let codeString = String(cString:buffer)
//
//            var scopeBSON = bson_t()
//
//            guard bson_init_static(&scopeBSON, scopeBuffer.pointee, Int(scopeLength))
//                else { return false }
//
//            guard let scopeDocument = documentFromUnsafePointer(&scopeBSON)
//                else { fatalError("Could not ") }
//
//            let code = Code(codeString, scope: scopeDocument)
//
//            value = .Code(code)
//
//        case BSON_TYPE_INT32:
//
//            let integer = bson_iter_int32_unsafe(&iterator)
//
//            value = .Number(.Integer32(integer))
//
//        case BSON_TYPE_INT64:
//
//            let integer = bson_iter_int64_unsafe(&iterator)
//
//            value = .Number(.Integer64(integer))
//
//        case BSON_TYPE_TIMESTAMP:
//
//            var time: UInt32 = 0
//
//            var increment: UInt32 = 0
//
//            bson_iter_timestamp(&iterator, &time, &increment)
//
//            let timestamp = Timestamp(time: time, oridinal: increment)
//
//            value = .Timestamp(timestamp)
//
//        case BSON_TYPE_MAXKEY:
//
//            value = .MaxMinKey(.Maximum)
//
//        case BSON_TYPE_MINKEY:
//
//            value = .MaxMinKey(.Minimum)
//
//        default: fatalError("Case \(type) not implemented")
//        }
//
//        // add key / value pair
//        if let value = value {
//
//            document[key] = value
//        }
//    }
//
//    return true
//}
