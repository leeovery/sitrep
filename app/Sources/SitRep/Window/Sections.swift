import SitRepWindow
import SwiftUI

/// A session's status: what is under way, then what comes next, dim. A line cut short opens in place to the whole of
/// it.
struct StatusSection: View {
    let status: Status
    let opened: Set<Item>
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Status", note: status.updated.map { Words.updated($0, at: now) }).padding(.bottom, 8)
            ForEach(Array(status.now.enumerated()), id: \.offset) { offset, line in
                Opening(item: .status(offset, line), opened: opened) { isOpen in
                    SectionLine(bullet: "•", text: line, isOpen: isOpen)
                }
            }
            if let next = status.next {
                Opening(item: .next(next), opened: opened) { isOpen in
                    SectionLine(
                        bullet: "◦", bulletColour: WindowStyle.faint, text: "next: \(next)", textColour: WindowStyle.soft,
                        isOpen: isOpen
                    )
                }
            }
        }
    }
}

/// What happened: the log's latest lines, the newest first, each led by its session's name in a project's view, and
/// opening in place to the whole of it and its detail.
struct NotesSection: View {
    let notes: [Note]
    let opened: Set<Item>
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Notes", note: "what happened").padding(.bottom, 8)
            ForEach(notes) { note in
                Opening(item: .note(note.id), opened: opened, hasMore: note.hasMore) { isOpen in
                    SectionLine(bullet: "•", lead: note.session, text: note.text, time: Words.age(note.at, at: now), isOpen: isOpen) {
                        ForEach(Array(note.detail.enumerated()), id: \.offset) { _, line in
                            Text(line)
                        }
                    }
                }
            }
        }
    }
}

/// What was parked to come back to, the oldest first, in grey: the window has one colour. Each opens in place to the
/// whole of it and where it was parked from.
struct ParkedSection: View {
    let parked: [Parked]
    let opened: Set<Item>
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Parked", note: Words.parked(parked.count)).padding(.bottom, 8)
            ForEach(parked) { item in
                Opening(item: .parked(item.id), opened: opened, hasMore: item.hasMore) { isOpen in
                    SectionLine(bullet: "◇", lead: item.session, text: item.title, time: Words.age(item.at, at: now), isOpen: isOpen) {
                        if let place = item.where {
                            Text(place)
                        }
                    }
                }
            }
        }
    }
}

/// The asks closed, the newest first, the latest three until "show all" opens it to every one, in grey. Each opens in
/// place to the whole of it and how it closed: Lee's answer, or Claude's resolve and its reason.
struct ResolvedSection: View {
    let resolved: [Resolved]
    let opened: Set<Item>
    let now: Date

    @State private var showsAll = false

    private static let shown = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Resolved", note: Words.resolved(resolved.count)).padding(.bottom, 8)
            ForEach(showsAll ? resolved : Array(resolved.prefix(Self.shown))) { ask in
                Opening(item: .resolved(ask.id), opened: opened, hasMore: ask.hasMore) { isOpen in
                    SectionLine(bullet: "✓", text: ask.title, time: Words.age(ask.closed, at: now), isOpen: isOpen) {
                        HowClosed(ask: ask)
                    }
                }
            }
            if resolved.count > Self.shown {
                Button(showsAll ? "show fewer" : "show all \(resolved.count)") { showsAll.toggle() }
                    .wordsButton(WindowStyle.faint, hover: WindowStyle.soft)
                    .font(WindowStyle.ui(12))
                    .padding(.leading, WindowStyle.wordsEdge)
                    .padding(.top, 6)
            }
        }
    }
}

/// How an ask closed, under it opened: Lee's answer, bright, leading the words in their flow.
private struct HowClosed: View {
    let ask: Resolved

    var body: some View {
        let (answer, words) = Words.howClosed(ask)

        if let answer {
            Text("\(Text(answer).fontWeight(.semibold).foregroundStyle(WindowStyle.text)) \(words)")
        } else {
            Text(words)
        }
    }
}

/// An item of a section with more to show than its line, as a button whose highlight under the pointer says it
/// opens: a press opens it in place, its line whole and its detail under it, and a second closes it, the press's
/// change on the window's spring, so the lines below move with it; still, under reduced motion. Opened, it shows nothing behind it. One with no detail is a button only while its line is cut short;
/// whole, it is the line alone, which opens to nothing and takes no keyboard stop. Its highlight reaches past the
/// column's edges, so the line keeps its place beside the heading.
private struct Opening<Line: View>: View {
    let item: Item
    let opened: Set<Item>
    var hasMore = false
    @ViewBuilder let line: (Bool) -> Line

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion

    var body: some View {
        if hasMore {
            button
        } else {
            ViewThatFits(in: .horizontal) {
                line(false)
                button
            }
        }
    }

    private var button: some View {
        let isOpen = opened.contains(item)

        return Button {
            withAnimation(reducesMotion ? nil : WindowStyle.spring) { act.toggleItem(item) }
        } label: {
            line(isOpen)
                .padding(.horizontal, WindowStyle.reach)
                .contentShape(Rectangle())
        }
        .rowButton(radius: 6, highlights: !isOpen)
        .padding(.horizontal, -WindowStyle.reach)
    }
}

/// A line of a section, on the one grid every line of Status, Notes, Parked and Resolved keeps, opened or closed: its
/// bullet in a lane, then its words, then its time on the first line. Its session's name, where it is a project's,
/// leads its words, quieter, in their own flow, so a line that wraps comes back to the words' edge. Opened, its words
/// wrap whole, and its detail sits close under them from the same edge, a size smaller, in the secondary colour.
struct SectionLine<Detail: View>: View {
    let bullet: String
    var bulletColour = WindowStyle.soft
    var lead: String?
    let text: String
    var textColour = WindowStyle.text
    var time: String?
    var isOpen = false
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: WindowStyle.wordsEdge - WindowStyle.lane.width) {
            Text(bullet)
                .font(WindowStyle.ui(bullet == "•" || bullet == "◦" ? 13 : 12))
                .foregroundStyle(bulletColour)
                .frame(width: WindowStyle.lane.width)
            VStack(alignment: .leading, spacing: 3) {
                Text(text).foregroundStyle(textColour).led(by: lead)
                    .font(WindowStyle.ui(13))
                    .lineLimit(isOpen ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isOpen)
                if isOpen {
                    VStack(alignment: .leading, spacing: 2) { detail() }
                        .font(WindowStyle.ui(12))
                        .foregroundStyle(WindowStyle.soft)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let time {
                Text(time).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
            }
        }
        .padding(.vertical, 4)
    }
}

extension SectionLine where Detail == EmptyView {
    init(
        bullet: String, bulletColour: Color = WindowStyle.soft, lead: String? = nil, text: String,
        textColour: Color = WindowStyle.text, time: String? = nil, isOpen: Bool = false
    ) {
        self.init(
            bullet: bullet, bulletColour: bulletColour, lead: lead, text: text, textColour: textColour, time: time,
            isOpen: isOpen
        ) { EmptyView() }
    }
}
