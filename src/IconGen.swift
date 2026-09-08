import AppKit

enum Mode: String { case status, app }

let args = CommandLine.arguments
let px = Int(args[1])!
let out = args[2]
let mode = args.count > 3 ? args[3] : "status"
let isStatus = mode == "status"

let img = NSImage(size: CGSize(width: px, height: px))
img.lockFocus()
NSGraphicsContext.current?.saveGraphicsState()
let ctx = NSGraphicsContext.current!.cgContext
ctx.scaleBy(x: CGFloat(px) / 64.0, y: CGFloat(px) / 64.0)

if !isStatus && px >= 128 {
    let bg = NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 60, height: 60), xRadius: 14, yRadius: 14)
    NSColor(calibratedWhite: 0.09, alpha: 1.0).setFill()
    bg.fill()
}

let arrowColor = isStatus ? NSColor.black : NSColor.white
let sparkColor = isStatus ? NSColor.black : NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.0, alpha: 1.0)

// macOS-указатель: острие слева-вверху, левый край вертикальный, хвост вниз-вправо (координаты y-up, 64-сетка)
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 26, y: 54))      // tip
arrow.line(to: NSPoint(x: 26, y: 14))      // left edge
arrow.line(to: NSPoint(x: 33, y: 21))      // inner notch
arrow.line(to: NSPoint(x: 40, y: 7))       // tail bottom-left
arrow.line(to: NSPoint(x: 45, y: 10))      // tail bottom-right
arrow.line(to: NSPoint(x: 38, y: 24))      // tail top
arrow.line(to: NSPoint(x: 48, y: 24))      // right notch
arrow.close()
arrowColor.setFill()
arrow.fill()
if !isStatus {
    NSColor(calibratedWhite: 0.05, alpha: 1.0).setStroke()
    arrow.lineWidth = 1.8
    arrow.lineJoinStyle = .round
    arrow.stroke()
}

// click-искры: дуги радиálно от острия — "кликающий" эффект
sparkColor.setStroke()
for (x1, y1, x2, y2) in [(16.0, 58.0, 21.0, 52.0), (12.0, 48.0, 18.0, 46.0), (30.0, 62.0, 31.0, 56.0)] {
    let line = NSBezierPath()
    line.move(to: NSPoint(x: x1, y: y1))
    line.line(to: NSPoint(x: x2, y: y2))
    line.lineWidth = 4
    line.lineCapStyle = .round
    line.stroke()
}
NSGraphicsContext.current?.restoreGraphicsState()
img.unlockFocus()

let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("icon \(mode) \(px)px -> \(out)")
