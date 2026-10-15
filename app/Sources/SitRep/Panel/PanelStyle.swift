import AppKit
import SitRepPanel

/// The panel's colours and type, from the prototype's CSS (meniscus.html's `--p-` colours and its row styles).
@MainActor
enum PanelStyle {
    /// The black: the lip and the panel, as black as the display's bezel they flare into.
    nonisolated static let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let ink = srgb(0xF5F5F7)
    static let ink2 = srgb(0x98989F)
    static let ink3 = srgb(0x5C5C63)
    static let quiet = srgb(0x8A8A92)
    static let off = srgb(0x6E6E76)
    static let mark = srgb(0x3A3A40)
    static let hover = srgb(0x141416)
    static let rule = srgb(0x232327)
    static let track = srgb(0x2C2C31)
    static let shim = srgb(0x9A9AA1)
    static let orange = color(LiveLight.orange)

    static let title = NSFont.systemFont(ofSize: 14, weight: .medium)
    static let needsTitle = NSFont.systemFont(ofSize: 14, weight: .semibold)
    static let code = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
    static let sub = NSFont.systemFont(ofSize: 12)
    static let age = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    static let headTitle = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let headCount = NSFont.systemFont(ofSize: 12)

    /// The prototype's letter-spacing of -0.01em, as a kern in points.
    static func tightKern(_ font: NSFont) -> CGFloat { -0.01 * font.pointSize }

    nonisolated static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    nonisolated static func color(_ rgb: LiveLight.RGB, alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255, alpha: alpha)
    }

    private static func srgb(_ hex: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1
        )
    }
}
