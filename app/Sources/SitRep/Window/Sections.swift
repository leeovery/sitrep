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
            ForEach(Array(status.now.enumerated()), id: \.offset) { _, line in
                Opening(item: .status(line), opened: opened) { isOpen in
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

/// What happened: the log's latest lines, the newest first, each naming its session in a project's view, and opening
/// in place to the whole of it and its detail.
struct NotesSection: View {
    let notes: [Note]
    let opened: Set<Item>
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Notes", note: "what happened").padding(.bottom, 8)
            ForEach(notes) { note in
                Opening(item: .note(note.id), opened: opened, hasMore: !note.detail.isEmpty) { isOpen in
                    SectionLine(bullet: "•", session: note.session, text: note.text, time: Words.age(note.at, at: now), isOpen: isOpen)
                } detail: {
                    ForEach(Array(note.detail.enumerated()), id: \.offset) { _, line in
                        OpenedLine(words: line)
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
                Opening(item: .parked(item.id), opened: opened, hasMore: item.where != nil) { isOpen in
                    SectionLine(bullet: "◇", session: item.session, text: item.title, time: Words.age(item.at, at: now), isOpen: isOpen)
                } detail: {
                    if let place = item.where {
                        OpenedLine(words: place)
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
                Opening(item: .resolved(ask.id), opened: opened, hasMore: true) { isOpen in
                    SectionLine(bullet: "✓", text: ask.title, time: Words.age(ask.closed, at: now), isOpen: isOpen)
                } detail: {
                    let (answer, words) = Words.howClosed(ask)

                    OpenedLine(answer: answer, words: words)
                }
            }
            if resolved.count > Self.shown {
                Button(showsAll ? "show fewer" : "show all \(resolved.count)") { showsAll.toggle() }
                    .wordsButton(WindowStyle.faint, hover: WindowStyle.soft)
                    .font(WindowStyle.ui(12))
                    .padding(.leading, 22)
                    .padding(.top, 6)
            }
        }
    }
}

/// An item of a section with more to show than its line, as a button highlighted under the pointer: a press opens
/// it in place, its line whole and its detail under it, and a second closes it. One with no detail is a button only
/// while its line is cut short; whole, it is the line alone, which opens to nothing and takes no keyboard stop. Its
/// highlight reaches past the column's edges, so the line keeps its place beside the heading.
private struct Opening<Line: View, Detail: View>: View {
    let item: Item
    let opened: Set<Item>
    var hasMore = false
    @ViewBuilder let line: (Bool) -> Line
    @ViewBuilder var detail: () -> Detail

    @Environment(\.windowActions) private var act

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

        return Button { act.toggleItem(item) } label: {
            VStack(alignment: .leading, spacing: 2) {
                line(isOpen)
                if isOpen {
                    VStack(alignment: .leading, spacing: 4) { detail() }.padding(.leading, 22)
                }
            }
            .padding(.horizontal, WindowStyle.reach)
            .contentShape(Rectangle())
        }
        .rowButton(radius: 6)
        .padding(.horizontal, -WindowStyle.reach)
    }
}

extension Opening where Detail == EmptyView {
    init(item: Item, opened: Set<Item>, @ViewBuilder line: @escaping (Bool) -> Line) {
        self.init(item: item, opened: opened, line: line) { EmptyView() }
    }
}

/// A line under an item opened: an answer, bright, then the words, wrapping.
private struct OpenedLine: View {
    var answer: String?
    let words: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let answer {
                Text(answer).font(WindowStyle.ui(12, .semibold)).foregroundStyle(WindowStyle.text)
            }
            Text(words)
                .font(WindowStyle.ui(12))
                .foregroundStyle(WindowStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
