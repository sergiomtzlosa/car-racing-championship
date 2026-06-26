import Foundation
import SwiftUI

final class RaceSession: ObservableObject {
    @Published private(set) var telemetry = RaceTelemetry.placeholder
    @Published private(set) var result: RaceResult?
    @Published private(set) var isPaused = false
    @Published private(set) var cameraMode: CameraMode
    @Published private(set) var isMuted = false

    let input = RaceInputState()
    weak var controller: RaceSceneController?

    init(settings: AppSettings) {
        cameraMode = settings.defaultCamera
        isMuted = AudioDirector.shared.isMuted
    }

    func publish(_ telemetry: RaceTelemetry) {
        self.telemetry = telemetry
        self.cameraMode = telemetry.cameraMode
    }

    func finish(_ result: RaceResult) {
        self.result = result
        self.isPaused = false
    }

    func resetUI() {
        result = nil
        telemetry = .placeholder
        isPaused = false
        cameraMode = controller?.cameraMode ?? cameraMode
    }

    func togglePause() {
        if result != nil { return }
        isPaused.toggle()
        if let controller {
            controller.setPaused(isPaused)
        } else if isPaused {
            AudioDirector.shared.pauseForGame()
        } else {
            AudioDirector.shared.resumeForGame()
        }
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        if let controller {
            controller.setPaused(false)
        } else {
            AudioDirector.shared.resumeForGame()
        }
    }

    func restart() {
        result = nil
        isPaused = false
        cameraMode = controller?.cameraMode ?? cameraMode
        controller?.restart()
    }

    func cycleCamera() {
        if let controller {
            controller.cycleCamera()
            cameraMode = controller.cameraMode
        } else {
            cameraMode = cameraMode.next()
        }
    }

    func toggleMute() {
        AudioDirector.shared.setMuted(!AudioDirector.shared.isMuted)
        isMuted = AudioDirector.shared.isMuted
    }

    func setThrottle(_ pressed: Bool) {
        input.setThrottle(pressed, screen: true)
    }

    func setBrake(_ pressed: Bool) {
        input.setBrake(pressed, screen: true)
    }

    func setBoost(_ pressed: Bool) {
        input.setBoost(pressed)
    }
}
