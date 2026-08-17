import AppKit
import GameController
import os
import SceneKit
import SwiftUI
import simd

final class RaceSCNView: SCNView {
    var keyDownHandler: ((NSEvent) -> Bool)?
    var keyUpHandler: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if keyDownHandler?(event) == true { return }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if keyUpHandler?(event) == true { return }
        super.keyUp(with: event)
    }
}

final class RaceSceneController: NSObject, SCNSceneRendererDelegate {
    let config: RaceConfig
    private(set) var settings: AppSettings
    let session: RaceSession
    let builtTrack: BuiltTrack
    let world: WorldBuildResult
    let simulation: RaceSimulation
    private(set) var cameraMode: CameraMode

    private weak var sceneView: RaceSCNView?
    private var carNodes: [UUID: RaceCarNode] = [:]
    private let playerCarNode: RaceCarNode
    private let opponentCarNode: RaceCarNode
    private let chaseCamera = SCNNode()
    private let topCamera = SCNNode()
    private let firstPersonCamera = SCNNode()
    private var chasePosition = SIMD3<Float>(repeating: 0)
    private var chaseTarget = SIMD3<Float>(repeating: 0)
    private var chaseInitialized = false
    private var accumulator: Double = 0
    private var lastFrameTime: TimeInterval = 0
    private var telemetryTimer: Double = 0
    private var didReportFinish = false
    private var crashAnimations: [UUID: CrashAnimation] = [:]
    private var cloudTask: Task<Void, Never>?
    private let cloudService = CloudAIService()
    private let cloudSnapshot = OSAllocatedUnfairLock<CloudAITelemetry?>(initialState: nil)
    private var cloudTick: Double = 0
    private let cloudSessionID = UUID().uuidString

    private struct CrashAnimation {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var orientation: simd_quatf
        var axis: SIMD3<Float>
        var angularSpeed: Float
        var elapsed: Float
    }

    init(config: RaceConfig, settings: AppSettings, session: RaceSession) {
        self.config = config
        self.settings = settings
        self.session = session
        let built = TrackPathBuilder.build(config.track)
        self.builtTrack = built
        self.world = TrackSceneBuilder.buildWorld(built: built,
                                                  environment: config.track.environment,
                                                  quality: settings.graphicsQuality)
        self.simulation = RaceSimulation(builtTrack: built, config: config)
        self.cameraMode = settings.defaultCamera
        self.playerCarNode = CarSceneFactory.makeCar(config: config.playerCar, quality: settings.graphicsQuality)
        self.opponentCarNode = CarSceneFactory.makeCar(config: config.opponentCar, quality: settings.graphicsQuality)
        super.init()

        buildCars()
        buildCameras()
        placeCarsAtStart()
        session.controller = self
    }

    func attach(to view: RaceSCNView) {
        sceneView = view
        view.scene = world.scene
        view.delegate = self
        updateCeilingVisibility()
        view.pointOfView = cameraNode(for: cameraMode)
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = antialiasingMode
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true
        view.showsStatistics = settings.showFPS
        view.backgroundColor = NSColor(calibratedRed: 0.012, green: 0.016, blue: 0.022, alpha: 1)
        view.keyDownHandler = { [weak self] event in self?.handleKeyDown(event) ?? false }
        view.keyUpHandler = { [weak self] event in self?.handleKeyUp(event) ?? false }
        view.window?.makeFirstResponder(view)

        AudioDirector.shared.apply(settings: settings)
        AudioDirector.shared.beginRace()
        setupGamepads()
        startCloudLoopIfNeeded()
        publishTelemetry(force: true)
    }

    func teardown() {
        cloudTask?.cancel()
        cloudTask = nil
        NotificationCenter.default.removeObserver(self)
        AudioDirector.shared.endRace()
        sceneView?.delegate = nil
        sceneView?.isPlaying = false
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        AudioDirector.shared.apply(settings: settings)
        sceneView?.showsStatistics = settings.showFPS
    }

    func setPaused(_ paused: Bool) {
        simulation.setPaused(paused)
        if paused {
            AudioDirector.shared.pauseForGame()
        } else {
            AudioDirector.shared.resumeForGame()
            lastFrameTime = 0
        }
    }

    func restart() {
        simulation.reset()
        crashAnimations.removeAll()
        didReportFinish = false
        accumulator = 0
        lastFrameTime = 0
        chaseInitialized = false
        session.input.clear()
        session.resetUI()
        placeCarsAtStart()
        AudioDirector.shared.beginRace()
        publishTelemetry(force: true)
    }

