import Foundation
import XCTest
@testable import ApexSlotRacing

final class MockURLProtocol: URLProtocol {
    struct CapturedRequest {
        let url: URL?
        let headers: [String: String]
        let body: Data?
    }

    static var handler: ((URLRequest) throws -> (Int, Data))?
    private static var captured: [CapturedRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        handler = nil
        captured = []
        lock.unlock()
    }

    static func configure(handler: @escaping (URLRequest) throws -> (Int, Data)) {
        lock.lock()
        Self.handler = handler
        captured = []
        lock.unlock()
    }

    static func capturedRequests() -> [CapturedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(from: request)
        Self.lock.lock()
        Self.captured.append(CapturedRequest(url: request.url,
                                             headers: request.allHTTPHeaderFields ?? [:],
                                             body: body))
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url ?? URL(string: "https://api.example")!,
                                           statusCode: status,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func readBody(from request: URLRequest) -> Data? {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

final class CloudAIServiceTests: XCTestCase {
    private func telemetry() -> CloudAITelemetry {
        CloudAITelemetry(sessionId: "test",
                         trackId: "sunset_speedway",
                         difficulty: "medium",
                         speed: 5,
                         maxSpeed: 10,
                         opponentGap: 1.2,
                         boostAvailable: false,
                         lookahead: [
                            CloudLookahead(distance: 2,
                                           curvature: 0.01,
                                           surface: "straight",
                                           loop: false)
                         ])
    }

    private func configuration(provider: CloudAIProvider = .openAI,
                               endpoint: String = "https://api.example/v1/chat/completions",
                               model: String = "test-model",
                               token: String = "secret-token") -> CloudAIConfiguration {
        CloudAIConfiguration(provider: provider,
                             endpoint: endpoint,
                             model: model,
                             token: token)
    }

    private func makeService(handler: @escaping (URLRequest) throws -> (Int, Data)) -> CloudAIService {
        MockURLProtocol.configure(handler: handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 2
        return CloudAIService(session: URLSession(configuration: configuration))
    }

    private func chatResponse(_ content: String, status: Int = 200) throws -> (Int, Data) {
        let payload: [String: Any] = [
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "choices": [
                [
                    "index": 0,
                    "message": [
                        "role": "assistant",
                        "content": content
                    ],
                    "finish_reason": "stop"
                ]
            ]
        ]
        return (status, try JSONSerialization.data(withJSONObject: payload))
    }

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testRejectsNonLoopbackHTTP() async {
        let service = CloudAIService()
        let connection = await service.testConnection(endpoint: "http://example.com/v1/drive")
        let response = await service.predict(endpoint: "file:///tmp/drive",
                                             telemetry: telemetry())
        XCTAssertFalse(connection)
        XCTAssertNil(response)
    }

    func testUnavailableEndpointFallsBackPromptly() async {
        let service = CloudAIService()
        let start = Date()
        let response = await service.predict(endpoint: "http://127.0.0.1:9/v1/drive",
                                             telemetry: telemetry())
        XCTAssertNil(response)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testUnavailableOpenAIEndpointFallsBackPromptly() async {
        let service = CloudAIService()
        let start = Date()
        let response = await service.predict(configuration: configuration(endpoint: "http://127.0.0.1:9/v1/chat/completions"),
                                             telemetry: telemetry())
        XCTAssertNil(response)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testDirectProtocolStillSendsTelemetryAndParsesDecision() async throws {
        let service = makeService { request in
            XCTAssertEqual(request.url?.path, "/v1/drive")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try JSONSerialization.jsonObject(with: MockURLProtocol.capturedRequests().last?.body ?? Data()) as? [String: Any]
            XCTAssertEqual(body?["trackId"] as? String, "sunset_speedway")
            return (200, Data(#"{"throttle":0.81,"brake":0.05,"targetSpeed":7.2,"confidence":0.9}"#.utf8))
        }

        let response = await service.predict(endpoint: "https://api.example/v1/drive",
                                             telemetry: telemetry())
        XCTAssertEqual(response?.throttle ?? -1, 0.81, accuracy: 0.001)
        XCTAssertEqual(response?.brake ?? -1, 0.05, accuracy: 0.001)
        XCTAssertEqual(response?.targetSpeed ?? -1, 7.2, accuracy: 0.001)
        XCTAssertEqual(response?.confidence ?? -1, 0.9, accuracy: 0.001)
        XCTAssertEqual(MockURLProtocol.capturedRequests().count, 1)
    }

    func testOpenAIRequestUsesBearerAuthModelAndMessages() async throws {
        let service = makeService { _ in
            try self.chatResponse(#"{"throttle":0.64,"brake":0.0,"targetSpeed":6.4,"confidence":0.8}"#)
        }

        let response = await service.predict(configuration: configuration(),
                                             telemetry: telemetry())
        XCTAssertEqual(response?.throttle ?? -1, 0.64, accuracy: 0.001)
        XCTAssertEqual(response?.brake ?? -1, 0.0, accuracy: 0.001)

        let captured = try XCTUnwrap(MockURLProtocol.capturedRequests().first)
        XCTAssertEqual(captured.url?.absoluteString, "https://api.example/v1/chat/completions")
        XCTAssertEqual(captured.headers["Authorization"], "Bearer secret-token")
        XCTAssertEqual(captured.headers["Content-Type"], "application/json")

        let body = try XCTUnwrap(captured.body)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["model"] as? String, "test-model")
        XCTAssertEqual(payload["max_tokens"] as? Int, 96)
        XCTAssertEqual(payload["stream"] as? Bool, false)

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertTrue((messages.first?["content"] as? String ?? "").contains("ONLY one compact JSON object"))
        XCTAssertEqual(messages.last?["role"] as? String, "user")
        XCTAssertTrue((messages.last?["content"] as? String ?? "").contains("\"speed\":5"))
    }

    func testOpenAIResponseAcceptsFencedJSON() async throws {
        let service = makeService { _ in
            try self.chatResponse("```json\n{\"throttle\":0.42,\"brake\":0.18,\"confidence\":0.55}\n```")
        }
        let response = await service.predict(configuration: configuration(),
                                             telemetry: telemetry())
        XCTAssertEqual(response?.throttle ?? -1, 0.42, accuracy: 0.001)
        XCTAssertEqual(response?.brake ?? -1, 0.18, accuracy: 0.001)
        XCTAssertEqual(response?.confidence ?? -1, 0.55, accuracy: 0.001)
    }

    func testOpenAIResponseExtractsJSONFromProseAndClampsValues() async throws {
        let service = makeService { _ in
            try self.chatResponse("Sure. Here is the move: {\"throttle\":1.8,\"brake\":-0.4} Keep racing!")
        }
        let response = await service.predict(configuration: configuration(),
                                             telemetry: telemetry())
        XCTAssertEqual(response?.throttle ?? -1, 1.0, accuracy: 0.001)
        XCTAssertEqual(response?.brake ?? -1, 0.0, accuracy: 0.001)
    }

    func testOpenAIResponseRejectsMalformedOrEmptyContent() async throws {
        let malformed = makeService { _ in
            try self.chatResponse("I would rather not answer.")
        }
        let malformedResponse = await malformed.predict(configuration: configuration(),
                                                        telemetry: telemetry())
        XCTAssertNil(malformedResponse)

        let empty = makeService { _ in
            try self.chatResponse("")
        }
        let emptyResponse = await empty.predict(configuration: configuration(),
                                                telemetry: telemetry())
        XCTAssertNil(emptyResponse)
    }

    func testOpenAIConnectionTestUsesChatProtocol() async throws {
        let service = makeService { _ in
            try self.chatResponse(#"{"throttle":0.5,"brake":0.0}"#)
        }
        let connected = await service.testConnection(configuration: configuration())
        XCTAssertTrue(connected)
        XCTAssertEqual(MockURLProtocol.capturedRequests().count, 1)
    }
}
