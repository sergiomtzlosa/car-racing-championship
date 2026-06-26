#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_master.png"
let size = 1024
let rect = CGRect(x: 0, y: 0, width: size, height: size)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Unable to create bitmap context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let cg = context.cgContext
cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)
cg.clear(rect)

// Transparent outer margin, macOS-style rounded square.
let tile = CGRect(x: 62, y: 62, width: 900, height: 900)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 198, cornerHeight: 198, transform: nil)

cg.saveGState()
cg.addPath(tilePath)
cg.clip()

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(calibratedRed: 0.105, green: 0.120, blue: 0.145, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.030, green: 0.034, blue: 0.042, alpha: 1).cgColor
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1]) {
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 962), end: CGPoint(x: 512, y: 62), options: [])
}

// Carbon-fibre style diagonal weave.
cg.setLineWidth(2)
for i in stride(from: -1100, through: 1600, by: 44) {
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.022).cgColor)
    cg.move(to: CGPoint(x: i, y: 62))
    cg.addLine(to: CGPoint(x: i + 900, y: 962))
    cg.strokePath()
    cg.setStrokeColor(NSColor.black.withAlphaComponent(0.15).cgColor)
    cg.move(to: CGPoint(x: i + 22, y: 62))
    cg.addLine(to: CGPoint(x: i + 922, y: 962))
    cg.strokePath()
}

// Warm ambient glow behind the car.
if let glow = CGGradient(colorsSpace: colorSpace, colors: [
    NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.08, alpha: 0.32).cgColor,
    NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.08, alpha: 0.0).cgColor
] as CFArray, locations: [0, 1]) {
    cg.drawRadialGradient(glow, startCenter: CGPoint(x: 690, y: 390), startRadius: 20,
                          endCenter: CGPoint(x: 690, y: 390), endRadius: 430, options: [])
}

// Stylised track ribbon sweeping into a loop.
func drawTrack() {
    cg.saveGState()
    cg.setLineCap(.round)
    cg.setLineJoin(.round)

    // Shadow.
    cg.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: NSColor.black.withAlphaComponent(0.8).cgColor)
    cg.setStrokeColor(NSColor(calibratedWhite: 0.055, alpha: 1).cgColor)
    cg.setLineWidth(184)
    cg.move(to: CGPoint(x: 118, y: 740))
    cg.addCurve(to: CGPoint(x: 420, y: 560), control1: CGPoint(x: 230, y: 840), control2: CGPoint(x: 330, y: 690))
    cg.addCurve(to: CGPoint(x: 680, y: 790), control1: CGPoint(x: 530, y: 430), control2: CGPoint(x: 605, y: 690))
    cg.addCurve(to: CGPoint(x: 910, y: 700), control1: CGPoint(x: 770, y: 900), control2: CGPoint(x: 850, y: 810))
    cg.strokePath()
    cg.setShadow(offset: .zero, blur: 0, color: nil)

    // Red racing surface.
    cg.setStrokeColor(NSColor(calibratedRed: 0.76, green: 0.055, blue: 0.035, alpha: 1).cgColor)
    cg.setLineWidth(158)
    cg.move(to: CGPoint(x: 118, y: 740))
    cg.addCurve(to: CGPoint(x: 420, y: 560), control1: CGPoint(x: 230, y: 840), control2: CGPoint(x: 330, y: 690))
    cg.addCurve(to: CGPoint(x: 680, y: 790), control1: CGPoint(x: 530, y: 430), control2: CGPoint(x: 605, y: 690))
    cg.addCurve(to: CGPoint(x: 910, y: 700), control1: CGPoint(x: 770, y: 900), control2: CGPoint(x: 850, y: 810))
    cg.strokePath()

    // Inner highlight.
    cg.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.22, blue: 0.08, alpha: 0.45).cgColor)
    cg.setLineWidth(132)
    cg.move(to: CGPoint(x: 122, y: 741))
    cg.addCurve(to: CGPoint(x: 420, y: 562), control1: CGPoint(x: 232, y: 839), control2: CGPoint(x: 332, y: 692))
    cg.addCurve(to: CGPoint(x: 680, y: 792), control1: CGPoint(x: 530, y: 433), control2: CGPoint(x: 605, y: 692))
    cg.addCurve(to: CGPoint(x: 908, y: 702), control1: CGPoint(x: 770, y: 899), control2: CGPoint(x: 850, y: 812))
    cg.strokePath()

    // White lane markings.
    cg.setStrokeColor(NSColor(calibratedWhite: 0.95, alpha: 0.88).cgColor)
    cg.setLineWidth(6)
    cg.move(to: CGPoint(x: 118, y: 755))
    cg.addCurve(to: CGPoint(x: 420, y: 575), control1: CGPoint(x: 230, y: 855), control2: CGPoint(x: 330, y: 705))
    cg.addCurve(to: CGPoint(x: 680, y: 805), control1: CGPoint(x: 530, y: 448), control2: CGPoint(x: 605, y: 705))
    cg.addCurve(to: CGPoint(x: 910, y: 715), control1: CGPoint(x: 770, y: 915), control2: CGPoint(x: 850, y: 825))
    cg.strokePath()
    cg.setLineDash(phase: 0, lengths: [22, 20])
    cg.move(to: CGPoint(x: 118, y: 725))
    cg.addCurve(to: CGPoint(x: 420, y: 545), control1: CGPoint(x: 230, y: 825), control2: CGPoint(x: 330, y: 675))
    cg.addCurve(to: CGPoint(x: 680, y: 775), control1: CGPoint(x: 530, y: 415), control2: CGPoint(x: 605, y: 675))
    cg.addCurve(to: CGPoint(x: 910, y: 685), control1: CGPoint(x: 770, y: 885), control2: CGPoint(x: 850, y: 795))
    cg.strokePath()
    cg.setLineDash(phase: 0, lengths: [])

    cg.restoreGState()
}
drawTrack()

