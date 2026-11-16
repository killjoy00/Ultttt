import AppKit
import Foundation

// Deterministic 1024px full-bleed icon. Drawn on the GitHub macOS runner.
let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("UltimateTTTApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try FileManager.default.createDirectory(
    at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
)

func ink(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 255)/255,
            green: CGFloat((hex >> 8) & 255)/255,
            blue: CGFloat(hex & 255)/255, alpha: alpha)
}
func stroke(_ a: NSPoint, _ b: NSPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: a); path.line(to: b)
    path.lineCapStyle = .round; path.lineWidth = width
    color.setStroke(); path.stroke()
}
func mark(_ symbol: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor) {
    let radius = size/2
    if symbol == "X" {
        stroke(NSPoint(x: x-radius, y: y-radius), NSPoint(x: x+radius, y: y+radius),
               width: size * 0.19, color: color)
        stroke(NSPoint(x: x-radius, y: y+radius), NSPoint(x: x+radius, y: y-radius),
               width: size * 0.19, color: color)
    } else {
        let ring = NSBezierPath(ovalIn: NSRect(
            x: x-radius, y: y-radius, width: size, height: size))
        ring.lineWidth = size * 0.19
        color.setStroke(); ring.stroke()
    }
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

ink(0x0B121D).setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
let outer = NSBezierPath(roundedRect: NSRect(x: 61, y: 61, width: 902, height: 902),
                         xRadius: 150, yRadius: 150)
NSGradient(starting: ink(0x1A3445), ending: ink(0x0C1421))!.draw(in: outer, angle: 120)

let frame = NSRect(x: 118, y: 118, width: 788, height: 788)
let backing = NSBezierPath(roundedRect: frame, xRadius: 78, yRadius: 78)
ink(0x1B2C40).setFill(); backing.fill()
ink(0x7F9CA8, alpha: 0.27).setStroke()
backing.lineWidth = 8; backing.stroke()

let gap: CGFloat = 17
let inset: CGFloat = 29
let side = (frame.width - inset * 2 - gap * 2) / 3
func tile(_ index: Int) -> NSRect {
    NSRect(x: frame.minX + inset + CGFloat(index % 3) * (side + gap),
           y: frame.maxY - inset - side - CGFloat(index / 3) * (side + gap),
           width: side, height: side)
}
for index in 0..<9 {
    let rect = tile(index)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 29, yRadius: 29)
    ink(index == 4 ? 0x2C5960 : 0x293949).setFill(); shape.fill()
    ink(index == 4 ? 0x6EDFD8 : 0x6B8797, alpha: index == 4 ? 0.95 : 0.26).setStroke()
    shape.lineWidth = index == 4 ? 7 : 3; shape.stroke()
    for split in 1...2 {
        let a = CGFloat(split) * side / 3
        stroke(NSPoint(x: rect.minX+a, y: rect.minY+16),
               NSPoint(x: rect.minX+a, y: rect.maxY-16),
               width: 4, color: ink(0x8097A6, alpha: 0.33))
        stroke(NSPoint(x: rect.minX+16, y: rect.minY+a),
               NSPoint(x: rect.maxX-16, y: rect.minY+a),
               width: 4, color: ink(0x8097A6, alpha: 0.33))
    }
}
for (index, symbol, size) in [(4, "X", 145.0), (2, "O", 122.0),
                              (0, "X", 85.0), (8, "O", 85.0)] {
    let rect = tile(index)
    mark(symbol, x: rect.midX, y: rect.midY, size: size,
         color: ink(symbol == "X" ? 0x6EDFD8 : 0xFFAE86))
}

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the app icon")
}
try png.write(to: destination, options: .atomic)
print("AppIcon: 1024x1024, \(png.count) bytes")
