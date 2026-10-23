import enum SitRepPanel.Wash
import SitRepWindow
import SwiftUI

/// A session's mark in its lane, as the panel row draws it: the orange dot with its glow, the open ring, the turning
/// arc, the dotted ring, still, an away session's faint dot. On the accent of a selection in the list that has the window's focus, its greys
/// go white, as the system's own rows' icons do; its orange stays orange.
struct MarkView: View {
    let mark: Mark

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Group {
            switch mark {
            case .needs: NeedsDot()
            case .turn:
                Circle()
                    .strokeBorder(WindowStyle.colour(WindowStyle.text, on: prominence), lineWidth: 1.5)
                    .frame(width: 9, height: 9)
            case .working: TurningArc()
            case .onItsWork: DottedRingView(ring: .card, ink: WindowStyle.colour(WindowStyle.dotted, on: prominence))
            case .away: Circle().fill(WindowStyle.colour(WindowStyle.awayDot, on: prominence)).frame(width: 5, height: 5)
            case .snoozed: Circle().fill(WindowStyle.faint).frame(width: 7, height: 7)
            }
        }
        .frame(width: WindowStyle.lane.width, height: WindowStyle.lane.height)
        .spoken(Spoken.mark(mark))
    }
}

/// A closed ask's tick, in the mark's lane.
struct ClosedTick: View {
    var colour = WindowStyle.soft

    var body: some View {
        Text("✓")
            .font(WindowStyle.ui(12))
            .foregroundStyle(colour)
            .frame(width: WindowStyle.lane.width)
            .accessibilityLabel(Spoken.closed)
    }
}

struct NeedsDot: View {
    var body: some View {
        Circle()
            .fill(WindowStyle.orange)
            .frame(width: 7, height: 7)
            .shadow(color: WindowStyle.orange.opacity(0.7), radius: 4)
    }
}

/// The prototype's 11-point arc, turning once a second; still under reduced motion. On the accent of a selection, its
/// arc white over a dimmer white track.
struct TurningArc: View {
    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @State private var isTurning = false

    var body: some View {
        ZStack {
            Circle().stroke(
                WindowStyle.colour(WindowStyle.track, on: prominence, selected: WindowStyle.selectedTrack),
                lineWidth: 1.5
            )
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    WindowStyle.colour(WindowStyle.arc, on: prominence),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .rotationEffect(.degrees(isTurning ? 270 : -90))
        }
        .frame(width: 9, height: 9)
        .onAppear(perform: follow)
        .onChange(of: reducesMotion, follow)
    }

    /// Turning, or held still the moment motion is reduced.
    private func follow() {
        if reducesMotion {
            withTransaction(\.disablesAnimations, true) { isTurning = false }
        } else {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { isTurning = true }
        }
    }
}

/// A button as a pill: the yes, white, the brightest thing in the window; an option, outlined on a fill; the rest
/// outlined; ignore, quiet grey text. Each lifts under the pointer, and keeps the width of its words on one line. One
/// that `fills`, as a card's buttons laid out as rows, takes the width it is given, its words from the left and
/// wrapping, its ends still round.
struct Pill: View {
    enum Look {
        case white, option, outlined, quiet
    }

    let words: String
    let look: Look
    var fills = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(words)
                .font(WindowStyle.ui(12, look == .option || look == .white ? .semibold : .medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: !fills, vertical: true)
                .padding(.vertical, look == .white || look == .quiet ? 6 : 5)
                .padding(.horizontal, padding)
                .frame(maxWidth: fills ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(PillStyle(look: look))
        .contentShape(.focusEffect, RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    static let radius: CGFloat = 13

    private var padding: CGFloat {
        switch look {
        case .white: 13
        case .option, .outlined: 12
        case .quiet: 8
        }
    }
}

/// A pill's ink, fill and ring, a little lifted under the pointer or keyboard focus, and the more pressed; faint while
/// it is the one whose jump runs.
private struct PillStyle: ButtonStyle {
    let look: Pill.Look

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPressed: configuration.isPressed) { highlight in
            let shape = RoundedRectangle(cornerRadius: Pill.radius, style: .continuous)

            configuration.label
                .foregroundStyle(foreground(highlight))
                .background(shape.fill(fill(highlight)))
                .overlay(shape.strokeBorder(ring(highlight), lineWidth: look == .outlined || look == .option ? 1 : 0))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.45)
        }
    }

