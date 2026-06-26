import AppKit
import SceneKit
import simd

struct WorldBuildResult {
    var scene: SCNScene
    var trackRoot: SCNNode
    var environmentRoot: SCNNode
    var startLights: [SCNMaterial]
    var builtTrack: BuiltTrack
}

enum TrackSceneBuilder {
    static let trackHalfWidth: Float = 1.44
    static let railHeight: Float = 0.115
    static let deckThickness: Float = 0.10

    static func buildWorld(built: BuiltTrack, environment: TrackEnvironment, quality: GraphicsQuality) -> WorldBuildResult {
        let scene = SCNScene()
        scene.background.contents = TextureFactory.roomBackdrop
        scene.lightingEnvironment.contents = environment == .night ? TextureFactory.nightEnvironment : TextureFactory.studioEnvironment
        scene.lightingEnvironment.intensity = environment == .night ? 0.7 : 1.15

        let trackRoot = buildTrack(built: built, environment: environment, quality: quality)
        scene.rootNode.addChildNode(trackRoot)

        let environmentRoot = buildEnvironment(built: built, environment: environment)
        scene.rootNode.addChildNode(environmentRoot)

        addLighting(to: scene, built: built, environment: environment)

        let startLights = buildStartGantry(built: built, root: trackRoot)

        return WorldBuildResult(scene: scene,
                                trackRoot: trackRoot,
                                environmentRoot: environmentRoot,
                                startLights: startLights,
                                builtTrack: built)
    }

    // MARK: - Track construction

