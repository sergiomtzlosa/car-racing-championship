import AppKit
import SceneKit
import SwiftUI
import simd

final class TrackEditorSceneController {
    weak var view: SCNView?
    private(set) var layout: TrackLayout
    private(set) var revision: Int
    private(set) var quality: GraphicsQuality
    var resetSignal: Int

    private var cameraNode: SCNNode?
    private var savedCameraTransform: SCNMatrix4?
    private var savedOrthographicScale: CGFloat?

    init(view: SCNView, layout: TrackLayout, revision: Int, quality: GraphicsQuality, resetSignal: Int) {
        self.view = view
        self.layout = layout
        self.revision = revision
        self.quality = quality
        self.resetSignal = resetSignal
        configureView()
        rebuild()
    }

    func update(layout: TrackLayout, revision: Int, quality: GraphicsQuality) {
        saveCamera()
        self.layout = layout
        self.revision = revision
        self.quality = quality
        rebuild()
    }

    func resetCamera() {
        savedCameraTransform = nil
        savedOrthographicScale = nil
        rebuild()
    }

    private func configureView() {
        guard let view else { return }
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true
        view.backgroundColor = NSColor(calibratedRed: 0.012, green: 0.016, blue: 0.022, alpha: 1)
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
    }

    private func saveCamera() {
        guard let point = view?.pointOfView, let camera = point.camera else { return }
        savedCameraTransform = point.transform
        savedOrthographicScale = camera.orthographicScale
    }

    private func rebuild() {
        guard let view else { return }
        let built = TrackPathBuilder.build(layout)
        let world = TrackSceneBuilder.buildWorld(built: built,
                                                 environment: layout.environment,
                                                 quality: quality)
        let scene = world.scene
        scene.background.contents = NSColor(calibratedRed: 0.012, green: 0.016, blue: 0.022, alpha: 1)

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = savedOrthographicScale ?? CGFloat(max(6, max(built.size.x, built.size.z) * 0.80))
        camera.zNear = 0.1
        camera.zFar = 240
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        let node = SCNNode()
        node.camera = camera
        if let savedCameraTransform {
            node.transform = savedCameraTransform
        } else {
            node.position = SCNVector3(built.center.x, max(14, built.size.y + 12), built.center.z + 0.001)
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        }
        scene.rootNode.addChildNode(node)
        cameraNode = node

        addMarkers(built: built, to: scene)
        view.scene = scene
        view.pointOfView = node
    }

    private func addMarkers(built: BuiltTrack, to scene: SCNScene) {
        let start = built.startFrame
        let startNode = marker(color: NSColor(calibratedRed: 0.10, green: 1.0, blue: 0.38, alpha: 1),
                               at: start.position + start.up * 0.12)
        scene.rootNode.addChildNode(startNode)

        if let end = built.centerFrames.last {
            let endColor = built.isClosed
                ? NSColor(calibratedRed: 0.10, green: 1.0, blue: 0.38, alpha: 1)
                : NSColor(calibratedRed: 1.0, green: 0.18, blue: 0.10, alpha: 1)
            let endNode = marker(color: endColor, at: end.position + end.up * 0.12)
            scene.rootNode.addChildNode(endNode)
            endNode.runAction(.repeatForever(.sequence([
                .scale(to: 1.35, duration: 0.55),
                .scale(to: 0.95, duration: 0.55)
            ])))
        }
    }

    private func marker(color: NSColor, at position: SIMD3<Float>) -> SCNNode {
        let sphere = SCNSphere(radius: 0.24)
        sphere.segmentCount = 24
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 1.2
        sphere.firstMaterial = material
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(position.x, position.y + 0.2, position.z)
        node.castsShadow = false
        return node
    }
}

struct TrackEditorSceneView: NSViewRepresentable {
    let layout: TrackLayout
    let revision: Int
    let quality: GraphicsQuality
    let resetSignal: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let controller = TrackEditorSceneController(view: view,
                                                    layout: layout,
                                                    revision: revision,
                                                    quality: quality,
                                                    resetSignal: resetSignal)
        context.coordinator.controller = controller
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        guard let controller = context.coordinator.controller else { return }
        if resetSignal != controller.resetSignal {
            controller.resetSignal = resetSignal
            controller.resetCamera()
        }
        if revision != controller.revision {
            controller.update(layout: layout, revision: revision, quality: quality)
        }
    }

    static func dismantleNSView(_ nsView: SCNView, coordinator: Coordinator) {
        nsView.isPlaying = false
        nsView.scene = nil
        coordinator.controller = nil
    }

    final class Coordinator {
        var controller: TrackEditorSceneController?
    }
}
