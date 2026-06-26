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

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 0.35
        configuration.timeoutIntervalForResource = 0.6
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func predict(endpoint: String, telemetry: CloudAITelemetry) async -> CloudAIDriveResponse? {
        guard let url = validatedURL(endpoint) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 0.35
        guard let body = try? encoder.encode(telemetry) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let value = try? decoder.decode(CloudAIDriveResponse.self, from: data) else {
                return nil
            }
            let throttle = min(1, max(0, value.throttle))
            let brake = min(1, max(0, value.brake))
            return CloudAIDriveResponse(
                throttle: throttle,
                brake: brake,
                targetSpeed: value.targetSpeed,
                confidence: value.confidence
            )
        } catch {
            return nil
        }
    }

    func testConnection(endpoint: String) async -> Bool {
        let sample = CloudAITelemetry(
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
        return await predict(endpoint: endpoint, telemetry: sample) != nil
    }

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
}