// Start/finish checker strip on the track.
cg.saveGState()
cg.translateBy(x: 150, y: 700)
cg.rotate(by: -0.48)
for row in 0..<3 {
    for col in 0..<8 {
        let isDark = (row + col) % 2 == 0
        cg.setFillColor((isDark ? NSColor.white : NSColor.black).withAlphaComponent(0.92).cgColor)
        cg.fill(CGRect(x: CGFloat(col) * 17, y: CGFloat(row) * 17, width: 17, height: 17))
    }
}
cg.restoreGState()

// Car in three-quarter view.
func drawCar() {
    cg.saveGState()
    cg.translateBy(x: 600, y: 330)
    cg.rotate(by: -0.13)
    cg.scaleBy(x: 1.06, y: 1.06)
    cg.setShadow(offset: CGSize(width: 0, height: -22), blur: 38, color: NSColor.black.withAlphaComponent(0.75).cgColor)

    // Rear wheel.
    cg.setFillColor(NSColor(calibratedWhite: 0.045, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: -285, y: 6, width: 146, height: 146))
    cg.setFillColor(NSColor(calibratedWhite: 0.34, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: -252, y: 39, width: 80, height: 80))
    cg.setFillColor(NSColor(calibratedWhite: 0.13, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: -232, y: 59, width: 40, height: 40))

    // Front wheel.
    cg.setFillColor(NSColor(calibratedWhite: 0.045, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: 190, y: 24, width: 136, height: 136))
    cg.setFillColor(NSColor(calibratedWhite: 0.34, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: 219, y: 53, width: 78, height: 78))
    cg.setFillColor(NSColor(calibratedWhite: 0.13, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: 239, y: 73, width: 38, height: 38))

    // Main body silhouette.
    let body = NSBezierPath()
    body.move(to: CGPoint(x: -300, y: 112))
    body.curve(to: CGPoint(x: -220, y: 190), controlPoint1: CGPoint(x: -318, y: 160), controlPoint2: CGPoint(x: -280, y: 188))
    body.curve(to: CGPoint(x: -88, y: 213), controlPoint1: CGPoint(x: -174, y: 208), controlPoint2: CGPoint(x: -125, y: 216))
    body.line(to: CGPoint(x: 122, y: 205))
    body.curve(to: CGPoint(x: 248, y: 170), controlPoint1: CGPoint(x: 190, y: 204), controlPoint2: CGPoint(x: 226, y: 190))
    body.curve(to: CGPoint(x: 312, y: 119), controlPoint1: CGPoint(x: 281, y: 152), controlPoint2: CGPoint(x: 304, y: 137))
    body.line(to: CGPoint(x: 300, y: 93))
    body.curve(to: CGPoint(x: 120, y: 72), controlPoint1: CGPoint(x: 250, y: 87), controlPoint2: CGPoint(x: 180, y: 75))
    body.line(to: CGPoint(x: -210, y: 72))
    body.curve(to: CGPoint(x: -300, y: 112), controlPoint1: CGPoint(x: -260, y: 76), controlPoint2: CGPoint(x: -292, y: 92))
    body.close()

    if let grad = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.07, alpha: 1),
        NSColor(calibratedRed: 0.68, green: 0.045, blue: 0.02, alpha: 1)
    ], atLocations: [0.0, 1.0], colorSpace: .deviceRGB) {
        grad.draw(in: body, angle: 72)
    }

    // Body highlight.
    cg.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.2, alpha: 0.7).cgColor)
    cg.setLineWidth(5)
    cg.move(to: CGPoint(x: -206, y: 186))
    cg.addCurve(to: CGPoint(x: 220, y: 177), control1: CGPoint(x: -95, y: 214), control2: CGPoint(x: 110, y: 204))
    cg.strokePath()

    // Cabin / glass.
    let glass = NSBezierPath()
    glass.move(to: CGPoint(x: -112, y: 201))
    glass.curve(to: CGPoint(x: 60, y: 198), controlPoint1: CGPoint(x: -64, y: 266), controlPoint2: CGPoint(x: 2, y: 252))
    glass.line(to: CGPoint(x: 78, y: 199))
    glass.curve(to: CGPoint(x: -25, y: 216), controlPoint1: CGPoint(x: 50, y: 236), controlPoint2: CGPoint(x: 10, y: 229))
    glass.close()
    if let glassGrad = NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.15, alpha: 0.96),
        NSColor(calibratedRed: 0.32, green: 0.55, blue: 0.66, alpha: 0.9)
    ], atLocations: [0, 1], colorSpace: .deviceRGB) {
        glassGrad.draw(in: glass, angle: 60)
    }

    // Rear wing.
    cg.setFillColor(NSColor(calibratedWhite: 0.06, alpha: 1).cgColor)
    cg.fill(CGRect(x: -276, y: 230, width: 150, height: 18))
    cg.fill(CGRect(x: -268, y: 217, width: 18, height: 36))
    cg.fill(CGRect(x: -152, y: 217, width: 18, height: 36))
    cg.setFillColor(NSColor(calibratedRed: 0.95, green: 0.18, blue: 0.05, alpha: 1).cgColor)
    cg.fill(CGRect(x: -270, y: 234, width: 138, height: 5))

    // Headlight.
    cg.setFillColor(NSColor(calibratedWhite: 0.92, alpha: 1).cgColor)
    cg.fillEllipse(in: CGRect(x: 230, y: 126, width: 70, height: 38))
    cg.setFillColor(NSColor(calibratedRed: 0.55, green: 0.85, blue: 1.0, alpha: 0.9).cgColor)
    cg.fillEllipse(in: CGRect(x: 245, y: 136, width: 40, height: 20))

    // Tail light.
    cg.setFillColor(NSColor(calibratedRed: 1.0, green: 0.1, blue: 0.06, alpha: 0.95).cgColor)
    cg.fill(CGRect(x: -311, y: 128, width: 18, height: 34))

    // Racing number roundel.
    cg.setFillColor(NSColor(calibratedWhite: 0.96, alpha: 0.95).cgColor)
    cg.fillEllipse(in: CGRect(x: -88, y: 110, width: 74, height: 74))
    let number = "7" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "HelveticaNeue-Bold", size: 55) ?? NSFont.boldSystemFont(ofSize: 55),
        .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.12, alpha: 1)
    ]
    let numberSize = number.size(withAttributes: attrs)
    number.draw(at: CGPoint(x: -51 - numberSize.width / 2, y: 113), withAttributes: attrs)

    // Splitter and side skirt.
    cg.setFillColor(NSColor(calibratedWhite: 0.05, alpha: 1).cgColor)
    cg.fill(CGRect(x: 240, y: 92, width: 92, height: 16))
    cg.fill(CGRect(x: -244, y: 86, width: 420, height: 13))
    cg.restoreGState()
}
drawCar()

// Vignette / inner edge.
cg.saveGState()
cg.addPath(tilePath)
cg.clip()
if let vignette = CGGradient(colorsSpace: colorSpace, colors: [
    NSColor.black.withAlphaComponent(0).cgColor,
    NSColor.black.withAlphaComponent(0.45).cgColor
] as CFArray, locations: [0.55, 1.0]) {
    cg.drawRadialGradient(vignette, startCenter: CGPoint(x: 512, y: 512), startRadius: 300,
                          endCenter: CGPoint(x: 512, y: 512), endRadius: 680, options: [])
}
cg.restoreGState()
cg.restoreGState()

// Tile rim.
cg.saveGState()
cg.addPath(tilePath)
cg.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor)
cg.setLineWidth(6)
cg.strokePath()
cg.setStrokeColor(NSColor.black.withAlphaComponent(0.9).cgColor)
cg.setLineWidth(2)
let innerRim = CGPath(roundedRect: tile.insetBy(dx: 7, dy: 7), cornerWidth: 192, cornerHeight: 192, transform: nil)
cg.addPath(innerRim)
cg.strokePath()
cg.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