    private static func buildTrack(built: BuiltTrack,
                                   environment: TrackEnvironment,
                                   quality: GraphicsQuality) -> SCNNode {
        let root = SCNNode()
        root.name = "track"

        guard !built.centerFrames.isEmpty else { return root }

        let trackMaterial = SCNMaterial()
        trackMaterial.lightingModel = .physicallyBased
        trackMaterial.diffuse.contents = TextureFactory.trackSurface
        trackMaterial.diffuse.wrapS = .repeat
        trackMaterial.diffuse.wrapT = .repeat
        trackMaterial.metalness.contents = NSNumber(value: 0.05)
        trackMaterial.roughness.contents = NSNumber(value: 0.42)
        trackMaterial.clearCoat.contents = NSNumber(value: 0.25)
        trackMaterial.clearCoatRoughness.contents = NSNumber(value: 0.22)
        trackMaterial.normal.contents = TextureFactory.metalFlakeNormal
        trackMaterial.normal.intensity = 0.08
        trackMaterial.normal.wrapS = .repeat
        trackMaterial.normal.wrapT = .repeat

        let underMaterial = plastic(color: NSColor(calibratedWhite: 0.045, alpha: 1), roughness: 0.52)
        let railMaterial = plastic(color: NSColor(calibratedWhite: 0.075, alpha: 1), roughness: 0.35)
        let whiteMaterial = plastic(color: NSColor(calibratedWhite: 0.90, alpha: 1), roughness: 0.38)
        let slotMaterial = SCNMaterial()
        slotMaterial.lightingModel = .physicallyBased
        slotMaterial.diffuse.contents = TextureFactory.slot
        slotMaterial.diffuse.wrapS = .repeat
        slotMaterial.diffuse.wrapT = .repeat
        slotMaterial.roughness.contents = NSNumber(value: 0.8)
        slotMaterial.metalness.contents = NSNumber(value: 0.0)
        let curbMaterial = SCNMaterial()
        curbMaterial.lightingModel = .physicallyBased
        curbMaterial.diffuse.contents = TextureFactory.curb
        curbMaterial.diffuse.wrapS = .repeat
        curbMaterial.diffuse.wrapT = .repeat
        curbMaterial.roughness.contents = NSNumber(value: 0.33)
        curbMaterial.clearCoat.contents = NSNumber(value: 0.2)
        curbMaterial.isDoubleSided = true

        // Deck.
        let deck = ribbonGeometry(frames: built.centerFrames,
                                  leftOffset: trackHalfWidth,
                                  rightOffset: -trackHalfWidth,
                                  upOffset: 0,
                                  normalMultiplier: 1,
                                  uvScale: 2.4,
                                  material: trackMaterial)
        root.addChildNode(SCNNode(geometry: deck))

        // Underside and edge walls.
        let under = ribbonGeometry(frames: built.centerFrames,
                                   leftOffset: trackHalfWidth,
                                   rightOffset: -trackHalfWidth,
                                   upOffset: -deckThickness,
                                   normalMultiplier: -1,
                                   uvScale: 2.4,
                                   material: underMaterial)
        root.addChildNode(SCNNode(geometry: under))
        for offset in [trackHalfWidth, -trackHalfWidth] {
            let wall = wallGeometry(frames: built.centerFrames,
                                    offset: offset,
                                    bottom: -deckThickness,
                                    top: 0.015,
                                    outwardSign: offset > 0 ? 1 : -1,
                                    material: underMaterial)
            root.addChildNode(SCNNode(geometry: wall))
        }

        // Outer rails with a narrow top cap.
        for offset in [trackHalfWidth + 0.09, -(trackHalfWidth + 0.09)] {
            let wall = wallGeometry(frames: built.centerFrames,
                                    offset: offset,
                                    bottom: 0,
                                    top: railHeight,
                                    outwardSign: offset > 0 ? 1 : -1,
                                    material: railMaterial)
            root.addChildNode(SCNNode(geometry: wall))
            let cap = ribbonGeometry(frames: built.centerFrames,
                                     leftOffset: offset + 0.045,
                                     rightOffset: offset - 0.045,
                                     upOffset: railHeight,
                                     normalMultiplier: 1,
                                     uvScale: 1.0,
                                     material: railMaterial)
            root.addChildNode(SCNNode(geometry: cap))
        }

        // White lane edge markings.
        for offset in [trackHalfWidth - 0.11, -(trackHalfWidth - 0.11), 0.0] {
            let line = ribbonGeometry(frames: built.centerFrames,
                                      leftOffset: offset + 0.025,
                                      rightOffset: offset - 0.025,
                                      upOffset: 0.003,
                                      normalMultiplier: 1,
                                      uvScale: 1.0,
                                      material: whiteMaterial)
            root.addChildNode(SCNNode(geometry: line))
        }

        // Lane slots follow the lane paths, including crossover geometry.
        for lane in built.lanePaths {
            let slot = ribbonGeometry(frames: lane.frames,
                                      leftOffset: 0.035,
                                      rightOffset: -0.035,
                                      upOffset: 0.006,
                                      normalMultiplier: 1,
                                      uvScale: 1.0,
                                      material: slotMaterial)
            root.addChildNode(SCNNode(geometry: slot))
        }

        // Curbs only on curved pieces.
        let curveFrames = built.centerFrames.filter { $0.kind.isCurve }
        if !curveFrames.isEmpty {
            for side in [Float(1), Float(-1)] {
                let outer = ribbonGeometry(frames: curveFrames,
                                           leftOffset: side * (trackHalfWidth + 0.03),
                                           rightOffset: side * (trackHalfWidth + 0.19),
                                           upOffset: 0.005,
                                           normalMultiplier: 1,
                                           uvScale: 1.2,
                                           material: curbMaterial)
                root.addChildNode(SCNNode(geometry: outer))
            }
        }

        // Joint bands. A one-piece (or empty) layout has no internal joint.
        if built.pieceRanges.count > 1 {
            for index in 1..<built.pieceRanges.count {
                let range = built.pieceRanges[index]
                guard range.lowerBound < built.length else { continue }
                let pose = built.lanePaths.first?.pose(at: range.lowerBound) ?? built.startFrame.pose
                let quad = flatQuad(center: pose.position,
                                    forward: pose.forward,
                                    left: pose.left,
                                    up: pose.up,
                                    width: trackHalfWidth * 2,
                                    length: 0.06,
                                    material: plastic(color: NSColor(calibratedWhite: 0.025, alpha: 1), roughness: 0.45),
                                    uRepeat: 1)
                root.addChildNode(quad)
            }
        }

        // Start / finish checker.
        let startPose = built.startFrame.pose
        let checkerMaterial = SCNMaterial()
        checkerMaterial.lightingModel = .physicallyBased
        checkerMaterial.diffuse.contents = TextureFactory.checker
        checkerMaterial.diffuse.wrapS = .repeat
        checkerMaterial.diffuse.wrapT = .clamp
        checkerMaterial.roughness.contents = NSNumber(value: 0.35)
        checkerMaterial.isDoubleSided = true
        let checkerQuad = flatQuad(center: startPose.position + startPose.up * 0.008,
                                   forward: startPose.forward,
                                   left: startPose.left,
                                   up: startPose.up,
                                   width: trackHalfWidth * 2,
                                   length: 0.36,
                                   material: checkerMaterial,
                                   uRepeat: 1)
        root.addChildNode(checkerQuad)

        // Bridge / loop support structure.
        addSupports(to: root, built: built)
        addElevationFurniture(to: root, built: built)

        return root
    }

    private static func addSupports(to root: SCNNode, built: BuiltTrack) {
        let supportMaterial = SCNMaterial()
        supportMaterial.lightingModel = .physicallyBased
        supportMaterial.diffuse.contents = NSColor(calibratedWhite: 0.13, alpha: 1)
        supportMaterial.metalness.contents = NSNumber(value: 0.7)
        supportMaterial.roughness.contents = NSNumber(value: 0.34)
        let beamMaterial = plastic(color: NSColor(calibratedWhite: 0.075, alpha: 1), roughness: 0.5)

        var lastSupportDistance: Float = -100
        for frame in built.centerFrames {
            let highlyElevated = frame.up.y > 0.3 ? frame.position.y : frame.position.y
            guard highlyElevated > 0.32 else { continue }
            if frame.s - lastSupportDistance < 1.7 { continue }
            lastSupportDistance = frame.s

            for side in [Float(-trackHalfWidth + 0.20), Float(trackHalfWidth - 0.20)] {
                let column = SCNCylinder(radius: 0.045, height: CGFloat(max(0.2, frame.position.y)))
                column.radialSegmentCount = 10
                column.firstMaterial = supportMaterial
                let node = SCNNode(geometry: column)
                node.position = SCNVector3(frame.position.x + frame.left.x * side,
                                           frame.position.y * 0.5,
                                           frame.position.z + frame.left.z * side)
                root.addChildNode(node)
            }

            let cross = SCNBox(width: CGFloat(trackHalfWidth * 2),
                               height: 0.025,
                               length: 0.025,
                               chamferRadius: 0.004)
            cross.firstMaterial = beamMaterial
            let crossNode = SCNNode(geometry: cross)
            crossNode.position = SCNVector3(frame.position.x, frame.position.y - 0.16, frame.position.z)
            crossNode.simdOrientation = frame.orientation
            root.addChildNode(crossNode)
        }
    }

