import enum SitRepPanel.WakeTime
import SitRepWindow
import SwiftUI

/// An ask as a card: its mark, title and time, after its session's name where it is a project's; where to look and
/// what its words are; its buttons, Snooze after them; and where Lee's answer is. One closed while it showed keeps its
/// place, faint and without buttons, saying how it closed. One asleep is quieted, as Paper's board H draws it, on a
/// darker card in a faint ring, its dot grey and unlit, its title soft, and in its buttons' place when it wakes, with
/// Wake now. Opened in place in a project's view, its head, and only its head, closes it again. Leading the detail
/// beside the list, as the line picked, it is larger (A1 revised). To VoiceOver it is a container named by its title,
/// which it says once, its buttons inside it.
struct CardView: View {
    let card: Card
    var session: String?
    let now: Date
    var leads = false
    var closesBack: (() -> Void)?

    @Environment(\.windowActions) private var act
    @Environment(\.pressedJump) private var pressedJump
    @Environment(\.wakeCalendar) private var calendar

    var body: some View {
        drawn
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Spoken.card(card, session: session))
    }

    @ViewBuilder private var drawn: some View {
        if card.lines == [.closed(.sent)] {
            head(sent)
        } else {
            VStack(alignment: .leading, spacing: card.isClosed ? 8 : 10) {
                head(title)
                details
                if !card.buttons.isEmpty {
                    buttons
                }
                if let wakes = card.snoozedUntil {
                    asleep(until: wakes)
                }
                ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                    CardLine(line: line, now: now)
                }
            }
            .padding(.top, leads ? 18 : 13)
            .padding(.bottom, leads ? 18 : 14)
            .padding(.leading, leads ? 18 : 14)
            .padding(.trailing, leads ? 20 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Washed(since: card.washed, now: now, radius: 14))
            .background(RoundedRectangle(cornerRadius: 14).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ring, lineWidth: card.isClosed || isAsleep ? 1 : 0))
        }
    }

    /// Closed by Lee's answer: one faint line, "sent, and Claude has it".
    private var sent: some View {
        HStack(spacing: 10) {
            ClosedTick(colour: WindowStyle.text)
            titled(WindowStyle.faint)
                .font(WindowStyle.ui(titleSize, .semibold))
                .spacing(-0.01, of: titleSize)
                .lineLimit(1)
                .accessibilityHidden(true)
            Text(Words.closed(.sent))
                .font(WindowStyle.ui(12))
                .foregroundStyle(WindowStyle.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
    }

    private var isAsleep: Bool { card.snoozedUntil != nil }

    /// Its title's size: as A2 revised draws a card, or larger leading the detail, as A1 revised draws it.
    private var titleSize: CGFloat { leads ? 18 : 15 }

    /// Behind it: the raise; nothing once closed, in its ring; asleep, the darker card in its faint ring.
    private var fill: Color {
        card.isClosed ? .clear : isAsleep ? WindowStyle.asleep : WindowStyle.raise
    }

    private var ring: Color {
        isAsleep ? WindowStyle.asleepRing : WindowStyle.line
    }

    private var title: some View {
        HStack(spacing: 10) {
            if card.isClosed {
                ClosedTick()
            } else {
                MarkView(mark: card.mark)
            }
            titled(card.isClosed ? WindowStyle.faint : isAsleep ? WindowStyle.soft : WindowStyle.text)
                .font(WindowStyle.ui(titleSize, .semibold))
                .spacing(-0.01, of: titleSize)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            Text(Words.age(card.since, at: now)).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
        }
    }

    /// Its head, which closes it back to its line where it can.
    @ViewBuilder private func head(_ content: some View) -> some View {
        if let closesBack {
            Button(action: closesBack) {
                content.padding(.vertical, 4).padding(.horizontal, 6).contentShape(Rectangle())
            }
            .rowButton()
            .accessibilityLabel(Spoken.closeCard)
            .padding(.vertical, -4)
            .padding(.horizontal, -6)
        } else {
            content
        }
    }

    /// Its title in this colour, after its session's name where it is a project's.
    private func titled(_ colour: Color) -> Text {
        Text(card.title).foregroundStyle(colour).led(by: session)
    }

    @ViewBuilder private var details: some View {
        if !card.isClosed {
            if let needs = card.needs {
                HStack(spacing: 5) {
                    Text("needs:").foregroundStyle(WindowStyle.faint)
                    Text(needs).foregroundStyle(WindowStyle.soft)
                }
                .font(WindowStyle.ui(13))
                .padding(.leading, 22)
            }
            if let place = card.where {
                Text(place).font(WindowStyle.ui(13)).foregroundStyle(WindowStyle.soft).padding(.leading, 22)
            }
        }
    }

    /// Its buttons, on one line as pills or its answers as rows (`CardButtons`), Snooze among them its own. Only the
    /// button whose jump runs shows it; the others stay as they look, and a press on one jumps in its place.
    private var buttons: some View {
        CardButtons(buttons: card.buttons) {
            ForEach(card.buttons, id: \.self) { button in
                if button == .snooze {
                    SnoozeButton(ask: card.id)
                } else {
                    Pill(words: Words.label(button), look: Pill.Look(button), wraps: true, leaves: button.leaves) {
                        act.press(button, card.id)
                    }
                        .disabled(pressedJump == .card(card.id, button))
                }
            }
        }
        .padding(.leading, 22)
        .padding(.top, 4)
    }

    /// Asleep, in its buttons' place: when it wakes, then Wake now, outlined.
    private func asleep(until wakes: Date) -> some View {
        HStack(spacing: 12) {
            Text(Words.snoozedUntil(WakeTime.words(wakes, at: now, in: calendar)))
                .font(WindowStyle.ui(12).monospacedDigit())
                .foregroundStyle(WindowStyle.soft)
            Pill(words: Words.wakeNow, look: .outlined) { act.wake(card.id) }
        }
        .padding(.leading, 22)
        .padding(.top, 4)
    }
}

/// A card's "Snooze ⌄", after Ignore: plain as Ignore is, in the soft grey with a small chevron, until a press drops
/// its menu of times (`SnoozeMenu`), when it is a pill while the menu shows. A time chosen snoozes the card's ask.
struct SnoozeButton: View {
    let ask: AskAddress

    @Environment(\.windowActions) private var act
    @Environment(\.wakeCalendar) private var calendar
    @State private var anchor = MenuAnchor()
    @State private var isOpen = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 5) {
                Text(Words.snooze)
                SnoozeChevron().stroke(style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                    .frame(width: 8, height: 5)
            }
            .font(WindowStyle.ui(12, .medium))
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .buttonStyle(SnoozeStyle(isOpen: isOpen))
        .background(MenuAnchorView(anchor: anchor))
        .contentShape(.focusEffect, RoundedRectangle(cornerRadius: Pill.radius, style: .continuous))
    }

    /// The pill shows, the menu drops once it has drawn (`MenuAnchor.popUp`), and the pill goes as the menu closes.
    private func open() {
        let snooze = act.snooze, ask = ask

        isOpen = true
        anchor.popUp(SnoozeMenu(at: Date(), in: calendar) { snooze(ask, $0) }) { isOpen = false }
    }
}

