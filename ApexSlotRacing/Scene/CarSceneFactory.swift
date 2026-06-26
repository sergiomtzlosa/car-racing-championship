import AppKit
import SceneKit
import simd

final class RaceCarNode {
    let root = SCNNode()
    let chassis = SCNNode()
    let wheelsRoot = SCNNode()
    private var spinNodes: [SCNNode] = []
    private var steeringNodes: [SCNNode] = []
    private var brakeMaterial: SCNMaterial?
    private var wheelSpin: Float = 0
    private var currentRoll: Float = 0
    private var currentPitch: Float = 0

    let model: CarModelKind
    let length: Float
    let width: Float
    let wheelRadius: Float
    let cockpitAnchor: SIMD3<Float>

    init(model: CarModelKind,
         length: Float,
         width: Float,
         wheelRadius: Float,
         cockpitAnchor: SIMD3<Float>) {
        self.model = model
        self.length = length
        self.width = width
        self.wheelRadius = wheelRadius
        self.cockpitAnchor = cockpitAnchor
        root.name = "car-\(model.rawValue)"
        root.addChildNode(chassis)
        root.addChildNode(wheelsRoot)
    }

    func addWheel(position: SIMD3<Float>,
                  radius: Float,
                  width: Float,
                  rimStyle: Int,
                  steering: Bool) {
        let pivot = SCNNode()
        pivot.simdPosition = position
        pivot.name = steering ? "front-wheel" : "rear-wheel"

        let spin = SCNNode()
        spin.name = "wheel-spin"

        let tirePipe = width * 0.42
        let torus = SCNTorus(ringRadius: CGFloat(max(0.01, radius - tirePipe)), pipeRadius: CGFloat(tirePipe))
        torus.ringSegmentCount = 32
        torus.pipeSegmentCount = 14
        let tireNode = SCNNode(geometry: torus)
        tireNode.eulerAngles.z = .pi / 2
        let tireMaterial = SCNMaterial()
        tireMaterial.lightingModel = .physicallyBased
        tireMaterial.diffuse.contents = NSColor(calibratedWhite: 0.045, alpha: 1)
        tireMaterial.roughness.contents = NSNumber(value: 0.92)
        tireMaterial.metalness.contents = NSNumber(value: 0.02)
        tireMaterial.normal.contents = TextureFactory.tireNormal
        tireMaterial.normal.intensity = 0.5
        tireMaterial.normal.wrapS = .repeat
        tireMaterial.normal.wrapT = .repeat
        tireMaterial.isDoubleSided = true
        torus.materials = [tireMaterial]
        spin.addChildNode(tireNode)

        let rimRadius = radius * (model == .formula ? 0.58 : 0.54)
        let rim = SCNCylinder(radius: CGFloat(rimRadius), height: CGFloat(width * 0.82))
        rim.radialSegmentCount = 28
        let rimNode = SCNNode(geometry: rim)
        rimNode.eulerAngles.z = .pi / 2
        let rimColor: NSColor
        switch rimStyle % 3 {
        case 0: rimColor = NSColor(calibratedWhite: 0.72, alpha: 1)
        case 1: rimColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        default: rimColor = NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.47, alpha: 1)
        }
        let rimMaterial = SCNMaterial()
        rimMaterial.lightingModel = .physicallyBased
        rimMaterial.diffuse.contents = rimColor
        rimMaterial.metalness.contents = NSNumber(value: 0.65)
        rimMaterial.roughness.contents = NSNumber(value: 0.30)
        rimNode.geometry?.materials = [rimMaterial]
        spin.addChildNode(rimNode)

        // Brake disc and caliper stay with the upright.
        let disc = SCNCylinder(radius: CGFloat(rimRadius * 0.92), height: 0.012)
        disc.radialSegmentCount = 24
        let discNode = SCNNode(geometry: disc)
        discNode.eulerAngles.z = .pi / 2
        let discMaterial = SCNMaterial()
        discMaterial.lightingModel = .physicallyBased
        discMaterial.diffuse.contents = NSColor(calibratedWhite: 0.26, alpha: 1)
        discMaterial.metalness.contents = NSNumber(value: 0.85)
        discMaterial.roughness.contents = NSNumber(value: 0.45)
        discNode.geometry?.materials = [discMaterial]
        pivot.addChildNode(discNode)