    private static func addElevationFurniture(to root: SCNNode, built: BuiltTrack) {
        // Marshals and flags at the corners of the track.
        let marshalPositions: [(Float, Float)] = [
            (built.boundsMin.x - 0.8, built.boundsMin.z - 0.7),
            (built.boundsMax.x + 0.8, built.boundsMax.z + 0.7)
        ]
        for (x, z) in marshalPositions {
            root.addChildNode(makeMarshal(at: SIMD3<Float>(x, 0, z), color: .systemBlue))
        }

        // Cones at the outside of the first two corners.
        var random = SeededRandom(seed: 7)
        for index in 0..<5 {
            let angle = Float(index) / 5 * 2 * .pi
            let radius = max(built.size.x, built.size.z) * 0.5 + 1.1
            let position = SIMD3<Float>(built.center.x + cos(angle) * radius,
                                        0.02,
                                        built.center.z + sin(angle) * radius)
            root.addChildNode(makeCone(at: position, scale: 0.7 + random.next() * 0.4))
        }
    }

    // MARK: - Environment

    private static func buildEnvironment(built: BuiltTrack, environment: TrackEnvironment) -> SCNNode {
        let root = SCNNode()
        root.name = "environment"
        let center = built.center
        let tableWidth = built.size.x + 6.5
        let tableDepth = built.size.z + 6.5
        let tableTopY: Float = -0.115

        let tableMaterial = SCNMaterial()
        tableMaterial.lightingModel = .physicallyBased
        tableMaterial.diffuse.contents = TextureFactory.wood
        tableMaterial.diffuse.wrapS = .repeat
        tableMaterial.diffuse.wrapT = .repeat
        tableMaterial.roughness.contents = NSNumber(value: 0.42)
        tableMaterial.metalness.contents = NSNumber(value: 0.0)
        tableMaterial.normal.contents = TextureFactory.metalFlakeNormal
        tableMaterial.normal.intensity = 0.15

        let table = SCNBox(width: CGFloat(tableWidth),
                           height: 0.28,
                           length: CGFloat(tableDepth),
                           chamferRadius: 0.05)
        table.materials = [tableMaterial]
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(center.x, tableTopY - 0.14, center.z)
        tableNode.castsShadow = false
        root.addChildNode(tableNode)

        // Dark felt mat on the tabletop.
        let matMaterial = SCNMaterial()
        matMaterial.lightingModel = .physicallyBased
        matMaterial.diffuse.contents = TextureFactory.tableMat
        matMaterial.roughness.contents = NSNumber(value: 0.92)
        matMaterial.diffuse.wrapS = .repeat
        matMaterial.diffuse.wrapT = .repeat
        let mat = SCNBox(width: CGFloat(tableWidth - 0.5),
                         height: 0.018,
                         length: CGFloat(tableDepth - 0.5),
                         chamferRadius: 0.08)
        mat.materials = [matMaterial]
        let matNode = SCNNode(geometry: mat)
        matNode.position = SCNVector3(center.x, tableTopY, center.z)
        matNode.castsShadow = false
        root.addChildNode(matNode)

        // Table legs.
        for x in [center.x - tableWidth * 0.43, center.x + tableWidth * 0.43] {
            for z in [center.z - tableDepth * 0.43, center.z + tableDepth * 0.43] {
                let leg = SCNBox(width: 0.18, height: 1.55, length: 0.18, chamferRadius: 0.03)
                leg.materials = [tableMaterial]
                let node = SCNNode(geometry: leg)
                node.position = SCNVector3(x, -0.9, z)
                node.castsShadow = false
                root.addChildNode(node)
            }
        }

        // Floor.
        let floorMaterial = SCNMaterial()
        floorMaterial.lightingModel = .physicallyBased
        floorMaterial.diffuse.contents = NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.045, alpha: 1)
        floorMaterial.roughness.contents = NSNumber(value: 0.85)
        let floor = SCNBox(width: 48, height: 0.12, length: 38, chamferRadius: 0)
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(center.x, -1.72, center.z)
        floorNode.castsShadow = false
        root.addChildNode(floorNode)

