import NIOCore

/// Extension for String conversion from ByteBuffer
extension String {
    public init(buffer: ByteBuffer) {
        var buffer = buffer
        self = buffer.readString(length: buffer.readableBytes) ?? ""
    }
}

