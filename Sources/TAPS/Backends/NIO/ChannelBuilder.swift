//
//  ChannelBuilder.swift
//  TAPS
//
//  Created by Joannis Orlandos on 09/09/2025.
//

internal import NIO

@resultBuilder internal struct ProtocolStackBuilder<InboundOut, OutboundOut> {
    @_disfavoredOverload
    internal static func buildPartialBlock<PartialInboundOut, PartialOutboundIn>(
        first subprotocol: ConnectionSubprotocol<InboundOut, PartialInboundOut, PartialOutboundIn, OutboundOut>
    ) -> ProtocolStack<InboundOut, PartialInboundOut, PartialOutboundIn, OutboundOut> {
        ProtocolStack<_, _, _, _>(unverified: subprotocol.handlers)
    }
    
    internal static func buildPartialBlock<Handler: ChannelDuplexHandler>(
        first handler: Handler
    ) -> ProtocolStack<InboundOut, Handler.InboundOut, Handler.OutboundIn, OutboundOut> {
        ProtocolStack<_, _, _, _> {
            [handler]
        }
    }
    
    @_disfavoredOverload
    internal static func buildPartialBlock<Handler: ChannelInboundHandler>(
        first handler: Handler
    ) -> ProtocolStack<InboundOut, Handler.InboundOut, OutboundOut, OutboundOut> where InboundOut == Handler.InboundIn {
        ProtocolStack<_, _, _, _> {
            [handler]
        }
    }
    
    @_disfavoredOverload
    internal static func buildPartialBlock<Handler: ChannelOutboundHandler>(
        first handler: Handler
    ) -> ProtocolStack<InboundOut, InboundOut, Handler.OutboundIn, OutboundOut> where OutboundOut == Handler.OutboundOut {
        ProtocolStack<_, _, _, _> {
            [handler]
        }
    }
    
    internal static func buildPartialBlock<
        Handler: ChannelDuplexHandler
    >(
        accumulated base: ProtocolStack<InboundOut, Handler.InboundIn, Handler.OutboundOut, OutboundOut>,
        next handler: Handler
    ) -> ProtocolStack<InboundOut, Handler.InboundOut, Handler.OutboundIn, OutboundOut>
    {
        ProtocolStack<_, _, _, _> {
            base.handlers() + [handler]
        }
    }
    
    @_disfavoredOverload
    internal static func buildPartialBlock<
        PartialIn, PartialOut,
        Handler: ChannelInboundHandler
    >(
        accumulated base: ProtocolStack<InboundOut, PartialIn, PartialOut, OutboundOut>,
        next handler: Handler
    ) -> ProtocolStack<InboundOut, Handler.InboundOut, PartialOut, OutboundOut> where PartialIn == Handler.InboundIn
    {
        ProtocolStack<_, _, _, _> {
            base.handlers() + [handler]
        }
    }
    
    @_disfavoredOverload
    internal static func buildPartialBlock<
        PartialIn, PartialOut,
        Handler: ChannelOutboundHandler
    >(
        accumulated base: ProtocolStack<InboundOut, PartialIn, PartialOut, OutboundOut>,
        next handler: Handler
    ) -> ProtocolStack<InboundOut, PartialIn, Handler.OutboundIn, OutboundOut> where PartialOut == Handler.OutboundOut
    {
        ProtocolStack<_, _, _, _> {
            base.handlers() + [handler]
        }
    }
    
    @_disfavoredOverload
    internal static func buildPartialBlock<PartialOut, Decoder: ByteToMessageDecoder>(
        accumulated base: ProtocolStack<InboundOut, ByteBuffer, PartialOut, OutboundOut>,
        next decoder: Decoder
    ) -> ProtocolStack<InboundOut, Decoder.InboundOut, PartialOut, OutboundOut> {
        ProtocolStack<_, _, _, _> {
            base.handlers() + [ByteToMessageHandler(decoder)]
        }
    }
    
    @_disfavoredOverload
    internal static func buildPartialBlock<PartialIn, Encoder: MessageToByteEncoder>(
        accumulated base: ProtocolStack<InboundOut, PartialIn, ByteBuffer, OutboundOut>,
        next encoder: Encoder
    ) -> ProtocolStack<InboundOut, PartialIn, Encoder.OutboundIn, OutboundOut> {
        ProtocolStack<_, _, _, _> {
            base.handlers() + [MessageToByteHandler(encoder)]
        }
    }
    
    internal static func buildFinalResult<Input, Output>(
        _ component: ProtocolStack<InboundOut, Output, Input, OutboundOut>
    ) -> ProtocolStack<InboundOut, Output, Input, OutboundOut> {
        component
    }
}

internal final class IODataOutboundEncoder: ChannelOutboundHandler {
    internal typealias OutboundIn = ByteBuffer
    internal typealias OutboundOut = IOData
    
    internal init() {}
    
    internal func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: nil)
    }
}

internal final class IODataOutboundDecoder: ChannelOutboundHandler {
    internal typealias OutboundIn = IOData
    internal typealias OutboundOut = ByteBuffer
    
    internal init() {}
    
    internal func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: nil)
    }
}

internal final class IODataInboundEncoder: ChannelInboundHandler {
    internal typealias InboundIn = ByteBuffer
    internal typealias InboundOut = IOData
    
    internal init() {}
    
    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }
}

internal final class IODataInboundDecoder: ChannelInboundHandler {
    internal typealias InboundIn = IOData
    internal typealias InboundOut = ByteBuffer
    
    internal init() {}
    
    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }
}

internal final class IODataDuplexHandler: ChannelDuplexHandler {
    internal typealias InboundIn = IOData
    internal typealias InboundOut = ByteBuffer
    internal typealias OutboundIn = ByteBuffer
    internal typealias OutboundOut = IOData
    
    internal init() {}
    
    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }
    
    internal func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: nil)
    }
}


internal final class NetworkBytesDuplexHandler: ChannelDuplexHandler {
    internal typealias InboundIn = _NetworkBytes
    internal typealias InboundOut = NetworkInputBytes
    internal typealias OutboundIn = NetworkOutputBytes
    internal typealias OutboundOut = _NetworkBytes
    
    internal init() {}
    
    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        let networkBytes = NetworkInputBytes(buffer: buffer)
        context.fireChannelRead(wrapInboundOut(networkBytes))
    }
    
    internal func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let networkBytes = unwrapOutboundIn(data)
        context.write(wrapOutboundOut(networkBytes.buffer), promise: nil)
    }
}
