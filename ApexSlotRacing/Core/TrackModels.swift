import Foundation
import simd

// MARK: - Codable vector

struct Vec3: Codable, Equatable, Hashable {
    var x: Float
    var y: Float
    var z: Float

    static let zero = Vec3(x: 0, y: 0, z: 0)

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(_ value: SIMD3<Float>) {
        x = value.x
        y = value.y
        z = value.z
    }

    var simd: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

// MARK: - Track pieces

enum TrackPieceKind: String, Codable, CaseIterable, Identifiable {
    case startFinish
    case straightLong
    case straightShort
    case curveSharp90
    case curveWide90
    case curveWide180
    case curve45
    case closureArc
    case chicane
    case crossover
    case bridge
    case loop360

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .startFinish: return "Start / Finish"
        case .straightLong: return "Long Straight"
        case .straightShort: return "Short Straight"
        case .curveSharp90: return "Sharp 90°"
        case .curveWide90: return "Wide 90°"
        case .curveWide180: return "Wide 180°"
        case .curve45: return "Sweeping 45°"
        case .closureArc: return "Link Curve"
        case .chicane: return "Chicane"
        case .crossover: return "Lane Crossover"
        case .bridge: return "Bridge"
        case .loop360: return "Loop 360°"
        }
    }

    var symbol: String {
        switch self {
        case .startFinish: return "flag.checkered"
        case .straightLong, .straightShort: return "arrow.right"
        case .curveSharp90, .curveWide90, .curveWide180, .curve45, .closureArc: return "arrow.turn.up.right"
        case .chicane: return "arrow.left.arrow.right"
        case .crossover: return "arrow.triangle.swap"
        case .bridge: return "road.lanes"
        case .loop360: return "arrow.triangle.2.circlepath"
        }
    }

    var isCurve: Bool {
        switch self {
        case .curveSharp90, .curveWide90, .curveWide180, .curve45, .closureArc: return true
        default: return false
        }
    }

    var isStraightLike: Bool {
        switch self {
        case .startFinish, .straightLong, .straightShort, .chicane, .crossover, .bridge, .loop360:
            return true
        default: return false
        }
    }

    var defaultLength: Float? {
        switch self {
        case .startFinish: return 8
        case .straightLong: return 8
        case .straightShort: return 4
        case .chicane: return 4
        case .crossover: return 4
        case .bridge: return 8
        case .loop360: return 4
        default: return nil
        }
    }

    var defaultRadius: Float? {
        switch self {
        case .curveSharp90: return 1.9
        case .curveWide90: return 3.0
        case .curveWide180: return 3.5
        case .curve45: return 3.0
        case .closureArc: return 2.4
        default: return nil
        }
    }

    var isLoop: Bool { self == .loop360 }
    var isBridge: Bool { self == .bridge }
    var isCrossover: Bool { self == .crossover }
}

struct TrackPiece: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var kind: TrackPieceKind
    var length: Float?
    var radius: Float?
    var mirrored: Bool
    var position: Vec3?
    var rotationY: Float?
    /// Used by the generated `closureArc` pieces. Standard catalog curves keep
    /// their fixed 45/90/180-degree sweep and leave this nil.
    var arcSweep: Float?

    init(id: UUID = UUID(),
         kind: TrackPieceKind,
         length: Float? = nil,
         radius: Float? = nil,
         mirrored: Bool = false,
         position: Vec3? = nil,
         rotationY: Float? = nil,
         arcSweep: Float? = nil) {
        self.id = id
        self.kind = kind
        self.length = length
        self.radius = radius
        self.mirrored = mirrored
        self.position = position
        self.rotationY = rotationY
        self.arcSweep = arcSweep
    }

    var effectiveLength: Float {
        length ?? kind.defaultLength ?? 4
    }

    var effectiveRadius: Float {
        radius ?? kind.defaultRadius ?? 3
    }

    var effectiveArcSweep: Float {
        arcSweep ?? .pi / 2
    }
}

enum TrackEnvironment: String, Codable, CaseIterable, Identifiable {
    case club
    case dusk
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .club: return "Club Day"
        case .dusk: return "Golden Dusk"
        case .night: return "Night Race"
        }
    }

    var icon: String {
        switch self {
        case .club: return "sun.max"
        case .dusk: return "sunset"
        case .night: return "moon.stars"
        }
    }
}

