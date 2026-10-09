// Renders the LBrowser-style app icon: white squircle, black dot-matrix clock dial, amber pivot.
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSColor(white: 0.996, alpha: 1).setFill()
tile.fill()
NSColor(white: 0, alpha: 0.10).setStroke()
tile.lineWidth = 4
tile.stroke()

// A shaded dome of square dots (lit from the upper left), with the hands carved out at three o'clock.
let center = (x: 512.0, y: 512.0), radius = 300.0
let cols = 21.0, step = radius * 2 / cols
let hands: [(angle: Double, length: Double)] = [(0, 0.62), (90, 0.8)] // degrees from 12, fraction of radius
func onHand(_ dx: Double, _ dy: Double) -> Bool {
    for hand in hands {
        let a = hand.angle * .pi / 180
        let (ux, uy) = (sin(a), -cos(a)) // screen space, y down
        let along = dx * ux + dy * uy, across = abs(dx * uy - dy * ux)
        if along > -0.02 && along < hand.length && across < 0.085 { return true }
    }
    return false
}
var row = 0.0
while row < cols {
    var col = 0.0
    while col < cols {
        let dx = (col + 0.5) / cols * 2 - 1, dy = (row + 0.5) / cols * 2 - 1 // unit disc, y down
        let d2 = dx * dx + dy * dy
        if d2 < 1, !onHand(dx, dy), d2 > 0.03 {
            let h = (1 - d2).squareRoot() * 0.75 + (0.5 - 0.35 * dy - 0.15 * dx) * 0.25
            let s = step * 0.66 * (0.25 + 0.75 * h)
            NSColor(srgbRed: 0.039, green: 0.039, blue: 0.043, alpha: 0.2 + 0.8 * h).setFill()
            let x = center.x + dx * radius, y = size - (center.y + dy * radius)
            NSBezierPath(rect: NSRect(x: x - s / 2, y: y - s / 2, width: s, height: s)).fill()
        }
        col += 1
    }
    row += 1
}
NSColor(srgbRed: 0.831, green: 0.525, blue: 0.039, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 512 - 38, y: 512 - 38, width: 76, height: 76)).fill()
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