    func cycleCamera() {
        cameraMode = cameraMode.next()
        updateCeilingVisibility()
        sceneView?.pointOfView = cameraNode(for: cameraMode)
        AudioDirector.shared.play(.uiClick)
        session.publish(simulation.telemetry(cameraMode: cameraMode))
    }

    private func updateCeilingVisibility() {
        let ceiling = world.environmentRoot.childNode(withName: "room-ceiling", recursively: true)
        ceiling?.isHidden = cameraMode == .topDown
    }

    func toggleMute() {
        AudioDirector.shared.setMuted(!AudioDirector.shared.isMuted)
    }

    private func buildCars() {
        playerCarNode.root.name = "player-car"
        opponentCarNode.root.name = "opponent-car"
        world.scene.rootNode.addChildNode(playerCarNode.root)
        world.scene.rootNode.addChildNode(opponentCarNode.root)

        carNodes[simulation.playerID] = playerCarNode
        if let opponentID = simulation.opponentID {
            carNodes[opponentID] = opponentCarNode
        }

        for car in simulation.cars {
            let node = car.isPlayer ? playerCarNode : opponentCarNode
            let pose = car.lanePath.pose(at: car.distance)
            node.root.simdPosition = pose.position
            node.root.simdOrientation = pose.orientation
        }
    }

    private func buildCameras() {
        let chase = SCNCamera()
        chase.fieldOfView = 55
        chase.zNear = 0.04
        chase.zFar = 220
        chase.wantsHDR = true
        chase.wantsExposureAdaptation = false
        chase.vignettingIntensity = 0.28
        chase.vignettingPower = 1.8
        chase.saturation = 1.06
        chase.contrast = 1.03
        chaseCamera.camera = chase
        chaseCamera.name = "chase-camera"
        world.scene.rootNode.addChildNode(chaseCamera)

        let top = SCNCamera()
        top.usesOrthographicProjection = true
        top.orthographicScale = CGFloat(max(6, max(builtTrack.size.x, builtTrack.size.z) * 0.72))
        top.zNear = 0.1
        top.zFar = 200
        top.wantsHDR = true
        top.wantsExposureAdaptation = false
        topCamera.camera = top
        topCamera.name = "top-camera"
        topCamera.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        topCamera.position = SCNVector3(builtTrack.center.x,
                                        builtTrack.center.y + max(12, builtTrack.size.y + 10),
                                        builtTrack.center.z + 0.01)
        world.scene.rootNode.addChildNode(topCamera)

        let cockpit = SCNCamera()
        cockpit.fieldOfView = 74
        cockpit.zNear = 0.015
        cockpit.zFar = 160
        cockpit.wantsHDR = true
        cockpit.wantsExposureAdaptation = false
        cockpit.motionBlurIntensity = 0.14
        firstPersonCamera.camera = cockpit
        firstPersonCamera.name = "cockpit-camera"
        firstPersonCamera.simdPosition = playerCarNode.cockpitAnchor + SIMD3<Float>(0, 0.03, 0)
        playerCarNode.chassis.addChildNode(firstPersonCamera)
    }

    private func placeCarsAtStart() {
        for car in simulation.cars {
            let pose = car.lanePath.pose(at: 0)
            let node = carNodes[car.id]
            node?.root.simdPosition = pose.position + pose.up * 0.012
            node?.root.simdOrientation = pose.orientation
            node?.update(dt: 0, speed: 0, steering: 0, braking: false, lateralAcceleration: 0, reduceMotion: true)
        }
    }

    private func cameraNode(for mode: CameraMode) -> SCNNode {
        switch mode {
        case .firstPerson: return firstPersonCamera
        case .thirdPerson: return chaseCamera
        case .topDown: return topCamera
        }
    }

