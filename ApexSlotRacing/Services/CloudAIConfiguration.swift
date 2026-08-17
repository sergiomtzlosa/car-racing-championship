import Foundation

/// Selects the wire protocol used by the optional external driver AI.
enum CloudAIProvider: String, Codable, CaseIterable, Identifiable {
    /// The original Apex protocol: telemetry JSON posted directly to `/v1/drive`.
    case direct
    /// OpenAI-compatible chat completions (`/v1/chat/completions`).
    case openAI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .direct: return "Direct JSON"
        case .openAI: return "OpenAI-compatible"
        }
    }

    var shortName: String {
        switch self {
        case .direct: return "DIRECT"
        case .openAI: return "OPENAI"
        }
    }

    var defaultURL: String {
        switch self {
        case .direct: return "http://127.0.0.1:8787/v1/drive"
        case .openAI: return "https://api.openai.com/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .direct: return ""
        case .openAI: return "gpt-4o-mini"
        }
    }

    var usesToken: Bool { self == .openAI }
    var usesModel: Bool { self == .openAI }

    /// Short request timeout for the direct protocol. Chat completions are
    /// allowed much longer because hosted language models routinely need
    /// several seconds to answer.
    var requestTimeout: TimeInterval {
        switch self {
        case .direct: return 0.35
        case .openAI: return 12.0
        }
    }

    var pollIntervalNanoseconds: UInt64 {
        switch self {
        case .direct: return 220_000_000
        case .openAI: return 1_500_000_000
        }
    }

    /// How long a cloud decision stays authoritative before the local AI takes
    /// over again. The OpenAI value covers one slow request plus scheduling
    /// jitter while still failing back to local control if the endpoint dies.
    var cloudControlMaximumAge: TimeInterval {
        switch self {
        case .direct: return 0.65
        case .openAI: return 20.0
        }
    }

    var protocolSummary: String {
        switch self {
        case .direct:
            return "POST /v1/drive · 350 ms request timeout · latest response wins"
        case .openAI:
            return "POST /v1/chat/completions · Bearer token · slower polling with local fallback"
        }
    }
}

struct CloudAIConfiguration: Equatable {
    var provider: CloudAIProvider
    var endpoint: String
    var model: String
    var token: String

    init(provider: CloudAIProvider,
         endpoint: String,
         model: String = "",
         token: String = "") {
        self.provider = provider
        self.endpoint = endpoint
        self.model = model
        self.token = token
    }

    init(settings: AppSettings) {
        provider = settings.cloudAIProvider
        endpoint = settings.cloudAIURL
        model = settings.cloudAIModel
        token = settings.cloudAIToken
    }

    var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A one-click endpoint/model pairing shown in Settings. The OpenCode entries
/// are conveniences for the OpenCode Zen OpenAI-compatible endpoint.
struct CloudAIModelPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let endpoint: String
    let model: String
    var provider: CloudAIProvider = .openAI
}

enum CloudAIModelPresets {
    static let openCodeEndpoint = "https://opencode.ai/inference/openai/v1/chat/completions"
    static let openCodeDocsURL = "https://opencode.ai/docs/zen/"

    static let openCodeFreeModels: [CloudAIModelPreset] = [
        CloudAIModelPreset(id: "opencode.deepseek-v4.1-flash-free",
                           title: "DeepSeek V4.1 Flash Free",
                           detail: "OpenCode Zen free tier",
                           endpoint: openCodeEndpoint,
                           model: "deepseek-v4.1-flash-free"),
        CloudAIModelPreset(id: "opencode.glm-5.3-flash-free",
                           title: "GLM 5.3 Flash Free",
                           detail: "OpenCode Zen free tier",
                           endpoint: openCodeEndpoint,
                           model: "glm-5.3-flash-free"),
        CloudAIModelPreset(id: "opencode.mimo-v2.6-flash-free",
                           title: "MiMo v2.6 Flash Free",
                           detail: "OpenCode Zen free tier",
                           endpoint: openCodeEndpoint,
                           model: "mimo-v2.6-flash-free"),
        CloudAIModelPreset(id: "opencode.big-pickle",
                           title: "Big Pickle",
                           detail: "OpenCode Zen free tier",
                           endpoint: openCodeEndpoint,
                           model: "big-pickle"),
        CloudAIModelPreset(id: "opencode.iceman-free",
                           title: "Iceman Free",
                           detail: "OpenCode Zen free tier",
                           endpoint: openCodeEndpoint,
                           model: "iceman-free"),
        CloudAIModelPreset(id: "opencode.beam-free",
                           title: "Beam Free",
                           detail: "OpenCode Zen free tier",
                           endpoint: openCodeEndpoint,
                           model: "beam-free")
    ]

    static let openCode = openCodeFreeModels[0]

    static let localMock = CloudAIModelPreset(id: "local.mock",
                                              title: "Local Mock",
                                              detail: "Bundled offline QA server",
                                              endpoint: "http://127.0.0.1:8787/v1/chat/completions",
                                              model: "mock-racer")

    static let openAI = CloudAIModelPreset(id: "openai.default",
                                           title: "OpenAI",
                                           detail: "Hosted OpenAI-compatible API",
                                           endpoint: CloudAIProvider.openAI.defaultURL,
                                           model: CloudAIProvider.openAI.defaultModel)
}
