import Foundation

struct CloudLookahead: Codable, Sendable {
    var distance: Double
    var curvature: Double
    var surface: String
    var loop: Bool
}

struct CloudAITelemetry: Codable, Sendable {
    var sessionId: String
    var trackId: String
    var difficulty: String
    var speed: Double
    var maxSpeed: Double
    var opponentGap: Double
    var boostAvailable: Bool
    var lookahead: [CloudLookahead]
}

struct CloudAIDriveResponse: Codable, Sendable {
    var throttle: Double
    var brake: Double
    var targetSpeed: Double?
    var confidence: Double?
}

actor CloudAIService {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = CloudAIProvider.openAI.requestTimeout
        configuration.timeoutIntervalForResource = 20.0
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Compatibility entry point for the original direct JSON protocol.
    func predict(endpoint: String, telemetry: CloudAITelemetry) async -> CloudAIDriveResponse? {
        let configuration = CloudAIConfiguration(provider: .direct, endpoint: endpoint)
        return await predict(configuration: configuration, telemetry: telemetry)
    }

    func predict(configuration: CloudAIConfiguration,
                 telemetry: CloudAITelemetry) async -> CloudAIDriveResponse? {
        guard let url = validatedURL(configuration.endpoint) else { return nil }
        switch configuration.provider {
        case .direct:
            return await predictDirect(url: url, telemetry: telemetry)
        case .openAI:
            return await predictChatCompletions(url: url,
                                                configuration: configuration,
                                                telemetry: telemetry)
        }
    }

    /// Compatibility entry point for the original direct JSON protocol.
    func testConnection(endpoint: String) async -> Bool {
        await testConnection(configuration: CloudAIConfiguration(provider: .direct, endpoint: endpoint))
    }

    func testConnection(configuration: CloudAIConfiguration) async -> Bool {
        await predict(configuration: configuration, telemetry: Self.connectionTestTelemetry) != nil
    }

    // MARK: - Direct protocol

    private func predictDirect(url: URL,
                               telemetry: CloudAITelemetry) async -> CloudAIDriveResponse? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = CloudAIProvider.direct.requestTimeout
        guard let body = try? encoder.encode(telemetry) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return decodeDriveResponse(data)
        } catch {
            return nil
        }
    }

    // MARK: - OpenAI-compatible chat completions

    private func predictChatCompletions(url: URL,
                                        configuration: CloudAIConfiguration,
                                        telemetry: CloudAITelemetry) async -> CloudAIDriveResponse? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = CloudAIProvider.openAI.requestTimeout
        if !configuration.trimmedToken.isEmpty {
            request.setValue("Bearer \(configuration.trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        let telemetryText = (try? encoder.encode(telemetry))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let payload = ChatCompletionRequest(
            model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? CloudAIProvider.openAI.defaultModel
                : configuration.model,
            messages: [
                ChatMessage(role: "system", content: Self.driverSystemPrompt),
                ChatMessage(role: "user", content: telemetryText)
            ],
            temperature: 0.2,
            maxTokens: 96,
            stream: false
        )
        guard let body = try? encoder.encode(payload) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return decodeChatCompletion(data)
        } catch {
            return nil
        }
    }

    private func decodeChatCompletion(_ data: Data) -> CloudAIDriveResponse? {
        // Some compatible servers can answer at the root for a direct-style
        // request; accept that shape as a convenience.
        if let direct = decodeDriveResponse(data) {
            return direct
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let first = choices.first else {
            return nil
        }
        let message = first["message"] as? [String: Any]
        let content: String?
        if let text = message?["content"] as? String {
            content = text
        } else if let parts = message?["content"] as? [[String: Any]] {
            content = parts.compactMap { $0["text"] as? String }.joined()
        } else {
            content = first["text"] as? String
        }
        guard let content, !content.isEmpty else { return nil }
        return decodeDriveJSONText(content)
    }

    private func decodeDriveJSONText(_ text: String) -> CloudAIDriveResponse? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidate = trimmed
        if candidate.hasPrefix("```") {
            // Remove the opening fence (```json / ```), the closing fence and
            // any surrounding whitespace.
            if let firstNewline = candidate.firstIndex(of: "\n") {
                candidate = String(candidate[candidate.index(after: firstNewline)...])
            }
            if let closing = candidate.range(of: "```", options: .backwards) {
                candidate = String(candidate[..<closing.lowerBound])
            }
            candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = candidate.firstIndex(of: "{"),
           let end = candidate.lastIndex(of: "}"),
           start <= end {
            candidate = String(candidate[start...end])
        }
        return decodeDriveResponse(Data(candidate.utf8))
    }

    private func decodeDriveResponse(_ data: Data) -> CloudAIDriveResponse? {
        guard let value = try? decoder.decode(CloudAIDriveResponse.self, from: data) else {
            return nil
        }
        return CloudAIDriveResponse(
            throttle: min(1, max(0, value.throttle)),
            brake: min(1, max(0, value.brake)),
            targetSpeed: value.targetSpeed,
            confidence: value.confidence
        )
    }

    // MARK: - Validation

    private func validatedURL(_ endpoint: String) -> URL? {
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else {
            return nil
        }
        if scheme == "https" { return url }
        if scheme == "http", host == "127.0.0.1" || host == "localhost" || host == "::1" {
            return url
        }
        return nil
    }

    private static let connectionTestTelemetry = CloudAITelemetry(
        sessionId: UUID().uuidString,
        trackId: "connection-test",
        difficulty: "medium",
        speed: 5,
        maxSpeed: 10,
        opponentGap: 0,
        boostAvailable: false,
        lookahead: [
            CloudLookahead(distance: 2, curvature: 0.01, surface: "straight", loop: false),
            CloudLookahead(distance: 6, curvature: 0.3, surface: "curve", loop: false)
        ]
    )

    private static let driverSystemPrompt = """
    You are the CPU driver in Apex Slot Racing, a 1:32 slot-car game.
    Reply with ONLY one compact JSON object, no markdown and no prose:
    {"throttle":0.0,"brake":0.0,"targetSpeed":0.0,"confidence":0.0}
    throttle and brake are 0...1, brake is only for slowing down, and the
    answer is advisory. Be conservative near curves and the vertical loop.
    """
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}
