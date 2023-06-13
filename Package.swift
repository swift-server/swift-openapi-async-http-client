// swift-tools-version: 5.8
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
import Foundation
import PackageDescription

let package = Package(
    name: "swift-openapi-async-http-client",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "OpenAPIAsyncHTTPClient",
            targets: ["OpenAPIAsyncHTTPClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.51.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.17.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", branch: "main"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OpenAPIAsyncHTTPClient",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "OpenAPIAsyncHTTPClientTests",
            dependencies: [
                "OpenAPIAsyncHTTPClient",
            ]
        ),
    ]
)
