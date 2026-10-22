import AppKit
import SitRepPanel

/// The edge's colours and type in black, from the prototype's CSS (meniscus.html's `--p-` colours and its row styles).
@MainActor
enum EdgeStyle {
    /// The black: the notch and the panel, as black as the display's bezel they flare into.
    nonisolated static let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let ink = srgb(0xF5F5F7)
    static let ink2 = srgb(0x98989F)
    static let ink3 = srgb(0x5C5C63)
    static let off = srgb(0x6E6E76)
    static let hover = srgb(0x141416)
    /// A row a click is jumping from, pressed in.
    static let press = srgb(0x1C1C20)
    /// A lifted notch's shadow at full lift: the prototype's CSS blur of 12, which Core Animation's radius halves.
    static let liftBlur = 6.0
    static let rule = srgb(0x232327)
    static let track = srgb(0x2C2C31)
    static let shim = srgb(0x9A9AA1)
    /// The strip's (strip.html's `--p-` colours beyond the panel's): an away ask's words, a working mark's letters, and
    /// its arc.
    static let quiet = srgb(0x8A8A92)
    static let grey = srgb(0x8E8E95)
    static let arc = srgb(0xC9C9CF)
    /// A row on its own work's verb, from Paper's board D; its subject and its dotted ring are `grey`.
    static let waitingVerb = srgb(0xB4B4BA)
    /// Board D's eyebrows: a section's name, its count where it is not needs you's orange, and its chevron; and "N
    /// earlier"'s ring.
    static let eyebrow = white(0.55)
    static let eyebrowCount = white(0.30)
    static let chevron = white(0.25)
    static let earlierRing = white(0.35)
    static let orange = color(LiveLight.orange)
    /// A new row's wash, and the ring round it (the prototype's `--wash-bg` and `--wash-ring`).
    static let wash = color(LiveLight.orange, alpha: 0.12)
    static let washRing = color(LiveLight.orange, alpha: 0.26)

    /// A row's title, an ask's among them (board D: every ask's line medium, as Lee approved it).
    static let title = NSFont.systemFont(ofSize: 14, weight: .medium)
    /// A row on its own work's subject, where it is no command; a wake's countdown in its tabular figures, so a row
    /// can leave room for every reading it will take (`Session.countdownRoom`).
    static let subject = NSFont.systemFont(ofSize: 14, weight: .regular)
    static let countdown = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    static let code = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
    static let sub = NSFont.systemFont(ofSize: 12)
    static let age = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    /// A Needs you row's "+2" after its session's name, in tabular figures (board F).
    static let count = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    /// A row's button under the pointer, and its glyph (board F).
    static let opener = white(0x1A / 255.0)
    static let openerGlyph = white(0.8)
    static let headTitle = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let headCount = NSFont.systemFont(ofSize: 12)
    /// An eyebrow's name, and its count in tabular figures.
    static let eyebrowTitle = NSFont.systemFont(ofSize: 11, weight: .semibold)
    static let eyebrowFigures = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    /// A your-turn row's words on one line, and "8 earlier": regular (board D, as Lee approved it).
    static let line = NSFont.systemFont(ofSize: 13, weight: .regular)
    /// A mark's letters, and a count's rows, needs you's bolder.
    static let letters = NSFont.systemFont(ofSize: 9.5, weight: .semibold)
    static let rowTitle = NSFont.systemFont(ofSize: 13, weight: .medium)
    /// A wake's countdown in a count's row, in tabular figures, as `countdown`.
    static let rowCountdown = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    static let rowSub = NSFont.systemFont(ofSize: 11)

    /// The prototype's letter-spacing of -0.01em, as a kern in points.
    static func tightKern(_ font: NSFont) -> CGFloat { -0.01 * font.pointSize }

    nonisolated static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    nonisolated static func color(_ rgb: LiveLight.RGB, alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255, alpha: alpha)
    }

    private static func white(_ alpha: Double) -> CGColor {
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha)
    }

    private static func srgb(_ hex: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1
        )
    }
}