    private func foreground(_ highlight: Highlight) -> Color {
        switch look {
        case .white: WindowStyle.ink
        case .option, .outlined: WindowStyle.text
        case .quiet: highlight == .none ? WindowStyle.faint : WindowStyle.soft
        }
    }

    private func fill(_ highlight: Highlight) -> Color {
        switch (look, highlight) {
        case (.white, .none): WindowStyle.text
        case (.white, _): WindowStyle.text.opacity(highlight == .picked ? 0.75 : 0.88)
        case (.option, .none): WindowStyle.option
        case (.option, _), (.outlined, .picked): WindowStyle.optionLift
        case (.outlined, .hover): WindowStyle.option
        case (.outlined, .none), (.quiet, _): .clear
        }
    }

    private func ring(_ highlight: Highlight) -> Color {
        switch look {
        case .option: highlight == .none ? WindowStyle.optionRing : WindowStyle.ringLift
        default: highlight == .none ? WindowStyle.ring : WindowStyle.ringLift
        }
    }
}

/// A page's title, a session's, a project's or Settings': the biggest words in the window, to VoiceOver a heading.
struct PageTitle: View {
    let words: String

    var body: some View {
        Text(words)
            .font(WindowStyle.ui(28, .bold))
            .spacing(-0.03, of: 28)
            .foregroundStyle(WindowStyle.text)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A section's heading: its name in small capitals, and a few words on the right; to VoiceOver, one heading.
struct SectionHeading: View {
    let name: String
    var note: String?
    var isOrange = false
    /// Faint after the note, " · " between them: Asks' asleep, "1 snoozed".
    var aside: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name.uppercased())
                .font(WindowStyle.ui(11, .semibold))
                .spacing(0.08, of: 11)
                .foregroundStyle(WindowStyle.soft)
            Spacer()
            notes.font(WindowStyle.ui(12))
        }
        .frame(height: 16)
        .spoken(Spoken.heading(name, note: note, aside: aside))
        .accessibilityAddTraits(.isHeader)
    }

    private var notes: Text {
        let first = note.map { Text($0).foregroundStyle(isOrange ? WindowStyle.orange : WindowStyle.faint) }
        let then = aside.map { Text(note == nil ? $0 : " · \($0)").foregroundStyle(WindowStyle.faint) }

        return [first, then].compactMap(\.self).reduce(Text("")) { Text("\($0)\($1)") }
    }
}

extension View {
    /// One element to VoiceOver, read as these words in place of what it draws.
    func spoken(_ words: String) -> some View {
        accessibilityElement(children: .ignore).accessibilityLabel(words)
    }
}

extension Text {
    /// These words after their session's name, where there is one: quieter, and in the words' own flow, so a line
    /// that wraps comes back to the words' edge, never to a column of the name's.
    func led(by session: String?) -> Text {
        guard let session else {
            return self
        }
        return Text("\(Text("\(session):").foregroundStyle(WindowStyle.soft)) \(self)")
    }
}

/// A row washed orange as it comes, the wash fading out over its two seconds (`Wash`).
struct Washed: ViewModifier {
    let since: Date?
    let now: Date
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.background { WashFill(since: since, now: now, radius: radius) }
    }
}

/// The wash itself, fading by the frame while it lasts.
struct WashFill: View {
    let since: Date?
    let now: Date
    let radius: CGFloat

    var body: some View {
        Framed(now: now, isMoving: amount(at: now) > 0) { now in
            RoundedRectangle(cornerRadius: radius)
                .fill(WindowStyle.wash)
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(WindowStyle.washRing, lineWidth: 1))
                .opacity(amount(at: now))
        }
    }

    private func amount(at time: Date) -> Double {
        since.map { Wash.amount(since: time.timeIntervalSince($0) * 1000) } ?? 0
    }
}

/// What moves by the frame, drawn at each frame's time while it moves, and at the model's time, `now`, while it stands
/// or is drawn as a still. Only what moves is drawn again each frame, never the list or the page around it. Its
/// content changes identity as `isMoving` flips, so nothing with state of its own belongs inside it.
struct Framed<Content: View>: View {
    let now: Date
    let isMoving: Bool
    @ViewBuilder let content: (Date) -> Content

    @Environment(\.isStill) private var isStill