/// Snooze's chevron, pointing down, 8 by 5.
private struct SnoozeChevron: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + 0.75, y: rect.minY + 0.75))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 0.75))
            path.addLine(to: CGPoint(x: rect.maxX - 0.75, y: rect.minY + 0.75))
        }
    }
}

/// Snooze's look: its words soft, the text's under the pointer; its menu open, a pill of white at 8%.
private struct SnoozeStyle: ButtonStyle {
    let isOpen: Bool

    func makeBody(configuration: Configuration) -> some View {
        Highlighted(isPressed: configuration.isPressed) { highlight in
            let shape = RoundedRectangle(cornerRadius: Pill.radius, style: .continuous)

            configuration.label
                .foregroundStyle(Pill.Look.quiet.ink(highlight))
                .background(shape.fill(isOpen ? WindowStyle.menuOpen : .clear))
                .contentShape(shape)
        }
    }
}

/// A card's buttons, one subview each in the card's order: on one line as pills while they fit at their one-line
/// widths, as measured; else rows, each as wide as its words, wrapping only past `Card.rowWidth`, then the rest on a
/// line after them (`Card.arrangement`).
struct CardButtons: Layout {
    /// A button's frame, from the top left, and the proposal it was measured with, which places it as measured.
    struct Place: Equatable {
        let frame: CGRect
        let proposal: ProposedViewSize
    }

