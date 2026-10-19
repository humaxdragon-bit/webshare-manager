import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let directory = root.appendingPathComponent(".build/Manager.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func render(_ size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(size) / 1024); transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 196, yRadius: 196)
    NSGradient(starting: NSColor(srgbRed: 0.04, green: 0.26, blue: 0.76, alpha: 1), ending: NSColor(srgbRed: 0.18, green: 0.64, blue: 1, alpha: 1))!.draw(in: tile, angle: 75)
    let back = NSBezierPath()
    back.move(to: NSPoint(x: 235, y: 330)); back.line(to: NSPoint(x: 235, y: 702))
    back.curve(to: NSPoint(x: 273, y: 740), controlPoint1: NSPoint(x: 235, y: 728), controlPoint2: NSPoint(x: 247, y: 740))
    back.line(to: NSPoint(x: 418, y: 740)); back.line(to: NSPoint(x: 477, y: 678)); back.line(to: NSPoint(x: 752, y: 678))
    back.curve(to: NSPoint(x: 790, y: 640), controlPoint1: NSPoint(x: 778, y: 678), controlPoint2: NSPoint(x: 790, y: 666))
    back.line(to: NSPoint(x: 790, y: 330)); back.close()
    NSColor(srgbRed: 0.65, green: 0.84, blue: 1, alpha: 1).setFill(); back.fill()
    let folder = NSBezierPath(roundedRect: NSRect(x: 218, y: 282, width: 588, height: 366), xRadius: 46, yRadius: 46)
    NSColor.white.setFill(); folder.fill()
    NSColor(srgbRed: 0.08, green: 0.39, blue: 0.88, alpha: 1).setStroke()
    func arrow(_ points: [NSPoint]) {
        let path = NSBezierPath(); path.lineWidth = 42; path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.move(to: points[0]); for point in points.dropFirst() { path.line(to: point) }; path.stroke()
    }
    arrow([NSPoint(x: 406,y: 380), NSPoint(x: 406,y: 551)])
    arrow([NSPoint(x: 348,y: 493), NSPoint(x: 406,y: 551), NSPoint(x: 464,y: 493)])
    arrow([NSPoint(x: 617,y: 551), NSPoint(x: 617,y: 380)])
    arrow([NSPoint(x: 559,y: 438), NSPoint(x: 617,y: 380), NSPoint(x: 675,y: 438)])
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for size in [16,32,128,256,512] {
    try render(size).write(to: directory.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: directory.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to: root.appendingPathComponent("Assets/WebshareManager.png"))
