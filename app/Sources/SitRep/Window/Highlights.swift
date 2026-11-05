import SwiftUI

/// How a row or a button shows: the pointer over it, lightly; picked or pressed, strongly. Keyboard focus is the
/// system's own: its ring on a button, shaped to it, and the selection in the sidebar's list.
enum Highlight: Equatable {
    case none, hover, picked

    static func of(isPicked: Bool, isPressed: Bool, isHovered: Bool) -> Highlight {
        if isPicked || isPressed {
            .picked
        } else if isHovered {
            .hover
        } else {
            .none
        }
    }
}

extension View {
    /// A page's line as a button: a project's sessions and asks, an item that opens, a card's head, highlighted
    /// behind its words as the pointer passes over it. One that `highlights` no longer, as an item opened, shows
    /// nothing behind it.
    func rowButton(radius: CGFloat = 8, highlights: Bool = true) -> some View {
        buttonStyle(RowStyle(radius: radius, highlights: highlights))
            .contentShape(.focusEffect, RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Words as a button, brighter under the pointer: a project's name over its session, "show all".
    func wordsButton(_ colour: Color = WindowStyle.soft, hover: Color = WindowStyle.text) -> some View {
        buttonStyle(WordsStyle(colour: colour, hover: hover)).contentShape(.focusEffect, RoundedRectangle(cornerRadius: 4))
    }

    /// "Open in Ghostty ↗", and a parked item's "Back to its session ›", drawn alike.
    func jumpButton() -> some View {
        buttonStyle(JumpStyle()).contentShape(.focusEffect, RoundedRectangle(cornerRadius: JumpStyle.radius))
    }
}

private struct RowStyle: ButtonStyle {
    let radius: CGFloat
    let highlights: Bool

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPressed: configuration.isPressed) { highlight in
            configuration.label.background {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill(highlight))
            }
        }
    }

    private func fill(_ highlight: Highlight) -> Color {
        switch highlights ? highlight : .none {
        case .none: .clear
        case .hover: WindowStyle.hover
        case .picked: WindowStyle.raise
        }
    }
}

private struct WordsStyle: ButtonStyle {
    let colour: Color
    let hover: Color

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPressed: configuration.isPressed) { highlight in
            configuration.label.foregroundStyle(highlight == .none ? colour : hover)
        }
    }
}

/// Outlined in a hairline, as A1 and A2 revised draw it, filled and lifted under the pointer; faint while its jump
/// runs.
private struct JumpStyle: ButtonStyle {
    static let radius: CGFloat = 8
    /// Its hairline at rest.
    private static let ring = Color(hex: 0x3A3A40)

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPressed: configuration.isPressed) { highlight in
            let shape = RoundedRectangle(cornerRadius: Self.radius)

            configuration.label
                .background(shape.fill(highlight == .none ? Color.clear : WindowStyle.option))
                .overlay(shape.strokeBorder(highlight == .none ? Self.ring : WindowStyle.ringLift, lineWidth: 1))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.45)
        }
    }
}

/// Its label told whether the pointer is over it, and whether it is picked or pressed. A button disabled under the
/// pointer, as a pill is while its jump runs, hears no exit, so its hover is let go as it disables. A row that slides
/// out from under a still pointer can keep its hover until the pointer next moves: accepted.
struct Highlighted<Content: View>: View {
    var isPicked = false
    var isPressed = false
    @ViewBuilder let content: (Highlight) -> Content

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isHovered = false

    var body: some View {
        let highlight = isEnabled
            ? Highlight.of(isPicked: isPicked, isPressed: isPressed, isHovered: isHovered || isHoveredStill)
            : isPicked ? .picked : .none

        content(highlight)
            .onHover { isHovered = $0 }
            .onChange(of: isEnabled) { _, isEnabled in
                if !isEnabled {
                    isHovered = false
                }
            }
    }
}