    var body: some View {
        if isMoving, !isStill {
            TimelineView(.animation) { frame in content(max(frame.date, now)) }
        } else {
            content(now)
        }
    }
}

/// A column that scrolls past the window's height; drawn as a still, laid out whole from its top, as an image
/// renderer draws nothing a scroll view holds.
struct Scrolling<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.isStill) private var isStill

    var body: some View {
        if isStill {
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else if #available(macOS 26, *) {
            // The page runs up under the window's toolbar, beside the traffic lights, where the toolbar's soft edge
            // would blur it as it scrolls.
            ScrollView { content }.scrollIndicators(.never).scrollEdgeEffectHidden(true, for: .top)
        } else {
            ScrollView { content }.scrollIndicators(.never)
        }
    }
}

/// Two columns side by side, the first the wider by `ratio`, as the drawing sets Status and Notes beside Parked and
/// Resolved, each as tall as it needs; one alone, as Notes with nothing parked, across the whole.
struct TwoColumns: Layout {
    var ratio: CGFloat = 1.25
    var spacing: CGFloat = 44

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = widths(proposal.width ?? 0, count: subviews.count)
        let heights = zip(subviews, widths).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }

        return CGSize(width: proposal.width ?? 0, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX

        for (subview, width) in zip(subviews, widths(bounds.width, count: subviews.count)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: nil))
            x += width + spacing
        }
    }

    /// The first column's width and the second's, out of the whole, less the space between.
    private func widths(_ whole: CGFloat, count: Int) -> [CGFloat] {
        guard count > 1 else {
            return [whole]
        }

        let second = (whole - spacing) / (ratio + 1)

        return [whole - spacing - second, second]
    }
}

/// A title and the button that goes with it, as a session's name and its jump: the button trailing on the title's
/// row, centred on its first line, while the title wraps to no more lines beside it than across the whole width, as
/// measured, and the width holds the button at all; else the button under the title, leading. A title alone takes the
/// whole width.
struct TitleRow: Layout {
    var spacing: CGFloat = 16
    var under: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = Self.finite(proposal.width)
        let frames = frames(width, subviews)

        return CGSize(width: width ?? frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (subview, frame) in zip(subviews, frames(Self.finite(bounds.width), subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(_ width: CGFloat?, _ subviews: Subviews) -> [CGRect] {
        guard let title = subviews.first else {
            return []
        }

        return frames(
            width, button: subviews.count > 1 ? subviews[1].sizeThatFits(.unspecified) : nil,
            title: { title.sizeThatFits(ProposedViewSize(width: $0, height: nil)) }
        )
    }

    /// The title's place, then the button's, from the top left, in this width, as `title` measures the title in a
    /// width, or on one line in none; with no width, side by side, the title on one line. Where the button is the
    /// taller, the two are centred on the line, the title lowered to it.
    func frames(_ width: CGFloat?, button: CGSize?, title: (CGFloat?) -> CGSize) -> [CGRect] {
        let line = title(nil)

        guard let button else {
            return [CGRect(origin: .zero, size: title(width ?? line.width))]
        }

        let whole = width ?? line.width + spacing + button.width
        let across = title(whole)
        let besideWidth = whole - button.width - spacing

        if besideWidth >= 0, case let beside = title(besideWidth), beside.height <= across.height {
            let offset = (line.height - button.height) / 2

            return [
                CGRect(origin: CGPoint(x: 0, y: max(-offset, 0)), size: beside),
                CGRect(origin: CGPoint(x: whole - button.width, y: max(offset, 0)), size: button),
            ]
        }
        return [
            CGRect(origin: .zero, size: across),
            CGRect(origin: CGPoint(x: 0, y: across.height + under), size: button),
        ]
    }

    /// A width proposed, where it is one: nil for none, or for an infinite one.
    static func finite(_ width: CGFloat?) -> CGFloat? {
        width.flatMap { $0.isFinite ? $0 : nil }
    }
}

extension EnvironmentValues {
    /// SitRep's own Reduce motion, or the Mac's: no slides, no washes, and the arc held still.
    @Entry var reducesWindowMotion = false
    /// Drawn offscreen, as a still.
    @Entry var isStill = false
    /// Drawn as a still with the pointer over every row and button at once, to show how each highlights.
    @Entry var isHoveredStill = false
}
