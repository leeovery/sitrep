import SwiftUI

/// How a row or a button shows: the pointer over it, lightly; picked or pressed, strongly. Keyboard focus is a mark of
/// its own (`FocusMark`), so a row tabbed to never looks like the one under the pointer.
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
    /// A row as a button: the list's sessions, projects and quiet names, a page's lines and its items, highlighted as
    /// the pointer passes over it, the one picked kept highlighted the stronger, and marked while it has keyboard
    /// focus.
    func rowButton(isPicked: Bool = false, radius: CGFloat = 8) -> some View {
        buttonStyle(RowStyle(isPicked: isPicked, radius: radius))
            .focusMark(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Words as a button, brighter under the pointer: a project's name over its session, "show all".
    func wordsButton(_ colour: Color = WindowStyle.soft, hover: Color = WindowStyle.text) -> some View {
        buttonStyle(WordsStyle(colour: colour, hover: hover)).focusMark(RoundedRectangle(cornerRadius: 4), inset: -3)
    }

    /// "Open in Ghostty ↗".
    func jumpButton() -> some View {
        buttonStyle(JumpStyle()).focusMark(RoundedRectangle(cornerRadius: 7))
    }

    /// Keyboard focus on the button this is set on, as a thin white outline round its shape.
    func focusMark(_ shape: some InsettableShape, inset: CGFloat = 0) -> some View {
        modifier(FocusMark(shape: shape, inset: inset))
    }
}

/// Keyboard focus, quietly: a thin white outline at low opacity, following the shape's own corners; never the system's
/// blue ring, which the window turns off (`WindowContent`), nor a fill, nor the pointer's highlight. Read with
/// `@FocusState` on the button itself, which reports the focus of the view it is set on.
private struct FocusMark<Mark: InsettableShape>: ViewModifier {
    let shape: Mark
    let inset: CGFloat

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .overlay {
                shape.inset(by: inset).strokeBorder(WindowStyle.focus, lineWidth: 1).opacity(isFocused ? 1 : 0)
            }
    }
}

private struct RowStyle: ButtonStyle {
    let isPicked: Bool
    let radius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPicked: isPicked, isPressed: configuration.isPressed) { highlight in
            configuration.label.background { HighlightShape(highlight: highlight, radius: radius) }
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

/// A raised chip in a hairline, lifted under the pointer; faint while its jump runs.
private struct JumpStyle: ButtonStyle {
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

/// A highlight's shape behind a row: on macOS 26's glass sidebar, glass, the picked one the stronger; on the page,
/// before macOS 26, and drawn as a still, which renders no glass, the window's fills, the picked one the panel's raise.
private struct HighlightShape: View {
    let highlight: Highlight
    let radius: CGFloat

    @Environment(\.isOnGlass) private var isOnGlass

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if highlight == .none {
            Color.clear
        } else if #available(macOS 26, *), isOnGlass {
            Color.clear.glassEffect(.regular.tint(WindowStyle.glassTint(highlight)), in: shape)
        } else {
            shape.fill(highlight == .picked ? WindowStyle.raise : WindowStyle.hover)
        }
    }
}

/// The board's column as macOS 26's glass sidebar, floating inside the window as Settings' does, its rows' glass in one
/// container so they render together over it; before it, and as a still, the panel's black with a hairline beside it.
struct Sidebar: ViewModifier {
    @Environment(\.isStill) private var isStill

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !isStill {
            GlassEffectContainer(spacing: 0) {
                content.environment(\.isOnGlass, true)
            }
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

extension EnvironmentValues {
    /// Drawn on macOS 26's glass sidebar, where highlights are glass.
    @Entry var isOnGlass = false
}
