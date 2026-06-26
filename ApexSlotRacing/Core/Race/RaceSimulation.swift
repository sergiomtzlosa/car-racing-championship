import Foundation
import simd

enum SimCarState: String {
    case waiting
    case running
    case deslot
    case finished
}

final class SimCar {
    let id = UUID()
    let name: String
    let colorHex: String
    let model: CarModelKind
    let isPlayer: Bool
    let laneIndex: Int
    let lanePath: LanePath
    let stats: CarStats
    let difficulty: Difficulty
    let isPursuer: Bool
    var aiDriver: AIDriver?

    var state: SimCarState = .waiting
    var startDelay: Float = 0
    var distance: Float = 0
    var speed: Float = 0
    var completedLaps: Int = 0
    var raceTime: Double = 0
    var lapStartTime: Double = 0
    var currentLapTime: Double = 0
    var lastLap: Double = 0
    var bestLap: Double = 0
    var topSpeed: Float = 0
    var deslots: Int = 0
    var penalty: Float = 0
    var finishTime: Double?
    var totalTime: Double = 0
    var totalDistance: Float = 0
    var boostCharges: Int = 0
    var boostRemaining: Float = 0
    var boostActive: Bool = false
    var wasOnLoop: Bool = false
    var lastPose: TrackPose
    var lastBraking: Bool = false
    var lastThrottle: Float = 0
    var lastBrake: Float = 0
    var skill: Float = 1.0

    init(id: UUID = UUID(),
         name: String,
         colorHex: String,
         model: CarModelKind,
         isPlayer: Bool,
         laneIndex: Int,
         lanePath: LanePath,
         stats: CarStats,
         difficulty: Difficulty,
         isPursuer: Bool,
         seed: UInt64) {
        self.name = name
        self.colorHex = colorHex
        self.model = model
        self.isPlayer = isPlayer
        self.laneIndex = laneIndex
        self.lanePath = lanePath
        self.stats = stats
        self.difficulty = difficulty
        self.isPursuer = isPursuer
        self.lastPose = lanePath.pose(at: 0)
        if !isPlayer {
            self.aiDriver = AIDriver(lanePath: lanePath, stats: stats, difficulty: difficulty, seed: seed)
        }
    }

    var progress: Float {
        guard lanePath.length > 0 else { return Float(completedLaps) }
        return Float(completedLaps) + distance / lanePath.length
    }

    var displaySpeed: Double {
        Double(speed) * 30.0
    }

    var displayTopSpeed: Double {
        Double(topSpeed) * 30.0
    }
}

final class RaceSimulation {
    let config: RaceConfig
    let builtTrack: BuiltTrack
    let playerID: UUID
    let opponentID: UUID?
    private(set) var cars: [SimCar]
    private(set) var phase: RacePhase = .countdown
    private(set) var countdown: Double = 3.6
    private(set) var raceTime: Double = 0
    private(set) var result: RaceResult?
    private(set) var winnerID: UUID?
    private(set) var captureTimer: Float = 0
    private(set) var countdownBeep: Int = 4
    private(set) var aiMode: String = "LOCAL AI"
    private var pendingEvents: [RaceEvent] = []
    private var didEmitFinish = false
    private let cloudLock = NSLock()
    private var cloudControl: RaceInput?
    private var cloudLastSeen: Date = .distantPast
    private var phaseBeforePause: RacePhase = .racing

