import SwiftUI

/// The SitRep window's colours and type, from Paper's "The SitRep window" (surfaces round 3) and its tokens, in the
/// system's fonts: SF Pro where the drawing sets Inter, SF Mono where it sets Geist Mono.
enum WindowStyle {
    static let black = Color(hex: 0x000000)
    static let raise = Color(hex: 0x141416)
    static let line = Color(hex: 0x232327)
    static let text = Color(hex: 0xF5F5F7)
    static let soft = Color(hex: 0x98989F)
    static let faint = Color(hex: 0x5C5C63)
    static let orange = Color(hex: 0xE9643D)
    /// A white pill's words.
    static let ink = Color(hex: 0x111113)
    /// An outlined pill's ring.
    static let ring = Color(hex: 0x2C2C31)
    /// An option's fill and its ring.
    static let option = Color(hex: 0x1C1C1F)
    static let optionRing = Color(hex: 0x34343A)
    /// A pill under the pointer: its fill and its ring lifted.
    static let optionLift = Color(hex: 0x26262A)
    static let ringLift = Color(hex: 0x45454C)
    /// A row under the pointer, fainter than the picked one's raise.
    static let hover = Color(hex: 0x0D0D0F)
    /// An away session's dot.
    static let awayDot = Color(hex: 0x46464C)
    /// The working arc's track, and the arc.
    static let track = Color(hex: 0x2C2C31)
    static let arc = Color(hex: 0xC9C9CF)
    /// What is new, and a stop: washed orange in a ring of it.
    static let wash = orange.opacity(0.12)
    static let washRing = orange.opacity(0.28)

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    /// The window as drawn: its two columns and their insides.
    static let size = CGSize(width: 1100, height: 720)
    static let boardWidth: CGFloat = 296
    static let pageInset: CGFloat = 44
    /// The bar the traffic lights sit in, and the page's top row beside them.
    static let barHeight: CGFloat = 52
    /// A mark's lane, as the panel row's.
    static let lane = CGSize(width: 12, height: 18)
    /// How far a page line's highlight reaches past the column's edges, so its words keep their place beside the
    /// headings.
    static let reach: CGFloat = 8
    /// macOS 26's glass sidebar, floating inside the window.
    static let sidebarInset: CGFloat = 8
    static let sidebarRadius: CGFloat = 18

    /// The tint of a highlight's glass: the picked one's the stronger.
    static func glassTint(_ highlight: Highlight) -> Color {
        .white.opacity(highlight == .picked ? 0.14 : 0.05)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// Letter-spacing as the drawing gives it, in ems of this size.
    func spacing(_ ems: CGFloat, of size: CGFloat) -> some View {
        tracking(ems * size)
    }
}
