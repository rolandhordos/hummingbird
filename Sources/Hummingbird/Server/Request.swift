//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

/// Holds all the values required to process a request
public final class HBRequest {
    // MARK: Member variables

    /// URI path
    public let uri: HBURL
    /// HTTP version
    public let version: HTTPVersion
    /// Request HTTP method
    public let method: HTTPMethod
    /// Request HTTP headers
    public let headers: HTTPHeaders
    /// Body of HTTP request
    public let body: HBRequestBody
    /// Logger to use
    public let logger: Logger
    /// reference to application
    public let application: HBApplication
    /// Request extensions
    public let extensions: HBExtensions<HBRequest>
    /// context used to access common members from channel
    public let context: HBRequestContext
    /// endpoint that services this request
    //internal var endpointPath: String?

    /// EventLoop request is running on
    public var eventLoop: EventLoop { self.context.eventLoop }
    /// ByteBuffer allocator used by request
    public var allocator: ByteBufferAllocator { self.context.allocator }
    /// IP request came from
    public var remoteAddress: SocketAddress? { self.context.remoteAddress }

    /// Parameters extracted during processing of request URI. These are available to you inside the route handler
    public var parameters: HBParameters {
        get {
            self.extensions.get(
                \.parameters,
                error: "Cannot access HBRequest.parameters on a route not extracting parameters from the URI."
            )
        }
    }

    // MARK: Initialization

    /// Create new HBRequest
    /// - Parameters:
    ///   - head: HTTP head
    ///   - body: HTTP body
    ///   - application: reference to application that created this request
    ///   - eventLoop: EventLoop request processing is running on
    ///   - allocator: Allocator used by channel request processing is running on
    public init(
        head: HTTPRequestHead,
        body: HBRequestBody,
        application: HBApplication,
        context: HBRequestContext
    ) {
        self.uri = .init(head.uri)
        self.version = head.version
        self.method = head.method
        self.headers = head.headers
        self.body = body
        self.logger = application.logger.with(metadataKey: "hb_id", value: .stringConvertible(Self.globalRequestID.add(1)))
        self.application = application
        self.extensions = HBExtensions()
        //self.endpointPath = nil
        self.context = context
    }

    /// Create new HBRequest
    /// - Parameters:
    ///   - uri: uri
    ///   - version: HTTP version
    ///   - method: HTTP method
    ///   - headers: HTTP header
    ///   - body: Request body
    ///   - logger: Logger request uses
    ///   - application: Application
    ///   - extensions: Request extensions
    ///   - context: Request context
    public init(
        uri: HBURL,
        version: HTTPVersion,
        method: HTTPMethod,
        headers: HTTPHeaders,
        body: HBRequestBody,
        logger: Logger,
        application: HBApplication,
        extensions: HBExtensions<HBRequest>,
        context: HBRequestContext
    ) {
        self.uri = uri
        self.version = version
        self.method = method
        self.headers = headers
        self.body = body
        self.logger = logger
        self.application = application
        self.extensions = extensions
        //self.endpointPath = nil
        self.context = context
    }

    // MARK: Methods

    public func with(body: HBRequestBody) -> Self {
        return .init(
            uri: self.uri,
            version: self.version,
            method: self.method,
            headers: self.headers,
            body: body,
            logger: self.logger,
            application: self.application,
            extensions: self.extensions,
            context: self.context
        )
    }

    public func with<Type>(extension: KeyPath<HBRequest, Type>, value: Type) -> Self {
        var extensions = self.extensions
        extensions.set(`extension`, value: value)
        return .init(
            uri: self.uri,
            version: self.version,
            method: self.method,
            headers: self.headers,
            body: body,
            logger: self.logger,
            application: self.application,
            extensions: extensions,
            context: self.context
        )
    }

    /// Decode request using decoder stored at `HBApplication.decoder`.
    /// - Parameter type: Type you want to decode to
    public func decode<Type: Decodable>(as type: Type.Type) throws -> Type {
        do {
            return try self.application.decoder.decode(type, from: self)
        } catch {
            self.logger.debug("Decode Error: \(error)")
            throw HBHTTPError(.badRequest)
        }
    }

    /// Return failed `EventLoopFuture`
    public func failure<T>(_ error: Error) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(error)
    }

    /// Return failed `EventLoopFuture` with http response status code
    public func failure<T>(_ status: HTTPResponseStatus) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status))
    }

    /// Return failed `EventLoopFuture` with http response status code and message
    public func failure<T>(_ status: HTTPResponseStatus, message: String) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status, message: message))
    }

    /// Return succeeded `EventLoopFuture`
    public func success<T>(_ value: T) -> EventLoopFuture<T> {
        return self.eventLoop.makeSucceededFuture(value)
    }

    private static let globalRequestID = NIOAtomic<Int>.makeAtomic(value: 0)
}

extension Logger {
    /// Create new Logger with additional metadata value
    /// - Parameters:
    ///   - metadataKey: Metadata key
    ///   - value: Metadata value
    /// - Returns: Logger
    func with(metadataKey: String, value: MetadataValue) -> Logger {
        var logger = self
        logger[metadataKey: metadataKey] = value
        return logger
    }
}