        // Hobby-room shell. Four walls give the low chase and cockpit
        // cameras a believable background instead of a black void. The room
        // is intentionally open above the table so the top-down camera can
        // still see the complete diorama.
        let roomWidth = tableWidth + 9
        let roomDepth = tableDepth + 9
        let roomWallHeight: Float = 7.0
        let wallMaterial = SCNMaterial()
        wallMaterial.lightingModel = .physicallyBased
        wallMaterial.diffuse.contents = NSColor(calibratedRed: 0.070, green: 0.080, blue: 0.095, alpha: 1)
        wallMaterial.roughness.contents = NSNumber(value: 0.82)
        wallMaterial.metalness.contents = NSNumber(value: 0.02)
        wallMaterial.isDoubleSided = true

        func addRoomWall(width: Float, length: Float, position: SIMD3<Float>) {
            let wall = SCNBox(width: CGFloat(width), height: CGFloat(roomWallHeight), length: CGFloat(length), chamferRadius: 0.03)
            wall.materials = [wallMaterial]
            let node = SCNNode(geometry: wall)
            node.position = SCNVector3(position.x, position.y + roomWallHeight * 0.5 - 1.72, position.z)
            node.castsShadow = false
            root.addChildNode(node)
        }
        addRoomWall(width: 0.28, length: roomDepth,
                    position: SIMD3<Float>(center.x - roomWidth * 0.5, 0, center.z))
        addRoomWall(width: 0.28, length: roomDepth,
                    position: SIMD3<Float>(center.x + roomWidth * 0.5, 0, center.z))
        addRoomWall(width: roomWidth, length: 0.28,
                    position: SIMD3<Float>(center.x, 0, center.z - roomDepth * 0.5))
        addRoomWall(width: roomWidth, length: 0.28,
                    position: SIMD3<Float>(center.x, 0, center.z + roomDepth * 0.5))

        // A warm lightbox and a shelf break up the far wall. The lightbox is
        // emissive so it remains readable in night mode without adding a
        // second shadow-casting light.
        let lightboxMaterial = SCNMaterial()
        lightboxMaterial.lightingModel = .constant
        lightboxMaterial.diffuse.contents = NSColor(calibratedRed: 0.72, green: 0.34, blue: 0.15, alpha: 1)
        lightboxMaterial.emission.contents = NSColor(calibratedRed: 0.95, green: 0.44, blue: 0.15, alpha: 1)
        lightboxMaterial.emission.intensity = environment == .night ? 0.55 : 0.28

        let lightboxFrame = SCNBox(width: 0.08, height: 2.30, length: 4.60, chamferRadius: 0.04)
        lightboxFrame.materials = [plastic(color: NSColor(calibratedWhite: 0.045, alpha: 1), roughness: 0.55)]
        let lightboxFrameNode = SCNNode(geometry: lightboxFrame)
        lightboxFrameNode.position = SCNVector3(center.x + roomWidth * 0.5 - 0.13, 2.6, center.z - 2.3)
        lightboxFrameNode.castsShadow = false
        root.addChildNode(lightboxFrameNode)

        let lightbox = SCNBox(width: 0.06, height: 2.0, length: 4.2, chamferRadius: 0.04)
        lightbox.materials = [lightboxMaterial]
        let lightboxNode = SCNNode(geometry: lightbox)
        lightboxNode.position = SCNVector3(center.x + roomWidth * 0.5 - 0.20, 2.6, center.z - 2.3)
        lightboxNode.castsShadow = false
        root.addChildNode(lightboxNode)

        let wallShelf = SCNBox(width: 0.34, height: 0.10, length: 7.0, chamferRadius: 0.02)
        wallShelf.materials = [tableMaterial]
        let wallShelfNode = SCNNode(geometry: wallShelf)
        wallShelfNode.position = SCNVector3(center.x + roomWidth * 0.5 - 0.55, 2.1, center.z + 3.3)
        wallShelfNode.castsShadow = false
        root.addChildNode(wallShelfNode)

        let farShelf = SCNBox(width: 9.0, height: 0.12, length: 0.55, chamferRadius: 0.02)
        farShelf.materials = [tableMaterial]
        let farShelfNode = SCNNode(geometry: farShelf)
        farShelfNode.position = SCNVector3(center.x - 2.0, 3.0, center.z + roomDepth * 0.5 - 0.58)
        farShelfNode.castsShadow = false
        root.addChildNode(farShelfNode)

        // Tool chest and tyre stacks around the table. The chest lives on
        // the floor beside the table rather than floating over the mat.
        root.addChildNode(makeToolChest(at: SIMD3<Float>(center.x + tableWidth * 0.5 + 1.4,
                                                         -1.87,
                                                         center.z - tableDepth * 0.18)))
        root.addChildNode(makeTireStack(at: SIMD3<Float>(center.x - tableWidth * 0.46, 0, center.z + tableDepth * 0.33), count: 4))
        root.addChildNode(makeTireStack(at: SIMD3<Float>(center.x + tableWidth * 0.40, 0, center.z + tableDepth * 0.42), count: 3))

        // A few boxes / paint tins for scale.
        let boxMaterial = paint(NSColor(calibratedRed: 0.23, green: 0.10, blue: 0.055, alpha: 1), roughness: 0.65)
        for i in 0..<3 {
            let box = SCNBox(width: 0.44, height: 0.30, length: 0.34, chamferRadius: 0.02)
            box.materials = [boxMaterial]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(center.x - tableWidth * 0.43 + Float(i) * 0.45,
                                       0.15,
                                       center.z - tableDepth * 0.45)
            root.addChildNode(node)
        }

