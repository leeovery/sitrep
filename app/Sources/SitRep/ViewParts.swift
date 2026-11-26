import SwiftUI

/// The inks Settings' pictures and the welcome's stage draw the card's marks and words in, from Paper's tokens, and
/// their mono: SF Mono where the drawing sets Geist Mono.
enum PictureStyle {
    static let text = Color(hex: 0xF5F5F7)
    static let orange = Color(hex: 0xE9643D)

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}

extension Color {
    /// A colour as Paper's drawings give it, in sRGB.
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

    /// One element to VoiceOver, read as these words in place of what it draws.
    func spoken(_ words: String) -> some View {
        accessibilityElement(children: .ignore).accessibilityLabel(words)
    }
}
