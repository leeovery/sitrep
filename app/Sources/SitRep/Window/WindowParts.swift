import enum SitRepPanel.Wash
import SitRepWindow
import SwiftUI

/// A session's mark in its lane, as the panel row draws it: the orange dot with its glow, the open ring, the turning
/// arc, an away session's faint dot.
struct MarkView: View {
    let mark: Mark

    var body: some View {
        Group {
            switch mark {
            case .needs: NeedsDot()
            case .turn: Circle().strokeBorder(WindowStyle.text, lineWidth: 1.5).frame(width: 9, height: 9)
            case .working: TurningArc()
            case .away: Circle().fill(WindowStyle.awayDot).frame(width: 5, height: 5)
            }
        }
        .frame(width: WindowStyle.lane.width, height: WindowStyle.lane.height)
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

/// The prototype's 11-point arc, turning once a second; still under reduced motion.
struct TurningArc: View {
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @State private var isTurning = false

    var body: some View {
        ZStack {
            Circle().stroke(WindowStyle.track, lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(WindowStyle.arc, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
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
/// outlined; ignore, quiet grey text. Each lifts under the pointer. Given more width than its words take on one line,
/// as a card's answers laid out as rows, it takes it all, its words from the left and wrapping, its ends still round.
struct Pill: View {
    enum Look {
        case white, option, outlined, quiet
    }

    let words: String
    let look: Look
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(words)
                .font(WindowStyle.ui(12, look == .option || look == .white ? .semibold : .medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, look == .white || look == .quiet ? 6 : 5)
                .padding(.horizontal, padding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PillStyle(look: look))
    }

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
            let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)

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

/// A section's heading: its name in small capitals, and a few words on the right.
struct SectionHeading: View {
    let name: String
    var note: String?
    var isOrange = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name.uppercased())
                .font(WindowStyle.ui(11, .semibold))
                .spacing(0.08, of: 11)
                .foregroundStyle(WindowStyle.soft)
            Spacer()
            if let note {
                Text(note).font(WindowStyle.ui(12)).foregroundStyle(isOrange ? WindowStyle.orange : WindowStyle.faint)
            }
        }
        .frame(height: 16)
    }
}

/// A line of a section: its bullet in a lane, its words on one line, naming its session where it is a project's, and
/// its time on the right.
struct SectionLine: View {
    let bullet: String
    var bulletColour = WindowStyle.soft
    var session: String?
    let text: String
    var textColour = WindowStyle.text
    var time: String?
    /// Opened in place: its words whole, wrapping.
    var isOpen = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(bullet)
                .font(WindowStyle.ui(bullet == "•" || bullet == "◦" ? 13 : 12))
                .foregroundStyle(bulletColour)
                .frame(width: 12)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let session {
                    Text("\(session):").foregroundStyle(WindowStyle.soft).layoutPriority(1)
                }
                Text(text).foregroundStyle(textColour)
            }
            .font(WindowStyle.ui(13))
            .lineLimit(isOpen ? nil : 1)
            .fixedSize(horizontal: false, vertical: isOpen)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let time {
                Text(time).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A row washed orange as it comes, the wash fading out over its two seconds (`Wash`).
struct Washed: ViewModifier {
    let since: Date?
    let now: Date
    let radius: CGFloat

    func body(content: Content) -> some View {
        let amount = since.map { Wash.amount(since: now.timeIntervalSince($0) * 1000) } ?? 0

        content.background {
            RoundedRectangle(cornerRadius: radius)
                .fill(WindowStyle.wash)
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(WindowStyle.washRing, lineWidth: 1))
                .opacity(amount)
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

extension EnvironmentValues {
    /// SitRep's own Reduce motion, or the Mac's: no slides, no washes, and the arc held still.
    @Entry var reducesWindowMotion = false
    /// Drawn offscreen, as a still.
    @Entry var isStill = false
    /// Drawn as a still with the pointer over every row and button at once, to show how each highlights.
    @Entry var isHoveredStill = false
}