        let caliper = SCNBox(width: CGFloat(width * 0.32), height: 0.09, length: 0.11, chamferRadius: 0.025)
        caliper.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.92, green: 0.12, blue: 0.06, alpha: 1)
        caliper.firstMaterial?.lightingModel = .physicallyBased
        caliper.firstMaterial?.roughness.contents = NSNumber(value: 0.35)
        let caliperNode = SCNNode(geometry: caliper)
        caliperNode.position = SCNVector3(0, Float(rimRadius) * 0.68, 0)
        pivot.addChildNode(caliperNode)

        let spokeCount = rimStyle % 3 == 1 ? 5 : 6
        for index in 0..<spokeCount {
            let angle = Float(index) / Float(spokeCount) * 2 * .pi
            let spoke = SCNBox(width: CGFloat(width * 0.72),
                               height: CGFloat(rimRadius * 0.92),
                               length: 0.022,
                               chamferRadius: 0.008)
            spoke.firstMaterial = rimMaterial
            let spokeNode = SCNNode(geometry: spoke)
            spokeNode.position = SCNVector3(0, Float(rimRadius) * 0.48, 0)
            spokeNode.eulerAngles.x = CGFloat(angle)
            spin.addChildNode(spokeNode)
        }

        let hub = SCNCylinder(radius: CGFloat(rimRadius * 0.16), height: CGFloat(width * 0.95))
        hub.radialSegmentCount = 16
        hub.firstMaterial = rimMaterial
        let hubNode = SCNNode(geometry: hub)
        hubNode.eulerAngles.z = .pi / 2
        spin.addChildNode(hubNode)

        pivot.addChildNode(spin)
        wheelsRoot.addChildNode(pivot)
        spinNodes.append(spin)
        if steering { steeringNodes.append(pivot) }
    }

    func setBrakeMaterial(_ material: SCNMaterial) {
        brakeMaterial = material
    }

    func update(dt: Float,
                speed: Float,
                steering: Float,
                braking: Bool,
                lateralAcceleration: Float,
                reduceMotion: Bool) {
        wheelSpin += speed / max(0.1, wheelRadius) * dt
        for spin in spinNodes {
            spin.eulerAngles.x = CGFloat(wheelSpin)
        }
        for steeringNode in steeringNodes {
            steeringNode.eulerAngles.y = CGFloat(steering)
        }

        let targetRoll = reduceMotion ? 0 : max(-0.09, min(0.09, -lateralAcceleration * 0.007))
        let targetPitch = reduceMotion ? 0 : max(-0.035, min(0.035, -Float(dt) * 0))
        currentRoll += (targetRoll - currentRoll) * min(1, dt * 8)
        currentPitch += (targetPitch - currentPitch) * min(1, dt * 8)
        chassis.eulerAngles.z = CGFloat(currentRoll)
        chassis.eulerAngles.x = CGFloat(currentPitch)

        if let brakeMaterial {
            let intensity: CGFloat = braking ? 1.5 : 0.22
            brakeMaterial.emission.intensity = intensity
        }
    }
}

enum CarSceneFactory {
    static func makeCar(config: CarConfig, quality: GraphicsQuality = .high) -> RaceCarNode {
        switch config.model {
        case .gt:
            return makeGT(config: config)
        case .rally:
            return makeRally(config: config)
        case .formula:
            return makeFormula(config: config)
        }
    }

    // MARK: - Materials

    private static func paint(_ color: NSColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.metalness.contents = NSNumber(value: 0.62)
        material.roughness.contents = NSNumber(value: 0.24)
        material.clearCoat.contents = NSNumber(value: 0.9)
        material.clearCoatRoughness.contents = NSNumber(value: 0.07)
        material.normal.contents = TextureFactory.metalFlakeNormal
        material.normal.intensity = 0.10
        material.normal.wrapS = .repeat
        material.normal.wrapT = .repeat
        material.isDoubleSided = true
        return material
    }

    private static func secondaryPaint(_ color: NSColor) -> SCNMaterial {
        let material = paint(color)
        material.metalness.contents = NSNumber(value: 0.35)
        material.roughness.contents = NSNumber(value: 0.32)
        return material
    }