    private var antialiasingMode: SCNAntialiasingMode {
        switch settings.graphicsQuality {
        case .low: return .none
        case .medium: return .multisampling2X
        case .high, .ultra: return .multisampling4X
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let rawDelta: Double
        if lastFrameTime == 0 {
            rawDelta = 0
        } else {
            rawDelta = max(0, min(0.10, time - lastFrameTime))
        }
        lastFrameTime = time
        let dt = Float(rawDelta)

        if !session.isPaused {
            accumulator += rawDelta
            let fixedStep = 1.0 / 120.0
            var steps = 0
            while accumulator >= fixedStep, steps < 12 {
                simulation.update(dt: Float(fixedStep), input: session.input.snapshot())
                accumulator -= fixedStep
                steps += 1
            }
        }

        drainEvents()
        updateCarNodes(dt: dt)
        updateCamera(dt: dt)
        updateStartLights()
        updateAudio()
        updateCloudSnapshotIfNeeded(dt: dt)
        publishTelemetry()
        reportFinishIfNeeded()
    }

    private func drainEvents() {
        let events = simulation.drainEvents()
        for event in events {
            switch event {
            case .countdownTick:
                AudioDirector.shared.play(.countdown)
            case .started:
                AudioDirector.shared.play(.go)
                HapticsService.impact()
            case .deslot(let carID, let position, let forward, let up, let left, let speed):
                beginCrash(carID: carID, position: position, forward: forward, up: up, left: left, speed: speed)
                AudioDirector.shared.play(.crash)
                if carID == simulation.playerID { HapticsService.deslot() }
            case .reslot(let carID):
                crashAnimations.removeValue(forKey: carID)
            case .lap(let carID, _, _):
                if carID == simulation.playerID { AudioDirector.shared.play(.lap) }
            case .boost(let carID):
                if carID == simulation.playerID { AudioDirector.shared.play(.boost) }
            case .capture:
                AudioDirector.shared.play(.finish)
            case .finish:
                AudioDirector.shared.play(.finish)
            }
        }
    }

    private func beginCrash(carID: UUID,
                            position: SIMD3<Float>,
                            forward: SIMD3<Float>,
                            up: SIMD3<Float>,
                            left: SIMD3<Float>,
                            speed: Float) {
        guard let car = simulation.cars.first(where: { $0.id == carID }) else { return }
        var random = SeededUnitRandom(seed: UInt64(bitPattern: Int64(carID.uuidString.hashValue)) ^ 0xC0FFEE)
        let side = (random.next() - 0.5) * 2
        let pose = car.lastPose
        let axis = simd_normalize(left + simd_normalize(up) * 0.25)
        crashAnimations[carID] = CrashAnimation(
            position: position + up * 0.28,
            velocity: forward * (1.1 + speed * 0.22) + up * (1.6 + speed * 0.05) + left * side * 0.9,
            orientation: pose.orientation,
            axis: axis,
            angularSpeed: 4.2 + abs(side) * 2.8,
            elapsed: 0
        )
    }

    private func updateCarNodes(dt: Float) {
        for car in simulation.cars {
            guard let node = carNodes[car.id] else { continue }
            if var crash = crashAnimations[car.id] {
                crash.elapsed += dt
                crash.velocity.y -= 9.8 * dt
                crash.position += crash.velocity * dt
                if crash.position.y < 0.18 {
                    crash.position.y = 0.18
                    crash.velocity.y = -crash.velocity.y * 0.18
                    crash.velocity.x *= 0.58
                    crash.velocity.z *= 0.58
                    crash.angularSpeed *= 0.88
                }
                let spin = simd_quatf(angle: crash.angularSpeed * dt, axis: crash.axis)
                crash.orientation = simd_normalize(spin * crash.orientation)
                crashAnimations[car.id] = crash
                node.root.simdPosition = crash.position
                node.root.simdOrientation = crash.orientation
                node.update(dt: dt, speed: 0, steering: 0, braking: false, lateralAcceleration: 0, reduceMotion: settings.reduceMotion)
                continue
            }

            if car.state == .deslot {
                beginCrash(carID: car.id,
                           position: car.lastPose.position,
                           forward: car.lastPose.forward,
                           up: car.lastPose.up,
                           left: car.lastPose.left,
                           speed: 2)
                continue
            }

            let pose = car.lanePath.pose(at: car.distance)
            node.root.simdPosition = pose.position + pose.up * 0.012
            node.root.simdOrientation = pose.orientation

            let ahead = car.lanePath.pose(at: car.distance + 0.36)
            let turn = simd_dot(simd_cross(pose.forward, ahead.forward), pose.up)
            let steering = max(-0.55, min(0.55, turn * 2.8))
            let lateral = car.speed * car.speed * pose.curvature * (turn >= 0 ? 1 : -1)
            node.update(dt: dt,
                        speed: car.speed,
                        steering: steering,
                        braking: car.lastBraking,
                        lateralAcceleration: lateral,
                        reduceMotion: settings.reduceMotion)
        }
    }

    private func updateCamera(dt: Float) {
        guard let player = simulation.cars.first(where: { $0.isPlayer }) else { return }
        let crash = crashAnimations[player.id]
        let orientation = crash?.orientation ?? player.lanePath.pose(at: player.distance).orientation
        let position = crash?.position ?? player.lanePath.pose(at: player.distance).position
        let forward = orientation.act(SIMD3<Float>(0, 0, -1))
        let up = orientation.act(SIMD3<Float>(0, 1, 0))
        let left = -orientation.act(SIMD3<Float>(1, 0, 0))
        let speed = crash == nil ? player.speed : 0

        let desiredPosition = position + up * 2.0 - forward * (5.4 + speed * 0.12) + left * 0.22
        let desiredTarget = position + up * 0.45 + forward * (5.4 + speed * 0.18)
        if !chaseInitialized {
            chasePosition = desiredPosition
            chaseTarget = desiredTarget
            chaseInitialized = true
        }
        let posBlend = 1 - exp(-max(0, dt) * 9)
        let targetBlend = 1 - exp(-max(0, dt) * 12)
        chasePosition += (desiredPosition - chasePosition) * posBlend
        chaseTarget += (desiredTarget - chaseTarget) * targetBlend
        chaseCamera.simdPosition = chasePosition
        let cameraUp = simd_normalize(up + SIMD3<Float>(0, 0.12, 0))
        chaseCamera.look(at: SCNVector3(chaseTarget),
                         up: SCNVector3(cameraUp),
                         localFront: SCNVector3(0, 0, -1))
        chaseCamera.camera?.fieldOfView = CGFloat(55 + min(13, Double(max(0, speed)) * 1.15))

        if let camera = firstPersonCamera.camera {
            camera.fieldOfView = CGFloat(72 + min(10, Double(max(0, speed)) * 0.9))
        }
        if !settings.reduceMotion {
            let shake = max(0, speed - 6.0) * 0.0012
            firstPersonCamera.simdPosition = playerCarNode.cockpitAnchor
                + SIMD3<Float>(0, 0.03 + sin(Float(lastFrameTime) * 31) * shake, 0)
        }

        if cameraMode == .topDown {
            topCamera.camera?.orthographicScale = CGFloat(max(6, max(builtTrack.size.x, builtTrack.size.z) * 0.72))
        }
    }

    private func updateStartLights() {
        let materials = world.startLights
        guard !materials.isEmpty else { return }
        let red = NSColor(calibratedRed: 1.0, green: 0.12, blue: 0.05, alpha: 1)
        let green = NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.35, alpha: 1)
        let dim = NSColor(calibratedWhite: 0.08, alpha: 1)

        var color = dim
        var intensity: CGFloat = 0.15
        if simulation.phase == .countdown {
            let elapsed = 3.6 - simulation.countdown
            let lit = min(5, max(0, Int(elapsed / 0.55) + 1))
            for (index, material) in materials.enumerated() {
                let on = index < lit
                material.emission.contents = on ? red : dim
                material.emission.intensity = on ? 2.4 : 0.1
            }
            return
        } else if simulation.phase == .racing, simulation.raceTime < 1.25 {
            color = green
            intensity = 2.6
        }
        for material in materials {
            material.emission.contents = color
            material.emission.intensity = intensity
        }
    }

