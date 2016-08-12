//
//  UnsafePointer.swift
//  BSON
//
//  Created by Alsey Coleman Miller on 12/13/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import CBSON

public extension BSON {

    /// Carries an UnsafeMutablePointer<bson_t> and calls `bson_destroy` on it upon deinitialization.
    public final class AutoReleasingCarrier {
        public let pointer: UnsafeMutablePointer<bson_t>

        public init(bson: UnsafeMutablePointer<bson_t>) {
            self.pointer = bson
        }

        public convenience init?(document: BSON.Document) {
            guard let bson = BSON.unsafePointerFromDocument(document) else {
                return nil
            }

            self.init(bson: bson)
        }

        deinit {
            bson_destroy(self.pointer)
        }
    }
}

public extension BSON {
    
    /// Creates an unsafe pointer of a BSON document for use with the C API.
    ///
    /// Make sure to use ```bson_destroy``` clean up the allocated BSON document.
    static func unsafePointerFromDocument(_ document: BSON.Document) -> UnsafeMutablePointer<bson_t>? {
        
        let documentPointer = bson_new()
        
        for (key, value) in document {
            
            guard appendValue(documentPointer!, key: key, value: value) == true
                else { return nil }
        }
        
        return documentPointer
    }
    
    /// Creates a ```BSON.Document``` from an unsafe pointer. 
    ///
    /// - Precondition: The ```bson_t``` must be valid.
    static func documentFromUnsafePointer(_ documentPointer: UnsafePointer<bson_t>) -> BSON.Document? {
        
        var iterator = bson_iter_t()
        
        guard bson_iter_init(&iterator, documentPointer) == true
            else { return nil }
        
        var document = BSON.Document()
        
        guard iterate(&document, iterator: iterator) == true
            else { return nil }
        
        return document
    }
}

private extension BSON {
    
    /// Appends a  ```BSON.Value``` to a document pointer. Returns false for if an error ocurred (over max limit).
    static func appendValue(_ documentPointer: UnsafeMutablePointer<bson_t>, key: String, value: BSON.Value) -> Bool {
        
        let keyLength = Int32(key.utf8.count)
        
        switch value {
            
        case .null:
            
            return bson_append_null(documentPointer, key, keyLength)
            
        case let .string(string):
            
            let stringLength = Int32(string.utf8.count)
            
            return bson_append_utf8(documentPointer, key, keyLength, string, stringLength)
            
        case let .number(number):
            
            switch number {
            case let .boolean(value): return bson_append_bool(documentPointer, key, keyLength, value)
            case let .integer32(value): return bson_append_int32(documentPointer, key, keyLength, value)
            case let .integer64(value): return bson_append_int64(documentPointer, key, keyLength, value)
            case let .double(value): return bson_append_double(documentPointer, key, keyLength, value)
            }
            
        case let .date(date):
            
            var time = timeval(timeInterval: date.timeIntervalSince1970)
            
            return bson_append_timeval(documentPointer, key, keyLength, &time)
            
        case let .timestamp(timestamp):
            
            return bson_append_timestamp(documentPointer, key, keyLength, timestamp.time, timestamp.oridinal)
            
        case let .binary(binary):
            
            let subtype: bson_subtype_t
            
            switch binary.subtype {
                
            case .generic: subtype = BSON_SUBTYPE_BINARY
                
            case .function: subtype = BSON_SUBTYPE_FUNCTION
                
            case .old: subtype = BSON_SUBTYPE_BINARY_DEPRECATED
                
            case .uuidOld: subtype = BSON_SUBTYPE_UUID_DEPRECATED
                
            case .uuid: subtype = BSON_SUBTYPE_UUID
                
            case .md5: subtype = BSON_SUBTYPE_MD5
                
            case .user: subtype = BSON_SUBTYPE_USER
            }
            
            return bson_append_binary(documentPointer, key, keyLength, subtype, binary.data.byteValue, UInt32(binary.data.byteValue.count))
            
        case let .regularExpression(regularExpression):
            
            return bson_append_regex(documentPointer, key, keyLength, regularExpression.pattern, regularExpression.options)
            
        case let .maxMinKey(keyType):
            
            switch keyType {
                
            case .maximum:
                
                return bson_append_maxkey(documentPointer, key, keyLength)
                
            case .minimum:
                
                return bson_append_minkey(documentPointer, key, keyLength)
            }
            
        case let .code(code):
            
            if let scope = code.scope {
                
                guard let scopePointer = BSON.unsafePointerFromDocument(scope)
                    else { return false }
                
                return bson_append_code_with_scope(documentPointer, key, keyLength, code.code, scopePointer)
            }
            else {
                
                return bson_append_code(documentPointer, key, keyLength, code.code)
            }
            
        case let .objectID(objectID):
            
            var oid = bson_oid_t(bytes: objectID.byteValue)
            
            return bson_append_oid(documentPointer, key, keyLength, &oid)
            
        case let .document(childDocument):
            
            let childDocumentPointer = bson_new()
            
            defer { bson_destroy(childDocumentPointer) }
            
            guard bson_append_document_begin(documentPointer, key, keyLength, childDocumentPointer)
                else { return false }
        
            for (childKey, childValue) in childDocument {
                
                guard appendValue(childDocumentPointer!, key: childKey, value: childValue)
                    else { return false }
            }
            
            return bson_append_document_end(documentPointer, childDocumentPointer)
            
        case let .array(array):
            
            let childPointer = bson_new()
            
            defer { bson_destroy(childPointer) }
            
            guard bson_append_array_begin(documentPointer, key, keyLength, childPointer)
                else { return false }
            
            for (index, subvalue) in array.enumerated() {
                
                let indexKey = "\(index)"
                
                guard appendValue(childPointer!, key: indexKey, value: subvalue)
                    else { return false }
            }
            
            return bson_append_array_end(documentPointer, childPointer)
        }
    }
    
