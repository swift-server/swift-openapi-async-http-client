//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftOpenAPIGenerator open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftOpenAPIGenerator project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftOpenAPIGenerator project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import XCTest
import OpenAPIRuntime
import NIOCore
import NIOPosix
import AsyncHTTPClient
@testable import OpenAPIAsyncHTTPClient

class Test_AsyncHTTPClientTransport: XCTestCase {

    static var testData: Data {
        get throws {
            try XCTUnwrap(#"[{}]"#.data(using: .utf8))
        }
    }

    static var testBuffer: ByteBuffer {
        ByteBuffer(string: #"[{}]"#)
    }

    static var testUrl: URL {
        get throws {
            try XCTUnwrap(URL(string: "http://example.com/api/v1/hello/Maria?greeting=Howdy"))
        }
    }

    func testConvertRequest() throws {
        let request: OpenAPIRuntime.Request = .init(
            path: "/hello%20world/Maria",
            query: "greeting=Howdy",
            method: .post,
            headerFields: [
                .init(name: "content-type", value: "application/json")
            ],
            body: try Self.testData
        )
        let httpRequest = try AsyncHTTPClientTransport.convertRequest(
            request,
            baseURL: try XCTUnwrap(URL(string: "http://example.com/api/v1"))
        )
        XCTAssertEqual(httpRequest.url, "http://example.com/api/v1/hello%20world/Maria?greeting=Howdy")
        XCTAssertEqual(httpRequest.method, .POST)
        XCTAssertEqual(
            httpRequest.headers,
            [
                "content-type": "application/json"
            ]
        )
        // TODO: Not sure how to test that httpRequest.body is what we expect, can't
        // find an API for reading it back.
    }

    func testConvertResponse() async throws {
        let httpResponse = HTTPClientResponse(
            status: .ok,
            headers: [
                "content-type": "application/json"
            ],
            body: .bytes(Self.testBuffer)
        )
        let response = try await AsyncHTTPClientTransport.convertResponse(httpResponse)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(
            response.headerFields,
            [
                .init(name: "content-type", value: "application/json")
            ]
        )
        XCTAssertEqual(response.body, try Self.testData)
    }

    func testSend() async throws {
        let transport = AsyncHTTPClientTransport(
            configuration: .init(),
            requestSender: TestSender.test
        )
        let request: OpenAPIRuntime.Request = .init(
            path: "/api/v1/hello/Maria",
            method: .get,
            headerFields: [
                .init(name: "x-request", value: "yes")
            ]
        )
        let response = try await transport.send(
            request,
            baseURL: Self.testUrl,
            operationID: "sayHello"
        )
        XCTAssertEqual(response.statusCode, 200)
    }
}

struct TestSender: HTTPRequestSending {
    var sendClosure:
        @Sendable (AsyncHTTPClientTransport.Request, HTTPClient, TimeAmount) async throws -> AsyncHTTPClientTransport
            .Response
    func send(
        request: AsyncHTTPClientTransport.Request,
        with client: HTTPClient,
        timeout: TimeAmount
    ) async throws -> AsyncHTTPClientTransport.Response {
        try await sendClosure(request, client, timeout)
    }

    static var test: Self {
        TestSender { request, _, _ in
            XCTAssertEqual(request.headers.first(name: "x-request"), "yes")
            return HTTPClientResponse(
                status: .ok,
                headers: [
                    "content-type": "application/json"
                ],
                body: .bytes(Test_AsyncHTTPClientTransport.testBuffer)
            )
        }
    }
}
