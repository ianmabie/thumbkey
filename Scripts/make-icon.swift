import AppKit
let directory=CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
for (points,scale,name) in [(16,1,"icon_16x16.png"),(16,2,"icon_16x16@2x.png"),(32,1,"icon_32x32.png"),(32,2,"icon_32x32@2x.png"),(128,1,"icon_128x128.png"),(128,2,"icon_128x128@2x.png"),(256,1,"icon_256x256.png"),(256,2,"icon_256x256@2x.png"),(512,1,"icon_512x512.png"),(512,2,"icon_512x512@2x.png")] {
 let pixels=points*scale
 let image=NSImage(size:NSSize(width:1024,height:1024))
 image.lockFocus()
 NSGradient(starting:NSColor(srgbRed:0.04,green:0.25,blue:0.23,alpha:1),ending:NSColor(srgbRed:0.05,green:0.52,blue:0.4,alpha:1))!.draw(in:NSBezierPath(roundedRect:NSRect(x:32,y:32,width:960,height:960),xRadius:220,yRadius:220),angle:45)
 for row in 0..<4 {for col in 0..<3 {
  let rect=NSRect(x:222+col*202,y:200+row*164,width:176,height:138)
  (row==3 && col==0 ? NSColor(srgbRed:0.63,green:1,blue:0.79,alpha:1):NSColor.white.withAlphaComponent(0.88)).setFill()
  NSBezierPath(roundedRect:rect,xRadius:30,yRadius:30).fill()
 }}
 image.unlockFocus()
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep);image.draw(in:NSRect(x:0,y:0,width:pixels,height:pixels));NSGraphicsContext.restoreGraphicsState()
 try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:directory).appendingPathComponent(name))
}
