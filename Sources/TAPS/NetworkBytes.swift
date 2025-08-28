//
//  NetworkBytes.swift
//  TAPS
import BinaryParsing

#if canImport(NIOCore)
import NIOCore
#endif
#if canImport(Foundation)
import Foundation
#endif

/// Network bytes exposed as a span over underlying storage
/// 
/// This type provides zero-copy access to network data through BinaryParsing's ParserSpan.
/// It has no public properties except methods to access the underlying bytes safely.
public struct NetworkBytes: Sendable {
    private let backing: BackingData
    
    private enum BackingData: Sendable {
        #if canImport(NIOCore)
        case buffer(ByteBuffer)
        #endif
        #if canImport(Foundation)
        case data(Data)
        #endif
        case array([UInt8])
    }
    
    #if canImport(NIOCore)
    /// Internal initializer from NIO ByteBuffer
    internal init(buffer: ByteBuffer) {
        self.backing = .buffer(buffer)
    }
    #endif
    
    #if canImport(Foundation)
    /// Internal initializer from Foundation Data
    internal init(data: Data) {
        self.backing = .data(data)
    }
    #endif
    
    /// Internal initializer from byte array
    internal init(bytes: [UInt8]) {
        self.backing = .array(bytes)
    }
    
    /// Access the underlying bytes safely through a span
    public func withBytes<T>(_ body: (borrowing Span<UInt8>) throws -> T) rethrows -> T {
        switch backing {
        #if canImport(NIOCore)
        case .buffer(let buffer):
            
            return try buffer.readableBytesView.withContiguousStorageIfAvailable { ptr -> T in
                try body(Span(_unsafeElements: UnsafeBufferPointer(start: ptr.baseAddress, count: ptr.count)))
            } ?? {
                let copy = [UInt8](buffer.readableBytesView) // fallback-copy
                return try copy.withUnsafeBufferPointer { p in
                    try body(Span(_unsafeElements: p))
                }
            }()
        #endif
        #if canImport(Foundation)
        case .data(let data):
            return try data.withUnsafeBytes { raw in
                let p = raw.bindMemory(to: UInt8.self)
                return try body(Span(_unsafeElements: p))
            }
        #endif
        case .array(let array):
            return try array.withUnsafeBufferPointer { p in
                try body(Span(_unsafeElements: p))
            }
        }
    }
    
    /// Parse the bytes using BinaryParsing
    /// 
    /// Usage example (inspired by swift-binary-parsing):
    /// ```
    /// let result = try networkBytes.parse { parser in
    ///     let magic = try UInt32(parsingBigEndian: &parser)
    ///     let length = try Int(parsing: &parser, storedAsBigEndian: UInt32.self)
    ///     return (magic, length)
    /// }
    /// ```
    public func parse<T>(_ body: (inout ParserSpan) throws -> T) throws -> T {
        return try withBytes { span in
            var parser = ParserSpan(RawSpan(_elements: span))
            return try body(&parser)
        }
    }
    
    // MARK: - Convenience parsing methods
    /// Parse a big-endian UInt32 from the start of the data
    public func parseUInt32BigEndian() throws -> UInt32 {
        return try parse { parser in
            try UInt32(parsingBigEndian: &parser)
        }
    }
    
    /// Parse a big-endian UInt16 from the start of the data  
    public func parseUInt16BigEndian() throws -> UInt16 {
        return try parse { parser in
            try UInt16(parsingBigEndian: &parser)
        }
    }
    
    /// Parse bytes as UTF-8 string (делает копию для безопасности)
    public func parseUTF8String() throws -> String {
        return try withBytes { span in
            // Явное декодирование → копия, никаких висячих ссылок.
            try span.withUnsafeBufferPointer { p in
                guard let s = String(bytes: p, encoding: .utf8) else {
                    throw NetworkBytesError.invalidUTF8
                }
                return s
            }
        }
    }
}

// MARK: - NetworkBytes specific errors

public enum NetworkBytesError: Error, Sendable {
    case invalidUTF8
    case insufficientData
    case invalidFormat
}
