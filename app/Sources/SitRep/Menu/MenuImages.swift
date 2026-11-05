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

    /// A session's mark: an orange dot for needs you, and for an away one a hollow orange ring; an open ring for your
    /// turn; the arc, for working, at this frame of its turn, and the dotted ring, for on its own work, each fainter
    /// than the rest. The orange marks are no template images, so a disabled item does not grey them to nothing; the
    /// rest are, so they take the menu's ink, highlighted or not.
    static func mark(_ session: Session, turn frame: Int = 0) -> NSImage {
        switch session.kind {
        case .needs: session.away ? awayRing : dot
        // the menu is given no Snoozed row (`PanelBoard.sessions`)
        case .turn, .snoozed, .snoozedTurn: ring
        case .working: arc[frame % arc.count]
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

    /// An away ask's: the needs dot's footprint, hollow, unlit (`Away`).
    private static let awayRing = drawn(isTemplate: false) {
        let side = Away.ringSide - Away.ringLine, inset = (lane.width - side) / 2
        let ring = NSBezierPath(ovalIn: NSRect(x: inset, y: inset, width: side, height: side))

        ring.lineWidth = Away.ringLine
        orange.setStroke()
        ring.stroke()
    }

    private static let ring = drawn {
        let ring = NSBezierPath(ovalIn: NSRect(x: 4.25, y: 4.25, width: 7.5, height: 7.5))

        ring.lineWidth = 1.5
        NSColor.black.setStroke()
        ring.stroke()
    }

    /// Working's arc round its track, a frame for each step of its turn, drawn once: the first, from the top, is the
    /// still one, and shown in turn, one each `MenuTurn.step`, they turn it clockwise once a second, as the panel's.
    static let arc = (0 ..< MenuTurn.frames).map { frame in
        drawn {
            let track = NSBezierPath(ovalIn: NSRect(x: 3.5, y: 3.5, width: 9, height: 9))
            let turn = NSBezierPath()
            let start = 270 + 360 * CGFloat(frame) / CGFloat(MenuTurn.frames)

            track.lineWidth = 1.5
            NSColor.black.withAlphaComponent(0.15).setStroke()
            track.stroke()
            // y runs down, so the angles run clockwise
            turn.appendArc(withCenter: NSPoint(x: 8, y: 8), radius: 4.5, startAngle: start, endAngle: start + 90)
            turn.lineWidth = 1.5
            turn.lineCapStyle = .round
            NSColor.black.withAlphaComponent(0.6).setStroke()
            turn.stroke()
        }
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
