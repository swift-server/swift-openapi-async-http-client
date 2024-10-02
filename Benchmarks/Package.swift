// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "benchmarks",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Benchmarks", targets: ["Benchmarks"]),
    ],
    dependencies: [
        .package(name: "swift-openapi-async-http-client", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.26.0"),
    ],
    targets: [
        .executableTarget(
            name: "Benchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client")
            ],
            path: "Sources",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)
