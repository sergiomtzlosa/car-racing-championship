import AppKit
import SceneKit
import SwiftUI

final class ShowcaseSceneController {
    let scene = SCNScene()
    private let turntable = SCNNode()
    private let cameraNode = SCNNode()
    private var carNode: RaceCarNode?
    private var currentConfig: CarConfig?
    private var autoRotate = true

    init(config: CarConfig, quality: GraphicsQuality) {
        buildEnvironment()
        update(config: config, quality: quality)
        setAutoRotate(true)
    }

    func update(config: CarConfig, quality: GraphicsQuality) {
        guard config != currentConfig else { return }
        currentConfig = config
        carNode?.root.removeFromParentNode()
        let car = CarSceneFactory.makeCar(config: config, quality: quality)
        car.root.position = SCNVector3(0, 0.12, 0)
        turntable.addChildNode(car.root)
        carNode = car
    }

    func setAutoRotate(_ value: Bool) {
        guard value != autoRotate || turntable.action(forKey: "turntable") == nil else { return }
        autoRotate = value
        turntable.removeAction(forKey: "turntable")
        if value {
            let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 28))
            spin.timingMode = .easeInEaseOut
            turntable.runAction(spin, forKey: "turntable")
        } else {
            turntable.eulerAngles.y = 0
        }
    }

    private func buildEnvironment() {
        scene.background.contents = NSColor(calibratedRed: 0.025, green: 0.032, blue: 0.042, alpha: 1)
        scene.lightingEnvironment.contents = TextureFactory.studioEnvironment
        scene.lightingEnvironment.intensity = 1.25

        let platform = SCNCylinder(radius: 2.55, height: 0.16)
        platform.radialSegmentCount = 96
        let platformMaterial = SCNMaterial()
        platformMaterial.lightingModel = .physicallyBased
        platformMaterial.diffuse.contents = NSColor(calibratedWhite: 0.075, alpha: 1)
        platformMaterial.roughness.contents = NSNumber(value: 0.28)
        platformMaterial.metalness.contents = NSNumber(value: 0.62)
        platformMaterial.clearCoat.contents = NSNumber(value: 0.4)
        platform.firstMaterial = platformMaterial
        let platformNode = SCNNode(geometry: platform)
        platformNode.position = SCNVector3(0, -0.12, 0)
        scene.rootNode.addChildNode(platformNode)

        let rim = SCNTorus(ringRadius: 2.53, pipeRadius: 0.035)
        rim.ringSegmentCount = 96
        rim.pipeSegmentCount = 12
        let rimMaterial = SCNMaterial()
        rimMaterial.lightingModel = .physicallyBased
        rimMaterial.diffuse.contents = NSColor(calibratedRed: 0.95, green: 0.29, blue: 0.14, alpha: 1)
        rimMaterial.emission.contents = NSColor(calibratedRed: 0.45, green: 0.08, blue: 0.02, alpha: 1)
        rimMaterial.emission.intensity = 0.8
        rimMaterial.metalness.contents = NSNumber(value: 0.6)
        rim.firstMaterial = rimMaterial
        let rimNode = SCNNode(geometry: rim)
        rimNode.position = SCNVector3(0, 0.015, 0)
        rimNode.eulerAngles.x = .pi / 2
        scene.rootNode.addChildNode(rimNode)

        let innerRing = SCNTorus(ringRadius: 2.30, pipeRadius: 0.012)
        innerRing.ringSegmentCount = 96
        innerRing.pipeSegmentCount = 8
        let innerMaterial = SCNMaterial()
        innerMaterial.lightingModel = .physicallyBased
        innerMaterial.diffuse.contents = NSColor(calibratedWhite: 0.8, alpha: 1)
        innerMaterial.metalness.contents = NSNumber(value: 0.9)
        innerMaterial.roughness.contents = NSNumber(value: 0.2)
        innerRing.firstMaterial = innerMaterial
        let innerNode = SCNNode(geometry: innerRing)
        innerNode.position = SCNVector3(0, 0.02, 0)
        innerNode.eulerAngles.x = .pi / 2
        scene.rootNode.addChildNode(innerNode)

        let backdrop = SCNBox(width: 22, height: 11, length: 0.2, chamferRadius: 0.3)
        let backdropMaterial = SCNMaterial()
        backdropMaterial.lightingModel = .physicallyBased
        backdropMaterial.diffuse.contents = NSColor(calibratedRed: 0.035, green: 0.045, blue: 0.06, alpha: 1)
        backdropMaterial.roughness.contents = NSNumber(value: 0.8)
        backdrop.firstMaterial = backdropMaterial
        let backdropNode = SCNNode(geometry: backdrop)
        backdropNode.position = SCNVector3(0, 3.6, -4.2)
        scene.rootNode.addChildNode(backdropNode)

        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 80
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.vignettingIntensity = 0.25
        camera.saturation = 1.05
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(4.2, 2.55, 5.5)
        cameraNode.look(at: SCNVector3(0, 0.82, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(cameraNode)

        scene.rootNode.addChildNode(turntable)
        addKeyLight()
        addFillLight()
        addRimLight()
    }

    private func addKeyLight() {
        let light = SCNLight()
        light.type = .spot
        light.intensity = 1250
        light.color = NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.85, alpha: 1)
        light.spotInnerAngle = 34
        light.spotOuterAngle = 72
        light.castsShadow = true
        light.shadowMode = .deferred
        light.shadowSampleCount = 24
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        light.shadowRadius = 4
        light.attenuationStartDistance = 2
        light.attenuationEndDistance = 16
        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(4.2, 6.4, 4.8)
        node.look(at: SCNVector3(0, 0.5, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(node)
    }

    private func addFillLight() {
        let light = SCNLight()
        light.type = .omni
        light.intensity = 520
        light.color = NSColor(calibratedRed: 0.48, green: 0.66, blue: 1.0, alpha: 1)
        light.attenuationStartDistance = 2
        light.attenuationEndDistance = 14
        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(-4.5, 2.8, 2.8)
        scene.rootNode.addChildNode(node)
    }

    private func addRimLight() {
        let light = SCNLight()
        light.type = .spot
        light.intensity = 950
        light.color = NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.24, alpha: 1)
        light.spotInnerAngle = 26
        light.spotOuterAngle = 60
        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(-1.5, 4.4, -4.0)
        node.look(at: SCNVector3(0, 0.8, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(node)
    }
}

struct ShowcaseSceneView: NSViewRepresentable {
    let config: CarConfig
    var qualitative: GraphicsQuality = .high
    var interactive = false
    var autoRotate = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let controller = ShowcaseSceneController(config: config, quality: qualitative)
        context.coordinator.controller = controller
        let view = SCNView()
        view.scene = controller.scene
        view.pointOfView = controller.scene.rootNode.childNodes.first(where: { $0.camera != nil })
        view.allowsCameraControl = interactive
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = NSColor(calibratedRed: 0.025, green: 0.032, blue: 0.042, alpha: 1)
        controller.setAutoRotate(autoRotate)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.controller?.update(config: config, quality: qualitative)
        context.coordinator.controller?.setAutoRotate(autoRotate)
        nsView.allowsCameraControl = interactive
    }

    static func dismantleNSView(_ nsView: SCNView, coordinator: Coordinator) {
        nsView.isPlaying = false
        coordinator.controller = nil
    }

    final class Coordinator {
        var controller: ShowcaseSceneController?
    }
}
