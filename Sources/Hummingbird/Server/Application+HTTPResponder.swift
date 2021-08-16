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
import NIOHTTP1

extension HBApplication {
    // MARK: HTTPResponder

    /// HTTP responder class for Hummingbird. This is the interface between Hummingbird and HummingbirdCore
    ///
    /// The HummingbirdCore server calls `respond` to get the HTTP response from Hummingbird
    public struct HTTPResponder: HBHTTPResponder {
        let application: HBApplication
        let responder: HBResponder

        /// Construct HTTP responder
        /// - Parameter application: application creating this responder
        public init(application: HBApplication) {
            self.application = application
            // application responder has been set for sure
            self.responder = application.constructResponder()
        }

        /// Logger used by responder
        public var logger: Logger { return self.application.logger }

        /// Return EventLoopFuture that will be fulfilled with the HTTP response for the supplied HTTP request
        /// - Parameters:
        ///   - request: request
        ///   - context: context from ChannelHandler
        /// - Returns: response
        public func respond(to request: HBHTTPRequest, channel: Channel) async throws -> HBHTTPResponse {
            let request = HBRequest(
                head: request.head,
                body: request.body,
                application: self.application,
                context: ChannelRequestContext(channel: channel)
            )

            // respond to request
            let response = try await self.responder.respond(to: request)
            //response.headers.add(name: "Date", value: HBDateCache.getDateCache(on: channel.eventLoop).currentDate)
            let responseHead = HTTPResponseHead(version: request.version, status: response.status, headers: response.headers)
            return HBHTTPResponse(head: responseHead, body: response.body)
        }
    }

    /// Context object for Channel to be provided to HBRequest
    struct ChannelRequestContext: HBRequestContext {
        let channel: Channel
        var eventLoop: EventLoop { return self.channel.eventLoop }
        var allocator: ByteBufferAllocator { return self.channel.allocator }
        var remoteAddress: SocketAddress? { return self.channel.remoteAddress }
    }
}