    init(builtTrack: BuiltTrack, config: RaceConfig, seed: UInt64 = 0xA9E7) {
        self.builtTrack = builtTrack
        self.config = config
        let lanes = builtTrack.lanePaths
        let playerLane = lanes.first ?? LanePath(laneIndex: 0, frames: [], cumulative: [], length: 0, pieceStartDistances: [:])
        let opponentLane = lanes.count > 1 ? lanes[1] : playerLane

        let playerStats = config.playerCar.model.stats
        let player = SimCar(name: "YOU",
                            colorHex: config.playerCar.primaryHex,
                            model: config.playerCar.model,
                            isPlayer: true,
                            laneIndex: 0,
                            lanePath: playerLane,
                            stats: playerStats,
                            difficulty: config.difficulty,
                            isPursuer: config.mode == .pursuit && config.pursuitRole == .pursuer,
                            seed: seed ^ 0x1111)
        let opponentStats = config.opponentCar.model.stats
        let opponent = SimCar(name: config.opponentName,
                              colorHex: config.opponentCar.primaryHex,
                              model: config.opponentCar.model,
                              isPlayer: false,
                              laneIndex: 1,
                              lanePath: opponentLane,
                              stats: opponentStats,
                              difficulty: config.difficulty,
                              isPursuer: config.mode == .pursuit && config.pursuitRole == .fugitive,
                              seed: seed ^ 0x2222)
        if let context = config.championshipContext {
            opponent.skill = context.rivalSkill
        }

        if config.mode == .pursuit {
            player.boostCharges = player.isPursuer ? 3 : 0
            opponent.boostCharges = opponent.isPursuer ? 3 : 0
            if player.isPursuer {
                player.startDelay = 3.0
            } else {
                opponent.startDelay = 3.0
            }
        }

        self.playerID = player.id
        self.opponentID = opponent.id
        self.cars = [player, opponent]
    }

    func reset() {
        pendingEvents.removeAll()
        result = nil
        winnerID = nil
        phase = .countdown
        phaseBeforePause = .racing
        countdown = 3.6
        raceTime = 0
        captureTimer = 0
        countdownBeep = 4
        didEmitFinish = false
        for car in cars {
            car.state = .waiting
            car.distance = 0
            car.speed = 0
            car.completedLaps = 0
            car.raceTime = 0
            car.lapStartTime = 0
            car.currentLapTime = 0
            car.lastLap = 0
            car.bestLap = 0
            car.topSpeed = 0
            car.deslots = 0
            car.penalty = 0
            car.finishTime = nil
            car.totalTime = 0
            car.totalDistance = 0
            car.boostRemaining = 0
            car.boostActive = false
            car.wasOnLoop = false
            car.lastPose = car.lanePath.pose(at: 0)
            if config.mode == .pursuit {
                car.startDelay = car.isPursuer ? 3.0 : 0
            } else {
                car.startDelay = 0
            }
        }
        cloudLastSeen = .distantPast
    }

    func setPaused(_ paused: Bool) {
        if paused {
            if phase == .racing || phase == .countdown {
                phaseBeforePause = phase
                phase = .paused
            }
        } else if phase == .paused {
            phase = phaseBeforePause
        }
    }

    func setCloudControl(throttle: Float?, brake: Float?) {
        cloudLock.lock()
        if let throttle, let brake {
            cloudControl = RaceInput(throttle: throttle, brake: brake, boost: false)
            cloudLastSeen = Date()
            aiMode = "CLOUD AI"
        } else {
            cloudControl = nil
            aiMode = "LOCAL AI"
        }
        cloudLock.unlock()
    }

    func update(dt: Float, input: RaceInput) {
        guard phase != .finished else { return }
        let dt = max(0, min(dt, 0.08))
        if phase == .paused { return }

        if phase == .countdown {
            countdown -= Double(dt)
            let beep = Int(ceil(countdown))
            if beep != countdownBeep {
                countdownBeep = beep
                if beep >= 1, beep <= 3 {
                    pendingEvents.append(.countdownTick(beep))
                }
            }
            if countdown <= 0 {
                phase = .racing
                raceTime = 0
                for car in cars {
                    car.lapStartTime = 0
                    if car.state == .waiting { car.state = .running }
                }
                pendingEvents.append(.started)
            }
            return
        }

        guard phase == .racing else { return }
        raceTime += Double(dt)

        for car in cars {
            guard car.state != .finished else { continue }
            update(car: car, dt: dt, playerInput: input)
        }

        evaluateFinishConditions()
    }