        // Practical lamps, one above the table.
        let lampY: Float = 4.9
        for offset in [-1.5, 1.5] {
            let lamp = SCNBox(width: 2.4, height: 0.16, length: 0.8, chamferRadius: 0.08)
            let lampMaterial = SCNMaterial()
            lampMaterial.lightingModel = .constant
            lampMaterial.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.55, alpha: 1)
            lampMaterial.emission.contents = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.42, alpha: 1)
            lampMaterial.emission.intensity = environment == .night ? 1.4 : 0.8
            lamp.materials = [lampMaterial]
            let node = SCNNode(geometry: lamp)
            node.position = SCNVector3(center.x + Float(offset) * tableWidth * 0.25,
                                        lampY,
                                        center.z + Float(offset) * 1.0)
            node.castsShadow = false
            root.addChildNode(node)
        }

        // The room ceiling is hidden by default so top-down cameras and
        // offscreen track overviews can see the whole diorama. The race
        // controller enables it for cockpit and chase views, where an open
        // black sky would otherwise break the hobby-room illusion.
        let ceiling = SCNNode()
        ceiling.name = "room-ceiling"
        ceiling.isHidden = true

        let ceilingMaterial = SCNMaterial()
        ceilingMaterial.lightingModel = .physicallyBased
        ceilingMaterial.diffuse.contents = NSColor(calibratedRed: 0.045, green: 0.052, blue: 0.062, alpha: 1)
        ceilingMaterial.roughness.contents = NSNumber(value: 0.9)
        ceilingMaterial.metalness.contents = NSNumber(value: 0.0)
        let ceilingSlab = SCNBox(width: CGFloat(roomWidth),
                                 height: 0.14,
                                 length: CGFloat(roomDepth),
                                 chamferRadius: 0.02)
        ceilingSlab.materials = [ceilingMaterial]
        let ceilingNode = SCNNode(geometry: ceilingSlab)
        ceilingNode.position = SCNVector3(center.x, 5.32, center.z)
        ceilingNode.castsShadow = false
        ceiling.addChildNode(ceilingNode)

        // Exposed timber beams give the low camera views a strong sense of
        // place without adding another shadow-casting light.
        let beamMaterial = paint(NSColor(calibratedRed: 0.10, green: 0.065, blue: 0.045, alpha: 1), roughness: 0.82)
        for zOffset in [-roomDepth * 0.28, 0, roomDepth * 0.28] {
            let beam = SCNBox(width: CGFloat(roomWidth),
                              height: 0.16,
                              length: 0.18,
                              chamferRadius: 0.025)
            beam.materials = [beamMaterial]
            let beamNode = SCNNode(geometry: beam)
            beamNode.position = SCNVector3(center.x, 5.20, center.z + zOffset)
            beamNode.castsShadow = false
            ceiling.addChildNode(beamNode)
        }

        // Recessed warm downlights.
        let downlightMaterial = SCNMaterial()
        downlightMaterial.lightingModel = .constant
        downlightMaterial.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.58, alpha: 1)
        downlightMaterial.emission.contents = NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.42, alpha: 1)
        downlightMaterial.emission.intensity = environment == .night ? 1.9 : 1.15
        for xOffset in [-roomWidth * 0.26, roomWidth * 0.26] {
            for zOffset in [-roomDepth * 0.24, 0, roomDepth * 0.24] {
                let panel = SCNBox(width: 1.6, height: 0.035, length: 0.5, chamferRadius: 0.04)
                panel.materials = [downlightMaterial]
                let panelNode = SCNNode(geometry: panel)
                panelNode.position = SCNVector3(center.x + xOffset, 5.235, center.z + zOffset)
                panelNode.castsShadow = false
                ceiling.addChildNode(panelNode)
            }
        }
        root.addChildNode(ceiling)

        return root
    }

    private static func addLighting(to scene: SCNScene, built: BuiltTrack, environment: TrackEnvironment) {
        let center = built.center
        let maxDimension = max(built.size.x, built.size.z)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = environment == .night ? 150 : 340
        ambient.color = environment == .night
            ? NSColor(calibratedRed: 0.35, green: 0.43, blue: 0.62, alpha: 1)
            : NSColor(calibratedRed: 0.70, green: 0.77, blue: 0.90, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Key light with real shadows.
        let key = SCNLight()
        key.type = .spot
        key.intensity = environment == .night ? 1300 : 1700
        key.color = environment == .night
            ? NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.36, alpha: 1)
            : NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.82, alpha: 1)
        key.castsShadow = true
        key.shadowMode = .deferred
        key.shadowSampleCount = 16
        key.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.shadowRadius = 3
        key.spotInnerAngle = 30
        key.spotOuterAngle = 72
        key.attenuationStartDistance = 5
        key.attenuationEndDistance = CGFloat(maxDimension * 3.2)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(center.x - maxDimension * 0.55,
                                       maxDimension * 1.45,
                                       center.z - maxDimension * 0.62)
        keyNode.look(at: SCNVector3(center.x, 0, center.z), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = environment == .night ? 300 : 520
        fill.color = environment == .night
            ? NSColor(calibratedRed: 0.35, green: 0.48, blue: 0.82, alpha: 1)
            : NSColor(calibratedRed: 0.52, green: 0.68, blue: 1.0, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(center.x + maxDimension * 0.65, maxDimension * 0.55, center.z + maxDimension * 0.25)
        scene.rootNode.addChildNode(fillNode)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = environment == .night ? 260 : 500
        rim.color = NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.18, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(-0.55, -2.35, 0)
        scene.rootNode.addChildNode(rimNode)

        // Practical overhead spots.
        for xOffset in [-0.32, 0.32] {
            let spot = SCNLight()
            spot.type = .spot
            spot.intensity = environment == .night ? 900 : 600
            spot.color = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.42, alpha: 1)
            spot.spotInnerAngle = 24
            spot.spotOuterAngle = 58
            spot.attenuationStartDistance = 2
            spot.attenuationEndDistance = CGFloat(maxDimension * 2)
            let node = SCNNode()
            node.light = spot
            node.position = SCNVector3(center.x + Float(xOffset) * maxDimension,
                                       6.2,
                                       center.z)
            node.look(at: SCNVector3(center.x, 0, center.z), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Start gantry

    private static func buildStartGantry(built: BuiltTrack, root: SCNNode) -> [SCNMaterial] {
        let pose = built.startFrame.pose
        let gantry = SCNNode()
        gantry.name = "start-gantry"
        gantry.simdPosition = pose.position + pose.forward * 0.3
        gantry.simdOrientation = pose.orientation
        root.addChildNode(gantry)

        let metal = SCNMaterial()
        metal.lightingModel = .physicallyBased
        metal.diffuse.contents = NSColor(calibratedWhite: 0.08, alpha: 1)
        metal.metalness.contents = NSNumber(value: 0.8)
        metal.roughness.contents = NSNumber(value: 0.28)
        let orange = paint(NSColor(calibratedRed: 0.95, green: 0.18, blue: 0.06, alpha: 1), roughness: 0.3)
        let white = paint(NSColor(calibratedWhite: 0.92, alpha: 1), roughness: 0.35)

        let postOffset = trackHalfWidth + 0.55
        for side in [-postOffset, postOffset] {
            let post = SCNBox(width: 0.10, height: 2.55, length: 0.10, chamferRadius: 0.02)
            post.materials = [metal]
            let node = SCNNode(geometry: post)
            node.position = SCNVector3(side, 1.275, 0)
            gantry.addChildNode(node)
        }
        let beam = SCNBox(width: CGFloat((postOffset + 0.25) * 2), height: 0.22, length: 0.16, chamferRadius: 0.035)
        beam.materials = [orange]
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(0, 2.46, 0)
        gantry.addChildNode(beamNode)

        // Banner.
        let banner = SCNBox(width: 2.1, height: 0.40, length: 0.055, chamferRadius: 0.02)
        banner.materials = [metal]
        let bannerNode = SCNNode(geometry: banner)
        bannerNode.position = SCNVector3(0, 2.52, 0.10)
        gantry.addChildNode(bannerNode)

        let text = SCNText(string: "APEX  SLOT  RACING", extrusionDepth: 0.015)
        text.font = NSFont(name: "HelveticaNeue-Bold", size: 0.14) ?? NSFont.boldSystemFont(ofSize: 0.14)
        text.flatness = 0.02
        text.firstMaterial = white
        let textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3(0.10, 0.10, 0.10)
        textNode.position = SCNVector3(-0.98, 2.40, 0.135)
        gantry.addChildNode(textNode)

        // Start lights.
        var materials: [SCNMaterial] = []
        for index in 0..<5 {
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = NSColor(calibratedWhite: 0.10, alpha: 1)
            material.emission.contents = NSColor(calibratedRed: 0.20, green: 0.03, blue: 0.02, alpha: 1)
            material.emission.intensity = 0.2
            materials.append(material)
            let sphere = SCNSphere(radius: 0.075)
            sphere.segmentCount = 16
            sphere.materials = [material]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(-0.40 + Float(index) * 0.20, 2.70, 0.08)
            gantry.addChildNode(node)
        }

        return materials
    }

    // MARK: - Props

    private static func makeToolChest(at position: SIMD3<Float>) -> SCNNode {
        let root = SCNNode()
        let red = paint(NSColor(calibratedRed: 0.48, green: 0.055, blue: 0.035, alpha: 1), roughness: 0.5)
        let metal = SCNMaterial()
        metal.lightingModel = .physicallyBased
        metal.diffuse.contents = NSColor(calibratedWhite: 0.23, alpha: 1)
        metal.metalness.contents = NSNumber(value: 0.8)
        metal.roughness.contents = NSNumber(value: 0.3)

        let body = SCNBox(width: 1.4, height: 1.0, length: 0.7, chamferRadius: 0.04)
        body.materials = [red]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(position.x, position.y + 0.65, position.z)
        root.addChildNode(bodyNode)
        for index in 0..<4 {
            let drawer = SCNBox(width: 1.25, height: 0.16, length: 0.035, chamferRadius: 0.012)
            drawer.materials = [metal]
            let node = SCNNode(geometry: drawer)
            node.position = SCNVector3(position.x, position.y + 0.30 + Float(index) * 0.19, position.z - 0.36)
            root.addChildNode(node)
            let handle = SCNCylinder(radius: 0.018, height: 0.36)
            handle.firstMaterial = metal
            let handleNode = SCNNode(geometry: handle)
            handleNode.position = SCNVector3(position.x, position.y + 0.30 + Float(index) * 0.19, position.z - 0.385)
            handleNode.eulerAngles.z = .pi / 2
            root.addChildNode(handleNode)
        }
        let lid = SCNBox(width: 1.45, height: 0.08, length: 0.75, chamferRadius: 0.025)
        lid.materials = [red]
        let lidNode = SCNNode(geometry: lid)
        lidNode.position = SCNVector3(position.x, position.y + 1.18, position.z)
        root.addChildNode(lidNode)
        return root
    }

    private static func makeTireStack(at position: SIMD3<Float>, count: Int) -> SCNNode {
        let root = SCNNode()
        let tire = SCNTorus(ringRadius: 0.20, pipeRadius: 0.075)
        tire.ringSegmentCount = 24
        tire.pipeSegmentCount = 10
        tire.firstMaterial = SCNMaterial()
        tire.firstMaterial?.lightingModel = .physicallyBased
        tire.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.035, alpha: 1)
        tire.firstMaterial?.roughness.contents = NSNumber(value: 0.94)
        for index in 0..<count {
            let node = SCNNode(geometry: tire)
            node.position = SCNVector3(position.x + (index % 2 == 0 ? 0 : 0.06),
                                       position.y + 0.075 + Float(index) * 0.14,
                                       position.z)
            node.eulerAngles.x = CGFloat(0.1 * Float(index))
            root.addChildNode(node)
        }
        return root
    }

    private static func makeMarshal(at position: SIMD3<Float>, color: NSColor) -> SCNNode {
        let root = SCNNode()
        let suit = SCNMaterial()
        suit.lightingModel = .physicallyBased
        suit.diffuse.contents = color
        suit.roughness.contents = NSNumber(value: 0.7)
        let skin = SCNMaterial()
        skin.lightingModel = .physicallyBased
        skin.diffuse.contents = NSColor(calibratedRed: 0.78, green: 0.58, blue: 0.42, alpha: 1)
        skin.roughness.contents = NSNumber(value: 0.8)

        let legs = SCNCapsule(capRadius: 0.045, height: 0.38)
        legs.firstMaterial = suit
        let legsNode = SCNNode(geometry: legs)
        legsNode.position = SCNVector3(position.x, position.y + 0.19, position.z)
        root.addChildNode(legsNode)

        let torso = SCNCapsule(capRadius: 0.075, height: 0.36)
        torso.firstMaterial = suit
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.position = SCNVector3(position.x, position.y + 0.48, position.z)
        root.addChildNode(torsoNode)

        let head = SCNSphere(radius: 0.075)
        head.firstMaterial = skin
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(position.x, position.y + 0.72, position.z)
        root.addChildNode(headNode)

        let helmet = SCNSphere(radius: 0.082)
        let helmetMaterial = SCNMaterial()
        helmetMaterial.lightingModel = .physicallyBased
        helmetMaterial.diffuse.contents = NSColor(calibratedWhite: 0.93, alpha: 1)
        helmetMaterial.roughness.contents = NSNumber(value: 0.35)
        helmet.firstMaterial = helmetMaterial
        let helmetNode = SCNNode(geometry: helmet)
        helmetNode.position = SCNVector3(position.x, position.y + 0.745, position.z)
        helmetNode.scale = SCNVector3(1.0, 0.8, 1.0)
        root.addChildNode(helmetNode)

        let flagPole = SCNCylinder(radius: 0.008, height: 0.9)
        flagPole.firstMaterial = metalMaterial()
        let poleNode = SCNNode(geometry: flagPole)
        poleNode.position = SCNVector3(position.x + 0.13, position.y + 0.58, position.z)
        root.addChildNode(poleNode)
        let flag = SCNBox(width: 0.18, height: 0.12, length: 0.01, chamferRadius: 0.004)
        flag.firstMaterial = paint(NSColor(calibratedRed: 0.92, green: 0.55, blue: 0.06, alpha: 1), roughness: 0.5)
        let flagNode = SCNNode(geometry: flag)
        flagNode.position = SCNVector3(position.x + 0.23, position.y + 0.95, position.z)
        root.addChildNode(flagNode)

        return root
    }

    private static func makeCone(at position: SIMD3<Float>, scale: Float) -> SCNNode {
        let cone = SCNCone(topRadius: 0.025, bottomRadius: 0.10, height: 0.32)
        cone.radialSegmentCount = 16
        cone.firstMaterial = paint(NSColor(calibratedRed: 0.95, green: 0.22, blue: 0.03, alpha: 1), roughness: 0.55)
        let node = SCNNode(geometry: cone)
        node.position = SCNVector3(position.x, position.y + 0.16 * scale, position.z)
        node.scale = SCNVector3(scale, scale, scale)
        return node
    }

    // MARK: - Mesh helpers

    private static func plastic(color: NSColor, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = NSNumber(value: Double(roughness))
        material.metalness.contents = NSNumber(value: 0)
        material.isDoubleSided = true
        return material
    }

    private static func paint(_ color: NSColor, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = NSNumber(value: Double(roughness))
        material.metalness.contents = NSNumber(value: 0.25)
        material.clearCoat.contents = NSNumber(value: 0.4)
        material.isDoubleSided = true
        return material
    }

    private static func metalMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = NSColor(calibratedWhite: 0.12, alpha: 1)
        material.metalness.contents = NSNumber(value: 0.9)
        material.roughness.contents = NSNumber(value: 0.28)
        return material
    }

    private static func ribbonGeometry(frames: [TrackFrame],
                                       leftOffset: Float,
                                       rightOffset: Float,
                                       upOffset: Float,
                                       normalMultiplier: Float,
                                       uvScale: Float,
                                       material: SCNMaterial) -> SCNGeometry {
        guard frames.count >= 2 else { return SCNGeometry() }
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        positions.reserveCapacity(frames.count * 2)
        normals.reserveCapacity(frames.count * 2)
        uvs.reserveCapacity(frames.count * 2)

        for frame in frames {
            let leftPoint = frame.position + frame.left * leftOffset + frame.up * upOffset
            let rightPoint = frame.position + frame.left * rightOffset + frame.up * upOffset
            let normal = frame.up * normalMultiplier
            positions.append(SCNVector3(leftPoint.x, leftPoint.y, leftPoint.z))
            positions.append(SCNVector3(rightPoint.x, rightPoint.y, rightPoint.z))
            normals.append(SCNVector3(normal.x, normal.y, normal.z))
            normals.append(SCNVector3(normal.x, normal.y, normal.z))
            let u = frame.s / max(0.1, uvScale)
            uvs.append(CGPoint(x: CGFloat(u), y: 0))
            uvs.append(CGPoint(x: CGFloat(u), y: 1))
        }

        for index in 0..<(frames.count - 1) {
            let a = Int32(index * 2)
            let b = Int32(index * 2 + 1)
            let c = Int32((index + 1) * 2)
            let d = Int32((index + 1) * 2 + 1)
            // Left, next-left, next-right / left, next-right, right.
            indices.append(contentsOf: [a, c, d, a, d, b])
        }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return geometry
    }

    private static func wallGeometry(frames: [TrackFrame],
                                     offset: Float,
                                     bottom: Float,
                                     top: Float,
                                     outwardSign: Float,
                                     material: SCNMaterial) -> SCNGeometry {
        guard frames.count >= 2 else { return SCNGeometry() }
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        for frame in frames {
            let bottomPoint = frame.position + frame.left * offset + frame.up * bottom
            let topPoint = frame.position + frame.left * offset + frame.up * top
            positions.append(SCNVector3(bottomPoint.x, bottomPoint.y, bottomPoint.z))
            positions.append(SCNVector3(topPoint.x, topPoint.y, topPoint.z))
            let normal = simd_normalize(frame.left * outwardSign)
            normals.append(SCNVector3(normal.x, normal.y, normal.z))
            normals.append(SCNVector3(normal.x, normal.y, normal.z))
            let u = frame.s / 1.5
            uvs.append(CGPoint(x: CGFloat(u), y: 0))
            uvs.append(CGPoint(x: CGFloat(u), y: 1))
        }
        for index in 0..<(frames.count - 1) {
            let a = Int32(index * 2)
            let b = Int32(index * 2 + 1)
            let c = Int32((index + 1) * 2)
            let d = Int32((index + 1) * 2 + 1)
            if outwardSign > 0 {
                indices.append(contentsOf: [a, c, d, a, d, b])
            } else {
                indices.append(contentsOf: [a, d, c, a, b, d])
            }
        }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return geometry
    }

    private static func flatQuad(center: SIMD3<Float>,
                                 forward: SIMD3<Float>,
                                 left: SIMD3<Float>,
                                 up: SIMD3<Float>,
                                 width: Float,
                                 length: Float,
                                 material: SCNMaterial,
                                 uRepeat: Float) -> SCNNode {
        let halfWidth = width * 0.5
        let halfLength = length * 0.5
        let a = center - left * halfWidth - forward * halfLength
        let b = center + left * halfWidth - forward * halfLength
        let c = center + left * halfWidth + forward * halfLength
        let d = center - left * halfWidth + forward * halfLength
        let vertices = [a, b, c, d].map { SCNVector3($0.x, $0.y, $0.z) }
        let normal = up
        let normals = Array(repeating: SCNVector3(normal.x, normal.y, normal.z), count: 4)
        let uvs = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: CGFloat(uRepeat), y: 0),
            CGPoint(x: CGFloat(uRepeat), y: 1),
            CGPoint(x: 0, y: 1)
        ]
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: [0, 1, 2, 0, 2, 3], primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }
}

private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Float {
        state = state &* 2862933555777941757 &+ 3037000493
        return Float((state >> 33) & 0xFFFFFF) / Float(0xFFFFFF)
    }
}
