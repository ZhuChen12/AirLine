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
])!
background.draw(in: canvas, angle: -45)

let route = NSBezierPath()
route.move(to: NSPoint(x: 150, y: 270))
route.curve(
    to: NSPoint(x: 780, y: 710),
    controlPoint1: NSPoint(x: 350, y: 240),
    controlPoint2: NSPoint(x: 610, y: 500)
)
route.lineWidth = 34
route.lineCapStyle = .round
NSColor(calibratedRed: 111 / 255, green: 168 / 255, blue: 220 / 255, alpha: 0.82).setStroke()
route.stroke()

let origin = NSBezierPath(ovalIn: NSRect(x: 118, y: 238, width: 64, height: 64))
NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 1).setFill()
origin.fill()

let wing = NSBezierPath()
wing.move(to: NSPoint(x: 862, y: 866))
wing.line(to: NSPoint(x: 704, y: 454))
wing.line(to: NSPoint(x: 620, y: 638))
wing.line(to: NSPoint(x: 438, y: 708))
wing.close()

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowBlurRadius = 44
shadow.shadowColor = NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 0.5)
shadow.shadowOffset = .zero
shadow.set()
NSColor(calibratedRed: 232 / 255, green: 200 / 255, blue: 122 / 255, alpha: 1).setFill()
wing.fill()
NSGraphicsContext.restoreGraphicsState()

let wingGradient = NSGradient(colors: [
    NSColor(calibratedRed: 248 / 255, green: 220 / 255, blue: 148 / 255, alpha: 1),
    NSColor(calibratedRed: 138 / 255, green: 122 / 255, blue: 77 / 255, alpha: 1),
])!
wingGradient.draw(in: wing, angle: -45)

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