struct TrackLayout: Codable, Identifiable, Equatable, Hashable {
    var schemaVersion: Int
    var id: UUID
    var name: String
    var laneCount: Int
    var pieces: [TrackPiece]
    var environment: TrackEnvironment
    var createdAt: Date
    var updatedAt: Date
    var isBuiltIn: Bool

    init(id: UUID = UUID(),
         name: String,
         pieces: [TrackPiece],
         environment: TrackEnvironment = .club,
         laneCount: Int = 2,
         isBuiltIn: Bool = false) {
        self.schemaVersion = 1
        self.id = id
        self.name = name
        self.laneCount = laneCount
        self.pieces = pieces
        self.environment = environment
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isBuiltIn = isBuiltIn
    }

    func duplicated() -> TrackLayout {
        var copy = self
        copy.id = UUID()
        copy.name = name + " Copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.isBuiltIn = false
        return copy
    }
}

// MARK: - Car models and configuration

enum CarModelKind: String, Codable, CaseIterable, Identifiable {
    case gt
    case rally
    case formula

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gt: return "GT Endurance"
        case .rally: return "80s Rally"
        case .formula: return "Open Wheel"
        }
    }

    var subtitle: String {
        switch self {
        case .gt: return "Apex GT-R"
        case .rally: return "Nordic 4WD"
        case .formula: return "Veloce F1"
        }
    }

    var unlockText: String? {
        switch self {
        case .gt: return nil
        case .rally: return "Win a race to unlock"
        case .formula: return "Win a championship to unlock"
        }
    }

    var stats: CarStats {
        switch self {
        case .gt:
            return CarStats(topSpeed: 10.1, acceleration: 9.2, grip: 21.0, stability: 0.95, mass: 1.0)
        case .rally:
            return CarStats(topSpeed: 9.2, acceleration: 8.4, grip: 23.5, stability: 0.98, mass: 1.05)
        case .formula:
            return CarStats(topSpeed: 10.8, acceleration: 10.2, grip: 19.5, stability: 0.86, mass: 0.86)
        }
    }
}

struct CarStats {
    var topSpeed: Float
    var acceleration: Float
    var grip: Float
    var stability: Float
    var mass: Float
}

struct CarConfig: Codable, Equatable, Hashable {
    var model: CarModelKind
    var primaryHex: String
    var secondaryHex: String
    var wheelStyle: Int
    var decalStyle: Int

    static func standard(for model: CarModelKind) -> CarConfig {
        switch model {
        case .gt:
            return CarConfig(model: .gt, primaryHex: "#E83B2F", secondaryHex: "#F5F2E9", wheelStyle: 0, decalStyle: 0)
        case .rally:
            return CarConfig(model: .rally, primaryHex: "#E9E2D0", secondaryHex: "#1D6FD1", wheelStyle: 1, decalStyle: 1)
        case .formula:
            return CarConfig(model: .formula, primaryHex: "#F0A516", secondaryHex: "#121820", wheelStyle: 2, decalStyle: 2)
        }
    }
}

// MARK: - Race configuration and results

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var skill: Float {
        switch self {
        case .easy: return 0.82
        case .medium: return 0.93
        case .hard: return 0.99
        }
    }

    var mistakeChance: Float {
        switch self {
        case .easy: return 0.018
        case .medium: return 0.004
        case .hard: return 0.0005
        }
    }

    var topSpeedScale: Float {
        switch self {
        case .easy: return 0.86
        case .medium: return 0.95
        case .hard: return 1.0
        }
    }
}

enum RaceMode: String, Codable, CaseIterable, Identifiable {
    case quick
    case pursuit
    case championship
    case qualifying

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quick: return "Quick Race"
        case .pursuit: return "Pursuit"
        case .championship: return "Championship"
        case .qualifying: return "Qualifying"
        }
    }
}

enum PursuitRole: String, Codable, CaseIterable, Identifiable {
    case pursuer
    case fugitive

    var id: String { rawValue }

    var displayName: String {
        self == .pursuer ? "Pursuer" : "Fugitive"
    }
}

struct ChampionshipRaceContext: Codable, Equatable, Hashable {
    var roundIndex: Int
    var rivalName: String
    var rivalColorHex: String
    var rivalSkill: Float
}

struct RaceConfig: Equatable {
    var id = UUID()
    var mode: RaceMode
    var track: TrackLayout
    var playerCar: CarConfig
    var opponentCar: CarConfig
    var difficulty: Difficulty
    var laps: Int
    var pursuitRole: PursuitRole
    var opponentName: String
    var championshipContext: ChampionshipRaceContext?
    var isTestDrive: Bool = false

