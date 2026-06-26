import Foundation
import simd

struct AISpeedProfile {
    let speedLimits: [Float]
    let cumulative: [Float]
    let length: Float

    init(lanePath: LanePath, stats: CarStats, difficulty: Difficulty) {
        length = lanePath.length
        cumulative = lanePath.cumulative
        let frames = lanePath.frames
        guard !frames.isEmpty else {
            speedLimits = []
            return
        }

        let top = stats.topSpeed * difficulty.topSpeedScale
        var limits = [Float](repeating: top, count: frames.count)
        for (index, frame) in frames.enumerated() {
            if frame.kind.isLoop {
                limits[index] = min(top, 6.15 + 0.62 * difficulty.skill)
            } else if frame.curvature > 0.035 {
                let safe = sqrt(stats.grip / max(0.02, frame.curvature))
                limits[index] = min(top, safe * (0.88 + 0.09 * difficulty.skill))
            } else {
                limits[index] = top
            }
        }

        let brake = max(1.0, stats.acceleration * 1.18)
        for _ in 0..<3 {
            for index in stride(from: frames.count - 1, through: 0, by: -1) {
                let next = (index + 1) % frames.count
                let ds: Float
                if next == 0 {
                    ds = max(0.01, length - cumulative[index] + cumulative[0])
                } else {
                    ds = max(0.01, cumulative[next] - cumulative[index])
                }
                let allowed = sqrt(limits[next] * limits[next] + 2 * brake * ds)
                limits[index] = min(limits[index], allowed)
            }
        }

        speedLimits = limits
    }

    func targetSpeed(at distance: Float) -> Float {
        guard !speedLimits.isEmpty, length > 0 else { return 0 }
        var value = distance.truncatingRemainder(dividingBy: length)
        if value < 0 { value += length }

        var low = 0
        var high = cumulative.count - 1
        while low < high {
            let mid = (low + high) / 2
            if cumulative[mid] <= value { low = mid + 1 } else { high = mid }
        }
        let index = max(0, min(speedLimits.count - 1, low - 1))
        let next = (index + 1) % speedLimits.count
        return min(speedLimits[index], speedLimits[next])
    }
}

struct AIDriver {
    let difficulty: Difficulty
    let profile: AISpeedProfile
    let baseTopSpeed: Float
    private var random: SeededUnitRandom
    private var mistakeCooldown: Float
    private var mistakeRemaining: Float = 0
    private var boostCooldown: Float = 0

    init(lanePath: LanePath, stats: CarStats, difficulty: Difficulty, seed: UInt64) {
        self.difficulty = difficulty
        self.profile = AISpeedProfile(lanePath: lanePath, stats: stats, difficulty: difficulty)
        self.baseTopSpeed = stats.topSpeed
        self.random = SeededUnitRandom(seed: seed)
        self.mistakeCooldown = 10 + random.next() * 24
    }

    mutating func step(dt: Float, distance: Float, speed: Float, boostAvailable: Bool, isPursuer: Bool, gap: Float) -> RaceInput {
        let target = profile.targetSpeed(at: distance)
        var throttle: Float = 0
        var brake: Float = 0

        if speed < target - 0.20 {
            throttle = 1
        } else if speed > target + 0.18 {
            brake = min(1, (speed - target) * 0.7 + 0.35)
        } else {
            throttle = 0.35
        }

        mistakeCooldown -= dt
        if mistakeCooldown <= 0 {
            mistakeCooldown = 11 + random.next() * 22
            if random.next() < difficulty.mistakeChance * 22 {
                mistakeRemaining = 0.45 + random.next() * 0.65
            }
        }

        if mistakeRemaining > 0 {
            mistakeRemaining -= dt
            throttle *= 0.15
            if speed > target * 0.92 || random.next() < 0.5 {
                brake = max(brake, 0.35)
            }
        }

        boostCooldown -= dt
        var wantsBoost = false
        if boostAvailable, boostCooldown <= 0, target > baseTopSpeed * 0.72, speed > baseTopSpeed * 0.40 {
            if isPursuer, gap > 1.5 {
                wantsBoost = true
            } else if !isPursuer, gap < 3.0, speed > baseTopSpeed * 0.65 {
                wantsBoost = true
            }
            if wantsBoost { boostCooldown = 1.4 }
        }

        return RaceInput(throttle: max(0, min(1, throttle)), brake: max(0, min(1, brake)), boost: wantsBoost)
    }
}

struct SeededUnitRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6364136223846793005 &+ 1442695040888963407
    }

    mutating func next() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Float((state >> 33) & 0xFFFFFF) / Float(0xFFFFFF)
    }
}
