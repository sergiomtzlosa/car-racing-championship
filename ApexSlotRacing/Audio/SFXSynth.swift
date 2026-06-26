import AVFoundation
import Foundation

enum SFXKind: String, CaseIterable, Hashable {
    case countdown
    case go
    case crash
    case lap
    case boost
    case finish
    case uiClick
    case paint
    case unlock
}

enum SFXSynth {
    static func makeBuffer(for kind: SFXKind, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        switch kind {
        case .countdown:
            return tone(format: format, duration: 0.13, frequency: 620, amplitude: 0.22, decay: 22)
        case .go:
            return sweep(format: format, duration: 0.42, start: 740, end: 1480, amplitude: 0.30)
        case .crash:
            return crash(format: format)
        case .lap:
            return arpeggio(format: format, notes: [880, 1174], spacing: 0.11, duration: 0.34, amplitude: 0.22)
        case .boost:
            return sweep(format: format, duration: 0.65, start: 260, end: 1800, amplitude: 0.26, noise: true)
        case .finish:
            return arpeggio(format: format, notes: [523.25, 659.25, 783.99, 1046.5], spacing: 0.15, duration: 1.2, amplitude: 0.24)
        case .uiClick:
            return tone(format: format, duration: 0.045, frequency: 1220, amplitude: 0.12, decay: 55)
        case .paint:
            return sweep(format: format, duration: 0.28, start: 900, end: 320, amplitude: 0.10, noise: true)
        case .unlock:
            return arpeggio(format: format, notes: [659.25, 880, 1318.5], spacing: 0.10, duration: 0.55, amplitude: 0.20)
        }
    }

    private static func tone(format: AVAudioFormat,
                             duration: Double,
                             frequency: Double,
                             amplitude: Float,
                             decay: Double) -> AVAudioPCMBuffer? {
        makeBuffer(format: format, duration: duration) { time, _ in
            let envelope = Float(exp(-time * decay))
            let attack = Float(min(1, time * 120))
            return Float(sin(time * frequency * .pi * 2)) * amplitude * envelope * attack
        }
    }

    private static func sweep(format: AVAudioFormat,
                              duration: Double,
                              start: Double,
                              end: Double,
                              amplitude: Float,
                              noise: Bool = false) -> AVAudioPCMBuffer? {
        var random: UInt64 = 0xCAFE
        return makeBuffer(format: format, duration: duration) { time, _ in
            let progress = min(1, time / duration)
            let frequency = start + (end - start) * progress
            let envelope = Float(sin(min(.pi, progress * .pi)) * (1 - progress * 0.35))
            let oscillator = Float(sin(time * frequency * .pi * 2))
            random = random &* 6364136223846793005 &+ 1442695040888963407
            let randomValue = Float((random >> 34) & 0xFFFF) / Float(0xFFFF) * 2 - 1
            let signal = oscillator * (noise ? 0.45 : 1.0) + (noise ? randomValue * 0.35 : 0)
            return signal * amplitude * envelope
        }
    }

    private static func arpeggio(format: AVAudioFormat,
                                 notes: [Double],
                                 spacing: Double,
                                 duration: Double,
                                 amplitude: Float) -> AVAudioPCMBuffer? {
        makeBuffer(format: format, duration: duration) { time, _ in
            var value: Float = 0
            for (index, note) in notes.enumerated() {
                let start = Double(index) * spacing
                let local = time - start
                guard local >= 0 else { continue }
                let envelope = Float(exp(-local * 4.2)) * Float(min(1, local * 90))
                let oscillator = Float(sin(local * note * .pi * 2))
                value += oscillator * envelope * amplitude / Float(max(1, notes.count)) * 2
            }
            return value
        }
    }

    private static func crash(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        var random: UInt64 = 0xBADF00D
        var low: Float = 0
        return makeBuffer(format: format, duration: 0.9) { time, _ in
            random = random &* 6364136223846793005 &+ 1442695040888963407
            let noise = Float((random >> 34) & 0xFFFF) / Float(0xFFFF) * 2 - 1
            low = low * 0.90 + noise * 0.10
            let envelope = Float(exp(-time * 4.5))
            let thud = Float(sin(time * 72 * .pi * 2)) * Float(exp(-time * 8))
            let rattle = (noise * 0.42 + low * 0.5) * Float(exp(-time * 2.6))
            return (thud * 0.45 + rattle * 0.55) * envelope * 0.55
        }
    }

    private static func makeBuffer(format: AVAudioFormat,
                                   duration: Double,
                                   sample: (Double, Int) -> Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(max(1, Int(duration * format.sampleRate)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channels = buffer.floatChannelData else { return nil }
        for frame in 0..<Int(frames) {
            let time = Double(frame) / format.sampleRate
            let value = max(-1, min(1, sample(time, frame)))
            for channel in 0..<Int(format.channelCount) {
                channels[channel][frame] = value
            }
        }
        return buffer
    }
}
