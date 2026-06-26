import AVFoundation
import XCTest
@testable import ApexSlotRacing

final class AudioSmokeTests: XCTestCase {
    func testSFXSynthGeneratesFiniteBuffersForEveryCue() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else {
            return XCTFail("Could not create audio format")
        }
        for kind in SFXKind.allCases {
            guard let buffer = SFXSynth.makeBuffer(for: kind, format: format) else {
                return XCTFail("Failed to generate \(kind.rawValue)")
            }
            XCTAssertGreaterThan(buffer.frameLength, 0, kind.rawValue)
            guard let channels = buffer.floatChannelData else {
                return XCTFail("Missing float channels for \(kind.rawValue)")
            }
            var peak: Float = 0
            for channel in 0..<Int(format.channelCount) {
                for frame in stride(from: 0, to: Int(buffer.frameLength), by: 17) {
                    let value = channels[channel][frame]
                    XCTAssertTrue(value.isFinite, "Non-finite sample in \(kind.rawValue)")
                    peak = max(peak, abs(value))
                }
            }
            XCTAssertGreaterThan(peak, 0, kind.rawValue)
            XCTAssertLessThanOrEqual(peak, 1.01, kind.rawValue)
        }
    }

    func testMusicSynthProducesANonSilentLoop() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else {
            return XCTFail("Could not create audio format")
        }
        guard let buffer = MusicSynth.makeLoop(format: format, intensity: 0.92, bars: 1) else {
            return XCTFail("Failed to generate music")
        }
        XCTAssertGreaterThan(buffer.frameLength, 44_100)
        guard let channels = buffer.floatChannelData else {
            return XCTFail("Missing music channels")
        }
        var peak: Float = 0
        for frame in stride(from: 0, to: Int(buffer.frameLength), by: 31) {
            let value = channels[0][frame]
            XCTAssertTrue(value.isFinite)
            peak = max(peak, abs(value))
        }
        XCTAssertGreaterThan(peak, 0.01)
    }

    func testMotorParameterStoreClampsRealtimeValues() {
        let store = MotorParameterStore()
        store.set(speed: 999, throttle: -2, active: true)
        let high = store.snapshot()
        XCTAssertEqual(high.speed, 16)
        XCTAssertEqual(high.throttle, 0)
        XCTAssertTrue(high.active)

        store.set(speed: -1, throttle: 2, active: false)
        let low = store.snapshot()
        XCTAssertEqual(low.speed, 0)
        XCTAssertEqual(low.throttle, 1)
        XCTAssertFalse(low.active)
    }

    func testAudioDirectorSettingsClampingDoesNotCrash() {
        var settings = AppSettings.default
        settings.masterVolume = 4
        settings.musicVolume = -1
        settings.sfxVolume = 0.25
        settings.engineVolume = 0.5
        AudioDirector.shared.apply(settings: settings)
        AudioDirector.shared.setMuted(true)
        XCTAssertTrue(AudioDirector.shared.isMuted)
        AudioDirector.shared.setMuted(false)
        XCTAssertFalse(AudioDirector.shared.isMuted)
    }
}