    private func updateAudio() {
        guard let player = simulation.cars.first(where: { $0.isPlayer }) else { return }
        let active = (simulation.phase == .racing || simulation.phase == .countdown)
            && player.state != .finished
            && player.state != .deslot
        AudioDirector.shared.updateMotor(index: 0,
                                         speed: player.speed,
                                         throttle: player.lastThrottle,
                                         active: active)
        if let opponent = simulation.cars.first(where: { !$0.isPlayer }) {
            let opponentActive = (simulation.phase == .racing || simulation.phase == .countdown)
                && opponent.state != .finished
                && opponent.state != .deslot
            AudioDirector.shared.updateMotor(index: 1,
                                             speed: opponent.speed,
                                             throttle: opponent.lastThrottle,
                                             active: opponentActive)
        }
    }

    private func publishTelemetry(force: Bool = false) {
        telemetryTimer += 1.0 / 60.0
        guard force || telemetryTimer > 0.055 else { return }
        telemetryTimer = 0
        let telemetry = simulation.telemetry(cameraMode: cameraMode)
        DispatchQueue.main.async { [weak self] in
            self?.session.publish(telemetry)
        }
    }

    private func reportFinishIfNeeded() {
        guard let result = simulation.result, !didReportFinish else { return }
        didReportFinish = true
        AudioDirector.shared.setMusicMode(.final)
        DispatchQueue.main.async { [weak self] in
            self?.session.finish(result)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let code = event.keyCode
        let repeatEvent = event.isARepeat
        switch code {
        case 13, 126, 49:
            session.input.setThrottle(true)
            return true
        case 1, 125:
            session.input.setBrake(true)
            return true
        case 56, 60:
            session.input.setBoost(true)
            return true
        case 8:
            if !repeatEvent { session.cycleCamera() }
            return true
        case 15:
            if !repeatEvent { session.restart() }
            return true
        case 53, 35:
            if !repeatEvent { session.togglePause() }
            return true
        case 46:
            if !repeatEvent { session.toggleMute() }
            return true
        default:
            return false
        }
    }

    private func handleKeyUp(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 13, 126, 49:
            session.input.setThrottle(false)
            return true
        case 1, 125:
            session.input.setBrake(false)
            return true
        case 56, 60:
            session.input.setBoost(false)
            return true
        default:
            return false
        }
    }

