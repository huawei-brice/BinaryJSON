//
//  Error.swift
//  BinaryJSON
//
//  Created by Alsey Coleman Miller on 12/20/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

#if os(OSX)
    import Darwin.C
#elseif os(Linux)
    import Glibc
#endif

import CBSON

public extension BSON {
    
    // BSON Error
    public struct BSONError: Error {
        
        /// The internal library domain of the error.
        let domain: UInt32
        
        /// The error code.
        let code: UInt32
        
        /// Human-readable error message. 
        let message: String
        
        /// Initializes error with the values from the unsafe pointer. 
        ///
        /// - Precondition: The unsafe pointer is not ```nil```.
        public init(unsafePointer: UnsafePointer<bson_error_t>) {
            
            //assert(unsafePointer != nil, "Trying to create Error from nil pointer")
            
            var messageTuple = unsafePointer.pointee.message
            
            let message = withUnsafePointer(&messageTuple) { (unsafeTuplePointer) -> String in
                
                let charPointer = unsafeBitCast(_: unsafeTuplePointer, to: UnsafePointer<CChar>.self)
                
                let string = String(cString:charPointer)
                
                return string
            }
            
            self.domain = unsafePointer.pointee.domain
            self.message = message
            self.code = unsafePointer.pointee.code
        }
    }
}
