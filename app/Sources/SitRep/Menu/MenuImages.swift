import AppKit
import SitRepMenu
import SitRepPanel

/// What the menu draws, from Paper's "The menu bar item" and "Icon and logo": the menu bar's glyph, and the one lane
/// of images on the left, each 16 points, holding a session's mark, Show's tick or a command's SF Symbol.
@MainActor
enum MenuImages {
    /// Claude Code's orange, the needs-you mark's.
    private static let orange = NSColor(srgbRed: 0xE9 / 255, green: 0x64 / 255, blue: 0x3D / 255, alpha: 1)
    private static let lane = NSSize(width: 16, height: 16)

    /// The light in its housing, an 18-point box: at rest a template image, its thin bar unlit, in the menu bar's ink;
    /// lit, its bar orange and its housing drawn in the ink of the bar it is drawn on, light or dark, or in the ink
    /// given, as a drawing of a menu bar sets it.
    static func glyph(_ glyph: MenuBoard.Glyph, ink given: NSColor? = nil) -> NSImage {
        let image = NSImage(size: NSSize(width: glyphSide, height: glyphSide), flipped: true) { _ in
            let ink: NSColor = glyph == .rest ? .black : given ?? (NSAppearance.currentDrawing().isDark ? .white : .black)
            let housing = NSBezierPath(roundedRect: glyphHousing, xRadius: 3.1, yRadius: 3.1)

            housing.lineWidth = 1.3
            ink.setStroke()
            housing.stroke()
            switch glyph {
            case .rest:
                ink.setFill()
                NSBezierPath(roundedRect: NSRect(x: 8.3, y: 5.6, width: 1.4, height: 6.8), xRadius: 0.7, yRadius: 0.7).fill()
            case .lit:
                orange.setFill()
                NSBezierPath(roundedRect: NSRect(x: 7.55, y: 4.3, width: 2.9, height: 9.4), xRadius: 1.45, yRadius: 1.45).fill()
            }

            return true
        }

        image.isTemplate = glyph == .rest
        image.accessibilityDescription = glyph == .rest ? "SitRep" : "SitRep: something needs you"

        return image
    }

    /// The glyph's box, and its housing in it, by which a drawing of a menu bar sets it.
    static let glyphSide: CGFloat = 18
    static let glyphHousing = NSRect(x: 5.9, y: 2.5, width: 6.2, height: 13)

    /// A session's mark: an orange dot for needs you, an away one's too; an open ring for your turn; a turning arc's
    /// still, for working, and the dotted ring, for on its own work, each fainter than the rest. All but the dot are
    /// template images, so they take the menu's ink, highlighted or not.
    static func mark(_ session: Session) -> NSImage {
        switch session.kind {
        case .needs: dot
        // the menu is given no Snoozed row (`PanelBoard.sessions`)
        case .turn, .snoozed: ring
        case .working: arc
        case .onItsWork: dotted
        }
    }

    private static let dot = drawn(isTemplate: false) {
        let glow = NSShadow()

        glow.shadowColor = orange.withAlphaComponent(0.7)
        glow.shadowBlurRadius = 4
        glow.set()
        orange.setFill()
        NSBezierPath(ovalIn: NSRect(x: 4.5, y: 4.5, width: 7, height: 7)).fill()
    }

    private static let ring = drawn {
        let ring = NSBezierPath(ovalIn: NSRect(x: 4.25, y: 4.25, width: 7.5, height: 7.5))

        ring.lineWidth = 1.5
        NSColor.black.setStroke()
        ring.stroke()
    }

    private static let arc = drawn {
        let track = NSBezierPath(ovalIn: NSRect(x: 3.5, y: 3.5, width: 9, height: 9))
        let turn = NSBezierPath()

        track.lineWidth = 1.5
        NSColor.black.withAlphaComponent(0.15).setStroke()
        track.stroke()
        turn.appendArc(withCenter: NSPoint(x: 8, y: 8), radius: 4.5, startAngle: 270, endAngle: 0)
        turn.lineWidth = 1.5
        turn.lineCapStyle = .round
        NSColor.black.withAlphaComponent(0.6).setStroke()
        turn.stroke()
    }

    /// The card's dotted ring, as faint as the arc.
    private static let dotted = drawn {
        let card = DottedRing.card
        let ring = NSBezierPath(ovalIn: NSRect(
            x: 8 - card.radius, y: 8 - card.radius, width: 2 * card.radius, height: 2 * card.radius
        ))

        ring.lineWidth = card.line
        ring.lineCapStyle = .round
        ring.setLineDash(card.dash, count: card.dash.count, phase: 0)
        NSColor.black.withAlphaComponent(0.6).setStroke()
        ring.stroke()
    }

    /// Show's tick, for the one in use; the others hold the lane empty, so their words line up with it.
    static func tick(_ isTicked: Bool) -> NSImage {
        isTicked ? symbol("checkmark") : blank
    }

    private static let blank = drawn {}

    /// A command's SF Symbol, in the lane.
    static func symbol(_ name: String) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? blank

        return image.withSymbolConfiguration(.init(pointSize: 13, weight: .regular)) ?? image
    }

    /// An image the size of the lane, drawn in its own coordinates, y down, as the drawings' are.
    private static func drawn(isTemplate: Bool = true, _ draw: @escaping () -> Void) -> NSImage {
        let image = NSImage(size: lane, flipped: true) { _ in
            draw()
            return true
        }

        image.isTemplate = isTemplate

        return image
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}
