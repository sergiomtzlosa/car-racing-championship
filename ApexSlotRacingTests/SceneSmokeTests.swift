import AppKit
import Metal
import SceneKit
import XCTest
import simd
@testable import ApexSlotRacing

@MainActor
final class SceneSmokeTests: XCTestCase {
    func testAllBuiltInWorldsAndCarsBuild() {
        for track in TrackCatalog.builtIn {
            let built = TrackPathBuilder.build(track)
            let world = TrackSceneBuilder.buildWorld(built: built,
                                                     environment: track.environment,
                                                     quality: .medium)
            XCTAssertGreaterThan(world.scene.rootNode.childNodes.count, 2, track.name)
            XCTAssertGreaterThan(world.trackRoot.childNodes.count, 8, track.name)
            XCTAssertFalse(world.startLights.isEmpty, track.name)
        }

        for model in CarModelKind.allCases {
            let node = CarSceneFactory.makeCar(config: .standard(for: model), quality: .medium)
            XCTAssertGreaterThan(recursiveNodeCount(node.root), 10, model.displayName)
            XCTAssertGreaterThan(node.wheelsRoot.childNodes.count, 2, model.displayName)
            XCTAssertFalse(node.cockpitAnchor.x.isNaN)
        }
    }

    func testBuiltInTrackOverviewsRender() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }
        for track in TrackCatalog.builtIn {
            let built = TrackPathBuilder.build(track)
            let world = TrackSceneBuilder.buildWorld(built: built,
                                                     environment: track.environment,
                                                     quality: .medium)
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            camera.orthographicScale = CGFloat(max(built.size.x, built.size.z) * 0.64 + 2)
            camera.zNear = 0.1
            camera.zFar = 200
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(built.center.x, 30, built.center.z)
            cameraNode.look(at: SCNVector3(built.center.x, 0, built.center.z),
                            up: SCNVector3(0, 0, -1),
                            localFront: SCNVector3(0, 0, -1))
            world.scene.rootNode.addChildNode(cameraNode)

            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = world.scene
            renderer.pointOfView = cameraNode
            renderer.autoenablesDefaultLighting = false
            let image = renderer.snapshot(atTime: 0,
                                          with: CGSize(width: 1200, height: 800),
                                          antialiasingMode: .multisampling4X)
            XCTAssertGreaterThan(image.size.width, 100, track.name)
            let filename = track.name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
            try writePNG(image, to: "/tmp/apex-track-\(filename).png")

            let perspectiveCamera = SCNCamera()
            perspectiveCamera.fieldOfView = 48
            perspectiveCamera.zNear = 0.1
            perspectiveCamera.zFar = 300
            let perspectiveNode = SCNNode()
            perspectiveNode.camera = perspectiveCamera
            perspectiveNode.position = SCNVector3(built.center.x + 12,
                                                  built.center.y + 10,
                                                  built.center.z + 13)
            perspectiveNode.look(at: SCNVector3(built.center.x, 0, built.center.z),
                                 up: SCNVector3(0, 1, 0),
                                 localFront: SCNVector3(0, 0, -1))
            world.scene.rootNode.addChildNode(perspectiveNode)
            renderer.pointOfView = perspectiveNode
            let perspective = renderer.snapshot(atTime: 0,
                                                with: CGSize(width: 1200, height: 800),
                                                antialiasingMode: .multisampling4X)
            try writePNG(perspective, to: "/tmp/apex-track-\(filename)-perspective.png")
        }
    }

    func testSunsetWorldRendersOffscreen() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }
        let built = TrackPathBuilder.build(TrackCatalog.sunsetSpeedway)
        let world = TrackSceneBuilder.buildWorld(built: built,
                                                 environment: .dusk,
                                                 quality: .high)
        let playerCar = CarSceneFactory.makeCar(config: .standard(for: .gt), quality: .high)
        let rivalCar = CarSceneFactory.makeCar(config: .standard(for: .rally), quality: .high)
        let playerPose = built.lanePaths[0].pose(at: 0)
        let rivalPose = built.lanePaths[1].pose(at: 0)
        playerCar.root.simdPosition = playerPose.position + playerPose.up * 0.02
        playerCar.root.simdOrientation = playerPose.orientation
        rivalCar.root.simdPosition = rivalPose.position + rivalPose.up * 0.02
        rivalCar.root.simdOrientation = rivalPose.orientation
        world.scene.rootNode.addChildNode(playerCar.root)
        world.scene.rootNode.addChildNode(rivalCar.root)

        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear = 0.1
        camera.zFar = 200
        camera.wantsHDR = true
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(built.center.x + 12,
                                         built.center.y + 14,
                                         built.center.z + 12)
        cameraNode.look(at: SCNVector3(built.center.x, 0, built.center.z),
                        up: SCNVector3(0, 1, 0),
                        localFront: SCNVector3(0, 0, -1))
        world.scene.rootNode.addChildNode(cameraNode)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = world.scene
        renderer.pointOfView = cameraNode
        renderer.autoenablesDefaultLighting = false
        let image = renderer.snapshot(atTime: 0,
                                      with: CGSize(width: 1280, height: 800),
                                      antialiasingMode: .multisampling4X)
        XCTAssertGreaterThan(image.size.width, 100)
        XCTAssertGreaterThan(image.size.height, 100)
        try writePNG(image, to: "/tmp/apex-sunset-render.png")

        camera.fieldOfView = 32
        cameraNode.position = SCNVector3(playerPose.position.x + 3.4,
                                         playerPose.position.y + 2.4,
                                         playerPose.position.z + 3.6)
        cameraNode.look(at: SCNVector3(playerPose.position.x,
                                       playerPose.position.y + 0.25,
                                       playerPose.position.z),
                        up: SCNVector3(0, 1, 0),
                        localFront: SCNVector3(0, 0, -1))
        let closeImage = renderer.snapshot(atTime: 0,
                                           with: CGSize(width: 1280, height: 800),
                                           antialiasingMode: .multisampling4X)
        try writePNG(closeImage, to: "/tmp/apex-car-render.png")
    }

    func testRaceSceneViewAttachesRendersAndTearsDown() throws {
        let config = TestSupport.config(track: TrackCatalog.sunsetSpeedway, laps: 3)
        let session = RaceSession(settings: .default)
        let controller = RaceSceneController(config: config, settings: .default, session: session)
        let view = RaceSCNView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        let window = NSWindow(contentRect: view.frame,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFront(nil)
        controller.attach(to: view)
        view.isPlaying = true
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        XCTAssertEqual(session.telemetry.phase, .countdown)
        XCTAssertEqual(controller.cameraMode, .thirdPerson)
        XCTAssertEqual(view.pointOfView?.name, "chase-camera")
        guard let chase = view.scene?.rootNode.childNode(withName: "chase-camera", recursively: true),
              let player = controller.simulation.cars.first(where: { $0.isPlayer }) else {
            return XCTFail("Race camera or player car missing")
        }
        let pose = player.lanePath.pose(at: player.distance)
        let distance = simd_distance(chase.simdPosition, pose.position)
        XCTAssertGreaterThan(distance, 4.0, "Chase camera should sit behind and above the car")
        XCTAssertGreaterThan(view.scene?.rootNode.childNodes.count ?? 0, 2)
        let image = view.snapshot()
        XCTAssertGreaterThan(image.size.width, 100)
        try writePNG(image, to: "/tmp/apex-race-render.png")

        for expected in [CameraMode.firstPerson, CameraMode.topDown] {
            while controller.cameraMode != expected {
                controller.cycleCamera()
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            let modeImage = view.snapshot()
            try writePNG(modeImage, to: "/tmp/apex-camera-\(expected.rawValue).png")
            XCTAssertEqual(view.pointOfView?.name, expected == .firstPerson ? "cockpit-camera" : "top-camera")
        }
        controller.teardown()
        window.orderOut(nil)
    }

    func testShowcaseSceneBuilds() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }
        for model in CarModelKind.allCases {
            let showcase = ShowcaseSceneController(config: .standard(for: model), quality: .high)
            guard let cameraNode = showcase.scene.rootNode.childNodes.first(where: { $0.camera != nil }) else {
                return XCTFail("Missing showcase camera for \(model.displayName)")
            }
            XCTAssertGreaterThan(showcase.scene.rootNode.childNodes.count, 2)
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = showcase.scene
            renderer.pointOfView = cameraNode
            renderer.autoenablesDefaultLighting = false
            let image = renderer.snapshot(atTime: 0,
                                          with: CGSize(width: 900, height: 900),
                                          antialiasingMode: .multisampling4X)
            let suffix = model == .gt ? "" : "-\(model.rawValue)"
            try writePNG(image, to: "/tmp/apex-showcase-render\(suffix).png")
        }
    }

    private func writePNG(_ image: NSImage, to path: String) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ApexRender", code: 1)
        }
        XCTAssertGreaterThan(png.count, 10_000)
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func recursiveNodeCount(_ node: SCNNode) -> Int {
        1 + node.childNodes.reduce(0) { $0 + recursiveNodeCount($1) }
    }
}
