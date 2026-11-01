import AppKit

/// A small screen above two rows of keys, drawn as a template image so it
/// matches the menu bar in light and dark mode. The screen is hollow while off.
enum MenuBarIcon {
    static func image(on: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
            NSColor.black.set()
            let screen = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 7.5, width: 13, height: 8), xRadius: 1.5, yRadius: 1.5)
            if on {
                screen.fill()
            } else {
                screen.lineWidth = 1.2
                screen.stroke()
            }
            let keys = NSBezierPath()
            for column in 0..<4 {
                keys.appendRoundedRect(NSRect(x: 2 + Double(column) * 3.6, y: 3.6, width: 2.8, height: 2.2), xRadius: 0.6, yRadius: 0.6)
            }
            keys.appendRoundedRect(NSRect(x: 4.5, y: 0.6, width: 9, height: 2.2), xRadius: 0.6, yRadius: 0.6)
            keys.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