    private func update(car: SimCar, dt: Float, playerInput: RaceInput) {
        if car.startDelay > 0 {
            car.startDelay -= dt
            return
        }

        if car.state == .waiting {
            car.state = .running
        }

        if car.state == .deslot {
            car.penalty -= dt
            if car.penalty <= 0 {
                respawn(car: car)
            }
            return
        }

        let frame = car.lanePath.pose(at: car.distance)
        car.lastPose = frame

        var driveInput: RaceInput
        if car.isPlayer {
            driveInput = playerInput
        } else if let ai = car.aiDriver {
            var driver = ai
            let other = cars.first(where: { $0.id != car.id })
            let gap = other.map { ($0.progress - car.progress) * car.lanePath.length } ?? 0
            driveInput = driver.step(dt: dt,
                                     distance: car.distance,
                                     speed: car.speed,
                                     boostAvailable: car.boostCharges > 0,
                                     isPursuer: car.isPursuer,
                                     gap: gap)
            car.aiDriver = driver
            cloudLock.lock()
            if let cloud = cloudControl, Date().timeIntervalSince(cloudLastSeen) < 0.65 {
                driveInput.throttle = cloud.throttle
                driveInput.brake = cloud.brake
                aiMode = "CLOUD AI"
            } else if aiMode == "CLOUD AI" {
                cloudControl = nil
                aiMode = "LOCAL AI"
            }
            cloudLock.unlock()
        } else {
            driveInput = .coast
        }

        if frame.kind.isLoop, !car.wasOnLoop {
            car.wasOnLoop = true
            if car.speed < 5.15 {
                triggerDeslot(car: car, pose: frame)
                return
            }
        } else if !frame.kind.isLoop {
            car.wasOnLoop = false
        }

        let stability = car.stats.stability
        if !frame.kind.isLoop, frame.curvature > 0.075 {
            let safe = sqrt((car.stats.grip * stability) / frame.curvature)
            let threshold = safe * (car.isPlayer ? 1.18 : 1.24)
            if car.speed > threshold {
                triggerDeslot(car: car, pose: frame)
                return
            }
        }

        if frame.kind.isLoop, car.speed < 4.05 {
            triggerDeslot(car: car, pose: frame)
            return
        }

        if driveInput.boost, car.boostCharges > 0, car.boostRemaining <= 0 {
            car.boostCharges -= 1
            car.boostRemaining = 1.0
            pendingEvents.append(.boost(carID: car.id))
        }
        if car.boostRemaining > 0 {
            car.boostRemaining -= dt
            car.boostActive = true
        } else {
            car.boostActive = false
        }

        let boostScale: Float = car.boostActive ? 1.23 : 1.0
        let topSpeed = car.stats.topSpeed * boostScale
        let throttle = max(0, min(1, driveInput.throttle))
        let brake = max(0, min(1, driveInput.brake))
        car.lastThrottle = throttle
        car.lastBrake = brake
        car.lastBraking = brake > 0.4

        let speedRatio = min(1, car.speed / max(0.1, topSpeed))
        var motorForce = car.stats.acceleration * throttle * (1 - 0.68 * speedRatio)
        if car.boostActive { motorForce *= 1.48 }
        let brakeForce = car.stats.acceleration * 1.42 * brake
        let coastDrag: Float = throttle < 0.05 ? 0.62 : 0.0
        let rolling = 0.20 + car.speed * 0.018
        let gravity = 9.8 * 0.30 * frame.forward.y
        let acceleration = motorForce - brakeForce - coastDrag - rolling - gravity
        car.speed = max(0, min(topSpeed, car.speed + acceleration * dt))
        car.topSpeed = max(car.topSpeed, car.speed)
        car.totalDistance += car.speed * dt

        if car.speed <= 0.01, driveInput.throttle < 0.02 {
            car.speed = 0
        }

        car.distance += car.speed * dt
        if car.distance >= car.lanePath.length, car.lanePath.length > 0 {
            while car.distance >= car.lanePath.length {
                car.distance -= car.lanePath.length
                car.completedLaps += 1
                let lapTime = raceTime - car.lapStartTime
                car.lastLap = lapTime
                car.lapStartTime = raceTime
                if lapTime > 0.2, car.bestLap == 0 || lapTime < car.bestLap {
                    car.bestLap = lapTime
                }
                pendingEvents.append(.lap(carID: car.id, lap: car.completedLaps, lapTime: lapTime))
                if car.completedLaps >= config.laps {
                    finishCar(car)
                    return
                }
            }
        }

        car.currentLapTime = raceTime - car.lapStartTime
    }

