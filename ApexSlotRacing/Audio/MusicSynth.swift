import AVFoundation
import Foundation

enum MusicSynth {
    static func makeLoop(format: AVAudioFormat, intensity: Double, bars: Int = 4) -> AVAudioPCMBuffer? {
        let bpm = 120.0
        let beat = 60.0 / bpm
        let step = beat / 4
        let steps = bars * 16
        let duration = Double(steps) * step
        let frames = AVAudioFrameCount(max(1, Int(duration * format.sampleRate)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channels = buffer.floatChannelData else { return nil }

        let bassNotes: [Double] = [55, 55, 73.42, 65.41, 55, 82.41, 73.42, 65.41]
        let arpNotes: [Double] = [220, 261.63, 329.63, 392, 329.63, 261.63]
        var random: UInt64 = 0x123456789

        for frame in 0..<Int(frames) {
            let time = Double(frame) / format.sampleRate
            let stepIndex = Int(time / step) % steps
            let local = time - Double(Int(time / step)) * step
            let barStep = stepIndex % 16
            let beatInBar = Double(stepIndex % 16) / 4.0

            var kick: Double = 0
            if stepIndex % 4 == 0 {
                let envelope = exp(-local * 11)
                kick = sin(local * (72 + 50 * exp(-local * 30)) * .pi * 2) * envelope * 0.80
            }

            var snare: Double = 0
            if barStep == 4 || barStep == 12 {
                random = random &* 6364136223846793005 &+ 1442695040888963407
                let noise = Double((random >> 34) & 0xFFFF) / Double(0xFFFF) * 2 - 1
                snare = noise * exp(-local * 18) * 0.32
            }

            var hat: Double = 0
            if stepIndex % 2 == 0 {
                random = random &* 6364136223846793005 &+ 1442695040888963407
                let noise = Double((random >> 34) & 0xFFFF) / Double(0xFFFF) * 2 - 1
                hat = noise * exp(-local * 45) * (stepIndex % 4 == 2 ? 0.18 : 0.09)
            }

            var bass: Double = 0
            if barStep % 2 == 0 {
                let note = bassNotes[(stepIndex / 2) % bassNotes.count]
                let bassEnvelope = exp(-local * 5.5) * 0.52
                bass = (sin(time * note * .pi * 2) * 0.72 + sin(time * note * 2 * .pi * 2) * 0.18) * bassEnvelope
            }

            var arp: Double = 0
            if intensity > 0.55, barStep % 2 == 0 {
                let note = arpNotes[(stepIndex / 2) % arpNotes.count] * (stepIndex % 8 < 4 ? 1 : 1.5)
                let arpEnvelope = exp(-local * 9.0) * 0.12
                arp = sin(time * note * .pi * 2) * arpEnvelope
            }

            let pad: Double
            if intensity > 0.7 {
                pad = (sin(time * 110 * .pi * 2) + sin(time * 164.81 * .pi * 2)) * 0.025
            } else {
                pad = sin(time * 110 * .pi * 2) * 0.018
            }

            let music = kick * 0.7 + snare + hat + bass + arp + pad
            let final = Float(max(-1, min(1, music * (0.42 + intensity * 0.22))))
            for channel in 0..<Int(format.channelCount) {
                let stereo = channel == 0 ? final : final * 0.96
                channels[channel][frame] = stereo
            }
            _ = beatInBar
        }
        return buffer
    }
}
