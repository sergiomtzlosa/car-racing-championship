import AVFoundation
import Foundation
import os.lock

struct MotorParameters {
    var speed: Float = 0
    var throttle: Float = 0
    var active: Bool = false
}

final class MotorParameterStore: @unchecked Sendable {
    private var parameters = MotorParameters()
    private var lock = os_unfair_lock_s()

    func set(speed: Float, throttle: Float, active: Bool) {
        os_unfair_lock_lock(&lock)
        parameters.speed = max(0, min(16, speed))
        parameters.throttle = max(0, min(1, throttle))
        parameters.active = active
        os_unfair_lock_unlock(&lock)
    }

    func snapshot() -> MotorParameters {
        os_unfair_lock_lock(&lock)
        let value = parameters
        os_unfair_lock_unlock(&lock)
        return value
    }
}

enum MotorSynth {
    static func makeNode(format: AVAudioFormat, store: MotorParameterStore) -> AVAudioSourceNode {
        let sampleRate = format.sampleRate
        var phase: Double = 0
        var whinePhase: Double = 0
        var noise: Float = 0
        var randomState: UInt64 = 0x9E3779B97F4A7C15
        var currentAmplitude: Float = 0

        return AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let parameters = store.snapshot()
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let baseFrequency = 62.0 + Double(parameters.speed) * 26.0 + Double(parameters.throttle) * 20.0
            let frequency = min(420, baseFrequency)
            let phaseIncrement = frequency / sampleRate
            let whineFrequency = min(1450, frequency * 3.7)
            let whineIncrement = whineFrequency / sampleRate
            let targetAmplitude: Float = parameters.active ? (0.16 + parameters.throttle * 0.10) : 0
            let amplitudeStep: Float = targetAmplitude > currentAmplitude ? 0.0025 : 0.0009

            for frame in 0..<Int(frameCount) {
                currentAmplitude += (targetAmplitude - currentAmplitude) * amplitudeStep
                phase += phaseIncrement
                if phase >= 1 { phase -= 1 }
                whinePhase += whineIncrement
                if whinePhase >= 1 { whinePhase -= 1 }

                randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
                let rawNoise = Float((randomState >> 34) & 0xFFFF) / Float(0xFFFF) - 0.5
                noise = noise * 0.92 + rawNoise * 0.08

                let saw = Float(phase * 2 - 1)
                let square = phase < 0.42 ? Float(1) : Float(-1)
                let whine = Float(sin(whinePhase * .pi * 2))
                let tooth = sin(Double(phase) * .pi * 2 * 7) * 0.10
                let signal = (saw * 0.34 + square * 0.12 + whine * 0.08 + noise * 0.09 + Float(tooth))
                    * currentAmplitude

                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    data[frame] = signal
                }
            }
            return noErr
        }
    }
}