    private static func glass() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.075, alpha: 0.92)
        material.metalness.contents = NSNumber(value: 0.0)
        material.roughness.contents = NSNumber(value: 0.035)
        material.clearCoat.contents = NSNumber(value: 1.0)
        material.clearCoatRoughness.contents = NSNumber(value: 0.02)
        material.transparency = 0.88
        material.isDoubleSided = true
        material.blendMode = .alpha
        return material
    }

    private static func rubber() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = NSColor(calibratedWhite: 0.035, alpha: 1)
        material.roughness.contents = NSNumber(value: 0.92)
        material.metalness.contents = NSNumber(value: 0.0)
        material.normal.contents = TextureFactory.tireNormal
        material.normal.intensity = 0.35
        material.normal.wrapS = .repeat
        material.normal.wrapT = .repeat
        return material
    }

    private static func carbon() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = TextureFactory.carbonFibre
        material.metalness.contents = NSNumber(value: 0.16)
        material.roughness.contents = NSNumber(value: 0.34)
        material.clearCoat.contents = NSNumber(value: 0.5)
        material.clearCoatRoughness.contents = NSNumber(value: 0.18)
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.isDoubleSided = true
        return material
    }

    private static func metal() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = NSColor(calibratedWhite: 0.11, alpha: 1)
        material.metalness.contents = NSNumber(value: 0.95)
        material.roughness.contents = NSNumber(value: 0.28)
        return material
    }

    private static func lightLens(color: NSColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 0.8
        material.isDoubleSided = true
        return material
    }

    private static func brakeLens() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = NSColor(calibratedRed: 0.9, green: 0.05, blue: 0.02, alpha: 1)
        material.emission.contents = NSColor(calibratedRed: 1.0, green: 0.04, blue: 0.01, alpha: 1)
        material.emission.intensity = 0.2
        material.isDoubleSided = true
        return material
    }

    private static func decalMaterial(_ image: NSImage, opacity: CGFloat = 1) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = image
        material.transparency = opacity
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        return material
    }

    // MARK: - GT

    private static func makeGT(config: CarConfig) -> RaceCarNode {
        let primary = NSColor(hex: config.primaryHex) ?? .red
        let secondary = NSColor(hex: config.secondaryHex) ?? .white
        let car = RaceCarNode(model: .gt,
                              length: 3.25,
                              width: 1.18,
                              wheelRadius: 0.33,
                              cockpitAnchor: SIMD3<Float>(0, 0.96, -0.46))
        let bodyMaterial = paint(primary)
        let accentMaterial = secondaryPaint(secondary)

        let body = LoftGeometry.make(sections: [
            .init(z: -1.62, width: 0.28, bottom: 0.08, top: 0.26, roundness: 2.4),
            .init(z: -1.48, width: 0.46, bottom: 0.07, top: 0.38, roundness: 2.9),
            .init(z: -1.10, width: 0.59, bottom: 0.065, top: 0.48, roundness: 3.4),
            .init(z: -0.55, width: 0.62, bottom: 0.065, top: 0.57, roundness: 3.7),
            .init(z: 0.15, width: 0.64, bottom: 0.065, top: 0.68, roundness: 3.8),
            .init(z: 0.82, width: 0.61, bottom: 0.065, top: 0.70, roundness: 3.7),
            .init(z: 1.30, width: 0.54, bottom: 0.07, top: 0.62, roundness: 3.4),
            .init(z: 1.55, width: 0.42, bottom: 0.08, top: 0.52, roundness: 3.0)
        ], segments: 32, material: bodyMaterial)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.name = "gt-body"
        car.chassis.addChildNode(bodyNode)

        let cabin = LoftGeometry.make(sections: [
            .init(z: -0.63, width: 0.48, bottom: 0.53, top: 0.60, roundness: 2.6),
            .init(z: -0.38, width: 0.52, bottom: 0.54, top: 0.88, roundness: 3.2),
            .init(z: 0.24, width: 0.52, bottom: 0.55, top: 1.02, roundness: 3.4),
            .init(z: 0.73, width: 0.46, bottom: 0.56, top: 0.92, roundness: 3.0),
            .init(z: 0.92, width: 0.40, bottom: 0.55, top: 0.70, roundness: 2.6)
        ], segments: 28, material: glass())
        car.chassis.addChildNode(SCNNode(geometry: cabin))

        let roof = roundedBox(width: 0.60, height: 0.035, length: 0.66, radius: 0.035, material: bodyMaterial)
        roof.position = SCNVector3(0, 1.005, 0.03)
        car.chassis.addChildNode(roof)

        let windshieldPillarLeft = roundedBox(width: 0.035, height: 0.32, length: 0.04, radius: 0.012, material: bodyMaterial)
        windshieldPillarLeft.position = SCNVector3(-0.43, 0.80, -0.36)
        windshieldPillarLeft.eulerAngles.x = -0.32
        car.chassis.addChildNode(windshieldPillarLeft)
        let windshieldPillarRight = windshieldPillarLeft.clone()
        windshieldPillarRight.position.x = 0.43
        car.chassis.addChildNode(windshieldPillarRight)

        addSecondaryStripe(to: car,
                           material: accentMaterial,
                           y: 0.58,
                           z: -1.05,
                           length: 0.95,
                           width: 0.10)
        addSecondaryStripe(to: car,
                           material: accentMaterial,
                           y: 1.030,
                           z: 0.0,
                           length: 0.54,
                           width: 0.10)

        // Splitter, skirts and diffuser.
        let splitter = roundedBox(width: 1.12, height: 0.032, length: 0.28, radius: 0.025, material: carbon())
        splitter.position = SCNVector3(0, 0.075, -1.58)
        car.chassis.addChildNode(splitter)
        for side in [-1.0, 1.0] {
            let skirt = roundedBox(width: 0.055, height: 0.075, length: 1.85, radius: 0.02, material: carbon())
            skirt.position = SCNVector3(Float(side) * 0.635, 0.14, 0.03)
            car.chassis.addChildNode(skirt)
        }
        let diffuser = roundedBox(width: 1.02, height: 0.075, length: 0.36, radius: 0.025, material: carbon())
        diffuser.position = SCNVector3(0, 0.12, 1.51)
        diffuser.eulerAngles.x = 0.22
        car.chassis.addChildNode(diffuser)

        // Rear wing.
        let wing = roundedBox(width: 1.02, height: 0.045, length: 0.26, radius: 0.018, material: carbon())
        wing.position = SCNVector3(0, 0.98, 1.43)
        car.chassis.addChildNode(wing)
        for side in [-0.36, 0.36] {
            let support = roundedBox(width: 0.035, height: 0.22, length: 0.06, radius: 0.01, material: carbon())
            support.position = SCNVector3(Float(side), 0.84, 1.42)
            car.chassis.addChildNode(support)
            let endplate = roundedBox(width: 0.025, height: 0.18, length: 0.28, radius: 0.012, material: carbon())
            endplate.position = SCNVector3(Float(side) * 0.58, 0.94, 1.43)
            car.chassis.addChildNode(endplate)
        }

        addGTDetails(car: car, primary: primary, secondary: secondary, accentMaterial: accentMaterial,
                     width: 1.18, decalStyle: config.decalStyle)

        // Wheels.
        let wheelWidth: Float = 0.25
        for z in [-1.03, 1.05] {
            for side in [-1.0, 1.0] {
                car.addWheel(position: SIMD3<Float>(Float(side) * 0.58, car.wheelRadius + 0.02, Float(z)),
                             radius: car.wheelRadius,
                             width: wheelWidth,
                             rimStyle: config.wheelStyle,
                             steering: z < 0)
            }
        }

        return car
    }

    private static func addGTDetails(car: RaceCarNode,
                                     primary: NSColor,
                                     secondary: NSColor,
                                     accentMaterial: SCNMaterial,
                                     width: Float,
                                     decalStyle: Int) {
        // Lights.
        let headlightMaterial = lightLens(color: NSColor(calibratedRed: 0.88, green: 0.96, blue: 1.0, alpha: 1))
        for side in [-1.0, 1.0] {
            let lens = SCNBox(width: 0.28, height: 0.10, length: 0.045, chamferRadius: 0.035)
            lens.firstMaterial = headlightMaterial
            let node = SCNNode(geometry: lens)
            node.position = SCNVector3(Float(side) * 0.36, 0.31, -1.58)
            car.chassis.addChildNode(node)
        }
        let brakeMaterial = brakeLens()
        for side in [-1.0, 1.0] {
            let lens = SCNBox(width: 0.26, height: 0.08, length: 0.035, chamferRadius: 0.025)
            lens.firstMaterial = brakeMaterial
            let node = SCNNode(geometry: lens)
            node.position = SCNVector3(Float(side) * 0.40, 0.41, 1.56)
            car.chassis.addChildNode(node)
        }
        car.setBrakeMaterial(brakeMaterial)

        // Exhausts.
        for side in [-0.26, 0.26] {
            let exhaust = SCNCylinder(radius: 0.040, height: 0.18)
            exhaust.radialSegmentCount = 16
            exhaust.firstMaterial = metal()
            let node = SCNNode(geometry: exhaust)
            node.position = SCNVector3(Float(side), 0.14, 1.62)
            node.eulerAngles.x = .pi / 2
            car.chassis.addChildNode(node)
        }

        // Mirrors.
        for side in [-1.0, 1.0] {
            let mirror = roundedBox(width: 0.16, height: 0.075, length: 0.09, radius: 0.035, material: accentMaterial)
            mirror.position = SCNVector3(Float(side) * 0.67, 0.68, -0.20)
            car.chassis.addChildNode(mirror)
        }

        // Hood vent.
        let vent = roundedBox(width: 0.40, height: 0.015, length: 0.28, radius: 0.01, material: carbon())
        vent.position = SCNVector3(0, 0.50, -0.92)
        vent.eulerAngles.x = -0.10
        car.chassis.addChildNode(vent)

        // Number roundel on the doors.
        addSideDecal(car: car,
                     image: TextureFactory.decalRoundel,
                     x: width * 0.5 + 0.003,
                     y: 0.48,
                     z: 0.0,
                     size: 0.31,
                     opacity: 1.0)

        if decalStyle != 2 {
            addSideDecal(car: car,
                         image: TextureFactory.sponsorDecal,
                         x: -width * 0.5 - 0.003,
                         y: 0.35,
                         z: 0.48,
                         size: 0.44,
                         opacity: 0.8)
        }

        // Small forehead stripe for the classic GT look.
        let hoodStripe = roundedBox(width: 0.09, height: 0.012, length: 0.76, radius: 0.005, material: accentMaterial)
        hoodStripe.position = SCNVector3(-0.10, 0.56, -0.76)
        car.chassis.addChildNode(hoodStripe)
        let hoodStripe2 = hoodStripe.clone()
        hoodStripe2.position.x = 0.10
        car.chassis.addChildNode(hoodStripe2)
    }

    // MARK: - Rally

    private static func makeRally(config: CarConfig) -> RaceCarNode {
        let primary = NSColor(hex: config.primaryHex) ?? NSColor(calibratedWhite: 0.9, alpha: 1)
        let secondary = NSColor(hex: config.secondaryHex) ?? .blue
        let car = RaceCarNode(model: .rally,
                              length: 3.05,
                              width: 1.22,
                              wheelRadius: 0.36,
                              cockpitAnchor: SIMD3<Float>(0, 1.18, -0.36))
        let bodyMaterial = paint(primary)
        let accentMaterial = secondaryPaint(secondary)

        let body = LoftGeometry.make(sections: [
            .init(z: -1.55, width: 0.46, bottom: 0.10, top: 0.44, roundness: 6),
            .init(z: -1.38, width: 0.57, bottom: 0.09, top: 0.52, roundness: 7),
            .init(z: -0.88, width: 0.63, bottom: 0.08, top: 0.59, roundness: 8),
            .init(z: -0.25, width: 0.64, bottom: 0.08, top: 0.64, roundness: 8),
            .init(z: 0.48, width: 0.64, bottom: 0.08, top: 0.67, roundness: 8),
            .init(z: 1.10, width: 0.62, bottom: 0.08, top: 0.64, roundness: 7),
            .init(z: 1.44, width: 0.53, bottom: 0.09, top: 0.57, roundness: 6)
        ], segments: 32, material: bodyMaterial)
        car.chassis.addChildNode(SCNNode(geometry: body))

        let cabin = LoftGeometry.make(sections: [
            .init(z: -0.70, width: 0.52, bottom: 0.55, top: 0.58, roundness: 2.5),
            .init(z: -0.45, width: 0.54, bottom: 0.56, top: 0.92, roundness: 2.3),
            .init(z: 0.28, width: 0.55, bottom: 0.57, top: 1.10, roundness: 2.4),
            .init(z: 0.70, width: 0.53, bottom: 0.57, top: 1.08, roundness: 2.3),
            .init(z: 0.96, width: 0.46, bottom: 0.56, top: 0.80, roundness: 2.2)
        ], segments: 24, material: glass())
        car.chassis.addChildNode(SCNNode(geometry: cabin))

        let roof = roundedBox(width: 0.60, height: 0.065, length: 0.70, radius: 0.04, material: bodyMaterial)
        roof.position = SCNVector3(0, 1.105, 0.08)
        car.chassis.addChildNode(roof)

        // Roof light pod.
        let pod = roundedBox(width: 0.52, height: 0.10, length: 0.20, radius: 0.035, material: carbon())
        pod.position = SCNVector3(0, 1.19, -0.40)
        car.chassis.addChildNode(pod)
        for x in [-0.22, -0.07, 0.08, 0.23] {
            let light = SCNCylinder(radius: 0.055, height: 0.055)
            light.radialSegmentCount = 16
            light.firstMaterial = lightLens(color: NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.65, alpha: 1))
            let node = SCNNode(geometry: light)
            node.position = SCNVector3(Float(x), 1.22, -0.52)
            node.eulerAngles.x = .pi / 2
            car.chassis.addChildNode(node)
        }

        // Fender flares.
        for z in [-0.95, 0.98] {
            for side in [-1.0, 1.0] {
                let flare = roundedBox(width: 0.09, height: 0.16, length: 0.52, radius: 0.05, material: carbon())
                flare.position = SCNVector3(Float(side) * 0.66, 0.42, Float(z))
                car.chassis.addChildNode(flare)
            }
        }

        // Mud flaps.
        for z in [-1.25, 1.25] {
            for side in [-1.0, 1.0] {
                let flap = SCNBox(width: 0.23, height: 0.20, length: 0.015, chamferRadius: 0.01)
                flap.firstMaterial = rubber()
                let node = SCNNode(geometry: flap)
                node.position = SCNVector3(Float(side) * 0.63, 0.23, Float(z))
                node.eulerAngles.x = 0.12
                car.chassis.addChildNode(node)
            }
        }

        // Rear spoiler.
        let spoiler = roundedBox(width: 0.92, height: 0.035, length: 0.22, radius: 0.015, material: carbon())
        spoiler.position = SCNVector3(0, 0.78, 1.38)
        car.chassis.addChildNode(spoiler)
        for side in [-0.34, 0.34] {
            let support = roundedBox(width: 0.03, height: 0.13, length: 0.05, radius: 0.01, material: carbon())
            support.position = SCNVector3(Float(side), 0.71, 1.38)
            car.chassis.addChildNode(support)
        }

        // Side stripes.
        for side in [-1.0, 1.0] {
            let stripe = roundedBox(width: 0.014, height: 0.09, length: 2.20, radius: 0.006, material: accentMaterial)
            stripe.position = SCNVector3(Float(side) * 0.647, 0.38, 0.02)
            car.chassis.addChildNode(stripe)
            let stripe2 = stripe.clone()
            stripe2.position.y = 0.50
            stripe2.geometry = roundedBox(width: 0.012, height: 0.035, length: 2.20, radius: 0.004, material: accentMaterial).geometry
            car.chassis.addChildNode(stripe2)
        }
        let hoodStripe = roundedBox(width: 0.16, height: 0.012, length: 0.88, radius: 0.005, material: accentMaterial)
        hoodStripe.position = SCNVector3(0, 0.61, -0.76)
        car.chassis.addChildNode(hoodStripe)

        // Lights.
        let headlightMaterial = lightLens(color: NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.70, alpha: 1))
        for side in [-1.0, 1.0] {
            let lens = SCNCylinder(radius: 0.105, height: 0.045)
            lens.radialSegmentCount = 18
            lens.firstMaterial = headlightMaterial
            let node = SCNNode(geometry: lens)
            node.position = SCNVector3(Float(side) * 0.37, 0.40, -1.52)
            node.eulerAngles.x = .pi / 2
            car.chassis.addChildNode(node)
        }
        let brakeMaterial = brakeLens()
        for side in [-1.0, 1.0] {
            let lens = SCNBox(width: 0.23, height: 0.12, length: 0.035, chamferRadius: 0.018)
            lens.firstMaterial = brakeMaterial
            let node = SCNNode(geometry: lens)
            node.position = SCNVector3(Float(side) * 0.38, 0.49, 1.48)
            car.chassis.addChildNode(node)
        }
        car.setBrakeMaterial(brakeMaterial)

        addSideDecal(car: car,
                     image: TextureFactory.decalRoundel,
                     x: 1.22 * 0.5 + 0.004,
                     y: 0.52,
                     z: -0.05,
                     size: 0.32,
                     opacity: 1.0)

        // Wheels.
        for z in [-1.03, 1.05] {
            for side in [-1.0, 1.0] {
                car.addWheel(position: SIMD3<Float>(Float(side) * 0.59, car.wheelRadius + 0.02, Float(z)),
                             radius: car.wheelRadius,
                             width: 0.27,
                             rimStyle: config.wheelStyle == 0 ? 1 : config.wheelStyle,
                             steering: z < 0)
            }
        }

        return car
    }

    // MARK: - Formula

    private static func makeFormula(config: CarConfig) -> RaceCarNode {
        let primary = NSColor(hex: config.primaryHex) ?? .orange
        let secondary = NSColor(hex: config.secondaryHex) ?? .black
        let car = RaceCarNode(model: .formula,
                              length: 3.55,
                              width: 1.62,
                              wheelRadius: 0.36,
                              cockpitAnchor: SIMD3<Float>(0, 0.98, -0.38))
        let bodyMaterial = paint(primary)
        let accentMaterial = secondaryPaint(secondary)

        let monocoque = LoftGeometry.make(sections: [
            .init(z: -1.78, width: 0.11, bottom: 0.11, top: 0.20, roundness: 2.2),
            .init(z: -1.50, width: 0.17, bottom: 0.09, top: 0.25, roundness: 2.4),
            .init(z: -1.10, width: 0.25, bottom: 0.08, top: 0.33, roundness: 2.6),
            .init(z: -0.65, width: 0.34, bottom: 0.075, top: 0.48, roundness: 2.8),
            .init(z: -0.15, width: 0.41, bottom: 0.075, top: 0.60, roundness: 3.0),
            .init(z: 0.40, width: 0.42, bottom: 0.075, top: 0.66, roundness: 3.0),
            .init(z: 0.95, width: 0.34, bottom: 0.075, top: 0.64, roundness: 2.8),
            .init(z: 1.35, width: 0.23, bottom: 0.08, top: 0.48, roundness: 2.4)
        ], segments: 28, material: bodyMaterial)
        car.chassis.addChildNode(SCNNode(geometry: monocoque))

        // Sidepods.
        for side in [-1.0, 1.0] {
            let sidepod = roundedBox(width: 0.39, height: 0.24, length: 1.18, radius: 0.10, material: bodyMaterial)
            sidepod.position = SCNVector3(Float(side) * 0.46, 0.27, 0.28)
            car.chassis.addChildNode(sidepod)
            let intake = roundedBox(width: 0.26, height: 0.13, length: 0.10, radius: 0.045, material: carbon())
            intake.position = SCNVector3(Float(side) * 0.46, 0.31, -0.31)
            car.chassis.addChildNode(intake)
        }

        // Cockpit opening, seat, driver, halo.
        let cockpit = roundedBox(width: 0.36, height: 0.08, length: 0.62, radius: 0.08, material: carbon())
        cockpit.position = SCNVector3(0, 0.56, 0.04)
        car.chassis.addChildNode(cockpit)
        let helmet = SCNSphere(radius: 0.135)
        helmet.segmentCount = 24
        helmet.firstMaterial = paint(NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.86, alpha: 1))
        let helmetNode = SCNNode(geometry: helmet)
        helmetNode.position = SCNVector3(0, 0.73, 0.05)
        car.chassis.addChildNode(helmetNode)
        let visor = SCNBox(width: 0.19, height: 0.055, length: 0.045, chamferRadius: 0.02)
        visor.firstMaterial = lightLens(color: NSColor(calibratedRed: 0.03, green: 0.10, blue: 0.14, alpha: 1))
        let visorNode = SCNNode(geometry: visor)
        visorNode.position = SCNVector3(0, 0.75, -0.09)
        car.chassis.addChildNode(visorNode)

        let halo = SCNTorus(ringRadius: 0.34, pipeRadius: 0.022)
        halo.ringSegmentCount = 28
        halo.pipeSegmentCount = 8
        halo.firstMaterial = carbon()
        let haloNode = SCNNode(geometry: halo)
        haloNode.position = SCNVector3(0, 0.83, 0.10)
        haloNode.eulerAngles.x = .pi / 2
        car.chassis.addChildNode(haloNode)
        let haloPost = SCNCylinder(radius: 0.020, height: 0.26)
        haloPost.firstMaterial = carbon()
        let haloPostNode = SCNNode(geometry: haloPost)
        haloPostNode.position = SCNVector3(0, 0.74, -0.22)
        car.chassis.addChildNode(haloPostNode)

        // Engine cover / airbox.
        let airbox = roundedBox(width: 0.25, height: 0.28, length: 0.30, radius: 0.08, material: bodyMaterial)
        airbox.position = SCNVector3(0, 0.71, 0.52)
        car.chassis.addChildNode(airbox)
        let intake = SCNCylinder(radius: 0.09, height: 0.12)
        intake.firstMaterial = carbon()
        let intakeNode = SCNNode(geometry: intake)
        intakeNode.position = SCNVector3(0, 0.83, 0.38)
        intakeNode.eulerAngles.x = .pi / 2
        car.chassis.addChildNode(intakeNode)

        // Front wing.
        let frontWing = roundedBox(width: 1.58, height: 0.035, length: 0.36, radius: 0.018, material: carbon())
        frontWing.position = SCNVector3(0, 0.13, -1.74)
        car.chassis.addChildNode(frontWing)
        for side in [-1.0, 1.0] {
            let endplate = roundedBox(width: 0.025, height: 0.20, length: 0.40, radius: 0.012, material: bodyMaterial)
            endplate.position = SCNVector3(Float(side) * 0.79, 0.21, -1.74)
            car.chassis.addChildNode(endplate)
        }

        // Rear wing.
        let rearWing = roundedBox(width: 1.34, height: 0.045, length: 0.30, radius: 0.018, material: carbon())
        rearWing.position = SCNVector3(0, 0.95, 1.45)
        car.chassis.addChildNode(rearWing)
        for side in [-1.0, 1.0] {
            let endplate = roundedBox(width: 0.03, height: 0.30, length: 0.36, radius: 0.012, material: bodyMaterial)
            endplate.position = SCNVector3(Float(side) * 0.68, 0.86, 1.45)
            car.chassis.addChildNode(endplate)
            let support = roundedBox(width: 0.035, height: 0.32, length: 0.045, radius: 0.01, material: carbon())
            support.position = SCNVector3(Float(side) * 0.28, 0.78, 1.43)
            car.chassis.addChildNode(support)
        }

        // Nose number and accent.
        addTopDecal(car: car,
                    image: TextureFactory.decalRoundel,
                    y: 0.285,
                    z: -1.38,
                    size: 0.26,
                    opacity: 1)
        let noseStripe = roundedBox(width: 0.09, height: 0.012, length: 0.72, radius: 0.004, material: accentMaterial)
        noseStripe.position = SCNVector3(0, 0.28, -1.30)
        car.chassis.addChildNode(noseStripe)

        // Lights.
        let brakeMaterial = brakeLens()
        let rainLight = roundedBox(width: 0.14, height: 0.07, length: 0.03, radius: 0.01, material: brakeMaterial)
        rainLight.position = SCNVector3(0, 0.35, 1.48)
        car.chassis.addChildNode(rainLight)
        car.setBrakeMaterial(brakeMaterial)

        // Wheels and suspension.
        let wheelWidth: Float = 0.30
        for z in [-1.12, 1.08] {
            for side in [-1.0, 1.0] {
                let x = Float(side) * 0.73
                car.addWheel(position: SIMD3<Float>(x, car.wheelRadius + 0.02, Float(z)),
                             radius: car.wheelRadius,
                             width: wheelWidth,
                             rimStyle: 2,
                             steering: z < 0)
                addSuspension(car: car,
                              from: SIMD3<Float>(Float(side) * 0.25, 0.30, Float(z)),
                              to: SIMD3<Float>(x, car.wheelRadius + 0.02, Float(z)))
                addSuspension(car: car,
                              from: SIMD3<Float>(Float(side) * 0.30, 0.52, Float(z) * 0.92),
                              to: SIMD3<Float>(x, car.wheelRadius + 0.22, Float(z)))
            }
        }

        return car
    }

    private static func addSuspension(car: RaceCarNode, from: SIMD3<Float>, to: SIMD3<Float>) {
        let direction = to - from
        let length = simd_length(direction)
        guard length > 0.01 else { return }
        let cylinder = SCNCylinder(radius: 0.014, height: CGFloat(length))
        cylinder.radialSegmentCount = 8
        cylinder.firstMaterial = carbon()
        let node = SCNNode(geometry: cylinder)
        node.simdPosition = (from + to) * 0.5
        node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(direction))
        car.chassis.addChildNode(node)
    }

    // MARK: - Details

    private static func roundedBox(width: Float,
                                   height: Float,
                                   length: Float,
                                   radius: Float,
                                   material: SCNMaterial) -> SCNNode {
        let box = SCNBox(width: CGFloat(width),
                         height: CGFloat(height),
                         length: CGFloat(length),
                         chamferRadius: CGFloat(radius))
        box.chamferSegmentCount = 8
        box.firstMaterial = material
        return SCNNode(geometry: box)
    }

    private static func addSecondaryStripe(to car: RaceCarNode,
                                           material: SCNMaterial,
                                           y: Float,
                                           z: Float,
                                           length: Float,
                                           width: Float) {
        let stripe = roundedBox(width: width, height: 0.012, length: length, radius: 0.004, material: material)
        stripe.position = SCNVector3(0, y, z)
        car.chassis.addChildNode(stripe)
    }

    private static func addSideDecal(car: RaceCarNode,
                                     image: NSImage,
                                     x: Float,
                                     y: Float,
                                     z: Float,
                                     size: Float,
                                     opacity: CGFloat) {
        let plane = SCNPlane(width: CGFloat(size), height: CGFloat(size))
        plane.firstMaterial = decalMaterial(image, opacity: opacity)
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(x, y, z)
        node.eulerAngles.y = x > 0 ? .pi / 2 : -.pi / 2
        car.chassis.addChildNode(node)
    }

    private static func addTopDecal(car: RaceCarNode,
                                    image: NSImage,
                                    y: Float,
                                    z: Float,
                                    size: Float,
                                    opacity: CGFloat) {
        let plane = SCNPlane(width: CGFloat(size), height: CGFloat(size))
        plane.firstMaterial = decalMaterial(image, opacity: opacity)
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, y, z)
        node.eulerAngles.x = -.pi / 2
        car.chassis.addChildNode(node)
    }
}

