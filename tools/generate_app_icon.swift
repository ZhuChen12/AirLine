import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
guard let cgContext = CGContext(
    data: nil,
    width: Int(size.width),
    height: Int(size.height),
    bitsPerComponent: 8,
    bytesPerRow: Int(size.width) * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Unable to create icon canvas")
}
let graphicsContext = NSGraphicsContext(cgContext: cgContext, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

let canvas = NSRect(origin: .zero, size: size)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 10 / 255, green: 14 / 255, blue: 26 / 255, alpha: 1),
    NSColor(calibratedRed: 21 / 255, green: 28 / 255, blue: 46 / 255, alpha: 1),
    NSColor(calibratedRed: 10 / 255, green: 14 / 255, blue: 26 / 255, alpha: 1),
])!
background.draw(in: canvas, angle: -45)

let orbit = NSBezierPath(ovalIn: NSRect(x: 184, y: 184, width: 656, height: 656))
orbit.lineWidth = 12
NSColor(calibratedRed: 111 / 255, green: 168 / 255, blue: 220 / 255, alpha: 0.10).setStroke()
orbit.stroke()

let route = NSBezierPath()
let routeStart = NSPoint(x: 225, y: 348)
let routeControl1 = NSPoint(x: 389, y: 328)
let routeControl2 = NSPoint(x: 594, y: 492)
let routeEnd = NSPoint(x: 768, y: 655)
func cubic(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat,
           _ c: CGFloat, _ d: CGFloat) -> CGFloat {
    let u = 1 - t
    return u * u * u * a
        + 3 * u * u * t * b
        + 3 * u * t * t * c
        + t * t * t * d
}
func cubicDerivative(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat,
                     _ c: CGFloat, _ d: CGFloat) -> CGFloat {
    let u = 1 - t
    return 3 * u * u * (b - a)
        + 6 * u * t * (c - b)
        + 3 * t * t * (d - c)
}
route.move(to: routeStart)
route.curve(
    to: routeEnd,
    controlPoint1: routeControl1,
    controlPoint2: routeControl2
)
NSGraphicsContext.saveGraphicsState()
let routeShadow = NSShadow()
routeShadow.shadowBlurRadius = 30
routeShadow.shadowColor = NSColor(calibratedRed: 111 / 255, green: 168 / 255, blue: 220 / 255, alpha: 0.38)
routeShadow.shadowOffset = .zero
routeShadow.set()
route.lineWidth = 54
NSColor(calibratedRed: 111 / 255, green: 168 / 255, blue: 220 / 255, alpha: 0.22).setStroke()
route.stroke()
NSGraphicsContext.restoreGraphicsState()

route.lineWidth = 28
route.lineCapStyle = .round
NSColor(calibratedRed: 111 / 255, green: 168 / 255, blue: 220 / 255, alpha: 0.82).setStroke()
route.stroke()

let originRing = NSBezierPath(ovalIn: NSRect(x: 177, y: 300, width: 96, height: 96))
originRing.lineWidth = 12
NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 0.24).setStroke()
originRing.stroke()

let origin = NSBezierPath(ovalIn: NSRect(x: 203, y: 326, width: 44, height: 44))
NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 1).setFill()
origin.fill()

let planeT: CGFloat = 0.94
let planeCenter = NSPoint(
    x: cubic(planeT, routeStart.x, routeControl1.x, routeControl2.x, routeEnd.x),
    y: cubic(planeT, routeStart.y, routeControl1.y, routeControl2.y, routeEnd.y)
)
let planeTangent = NSPoint(
    x: cubicDerivative(planeT, routeStart.x, routeControl1.x, routeControl2.x, routeEnd.x),
    y: cubicDerivative(planeT, routeStart.y, routeControl1.y, routeControl2.y, routeEnd.y)
)
let planeUnit: CGFloat = 80
let planeAngle = atan2(planeTangent.y, planeTangent.x) - Double.pi / 2
func planePoint(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    let dx = x * planeUnit
    let dy = -y * planeUnit
    return NSPoint(
        x: planeCenter.x + dx * cos(planeAngle) - dy * sin(planeAngle),
        y: planeCenter.y + dx * sin(planeAngle) + dy * cos(planeAngle)
    )
}

let plane = NSBezierPath()
plane.move(to: planePoint(0, -1.45))
plane.curve(
    to: planePoint(0.16, -0.24),
    controlPoint1: planePoint(0.11, -1.20),
    controlPoint2: planePoint(0.15, -0.55)
)
plane.line(to: planePoint(1.03, 0.26))
plane.line(to: planePoint(0.93, 0.48))
plane.line(to: planePoint(0.18, 0.20))
plane.line(to: planePoint(0.16, 0.76))
plane.line(to: planePoint(0.47, 1.02))
plane.line(to: planePoint(0.35, 1.15))
plane.line(to: planePoint(0, 0.91))
plane.line(to: planePoint(-0.35, 1.15))
plane.line(to: planePoint(-0.47, 1.02))
plane.line(to: planePoint(-0.16, 0.76))
plane.line(to: planePoint(-0.18, 0.20))
plane.line(to: planePoint(-0.93, 0.48))
plane.line(to: planePoint(-1.03, 0.26))
plane.line(to: planePoint(-0.16, -0.24))
plane.curve(
    to: planePoint(0, -1.45),
    controlPoint1: planePoint(-0.15, -0.55),
    controlPoint2: planePoint(-0.11, -1.20)
)
plane.close()

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowBlurRadius = 36
shadow.shadowColor = NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 0.38)
shadow.shadowOffset = .zero
shadow.set()
NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 1).setFill()
plane.fill()
NSGraphicsContext.restoreGraphicsState()

let wingGradient = NSGradient(colors: [
    NSColor(calibratedRed: 248 / 255, green: 220 / 255, blue: 148 / 255, alpha: 1),
    NSColor(calibratedRed: 138 / 255, green: 122 / 255, blue: 77 / 255, alpha: 1),
])!
wingGradient.draw(in: plane, angle: 56)
plane.lineWidth = 7
NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 0.48).setStroke()
plane.stroke()

graphicsContext.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let cgImage = cgContext.makeImage(),
      let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode app icon")
}

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("AirLine/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try png.write(to: output)
print("Generated \(output.path)")
