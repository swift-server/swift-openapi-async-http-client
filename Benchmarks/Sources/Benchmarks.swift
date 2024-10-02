import Benchmark
@_spi(Benchmarks) import OpenAPIAsyncHTTPClient
import AsyncHTTPClient
import NIOCore
import HTTPTypes
import OpenAPIRuntime
import Foundation

let benchmarks = {
    let defaultMetrics: [BenchmarkMetric] = [
        .mallocCountTotal,
        .cpuTotal
    ]
    let config: Benchmark.Configuration = .init(
        metrics: defaultMetrics,
        scalingFactor: .kilo,
        maxDuration: .seconds(10)
    )

    Benchmark("Creation.Default", configuration: config) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole({
                AsyncHTTPClientTransport()
            }())
        }
    }

    Benchmark("Conversion", configuration: config) { benchmark in
        let request = HTTPRequest(
            method: .post,
            scheme: nil,
            authority: nil,
            path: "/stuff",
            headerFields: [
                .init("x-stuff")!: "things"
            ]
        )
        let requestBody = HTTPBody("Hello world")
        let baseURL = URL(string: "https://example.com")!
        let response = HTTPClientResponse(
            status: .ok,
            headers: [
                "x-stuff": "things"
            ],
            body: .bytes(ByteBuffer(string: "Hello world"))
        )
        let transport = AsyncHTTPClientTransport(
            configuration: .init(),
            requestSenderClosure: { _, _, _ in
                response
            }
        )
        for _ in benchmark.scaledIterations {
            let (response, responseBody) = try await transport.send(
                request,
                body: requestBody,
                baseURL: baseURL,
                operationID: "postThings"
            )
            blackHole((response, responseBody))
        }
    }
}