    /// iterate and append values to document
    static func iterate( _ document: inout BSON.Document, iterator: bson_iter_t) -> Bool {
        
        var iterator = iterator
        while bson_iter_next(&iterator) {
            
            // key char buffer should not be changed or freed
            let keyBuffer = bson_iter_key_unsafe(&iterator)
            
            let key = String(cString:keyBuffer!)

            let type = bson_iter_type_unsafe(&iterator)
            
            var value: BSON.Value?
            
            switch type {
                
            case BSON_TYPE_DOUBLE:
                
                let double = bson_iter_double_unsafe(&iterator)
                
                value = .number(.double(double))
                
            case BSON_TYPE_UTF8:
                
                var length = 0
                
                let buffer = bson_iter_utf8_unsafe(&iterator, &length)
                
                let string = String(cString:buffer!)

                value = .string(string)
                
            case BSON_TYPE_DOCUMENT:
                
                var childIterator = bson_iter_t()
                
                var childDocument = BSON.Document()
                
                guard bson_iter_recurse(&iterator, &childIterator) &&
                    iterate(&childDocument, iterator: childIterator)
                    else { return false }
                
                value = .document(childDocument)
                
            case BSON_TYPE_ARRAY:
                
                var childIterator = bson_iter_t()
                
                var childDocument = BSON.Document()
                
                guard bson_iter_recurse(&iterator, &childIterator) &&
                    iterate(&childDocument, iterator: childIterator)
                    else { return false }
                
                let array = childDocument.map { (key, value) in return value }
                
                value = .array(array)
                
            case BSON_TYPE_BINARY:
                
                var subtype = bson_subtype_t(rawValue: 0)
                
                var length: UInt32 = 0
                
                let bufferPointer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)

                bson_iter_binary(&iterator, &subtype, &length, bufferPointer)
                
                var bytes: [UInt8] = [UInt8](repeating: 0, count: Int(length))
                
                memcpy(&bytes, bufferPointer.pointee, Int(length))
                
                let data = Data(byteValue: bytes)
                
                let binarySubtype: Binary.Subtype
                
                switch subtype {
                    
                case BSON_SUBTYPE_BINARY: binarySubtype = .generic
                case BSON_SUBTYPE_FUNCTION: binarySubtype = .function
                case BSON_SUBTYPE_BINARY_DEPRECATED: binarySubtype = .old
                case BSON_SUBTYPE_UUID_DEPRECATED: binarySubtype = .uuidOld
                case BSON_SUBTYPE_UUID: binarySubtype = .uuid
                case BSON_SUBTYPE_MD5: binarySubtype = .md5
                case BSON_SUBTYPE_USER: binarySubtype = .user
                    
                default: binarySubtype = .user
                }
                
                let binary = Binary(data: data, subtype: binarySubtype)
                
                value = .binary(binary)
                
            // deprecated, no bindings
            case BSON_TYPE_DBPOINTER, BSON_TYPE_UNDEFINED, BSON_TYPE_SYMBOL: value = nil
                
            case BSON_TYPE_OID:
                
                /// should not be freed
                let oidPointer = bson_iter_oid_unsafe(&iterator)
                
                let objectID = ObjectID(byteValue: oidPointer!.pointee.bytes)
                
                value = .objectID(objectID)
                
            case BSON_TYPE_BOOL:
                
                let boolean = bson_iter_bool_unsafe(&iterator)
                
                value = .number(.boolean(boolean))
                
            case BSON_TYPE_DATE_TIME:
                
                var time = timeval()
                
                bson_iter_timeval(&iterator, &time)
                
                let date = Date(timeIntervalSince1970: time.timeIntervalValue)
                
                value = .date(date)
                
            case BSON_TYPE_NULL:
                
                value = .null
                
            case BSON_TYPE_REGEX:
                
                let optionsBufferPointer = UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(capacity: 1)

                let patternBuffer = bson_iter_regex(&iterator, optionsBufferPointer)
                
                let optionsBuffer = optionsBufferPointer.pointee
                
                let options = String(cString:optionsBuffer!)
                
                let pattern = String(cString:patternBuffer!)
                
                let regex = RegularExpression(pattern, options: options)
                
                value = .regularExpression(regex)
                
            case BSON_TYPE_CODE:
                
                var length: UInt32 = 0
                
                let buffer = bson_iter_code_unsafe(&iterator, &length)
                
                let codeString = String(cString:buffer!)
                
                let code = Code(codeString)
                
                value = .code(code)
                
            case BSON_TYPE_CODEWSCOPE:
                
                var codeLength: UInt32 = 0
                
                var scopeLength: UInt32 = 0
                
                let scopeBuffer = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                
                defer { scopeBuffer.deinitialize(); scopeBuffer.deallocate(capacity: 1) }
                
                let buffer = bson_iter_codewscope(&iterator, &codeLength, &scopeLength, scopeBuffer)
                
                let codeString = String(cString:buffer!)
                
                var scopeBSON = bson_t()
                
                guard bson_init_static(&scopeBSON, scopeBuffer.pointee, Int(scopeLength))
                    else { return false }
                
                guard let scopeDocument = documentFromUnsafePointer(&scopeBSON)
                    else { fatalError("Could not ") }
                
                let code = Code(codeString, scope: scopeDocument)
                
                value = .code(code)
                
            case BSON_TYPE_INT32:
                
                let integer = bson_iter_int32_unsafe(&iterator)
                
                value = .number(.integer32(integer))
                
            case BSON_TYPE_INT64:
                
                let integer = bson_iter_int64_unsafe(&iterator)
                
                value = .number(.integer64(integer))
                
            case BSON_TYPE_TIMESTAMP:
                
                var time: UInt32 = 0
                
                var increment: UInt32 = 0
                
                bson_iter_timestamp(&iterator, &time, &increment)
                
                let timestamp = Timestamp(time: time, oridinal: increment)
                
                value = .timestamp(timestamp)
                
            case BSON_TYPE_MAXKEY:
                
                value = .maxMinKey(.maximum)
                
            case BSON_TYPE_MINKEY:
                
                value = .maxMinKey(.minimum)
                
            default: fatalError("Case \(type) not implemented")
            }
            
            // add key / value pair
            if let value = value {
                
                document[key] = value
            }
        }
        
        return true
    }
}




