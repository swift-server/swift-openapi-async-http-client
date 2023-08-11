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
import OpenAPIRuntime
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import NIOFoundationCompat
#if canImport(Darwin)
import Foundation
#else
@preconcurrency import struct Foundation.URL
import struct Foundation.URLComponents
import struct Foundation.Data
import protocol Foundation.LocalizedError
#endif

/// A client transport that performs HTTP operations using the HTTPClient type
/// provided by the AsyncHTTPClient library.
///
/// ### Use the AsyncHTTPClient transport
///
/// Create the underlying HTTP client:
///
///     let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
///
/// Either store a reference to the client elsewhere and shut it down during
/// cleanup, or add a defer block if the client is only used in the current
/// scope:
///
///     defer {
///         try! httpClient.syncShutdown()
///     }
///
/// Instantiate the transport and provide the HTTP client to it:
///
///     let transport = AsyncHTTPClientTransport(
///         configuration: .init(client: httpClient)
///     )
///
/// Create the base URL of the server to call using your client. If the server
/// URL was defined in the OpenAPI document, you find a generated method for it
/// on the `Servers` type, for example:
///
///     let serverURL = try Servers.server1()
///
/// Instantiate the `Client` type generated by the Swift OpenAPI Generator for
/// your provided OpenAPI document. For example:
///
///     let client = Client(
///         serverURL: serverURL,
///         transport: transport
///     )
///
/// Use the client to make HTTP calls defined in your OpenAPI document. For
/// example, if the OpenAPI document contains an HTTP operation with
/// the identifier `checkHealth`, call it from Swift with:
///
///     let response = try await client.checkHealth(.init())
///     // ...
public struct AsyncHTTPClientTransport: ClientTransport {

    /// A set of configuration values for the AsyncHTTPClient transport.
    public struct Configuration: Sendable {

        /// The HTTP client used for performing HTTP calls.
        public var client: HTTPClient

        /// The default request timeout.
        public var timeout: TimeAmount

        /// Creates a new configuration with the specified client and timeout.
        /// - Parameters:
        ///   - client: The underlying client used to perform HTTP operations.
        ///   - timeout: The request timeout, defaults to 1 minute.
        public init(client: HTTPClient, timeout: TimeAmount = .minutes(1)) {
            self.client = client
            self.timeout = timeout
        }
    }

    /// A request to be sent by the transport.
    internal typealias Request = HTTPClientRequest

    /// A response returned by the transport.
    internal typealias Response = HTTPClientResponse

    /// Specialized error thrown by the transport.
    internal enum Error: Swift.Error, CustomStringConvertible, LocalizedError {

        /// Invalid URL composed from base URL and received request.
        case invalidRequestURL(request: OpenAPIRuntime.Request, baseURL: URL)

        // MARK: CustomStringConvertible

        var description: String {
            switch self {
            case let .invalidRequestURL(request: request, baseURL: baseURL):
                return
                    "Invalid request URL from request path: \(request.path), query: \(request.query ?? "<nil>") relative to base URL: \(baseURL.absoluteString)"
            }
        }

        // MARK: LocalizedError

        var errorDescription: String? {
            description
        }
    }

    /// A set of configuration values used by the transport.
    public var configuration: Configuration

    /// Underlying request sender for the transport.
    internal let requestSender: any HTTPRequestSending

    /// Creates a new transport.
    /// - Parameters:
    ///   - configuration: A set of configuration values used by the transport.
    ///   - requestSender: The underlying request sender.
    internal init(
        configuration: Configuration,
        requestSender: any HTTPRequestSending
    ) {
        self.configuration = configuration
        self.requestSender = requestSender
    }

    /// Creates a new transport.
    /// - Parameters:
    ///   - configuration: A set of configuration values used by the transport.
    public init(configuration: Configuration) {
        self.init(
            configuration: configuration,
            requestSender: AsyncHTTPRequestSender()
        )
    }

    // MARK: ClientTransport

    public func send(
        _ request: OpenAPIRuntime.Request,
        baseURL: URL,
        operationID: String
    ) async throws -> OpenAPIRuntime.Response {
        let httpRequest = try Self.convertRequest(request, baseURL: baseURL)
        let httpResponse = try await invokeSession(with: httpRequest)
        let response = try await Self.convertResponse(httpResponse)
        return response
    }

    // MARK: Internal

    /// Converts the shared Request type into URLRequest.
    internal static func convertRequest(
        _ request: OpenAPIRuntime.Request,
        baseURL: URL
    ) throws -> HTTPClientRequest {
        guard var baseUrlComponents = URLComponents(string: baseURL.absoluteString) else {
            throw Error.invalidRequestURL(request: request, baseURL: baseURL)
        }
        baseUrlComponents.path += request.path
        baseUrlComponents.percentEncodedQuery = request.query
        guard let url = baseUrlComponents.url else {
            throw Error.invalidRequestURL(request: request, baseURL: baseURL)
        }
        var clientRequest = HTTPClientRequest(url: url.absoluteString)
        clientRequest.method = request.method.asHTTPMethod
        for header in request.headerFields {
            clientRequest.headers.add(name: header.name.lowercased(), value: header.value)
        }
        if let body = request.body {
            clientRequest.body = .bytes(body)
        }
        return clientRequest
    }

    /// Converts the received URLResponse into the shared Response.
    internal static func convertResponse(
        _ httpResponse: HTTPClientResponse
    ) async throws -> OpenAPIRuntime.Response {
        let headerFields: [OpenAPIRuntime.HeaderField] = httpResponse
            .headers
            .map { .init(name: $0, value: $1) }
        let body = try await httpResponse.body.collect(upTo: .max)
        let bodyData = Data(buffer: body, byteTransferStrategy: .noCopy)
        let response = OpenAPIRuntime.Response(
            statusCode: Int(httpResponse.status.code),
            headerFields: headerFields,
            body: bodyData
        )
        return response
    }

    // MARK: Private

    /// Makes the underlying HTTP call.
    private func invokeSession(with request: Request) async throws -> Response {
        try await requestSender.send(
            request: request,
            with: configuration.client,
            timeout: configuration.timeout
        )
    }
}

extension OpenAPIRuntime.HTTPMethod {
    var asHTTPMethod: NIOHTTP1.HTTPMethod {
        switch self {
        case .get:
            return .GET
        case .put:
            return .PUT
        case .post:
            return .POST
        case .delete:
            return .DELETE
        case .options:
            return .OPTIONS
        case .head:
            return .HEAD
        case .patch:
            return .PATCH
        case .trace:
            return .TRACE
        default:
            return .RAW(value: rawValue)
        }
    }
}

/// A type that performs HTTP operations using the HTTP client.
internal protocol HTTPRequestSending: Sendable {
    func send(
        request: AsyncHTTPClientTransport.Request,
        with client: HTTPClient,
        timeout: TimeAmount
    ) async throws -> AsyncHTTPClientTransport.Response
}

/// Performs HTTP calls using AsyncHTTPClient
internal struct AsyncHTTPRequestSender: HTTPRequestSending {
    func send(
        request: AsyncHTTPClientTransport.Request,
        with client: AsyncHTTPClient.HTTPClient,
        timeout: TimeAmount
    ) async throws -> AsyncHTTPClientTransport.Response {
        try await client.execute(
            request,
            timeout: timeout
        )
    }
}