    let buttons: [Card.Button]
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 6
    /// From the last row to the line after the rows: the card's gap of 10, and 2 (board I1).
    var restSpacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let frames = places(proposal.width, subviews).map(\.frame)
        let width = proposal.width ?? frames.map(\.maxX).max() ?? 0

        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (subview, place) in zip(subviews, places(bounds.width, subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + place.frame.minX, y: bounds.minY + place.frame.minY),
                proposal: place.proposal
            )
        }
    }

    private func places(_ width: CGFloat?, _ subviews: Subviews) -> [Place] {
        places(width, ideal: subviews.map { $0.sizeThatFits(.unspecified) }) { offset, proposal in
            subviews[offset].sizeThatFits(proposal)
        }
    }

    /// Each button's place, from its one-line size and its size as proposed a row's width.
    func places(_ width: CGFloat?, ideal: [CGSize], within: (Int, ProposedViewSize) -> CGSize) -> [Place] {
        guard let width, ideal.count == buttons.count,
              case let .rows(rowed) = Card.arrangement(
                  of: buttons, widths: ideal.map { Double($0.width) }, spacing: spacing, in: width
              )
        else {
            return line(ideal, top: 0)
        }

        return rows(rowed, width, ideal, within)
    }

    /// These a row each, as wide as its words up to the widest a row runs, then the rest on a line after them, each in
    /// its place.
    private func rows(
        _ rowed: [Int], _ width: CGFloat, _ ideal: [CGSize], _ within: (Int, ProposedViewSize) -> CGSize
    ) -> [Place] {
        let rest = ideal.indices.filter { !rowed.contains($0) }
        var places = line(ideal, top: 0)
        var top: CGFloat = 0

        for offset in rowed {
            let proposal = ProposedViewSize(
                width: CGFloat(Card.rowWidth(Double(ideal[offset].width), in: Double(width))), height: nil
            )
            let size = within(offset, proposal)

            places[offset] = Place(frame: CGRect(origin: CGPoint(x: 0, y: top), size: size), proposal: proposal)
            top += size.height + rowSpacing
        }
        for (offset, place) in zip(rest, line(rest.map { ideal[$0] }, top: top - rowSpacing + restSpacing)) {
            places[offset] = place
        }
        return places
    }

    /// One-line sizes side by side from the left, centred on one line, each placed unproposed, as measured.
    private func line(_ sizes: [CGSize], top: CGFloat) -> [Place] {
        let height = sizes.map(\.height).max() ?? 0
        var x: CGFloat = 0

        return sizes.map { size in
            defer { x += size.width + spacing }
            let frame = CGRect(x: x, y: top + (height - size.height) / 2, width: size.width, height: size.height)

            return Place(frame: frame, proposal: .unspecified)
        }
    }
}

/// A line under a card's buttons: the answer as the board words it, bright, then where it is, faint; while it waits
/// its two seconds, a line under it draining.
private struct CardLine: View {
    let line: Card.Line
    let now: Date

    var body: some View {
        let (answer, words) = Words.line(line)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let answer {
                    Text(answer).font(WindowStyle.ui(12, .semibold)).foregroundStyle(WindowStyle.text)
                }
                Text(words).font(WindowStyle.ui(12)).foregroundStyle(isFaint ? WindowStyle.faint : WindowStyle.soft)
            }
            if case let .waiting(pending) = line {
                Framed(now: now, isMoving: true) { now in Draining(left: 1 - pending.waited(at: now)) }
            }
        }
        .padding(.leading, 22)
    }

    private var isFaint: Bool {
        switch line {
        case .closed, .refused, .notSnoozed, .notWoken: false
        default: true
        }
    }
}

/// What is left of an answer's two seconds, as a line that drains.
private struct Draining: View {
    let left: Double

    var body: some View {
        GeometryReader { size in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(WindowStyle.line)
                RoundedRectangle(cornerRadius: 1).fill(WindowStyle.text).frame(width: size.size.width * left)
            }
        }
        .frame(height: 2)
    }
}