// MARK: - Lofted body geometry

struct LoftSection {
    var z: Float
    var width: Float
    var bottom: Float
    var top: Float
    var roundness: Float
}

enum LoftGeometry {
    static func make(sections: [LoftSection], segments: Int = 28, material: SCNMaterial) -> SCNGeometry {
        guard sections.count >= 2 else {
            return SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.1)
        }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [Int32] = []

        let ringCount = segments + 1
        positions.reserveCapacity(sections.count * ringCount + 2)
        normals.reserveCapacity(sections.count * ringCount + 2)
        uvs.reserveCapacity(sections.count * ringCount + 2)

        func sectionPoint(_ section: LoftSection, _ angle: Float) -> SIMD3<Float> {
            let c = cos(angle)
            let s = sin(angle)
            let exponent = 2 / max(1.4, section.roundness)
            let x = section.width * (c < 0 ? -1 : 1) * pow(abs(c), exponent)
            let centerY = (section.top + section.bottom) * 0.5
            let halfHeight = max(0.005, (section.top - section.bottom) * 0.5)
            let y = centerY + halfHeight * (s < 0 ? -1 : 1) * pow(abs(s), exponent)
            return SIMD3<Float>(x, y, section.z)
        }

        for (sectionIndex, section) in sections.enumerated() {
            for index in 0...segments {
                let angle = Float(index) / Float(segments) * 2 * Float.pi
                let p = sectionPoint(section, angle)
                positions.append(p)
                uvs.append(SIMD2<Float>(Float(index) / Float(segments),
                                        Float(sectionIndex) / Float(sections.count - 1)))

                let prevSection = sections[max(0, sectionIndex - 1)]
                let nextSection = sections[min(sections.count - 1, sectionIndex + 1)]
                let angleU = 2 * Float.pi / Float(segments)
                let pU0 = sectionPoint(section, angle - angleU)
                let pU1 = sectionPoint(section, angle + angleU)
                let pV0 = sectionPoint(prevSection, angle)
                let pV1 = sectionPoint(nextSection, angle)
                let tangentU = pU1 - pU0
                let tangentV = pV1 - pV0
                var n = simd_cross(tangentU, tangentV)
                if simd_length(n) < 0.0001 {
                    n = SIMD3<Float>(0, 1, 0)
                }
                normals.append(simd_normalize(n))
            }
        }