    private func triggerDeslot(car: SimCar, pose: TrackPose) {
        guard car.state == .running else { return }
        car.state = .deslot
        car.deslots += 1
        car.penalty = 3.0
        let crashSpeed = max(2.0, car.speed)
        car.speed = 0
        car.boostActive = false
        car.boostRemaining = 0
        pendingEvents.append(.deslot(carID: car.id,
                                     position: pose.position,
                                     forward: pose.forward,
                                     up: pose.up,
                                     left: pose.left,
                                     speed: crashSpeed))
    }

    private func respawn(car: SimCar) {
        let frame = car.lanePath.pose(at: car.distance)
        let pieceStart = car.lanePath.pieceStart(for: frame.pieceIndex)
        car.distance = max(0, min(car.lanePath.length - 0.01, pieceStart))
        car.speed = 0
        car.penalty = 0
        car.state = .running
        car.wasOnLoop = false
        car.lastPose = car.lanePath.pose(at: car.distance)
        pendingEvents.append(.reslot(carID: car.id))
    }

    private func finishCar(_ car: SimCar) {
        guard car.state != .finished else { return }
        car.state = .finished
        car.finishTime = raceTime
        car.totalTime = raceTime
    }

    private func evaluateFinishConditions() {
        guard phase == .racing else { return }
        if config.mode == .pursuit {
            guard let fugitive = cars.first(where: { !$0.isPursuer }),
                  let pursuer = cars.first(where: { $0.isPursuer }) else { return }
            let gapDistance = (fugitive.progress - pursuer.progress) * fugitive.lanePath.length
            if gapDistance <= 0.85, pursuer.startDelay <= 0 {
                captureTimer += 1.0 / 120.0
            } else {
                captureTimer = max(0, captureTimer - 0.6 / 120.0)
            }
            if fugitive.completedLaps >= config.laps {
                endRace(winner: fugitive.id)
                return
            }
            if captureTimer >= 1.0 {
                pendingEvents.append(.capture)
                endRace(winner: pursuer.id)
                return
            }
            return
        }

        if let player = cars.first(where: { $0.isPlayer }), player.state == .finished {
            let sorted = cars.sorted { lhs, rhs in
                let lt = lhs.finishTime ?? estimatedFinishTime(lhs)
                let rt = rhs.finishTime ?? estimatedFinishTime(rhs)
                return lt < rt
            }
            endRace(winner: sorted.first?.id)
        }
    }

    private func estimatedFinishTime(_ car: SimCar) -> Double {
        let remainingLaps = max(0, config.laps - car.completedLaps)
        let average = max(3.0, Double(car.topSpeed) * 0.62)
        let remainingDistance = Double(remainingLaps) * Double(car.lanePath.length) - Double(car.distance)
        return raceTime + max(0, remainingDistance) / average + (car.state == .deslot ? Double(car.penalty) : 0)
    }

    private func endRace(winner: UUID?) {
        guard phase != .finished else { return }
        phase = .finished
        winnerID = winner
        let player = cars.first(where: { $0.isPlayer })
        let playerWon = winner == playerID
        let sorted = cars.sorted { lhs, rhs in
            if config.mode == .pursuit {
                if lhs.id == winnerID { return true }
                if rhs.id == winnerID { return false }
            }
            let lt = lhs.finishTime ?? estimatedFinishTime(lhs)
            let rt = rhs.finishTime ?? estimatedFinishTime(rhs)
            return lt < rt
        }
        let carResults: [CarResult] = sorted.enumerated().map { index, car in
            let estimated = car.finishTime ?? estimatedFinishTime(car)
            let avg = car.raceTime > 0 ? Double(car.totalDistance) / car.raceTime : 0
            return CarResult(id: car.id,
                             name: car.name,
                             carModel: car.model,
                             colorHex: car.colorHex,
                             isPlayer: car.isPlayer,
                             position: index + 1,
                             totalTime: car.finishTime ?? estimated,
                             bestLap: car.bestLap,
                             averageSpeed: avg * 30,
                             topSpeed: car.displayTopSpeed,
                             deslots: car.deslots,
                             completedLaps: car.completedLaps,
                             finished: car.finishTime != nil)
        }
        result = RaceResult(id: UUID(),
                            trackID: builtTrack.layout.id,
                            trackName: builtTrack.layout.name,
                            mode: config.mode,
                            difficulty: config.difficulty,
                            date: Date(),
                            playerWon: playerWon,
                            cars: carResults,
                            playerBestLap: player?.bestLap ?? 0,
                            playerTopSpeed: player?.displayTopSpeed ?? 0,
                            playerDeslots: player?.deslots ?? 0,
                            championshipContext: config.championshipContext,
                            unlockMessages: [],
                            achievementMessages: [])
        pendingEvents.append(.finish(winnerID: winnerID))
    }

