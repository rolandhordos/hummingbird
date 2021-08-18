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

import Hummingbird
import HummingbirdCoreXCT
import NIO
import NIOHTTP1
import NIOTransportServices
import XCTest

/// Test using a live server and AsyncHTTPClient
class HBXCTLive: HBXCT {
    init(configuration: HBApplication.Configuration) {
        #if os(iOS)
        self.eventLoopGroup = NIOTSEventLoopGroup()
        #else
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
    }

    /// Start tests
    func start(application: HBApplication) throws {
        let promise = application.eventLoopGroup.next().makePromise(of: Void.self)
        let client = HBXCTClient(host: "localhost", port: application.server.port!, eventLoopGroupProvider: .createNew)
        promise.completeWithTask {
            do {
                try application.start()
                try await self.client.connect()
            } catch {
                // if start fails then shutdown client
                try await self.client.shutdown()
                throw error
            }
        }
        self.client = client
        try promise.futureResult.wait()
    }

    /// Stop tests
    func stop(application: HBApplication) {
        let promise = application.eventLoopGroup.next().makePromise(of: Void.self)
        promise.completeWithTask {
            try await self.client.shutdown()
        }
        try? promise.futureResult.wait()
        application.stop()
        application.wait()
        try? self.eventLoopGroup.syncShutdownGracefully()
    }

    /// Send request and call test callback on the response returned
    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil
    ) async throws -> HBXCTResponse {
        var headers = headers
        headers.replaceOrAdd(name: "connection", value: "keep-alive")
        headers.replaceOrAdd(name: "host", value: "localhost")
        let request = HBXCTClient.Request(uri, method: method, headers: headers, body: body)
        guard let client = self.client else { throw HBXCTError.notStarted }
        let response = try await self.client.execute(request)
        return .init(status: response.status, headers: response.headers, body: response.body)
    }

    let eventLoopGroup: EventLoopGroup
    var client: HBXCTClient?
}