    private func setupGamepads() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(gameControllerConnected),
                                               name: .GCControllerDidConnect,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(gameControllerDisconnected),
                                               name: .GCControllerDidDisconnect,
                                               object: nil)
        for controller in GCController.controllers() {
            configure(controller)
        }
    }

    @objc private func gameControllerConnected(_ note: Notification) {
        if let controller = note.object as? GCController {
            configure(controller)
        }
    }

    @objc private func gameControllerDisconnected(_ note: Notification) {
        session.input.setThrottle(false)
        session.input.setBrake(false)
        session.input.setBoost(false)
    }

    private func configure(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        pad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.session.input.setThrottle(value > 0.08)
        }
        pad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.session.input.setBrake(value > 0.08)
        }
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.session.input.setBoost(pressed)
        }
        pad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.session.cycleCamera() }
        }
        pad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.session.restart() }
        }
        pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.session.togglePause() }
        }
    }

    private func updateCloudSnapshotIfNeeded(dt: Float) {
        guard settings.cloudAIEnabled else { return }
        cloudTick += Double(dt)
        guard cloudTick > 0.20 else { return }
        cloudTick = 0
        guard let ai = simulation.cars.first(where: { !$0.isPlayer }) else { return }
        let player = simulation.cars.first(where: { $0.isPlayer })
        var lookahead: [CloudLookahead] = []
        for index in 0..<8 {
            let distance = ai.distance + Float(index) * 1.6
            let pose = ai.lanePath.pose(at: distance)
            let surface: String
            if pose.kind.isLoop { surface = "loop" }
            else if pose.kind.isCurve { surface = "curve" }
            else if pose.kind.isBridge { surface = "bridge" }
            else { surface = "straight" }
            lookahead.append(CloudLookahead(distance: Double(index) * 1.6,
                                            curvature: Double(pose.curvature),
                                            surface: surface,
                                            loop: pose.kind.isLoop))
        }
        let gap = player.map { Double(($0.progress - ai.progress) * ai.lanePath.length) } ?? 0
        let snapshot = CloudAITelemetry(
            sessionId: cloudSessionID,
            trackId: builtTrack.layout.id.uuidString,
            difficulty: config.difficulty.rawValue,
            speed: Double(ai.speed),
            maxSpeed: Double(ai.stats.topSpeed),
            opponentGap: gap,
            boostAvailable: ai.boostCharges > 0,
            lookahead: lookahead
        )
        cloudSnapshot.withLock { $0 = snapshot }
    }

    private func startCloudLoopIfNeeded() {
        guard settings.cloudAIEnabled else { return }
        let configuration = CloudAIConfiguration(settings: settings)
        let interval = configuration.provider.pollIntervalNanoseconds
        let maximumAge = configuration.provider.cloudControlMaximumAge
        cloudTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard let self, !Task.isCancelled else { return }
                let snapshot = self.cloudSnapshot.withLock { $0 }
                guard let snapshot else { continue }
                if let response = await self.cloudService.predict(configuration: configuration,
                                                                  telemetry: snapshot) {
                    self.simulation.setCloudControl(throttle: Float(response.throttle),
                                                    brake: Float(response.brake),
                                                    maxAge: maximumAge)
                } else {
                    self.simulation.setCloudControl(throttle: nil, brake: nil)
                }
            }
        }
    }
}

struct RaceSceneView: NSViewRepresentable {
    let config: RaceConfig
    let settings: AppSettings
    let session: RaceSession

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> RaceSCNView {
        let view = RaceSCNView()
        let controller = RaceSceneController(config: config, settings: settings, session: session)
        context.coordinator.controller = controller
        controller.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: RaceSCNView, context: Context) {
        context.coordinator.controller?.updateSettings(settings)
    }

    static func dismantleNSView(_ nsView: RaceSCNView, coordinator: Coordinator) {
        coordinator.controller?.teardown()
        coordinator.controller = nil
        nsView.delegate = nil
    }

    final class Coordinator {
        var controller: RaceSceneController?
    }
}