    func drainEvents() -> [RaceEvent] {
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        return events
    }

    func telemetry(cameraMode: CameraMode) -> RaceTelemetry {
        guard let player = cars.first(where: { $0.isPlayer }) else {
            return .placeholder
        }
        let sorted = cars.sorted { $0.progress > $1.progress }
        let position = (sorted.firstIndex(where: { $0.id == playerID }) ?? 0) + 1
        var telemetry = RaceTelemetry()
        telemetry.phase = phase
        telemetry.countdown = max(0, countdown)
        telemetry.raceTime = raceTime
        telemetry.lap = min(config.laps, player.completedLaps + 1)
        telemetry.totalLaps = config.laps
        telemetry.position = position
        telemetry.fieldSize = cars.count
        telemetry.speed = player.displaySpeed
        telemetry.topSpeed = player.displayTopSpeed
        telemetry.bestLap = player.bestLap
        telemetry.currentLap = player.currentLapTime
        telemetry.lastLap = player.lastLap
        telemetry.deslots = player.deslots
        telemetry.penalty = Double(player.penalty)
        telemetry.boostCharges = player.boostCharges
        telemetry.boostActive = player.boostActive
        telemetry.aiMode = aiMode
        telemetry.trackName = builtTrack.layout.name
        telemetry.cameraMode = cameraMode
        telemetry.throttle = Double(player.lastThrottle)
        telemetry.brake = Double(player.lastBrake)
        telemetry.playerProgress = player.progress
        telemetry.cars = cars.map {
            CarTelemetry(id: $0.id,
                         name: $0.name,
                         colorHex: $0.colorHex,
                         progress: $0.progress,
                         isPlayer: $0.isPlayer,
                         speed: $0.speed,
                         deslots: $0.deslots)
        }
        telemetry.playerIsPursuer = player.isPursuer
        telemetry.isPlayerFinished = player.finishTime != nil
        if config.mode == .pursuit, let other = cars.first(where: { $0.id != playerID }) {
            telemetry.opponentProgress = other.progress
            let gap = (other.progress - player.progress) * player.lanePath.length
            telemetry.gap = Double(gap)
            telemetry.captureProgress = min(1, Double(captureTimer))
            if player.isPursuer {
                telemetry.warning = captureTimer > 0 ? "CAPTURE" : nil
            }
        } else {
            telemetry.opponentProgress = cars.first(where: { $0.id != playerID })?.progress ?? 0
        }

        if player.state == .deslot {
            telemetry.statusMessage = "RESLOT IN \(String(format: "%.1f", player.penalty))"
        } else if player.startDelay > 0 {
            telemetry.statusMessage = "PURSUER START IN \(Int(ceil(player.startDelay)))"
        } else if player.boostActive {
            telemetry.statusMessage = "SIRENS BOOST"
        }

        telemetry.warning = warning(for: player, fallback: telemetry.warning)
        return telemetry
    }

    private func warning(for player: SimCar, fallback: String?) -> String? {
        guard player.state == .running else { return fallback }
        let start = player.distance
        let frames = player.lanePath.frames
        let index = player.lanePath.frameIndex(at: start)
        guard !frames.isEmpty else { return fallback }
        var ahead: Float = 0
        let stepDistance: Float = 0.22
        var cursor = index
        for _ in 0..<40 {
            let frame = frames[cursor]
            if frame.kind.isLoop, player.speed < 6.4 {
                return "LOOP AHEAD — SPEED UP"
            }
            if !frame.kind.isLoop, frame.curvature > 0.12 {
                let safe = sqrt((player.stats.grip * player.stats.stability) / frame.curvature) * 1.08
                if player.speed > safe {
                    return "BRAKE"
                }
            }
            cursor = (cursor + 1) % frames.count
            ahead += stepDistance
            if ahead > 7 { break }
        }
        return fallback
    }
}