        for sectionIndex in 0..<(sections.count - 1) {
            for index in 0..<segments {
                let a = Int32(sectionIndex * ringCount + index)
                let b = Int32(sectionIndex * ringCount + index + 1)
                let c = Int32((sectionIndex + 1) * ringCount + index + 1)
                let d = Int32((sectionIndex + 1) * ringCount + index)
                indices.append(contentsOf: [a, b, c, a, c, d])
            }
        }

        // Nose cap.
        let frontCenterIndex = Int32(positions.count)
        let first = sections[0]
        positions.append(SIMD3<Float>(0, (first.bottom + first.top) * 0.5, first.z))
        normals.append(SIMD3<Float>(0, 0, -1))
        uvs.append(SIMD2<Float>(0.5, 0.5))
        for index in 0..<segments {
            let a = Int32(index)
            let b = Int32(index + 1)
            indices.append(contentsOf: [frontCenterIndex, a, b])
        }

        // Tail cap.
        let rearCenterIndex = Int32(positions.count)
        let last = sections[sections.count - 1]
        positions.append(SIMD3<Float>(0, (last.bottom + last.top) * 0.5, last.z))
        normals.append(SIMD3<Float>(0, 0, 1))
        uvs.append(SIMD2<Float>(0.5, 0.5))
        let tailStart = (sections.count - 1) * ringCount
        for index in 0..<segments {
            let a = Int32(tailStart + index)
            let b = Int32(tailStart + index + 1)
            indices.append(contentsOf: [rearCenterIndex, b, a])
        }

        let positionData = positions.map { SCNVector3($0.x, $0.y, $0.z) }
        let normalData = normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let uvData = uvs.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positionData),
                SCNGeometrySource(normals: normalData),
                SCNGeometrySource(textureCoordinates: uvData)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        geometry.firstMaterial?.isDoubleSided = true
        return geometry
    }
}