    var laneCount: Int { max(2, min(2, track.laneCount)) }
}

struct CarResult: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var carModel: CarModelKind
    var colorHex: String
    var isPlayer: Bool
    var position: Int
    var totalTime: Double
    var bestLap: Double
    var averageSpeed: Double
    var topSpeed: Double
    var deslots: Int
    var completedLaps: Int
    var finished: Bool
}

struct RaceResult: Codable, Equatable, Identifiable {
    var id: UUID
    var trackID: UUID
    var trackName: String
    var mode: RaceMode
    var difficulty: Difficulty
    var date: Date
    var playerWon: Bool
    var cars: [CarResult]
    var playerBestLap: Double
    var playerTopSpeed: Double
    var playerDeslots: Int
    var championshipContext: ChampionshipRaceContext?
    var unlockMessages: [String]
    var achievementMessages: [String]
}

// MARK: - Profile, records, settings

struct PlayerProfile: Codable, Equatable {
    var playerName: String
    var carConfig: CarConfig
    var unlockedCars: [String]
    var unlockedDecalStyles: [Int]
    var achievements: [String]
    var races: Int
    var wins: Int
    var podiums: Int
    var championships: Int
    var pursuitsWon: Int
    var bestLaps: [String: Double]
    var topSpeed: Double
    var favoriteTrack: String?
    var totalDistance: Double

    static func fresh() -> PlayerProfile {
        PlayerProfile(
            playerName: "Driver",
            carConfig: .standard(for: .gt),
            unlockedCars: [CarModelKind.gt.rawValue],
            unlockedDecalStyles: [0],
            achievements: [],
            races: 0,
            wins: 0,
            podiums: 0,
            championships: 0,
            pursuitsWon: 0,
            bestLaps: [:],
            topSpeed: 0,
            favoriteTrack: nil,
            totalDistance: 0
        )
    }

    func isUnlocked(_ model: CarModelKind) -> Bool {
        model == .gt || unlockedCars.contains(model.rawValue)
    }
}

struct AppSettings: Codable, Equatable {
    var masterVolume: Double = 0.8
    var musicVolume: Double = 0.55
    var sfxVolume: Double = 0.85
    var engineVolume: Double = 0.75
    var graphicsQuality: GraphicsQuality = .high
    var defaultCamera: CameraMode = .thirdPerson
    var cloudAIEnabled: Bool = false
    var cloudAIURL: String = "http://127.0.0.1:8787/v1/drive"
    var reduceMotion: Bool = false
    var showFPS: Bool = false

    static let `default` = AppSettings()
}

enum GraphicsQuality: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case ultra

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var msaa: SCNAntialiasingModeWrapper {
        switch self {
        case .low: return .none
        case .medium: return .multisampling2X
        case .high, .ultra: return .multisampling4X
        }
    }
}

// SceneKit dependency kept out of pure model file is not worth it here; used by settings UI.
enum SCNAntialiasingModeWrapper {
    case none
    case multisampling2X
    case multisampling4X
}

enum CameraMode: String, Codable, CaseIterable, Identifiable {
    case firstPerson
    case thirdPerson
    case topDown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstPerson: return "Cockpit"
        case .thirdPerson: return "Chase"
        case .topDown: return "Cinematic"
        }
    }

    var icon: String {
        switch self {
        case .firstPerson: return "car.side"
        case .thirdPerson: return "camera.fill"
        case .topDown: return "map"
        }
    }

    func next() -> CameraMode {
        switch self {
        case .firstPerson: return .thirdPerson
        case .thirdPerson: return .topDown
        case .topDown: return .firstPerson
        }
    }
}

// MARK: - Championship

struct ChampionshipEntrant: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var colorHex: String
    var carModel: CarModelKind
    var skill: Float
    var isPlayer: Bool
    var points: Int = 0
    var wins: Int = 0
    var podiums: Int = 0
    var bestLap: Double = 0
    var qualifyingTime: Double = 0
}

struct ChampionshipRound: Codable, Identifiable, Equatable {
    var id: UUID
    var index: Int
    var trackID: UUID
    var trackName: String
    var completed: Bool
    var playerPosition: Int
    var playerPoints: Int
    var winnerName: String
    var results: [String: Double]
}

struct ChampionshipState: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var difficulty: Difficulty
    var entrants: [ChampionshipEntrant]
    var rounds: [ChampionshipRound]
    var currentRoundIndex: Int
    var completed: Bool
    var championName: String?
    var createdAt: Date
    var updatedAt: Date
}
