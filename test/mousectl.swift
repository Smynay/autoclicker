import CoreGraphics
import Foundation

let args = CommandLine.arguments

func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
    down?.flags = flags
    down?.post(tap: .cgSessionEventTap)
    usleep(60_000)
    let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
    up?.flags = flags
    up?.post(tap: .cgSessionEventTap)
}

switch args.count >= 2 ? args[1] : "" {
case "warp":
    let x = Double(args[2])!, y = Double(args[3])!
    CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
    usleep(100_000)
case "move":
    let x = Int(args[2])!, y = Int(args[3])!
    let e = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
    e?.post(tap: .cgSessionEventTap)
    usleep(100_000)
case "click":
    let x = Int(args[2])!, y = Int(args[3])!
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?.post(tap: .cgSessionEventTap)
    usleep(30_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?.post(tap: .cgSessionEventTap)
    usleep(30_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?.post(tap: .cgSessionEventTap)
case "startclicker":
    postKey(40 /*K*/, flags: [.maskCommand, .maskAlternate])
case "cursor":
    if let p = CGEvent(source: nil)?.location { print("\(Int(p.x)) \(Int(p.y))") }
default:
    FileHandle.standardError.write("usage: mousectl move x y | click x y | startclicker | cursor\n".data(using: .utf8)!)
}
