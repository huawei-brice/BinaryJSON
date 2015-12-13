//
//  UnsafePointer.swift
//  BSON
//
//  Created by Alsey Coleman Miller on 12/13/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

#if os(OSX)
    import bson
#elseif os(Linux)
    import CBSON
#endif

public extension BSON {
    
    /// Unsafe pointer of a BSON document for use with the C library.
    ///
    /// Make sure to use
    typealias UnsafePointer = UnsafeMutablePointer<bson_t>
}