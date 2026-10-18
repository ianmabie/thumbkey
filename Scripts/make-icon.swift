import AppKit

// Draw from vector paths at every icon size so the mouse stays clear in the Dock.
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 214, yRadius: 214)
NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.66, blue: 0.61, alpha: 1), ending: NSColor(srgbRed: 0.025, green: 0.31, blue: 0.34, alpha: 1))!.draw(in: tile, angle: -55)
NSGraphicsContext.saveGraphicsState()
let transform = NSAffineTransform()
transform.translateX(by: 512, yBy: 512)
transform.rotate(byDegrees: -20)
transform.translateX(by: -512, yBy: -512)
transform.concat()
let body = NSBezierPath()
body.move(to: NSPoint(x: 512, y: 855))
body.curve(to: NSPoint(x: 714, y: 661), controlPoint1: NSPoint(x: 644, y: 855), controlPoint2: NSPoint(x: 707, y: 788))
body.curve(to: NSPoint(x: 738, y: 372), controlPoint1: NSPoint(x: 724, y: 559), controlPoint2: NSPoint(x: 738, y: 471))
body.curve(to: NSPoint(x: 512, y: 157), controlPoint1: NSPoint(x: 738, y: 230), controlPoint2: NSPoint(x: 646, y: 157))
body.curve(to: NSPoint(x: 286, y: 372), controlPoint1: NSPoint(x: 378, y: 157), controlPoint2: NSPoint(x: 286, y: 230))
body.curve(to: NSPoint(x: 310, y: 661), controlPoint1: NSPoint(x: 286, y: 471), controlPoint2: NSPoint(x: 300, y: 559))
body.curve(to: NSPoint(x: 512, y: 855), controlPoint1: NSPoint(x: 317, y: 788), controlPoint2: NSPoint(x: 380, y: 855))
body.close()
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.shadowOffset = NSSize(width: 12, height: -20); shadow.shadowBlurRadius = 25; shadow.set()
NSColor(white: 0.12, alpha: 1).setFill(); body.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [NSColor(white: 0.98, alpha: 1), NSColor(white: 0.86, alpha: 1), NSColor(white: 0.73, alpha: 1)])!.draw(in: body, angle: -50)
NSColor.white.withAlphaComponent(0.65).setStroke(); body.lineWidth = 3; body.stroke()
// A split click surface and central wheel make the silhouette unmistakable at 32 px.
let seams = NSBezierPath(); seams.move(to: NSPoint(x: 512, y: 849)); seams.line(to: NSPoint(x: 512, y: 556))
seams.move(to: NSPoint(x: 306, y: 548)); seams.curve(to: NSPoint(x: 718, y: 548), controlPoint1: NSPoint(x: 418, y: 512), controlPoint2: NSPoint(x: 606, y: 512))
seams.lineWidth = 8; seams.lineCapStyle = .round; NSColor(white: 0.23, alpha: 1).setStroke(); seams.stroke()
let well = NSBezierPath(roundedRect: NSRect(x: 473, y: 628, width: 78, height: 147), xRadius: 36, yRadius: 36)
NSColor(white: 0.13, alpha: 1).setFill(); well.fill()
let wheel = NSBezierPath(roundedRect: NSRect(x: 490, y: 643, width: 44, height: 117), xRadius: 21, yRadius: 21)
NSGradient(starting: NSColor(srgbRed: 0.35, green: 0.98, blue: 0.81, alpha: 1), ending: NSColor(srgbRed: 0.06, green: 0.58, blue: 0.55, alpha: 1))!.draw(in: wheel, angle: 0)
for y in stride(from: 658, through: 745, by: 14) {
 let rib = NSBezierPath(); rib.move(to: NSPoint(x: 498, y: y)); rib.line(to: NSPoint(x: 526, y: y)); rib.lineWidth = 2; NSColor(white: 0.08, alpha: 0.35).setStroke(); rib.stroke()
}
// Two visible thumb controls tie the icon to mapping extra mouse buttons.
for y in [405, 470] {
 let side = NSBezierPath(roundedRect: NSRect(x: 274, y: y, width: 30, height: 48), xRadius: 10, yRadius: 10)
 NSColor(srgbRed: 0.06, green: 0.22, blue: 0.23, alpha: 1).setFill(); side.fill()
 NSColor(srgbRed: 0.37, green: 0.90, blue: 0.76, alpha: 1).setStroke(); side.lineWidth = 3; side.stroke()
}
NSGraphicsContext.restoreGraphicsState()
image.unlockFocus()
for (points, scale, name) in [(16,1,"icon_16x16.png"),(16,2,"icon_16x16@2x.png"),(32,1,"icon_32x32.png"),(32,2,"icon_32x32@2x.png"),(128,1,"icon_128x128.png"),(128,2,"icon_128x128@2x.png"),(256,1,"icon_256x256.png"),(256,2,"icon_256x256@2x.png"),(512,1,"icon_512x512.png"),(512,2,"icon_512x512@2x.png")] {
 let pixels = points * scale
 let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
 NSGraphicsContext.current?.imageInterpolation = .high
 image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
 NSGraphicsContext.restoreGraphicsState()
 try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
}
