import SwiftUI

/// How a row or a button shows: the pointer over it, or keyboard focus on it, lightly; picked or pressed, strongly.
enum Highlight: Equatable {
    case none, hover, picked

    static func of(isPicked: Bool, isPressed: Bool, isHovered: Bool, isFocused: Bool) -> Highlight {
        if isPicked || isPressed {
            .picked
        } else if isHovered || isFocused {
            .hover
        } else {
            .none
        }
    }
}

/// A row as a button: the list's sessions, projects and quiet names, a page's lines and its items, highlighted as the
/// pointer passes over it, the one picked kept highlighted the stronger.
struct RowStyle: ButtonStyle {
    var isPicked = false
    var radius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPicked: isPicked, isPressed: configuration.isPressed) { highlight in
            configuration.label.background { HighlightShape(highlight: highlight, radius: radius) }
        }
    }
}

/// Words as a button, brighter under the pointer: a project's name over its session, "show all".
struct WordsStyle: ButtonStyle {
    var colour = WindowStyle.soft
    var hover = WindowStyle.text

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPressed: configuration.isPressed) { highlight in
            configuration.label.foregroundStyle(highlight == .none ? colour : hover)
        }
    }
}

/// "Open in Ghostty ↗": a raised chip in a hairline, lifted under the pointer; faint while its jump runs.
struct JumpStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPressed: configuration.isPressed) { highlight in
            let shape = RoundedRectangle(cornerRadius: 7)

            configuration.label
                .background(shape.fill(highlight == .none ? WindowStyle.raise : WindowStyle.option))
                .overlay(shape.strokeBorder(highlight == .none ? WindowStyle.line : WindowStyle.ringLift, lineWidth: 1))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.45)
        }
    }
}

/// Its label told whether the pointer is over it or keyboard focus on it, and whether it is picked or pressed.
struct Highlighted<Content: View>: View {
    var isPicked = false
    var isPressed = false
    @ViewBuilder let content: (Highlight) -> Content

    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isHovered = false

    var body: some View {
        let highlight = isEnabled
            ? Highlight.of(isPicked: isPicked, isPressed: isPressed, isHovered: isHovered || isHoveredStill, isFocused: isFocused)
            : isPicked ? .picked : .none

        content(highlight).onHover { isHovered = $0 }
    }
}

/// A highlight's shape behind a row: on macOS 26's glass sidebar, glass, the picked one the stronger; before it, and
/// drawn as a still, which renders no glass, the window's fills, the picked one the panel's raise.
struct HighlightShape: View {
    let highlight: Highlight
    let radius: CGFloat

    @Environment(\.isStill) private var isStill

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if highlight == .none {
            Color.clear
        } else if #available(macOS 26, *), !isStill {
            Color.clear.glassEffect(.regular.tint(WindowStyle.glassTint(highlight)), in: shape)
        } else {
            shape.fill(highlight == .picked ? WindowStyle.raise : WindowStyle.hover)
        }
    }
}

/// The board's column as macOS 26's glass sidebar, floating inside the window as Settings' does; before it, the
/// panel's black with a hairline beside it.
struct Sidebar: ViewModifier {
    @Environment(\.isStill) private var isStill

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !isStill {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: WindowStyle.sidebarRadius, style: .continuous))
                .padding(WindowStyle.sidebarInset)
        } else {
            HStack(spacing: 0) {
                content
                Rectangle().fill(WindowStyle.line).frame(width: 1)
            }
        }
    }
}
