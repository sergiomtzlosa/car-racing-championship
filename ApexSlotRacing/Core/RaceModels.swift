import Foundation

enum RacePhase: String, Codable {
    case countdown
    case racing
    case paused
    case finished
}

struct RaceInput {
    var throttle: Float = 0
    var brake: Float = 0
    var boost: Bool = false

    static let coast = RaceInput()
}

final class RaceInputState {
    private let lock = NSLock()
    private var throttleDown = false
    private var brakeDown = false
    private var boostDown = false
    private var screenThrottle = false
    private var screenBrake = false

    func setThrottle(_ down: Bool, screen: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        if screen { screenThrottle = down } else { throttleDown = down }
    }

    func setBrake(_ down: Bool, screen: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        if screen { screenBrake = down } else { brakeDown = down }
    }

    func setBoost(_ down: Bool) {
        lock.lock(); defer { lock.unlock() }
        boostDown = down
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        throttleDown = false
        brakeDown = false
        boostDown = false
        screenThrottle = false
        screenBrake = false
    }

    func snapshot() -> RaceInput {
        lock.lock(); defer { lock.unlock() }
        let throttle = (throttleDown || screenThrottle) ? Float(1) : Float(0)
        let brake = (brakeDown || screenBrake) ? Float(1) : Float(0)
        return RaceInput(throttle: throttle, brake: brake, boost: boostDown)
    }
}

struct CarTelemetry: Identifiable, Equatable {
    var id: UUID
    var name: String
    var colorHex: String
    var progress: Float
    var isPlayer: Bool
    var speed: Float
    var deslots: Int
}

struct RaceTelemetry {
    var phase: RacePhase = .countdown
    var countdown: Double = 3.6
    var raceTime: Double = 0
    var lap: Int = 1
    var totalLaps: Int = 3
    var position: Int = 1
    var fieldSize: Int = 2
    var speed: Double = 0
    var topSpeed: Double = 0
    var bestLap: Double = 0
    var currentLap: Double = 0
    var lastLap: Double = 0
    var deslots: Int = 0
    var penalty: Double = 0
    var boostCharges: Int = 0
    var boostActive: Bool = false
    var gap: Double? = nil
    var captureProgress: Double = 0
    var warning: String? = nil
    var aiMode: String = "LOCAL AI"
    var trackName: String = ""
    var cameraMode: CameraMode = .thirdPerson
    var throttle: Double = 0
    var brake: Double = 0
    var playerProgress: Float = 0
    var opponentProgress: Float = 0
    var cars: [CarTelemetry] = []
    var playerIsPursuer: Bool = false
    var pursuitTimeRemaining: Double? = nil
    var statusMessage: String? = nil
    var isPlayerFinished: Bool = false

    static let placeholder = RaceTelemetry()
}

enum RaceEvent {
    case countdownTick(Int)
    case started
    case deslot(carID: UUID, position: SIMD3<Float>, forward: SIMD3<Float>, up: SIMD3<Float>, left: SIMD3<Float>, speed: Float)
    case reslot(carID: UUID)
    case lap(carID: UUID, lap: Int, lapTime: Double)
    case boost(carID: UUID)
    case finish(winnerID: UUID?)
    case capture
}

struct RaceCarPresentation {
    var id: UUID
    var pose: TrackPose
    var speed: Float
    var curvature: Float
    var braking: Bool
    var isPlayer: Bool
    var deslot: Bool
}
