import AppKit
import CoreGraphics
import SceneKit

enum TextureFactory {
    private static var cache: [String: NSImage] = [:]
    private static let lock = NSLock()

    static func cached(_ key: String, _ make: () -> NSImage) -> NSImage {
        lock.lock()
        defer { lock.unlock() }
        if let image = cache[key] { return image }
        let image = make()
        cache[key] = image
        return image
    }

    private static func image(width: Int = 512,
                              height: Int = 512,
                              draw: (CGContext, CGSize) -> Void) -> NSImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        draw(context, CGSize(width: width, height: height))
        guard let cgImage = context.makeImage() else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private static func rng(_ seed: UInt64) -> () -> Float {
        var state = seed
        return {
            state = state &* 2862933555777941757 &+ 3037000493
            let value = Float((state >> 33) & 0xFFFFFF) / Float(0xFFFFFF)
            return value
        }
    }

    // MARK: - Track

    static var trackSurface: NSImage {
        cached("trackSurface") {
            image(width: 512, height: 512) { context, size in
                let random = rng(0xA11CE)
                context.setFillColor(NSColor(calibratedRed: 0.095, green: 0.10, blue: 0.112, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))

                for _ in 0..<6800 {
                    let x = CGFloat(random()) * size.width
                    let y = CGFloat(random()) * size.height
                    let v = 0.06 + CGFloat(random()) * 0.09
                    context.setFillColor(NSColor(calibratedWhite: v, alpha: 0.18).cgColor)
                    let r: CGFloat = 0.4 + CGFloat(random()) * 1.2
                    context.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }

                // Fine moulded plastic streaks.
                context.setLineWidth(1)
                for i in 0..<90 {
                    let y = CGFloat(i) * size.height / 90
                    context.setStrokeColor(NSColor(calibratedWhite: 0.24, alpha: 0.035).cgColor)
                    context.move(to: CGPoint(x: 0, y: y))
                    context.addLine(to: CGPoint(x: size.width, y: y + CGFloat(random()) * 8 - 4))
                    context.strokePath()
                }

                // Rubber pickup lines where the cars run.
                for center in [0.30, 0.70] {
                    let rect = CGRect(x: size.width * center - 70, y: 0, width: 140, height: size.height)
                    let colors = [
                        NSColor(calibratedWhite: 0.02, alpha: 0.00).cgColor,
                        NSColor(calibratedWhite: 0.02, alpha: 0.24).cgColor,
                        NSColor(calibratedWhite: 0.02, alpha: 0.00).cgColor
                    ] as CFArray
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                 colors: colors,
                                                 locations: [0, 0.5, 1]) {
                        context.saveGState()
                        context.clip(to: rect)
                        context.drawLinearGradient(gradient,
                                                   start: CGPoint(x: rect.minX, y: 0),
                                                   end: CGPoint(x: rect.maxX, y: 0),
                                                   options: [])
                        context.restoreGState()
                    }
                }
            }
        }
    }

    static var slot: NSImage {
        cached("slot") {
            image(width: 32, height: 256) { context, size in
                context.setFillColor(NSColor(calibratedWhite: 0.012, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                context.setFillColor(NSColor(calibratedWhite: 0.20, alpha: 0.35).cgColor)
                context.fill(CGRect(x: 2, y: 0, width: 2, height: size.height))
                context.fill(CGRect(x: size.width - 4, y: 0, width: 2, height: size.height))
            }
        }
    }

    static var curb: NSImage {
        cached("curb") {
            image(width: 512, height: 64) { context, size in
                let segment: CGFloat = 42
                var index = 0
                var x: CGFloat = 0
                while x < size.width {
                    context.setFillColor((index % 2 == 0
                                          ? NSColor(calibratedRed: 0.83, green: 0.06, blue: 0.04, alpha: 1)
                                          : NSColor(calibratedWhite: 0.88, alpha: 1)).cgColor)
                    context.fill(CGRect(x: x, y: 0, width: segment, height: size.height))
                    x += segment
                    index += 1
                }
                context.setFillColor(NSColor.black.withAlphaComponent(0.12).cgColor)
                context.fill(CGRect(x: 0, y: 0, width: size.width, height: 5))
                context.fill(CGRect(x: 0, y: size.height - 5, width: size.width, height: 5))
            }
        }
    }

    static var laneLine: NSImage {
        cached("laneLine") {
            image(width: 32, height: 256) { context, size in
                context.setFillColor(NSColor(calibratedWhite: 0.92, alpha: 0.9).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                context.setFillColor(NSColor(calibratedWhite: 0.8, alpha: 0.2).cgColor)
                context.fill(CGRect(x: 0, y: 0, width: size.width, height: 2))
            }
        }
    }

    static var checker: NSImage {
        cached("checker") {
            image(width: 512, height: 96) { context, size in
                let tile: CGFloat = 32
                for row in 0..<3 {
                    for col in 0..<16 {
                        let isDark = (row + col) % 2 == 0
                        context.setFillColor((isDark ? NSColor.black : NSColor.white).withAlphaComponent(0.95).cgColor)
                        context.fill(CGRect(x: CGFloat(col) * tile,
                                            y: CGFloat(row) * tile,
                                            width: tile,
                                            height: tile))
                    }
                }
            }
        }
    }

    static var carbonFibre: NSImage {
        cached("carbonFibre") {
            image(width: 256, height: 256) { context, size in
                context.setFillColor(NSColor(calibratedWhite: 0.045, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                let cell: CGFloat = 16
                context.setLineWidth(2)
                for row in 0..<16 {
                    for col in 0..<16 {
                        let x = CGFloat(col) * cell
                        let y = CGFloat(row) * cell
                        context.setFillColor((row + col) % 2 == 0
                                             ? NSColor(calibratedWhite: 0.12, alpha: 0.9).cgColor
                                             : NSColor(calibratedWhite: 0.075, alpha: 0.9).cgColor)
                        context.fill(CGRect(x: x, y: y, width: cell, height: cell))
                        context.setStrokeColor(NSColor(calibratedWhite: 0.2, alpha: 0.25).cgColor)
                        context.stroke(CGRect(x: x + 1, y: y + 1, width: cell - 2, height: cell - 2))
                    }
                }
            }
        }
    }

    static var wood: NSImage {
        cached("wood") {
            image(width: 1024, height: 512) { context, size in
                let random = rng(0xB0A2D)
                context.setFillColor(NSColor(calibratedRed: 0.22, green: 0.14, blue: 0.085, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                let plankHeight = size.height / 8
                for plank in 0..<8 {
                    let y = CGFloat(plank) * plankHeight
                    let tint = 0.18 + CGFloat(random()) * 0.08
                    context.setFillColor(NSColor(calibratedRed: tint, green: tint * 0.62, blue: tint * 0.36, alpha: 1).cgColor)
                    context.fill(CGRect(x: 0, y: y, width: size.width, height: plankHeight - 2))
                    context.setStrokeColor(NSColor(calibratedWhite: 0.04, alpha: 0.65).cgColor)
                    context.setLineWidth(2)
                    context.stroke(CGRect(x: 0, y: y, width: size.width, height: plankHeight))

                    for _ in 0..<30 {
                        let offset = CGFloat(random()) * plankHeight
                        context.setStrokeColor(NSColor(calibratedWhite: 0.05, alpha: 0.09).cgColor)
                        context.setLineWidth(1)
                        context.move(to: CGPoint(x: 0, y: y + offset))
                        context.addCurve(to: CGPoint(x: size.width, y: y + offset + CGFloat(random()) * 8 - 4),
                                         control1: CGPoint(x: size.width * 0.33, y: y + offset + CGFloat(random()) * 10 - 5),
                                         control2: CGPoint(x: size.width * 0.66, y: y + offset + CGFloat(random()) * 10 - 5))
                        context.strokePath()
                    }
                }
            }
        }
    }

    static var tableMat: NSImage {
        cached("tableMat") {
            image(width: 512, height: 512) { context, size in
                let random = rng(0xF3E7)
                context.setFillColor(NSColor(calibratedRed: 0.055, green: 0.07, blue: 0.075, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                for _ in 0..<9000 {
                    let x = CGFloat(random()) * size.width
                    let y = CGFloat(random()) * size.height
                    let alpha = CGFloat(random()) * 0.08
                    context.setFillColor(NSColor(calibratedWhite: 0.35, alpha: alpha).cgColor)
                    let r = CGFloat(random()) * 1.6
                    context.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }
            }
        }
    }

    // MARK: - Car details

    static var metalFlakeNormal: NSImage {
        cached("metalFlakeNormal") {
            image(width: 256, height: 256) { context, size in
                let random = rng(0xF1A4)
                context.setFillColor(NSColor(calibratedRed: 0.5, green: 0.5, blue: 1.0, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                for _ in 0..<3200 {
                    let x = CGFloat(random()) * size.width
                    let y = CGFloat(random()) * size.height
                    let r = 0.4 + CGFloat(random()) * 0.8
                    let red = 0.5 + (CGFloat(random()) - 0.5) * 0.14
                    let green = 0.5 + (CGFloat(random()) - 0.5) * 0.14
                    context.setFillColor(NSColor(calibratedRed: red, green: green, blue: 1, alpha: 1).cgColor)
                    context.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }
            }
        }
    }

    static var tireNormal: NSImage {
        cached("tireNormal") {
            image(width: 256, height: 256) { context, size in
                context.setFillColor(NSColor(calibratedRed: 0.5, green: 0.5, blue: 1.0, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                context.setLineWidth(2)
                for row in 0..<18 {
                    let y = CGFloat(row) * 16
                    context.setStrokeColor(NSColor(calibratedRed: 0.55, green: 0.47, blue: 0.99, alpha: 0.75).cgColor)
                    context.move(to: CGPoint(x: 0, y: y))
                    context.addLine(to: CGPoint(x: size.width, y: y + 7))
                    context.strokePath()
                }
                context.setStrokeColor(NSColor(calibratedRed: 0.45, green: 0.55, blue: 0.98, alpha: 0.8).cgColor)
                for col in 0..<10 {
                    let x = CGFloat(col) * 28
                    context.move(to: CGPoint(x: x, y: 0))
                    context.addLine(to: CGPoint(x: x + 10, y: size.height))
                    context.strokePath()
                }
            }
        }
    }

    static var tireSidewall: NSImage {
        cached("tireSidewall") {
            image(width: 512, height: 128) { context, size in
                context.setFillColor(NSColor(calibratedWhite: 0.055, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                context.setStrokeColor(NSColor(calibratedWhite: 0.55, alpha: 0.32).cgColor)
                context.setLineWidth(2)
                context.stroke(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
                let text = "APEX  SLOT  SPORT" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .medium),
                    .foregroundColor: NSColor(calibratedWhite: 0.72, alpha: 0.6)
                ]
                for i in 0..<3 {
                    text.draw(at: CGPoint(x: 20 + CGFloat(i) * 170, y: 54), withAttributes: attrs)
                }
            }
        }
    }

    static var headlightLens: NSImage {
        cached("headlightLens") {
            image(width: 128, height: 128) { context, size in
                let colors = [
                    NSColor(calibratedWhite: 0.95, alpha: 1).cgColor,
                    NSColor(calibratedRed: 0.55, green: 0.78, blue: 0.9, alpha: 1).cgColor,
                    NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
                ] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors,
                                             locations: [0, 0.65, 1]) {
                    context.drawRadialGradient(gradient,
                                               startCenter: CGPoint(x: 48, y: 74),
                                               startRadius: 2,
                                               endCenter: CGPoint(x: 64, y: 64),
                                               endRadius: 70,
                                               options: [])
                }
            }
        }
    }

    static var decalRoundel: NSImage {
        cached("decalRoundel") {
            image(width: 256, height: 256) { context, size in
                context.setFillColor(NSColor(calibratedWhite: 0.95, alpha: 0.96).cgColor)
                context.fillEllipse(in: CGRect(x: 8, y: 8, width: 240, height: 240))
                context.setStrokeColor(NSColor(calibratedWhite: 0.1, alpha: 0.8).cgColor)
                context.setLineWidth(8)
                context.strokeEllipse(in: CGRect(x: 16, y: 16, width: 224, height: 224))
                let text = "7" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont(name: "HelveticaNeue-Bold", size: 150) ?? NSFont.boldSystemFont(ofSize: 150),
                    .foregroundColor: NSColor(calibratedWhite: 0.09, alpha: 1)
                ]
                let textSize = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                                      y: (size.height - textSize.height) / 2 - 4),
                          withAttributes: attrs)
            }
        }
    }

    static var sponsorDecal: NSImage {
        cached("sponsorDecal") {
            image(width: 512, height: 128) { context, size in
                context.clear(CGRect(origin: .zero, size: size))
                let text = "APEX" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont(name: "HelveticaNeue-Bold", size: 74) ?? NSFont.boldSystemFont(ofSize: 74),
                    .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1)
                ]
                text.draw(at: CGPoint(x: 20, y: 20), withAttributes: attrs)
                context.setFillColor(NSColor(calibratedRed: 1, green: 0.23, blue: 0.08, alpha: 1).cgColor)
                context.fill(CGRect(x: 270, y: 42, width: 220, height: 20))
                context.fill(CGRect(x: 270, y: 76, width: 140, height: 10))
            }
        }
    }

    static var racingStripeTexture: NSImage {
        cached("racingStripe") {
            image(width: 256, height: 64) { context, size in
                context.setFillColor(NSColor(calibratedRed: 0.94, green: 0.92, blue: 0.86, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                context.setFillColor(NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.08, alpha: 1).cgColor)
                context.fill(CGRect(x: 0, y: 24, width: size.width, height: 16))
            }
        }
    }

    // MARK: - Environment

    static var roomBackdrop: NSImage {
        cached("roomBackdrop") {
            image(width: 1024, height: 512) { context, size in
                let colors = [
                    NSColor(calibratedRed: 0.045, green: 0.052, blue: 0.068, alpha: 1).cgColor,
                    NSColor(calibratedRed: 0.075, green: 0.090, blue: 0.115, alpha: 1).cgColor,
                    NSColor(calibratedRed: 0.115, green: 0.140, blue: 0.175, alpha: 1).cgColor
                ] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors,
                                             locations: [0, 0.60, 1]) {
                    context.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: 0, y: size.height),
                                               options: [])
                }

                // Warm practical lights and a cool rim glow keep the room from
                // reading as a black void behind the track.
                func glow(_ center: CGPoint, radius: CGFloat, color: NSColor) {
                    let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                 colors: colors,
                                                 locations: [0, 1]) {
                        context.drawRadialGradient(gradient,
                                                   startCenter: center,
                                                   startRadius: 2,
                                                   endCenter: center,
                                                   endRadius: radius,
                                                   options: [])
                    }
                }
                glow(CGPoint(x: size.width * 0.18, y: size.height * 0.78),
                     radius: size.width * 0.28,
                     color: NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.29, alpha: 0.24))
                glow(CGPoint(x: size.width * 0.82, y: size.height * 0.72),
                     radius: size.width * 0.24,
                     color: NSColor(calibratedRed: 0.38, green: 0.57, blue: 0.92, alpha: 0.16))
                glow(CGPoint(x: size.width * 0.50, y: size.height * 0.94),
                     radius: size.width * 0.38,
                     color: NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.68, alpha: 0.10))

                let random = rng(0xBADC0DE)
                for _ in 0..<2600 {
                    let x = CGFloat(random()) * size.width
                    let y = CGFloat(random()) * size.height
                    let alpha = CGFloat(random()) * 0.035
                    context.setFillColor(NSColor(calibratedWhite: 0.8, alpha: alpha).cgColor)
                    context.fillEllipse(in: CGRect(x: x, y: y, width: 1.2, height: 1.2))
                }
            }
        }
    }

    static var studioEnvironment: NSImage {
        cached("studioEnvironment") {
            image(width: 1024, height: 512) { context, size in
                let colors = [
                    NSColor(calibratedRed: 0.30, green: 0.34, blue: 0.40, alpha: 1).cgColor,
                    NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1).cgColor,
                    NSColor(calibratedRed: 0.01, green: 0.012, blue: 0.016, alpha: 1).cgColor
                ] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors,
                                             locations: [0, 0.52, 1]) {
                    context.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: size.height),
                                               end: CGPoint(x: 0, y: 0),
                                               options: [])
                }

                func softbox(_ rect: CGRect, intensity: CGFloat, warm: Bool = false) {
                    let color = warm
                        ? NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.42, alpha: intensity)
                        : NSColor(calibratedWhite: 1.0, alpha: intensity)
                    let colors = [
                        color.cgColor,
                        color.withAlphaComponent(0).cgColor
                    ] as CFArray
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                 colors: colors,
                                                 locations: [0, 1]) {
                        context.drawRadialGradient(gradient,
                                                   startCenter: CGPoint(x: rect.midX, y: rect.midY),
                                                   startRadius: 2,
                                                   endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                                   endRadius: max(rect.width, rect.height) * 0.7,
                                                   options: [])
                    }
                }

                softbox(CGRect(x: 120, y: 300, width: 240, height: 110), intensity: 0.9)
                softbox(CGRect(x: 650, y: 320, width: 280, height: 100), intensity: 0.75)
                softbox(CGRect(x: 330, y: 120, width: 400, height: 80), intensity: 0.35, warm: true)
                softbox(CGRect(x: 760, y: 90, width: 160, height: 150), intensity: 0.5, warm: true)

                // Dark horizon line.
                context.setFillColor(NSColor.black.withAlphaComponent(0.2).cgColor)
                context.fill(CGRect(x: 0, y: 0, width: size.width, height: 38))
            }
        }
    }

    static var nightEnvironment: NSImage {
        cached("nightEnvironment") {
            image(width: 1024, height: 512) { context, size in
                let colors = [
                    NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.12, alpha: 1).cgColor,
                    NSColor(calibratedRed: 0.005, green: 0.009, blue: 0.018, alpha: 1).cgColor
                ] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors,
                                             locations: [0, 1]) {
                    context.drawLinearGradient(gradient,
                                               start: CGPoint(x: 0, y: size.height),
                                               end: CGPoint(x: 0, y: 0),
                                               options: [])
                }
                let random = rng(0x51A7)
                for _ in 0..<130 {
                    let x = CGFloat(random()) * size.width
                    let y = CGFloat(random()) * size.height * 0.65 + size.height * 0.3
                    let alpha = CGFloat(random()) * 0.5 + 0.15
                    context.setFillColor(NSColor(calibratedWhite: 1, alpha: alpha).cgColor)
                    let r = CGFloat(random()) * 1.4 + 0.4
                    context.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }
                for x in stride(from: 120, through: 940, by: 260) {
                    let rect = CGRect(x: x, y: 260, width: 130, height: 90)
                    let colors = [
                        NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.28, alpha: 0.85).cgColor,
                        NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.15, alpha: 0).cgColor
                    ] as CFArray
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                 colors: colors,
                                                 locations: [0, 1]) {
                        context.drawRadialGradient(gradient,
                                                   startCenter: CGPoint(x: rect.midX, y: rect.midY),
                                                   startRadius: 2,
                                                   endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                                   endRadius: 130,
                                                   options: [])
                    }
                }
            }
        }
    }
}
