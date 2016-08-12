//
//  Context.swift
//  BinaryJSON
//
//  Created by Alsey Coleman Miller on 12/14/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import CBSON

public extension BSON {
    
    public final class Context {
        
        /// The default, thread-safe BSON context.
        public static let defualt = Context(options: [.threadSafe, .disablePIDCache])
        
        // MARK: - Properties
        
        public let options: [Option]
        
        // MARK: - Internal Properties
        
        internal let internalPointer: OpaquePointer
        
        // MARK: - Initialization
        
        deinit { bson_context_destroy(internalPointer) }
        
        /// Initializes the context with the specified options.
        public init(options: [Option] = []) {
            
            let flags = options.optionsBitmask()
            
            self.options = options
            self.internalPointer = bson_context_new(bson_context_flags_t(rawValue: flags))
        }
    }
}

// MARK: - Supporting Types

public extension BSON.Context {
    
    public enum Option: UInt32, BitMaskOption {
        
        /// Context will be called from multiple threads.
        case threadSafe
        
        /// Call ```getpid()``` instead of caching the result of ```getpid()``` when initializing the context.
        case disablePIDCache
        
        /// Call ```gethostname()``` instead of caching the result of ```gethostname()``` when initializing the context.
        case disableHostCache
        
        //#if os(Linux)
        //case UseTaskID
        //#endif
        
        public init?(rawValue: UInt32) {
            
            switch rawValue {
            case BSON_CONTEXT_THREAD_SAFE.rawValue: self = .threadSafe
            case BSON_CONTEXT_DISABLE_PID_CACHE.rawValue: self = .disablePIDCache
            case BSON_CONTEXT_DISABLE_HOST_CACHE.rawValue: self = .disableHostCache
            //#if os(Linux)
            //case BSON_CONTEXT_USE_TASK_ID.rawValue: self = .UseTaskID
            //#endif
            default: return nil
            }
        }
        
        public var rawValue: UInt32 {
            
            switch self {
            case .threadSafe: return BSON_CONTEXT_THREAD_SAFE.rawValue
            case .disablePIDCache: return BSON_CONTEXT_DISABLE_PID_CACHE.rawValue
            case .disableHostCache: return BSON_CONTEXT_DISABLE_HOST_CACHE.rawValue
            
            //#if os(Linux)
            //case .UseTaskID: return BSON_CONTEXT_USE_TASK_ID.rawValue
            //#endif
            }
        }
    }
}



/// Bit mask that represents various options
public protocol BitMaskOption: RawRepresentable {
    
    static func optionsBitmask(_ options: [Self]) -> Self.RawValue
}

public extension BitMaskOption where Self.RawValue: Integer {
    
    static func optionsBitmask<S: Sequence where S.Iterator.Element == Self>(_ options: S) -> Self.RawValue {
        return options.reduce(0) { mask, option in
            mask | option.rawValue
        }
    }
}

public extension Sequence where Self.Iterator.Element: BitMaskOption, Self.Iterator.Element.RawValue: Integer {
    
    func optionsBitmask() -> Self.Iterator.Element.RawValue {
        
        let array = self.filter { (_) -> Bool in return true }
        
        return Self.Iterator.Element.optionsBitmask(array)
    }
}
