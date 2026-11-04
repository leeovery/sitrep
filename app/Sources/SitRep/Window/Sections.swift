import SitRepWindow
import SwiftUI

/// A session page's Now: what is under way, then what comes next, quieter, then how many items it parked for later,
/// which opens Parked narrowed to the session; on the heading's right, when its status last changed, while its log
/// still holds that line. A line cut short opens in place to the whole of it.
struct NowSection: View {
    let page: SessionPage
    let now: Date

    @Environment(\.windowActions) private var act

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(
                name: "Now", note: page.status.updated.map { Words.updated($0, at: now) },
                spoken: page.status.updated.map { Spoken.updated($0, at: now) }
            )
            Group {
                ForEach(Array(page.status.now.enumerated()), id: \.offset) { offset, line in
                    Opening(item: .status(offset, line), opened: page.opened) { isOpen in
                        SectionLine(bullet: "•", text: line, isOpen: isOpen)
                    }
                }
                if let next = page.status.next {
                    Opening(item: .next(next), opened: page.opened) { isOpen in
                        SectionLine(
                            bullet: "◦", bulletColour: WindowStyle.faint, word: Words.next, text: next,
                            textColour: WindowStyle.soft, isOpen: isOpen
                        )
                    }
                }
                if page.parked > 0 {
                    later
                }
            }
            .padding(.leading, WindowStyle.sectionIndent)
        }
    }

    /// "later · N parked ›", which opens Parked narrowed to the session.
    private var later: some View {
        Button { act.openParked(.session(page.id)) } label: {
            HStack(spacing: 8) {
                SectionLine(
                    bullet: "◇", bulletColour: WindowStyle.faint, word: Words.later, text: Words.parkedCount(page.parked),
                    textColour: WindowStyle.soft
                )
                .fixedSize()
                Chevron(isFolded: true).foregroundStyle(WindowStyle.faint)
            }
            .padding(.horizontal, WindowStyle.reach)
            .contentShape(Rectangle())
        }
        .rowButton(radius: 6)
        .padding(.horizontal, -WindowStyle.reach)
        .accessibilityLabel("\(Words.later), \(Words.parkedCount(page.parked))")
    }
}

/// A session page's What happened: one thread, the newest first, its asks still open, "Asked …", on hollow marks, and
/// its log's lines on dots, on one line down their marks; each line opens in place to the whole of it and its detail.
/// At its end "N resolved", folded, opens in place to its resolved asks, the newest closed first, each opening to how it
/// closed.
struct HappenedSection: View {
    let page: SessionPage
    let now: Date

    @Environment(\.windowActions) private var act

    private var showsResolved: Bool {
        page.opened.contains(.resolvedFold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(name: "What happened")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(page.happened.enumerated()), id: \.element.id) { offset, entry in
                    line(entry, along: OnThread(isFirst: offset == 0, isLast: offset == page.happened.count - 1))
                }
            }
            .padding(.leading, WindowStyle.sectionIndent)
            if !page.resolved.isEmpty {
                fold
                if showsResolved {
                    ForEach(page.resolved) { ask in
                        Opening(item: .resolved(ask.id), opened: page.opened, hasMore: ask.hasMore) { isOpen in
                            SectionLine(bullet: "✓", text: ask.title, time: Words.age(ask.closed, at: now), isOpen: isOpen) {
                                HowClosed(ask: ask)
                            }
                        }
                    }
                    .padding(.leading, WindowStyle.sectionIndent)
                }
            }
        }
    }

    @ViewBuilder private func line(_ entry: SessionPage.Happened, along thread: OnThread) -> some View {
        switch entry {
        case let .asked(asked):
            ThreadLine(mark: .asked, word: Words.asked, text: asked.title, at: asked.at, now: now, thread: thread)
        case let .line(note):
            Opening(item: .note(note.id), opened: page.opened, hasMore: note.hasMore) { isOpen in
                ThreadLine(mark: .line, text: note.text, at: note.at, now: now, thread: thread, isOpen: isOpen) {
                    ForEach(Array(note.detail.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
            }
        }
    }

    /// "N resolved ›", which opens its resolved asks in place under it, its chevron down, and folds them again.
    private var fold: some View {
        Button { act.toggleItem(.resolvedFold) } label: {
            HStack(spacing: WindowStyle.wordsEdge - WindowStyle.lane.width) {
                Text("✓")
                    .font(WindowStyle.ui(11, .semibold))
                    .foregroundStyle(WindowStyle.faint)
                    .frame(width: WindowStyle.lane.width)
                Text(Words.resolved(page.resolved.count)).font(WindowStyle.ui(13)).foregroundStyle(WindowStyle.soft)
                Chevron(isFolded: !showsResolved).foregroundStyle(WindowStyle.faint)
                Spacer(minLength: 0)
            }
            .frame(height: 32)
            .padding(.leading, WindowStyle.sectionIndent)
            .padding(.horizontal, WindowStyle.reach)
            .contentShape(Rectangle())
        }
        .rowButton(radius: 6)
        .padding(.horizontal, -WindowStyle.reach)
        .accessibilityLabel(
            showsResolved ? Words.resolved(page.resolved.count) : "\(Words.resolved(page.resolved.count)), folded"
        )
    }
}

/// Where a line of What happened stands on the thread's line: the first's runs down from its mark, the last's up to it.
private struct OnThread {
    let isFirst: Bool
    let isLast: Bool
}

/// A line of What happened: its mark on the thread's line, an ask still open's hollow, a log line's dot, each ringed in
/// the page's black so the line breaks round it; a quieter word before an ask's title, "Asked"; its words; and its time
/// in a lane of its own. Opened, its words wrap whole, and its detail sits close under them, as a section's line's.
private struct ThreadLine<Detail: View>: View {
    enum Mark {
        case asked, line
    }

    let mark: Mark
    var word: String?
    let text: String
    let at: Date
    let now: Date
    let thread: OnThread
    var isOpen = false
    @ViewBuilder var detail: () -> Detail

    /// The vertical padding round its first line, and the line's height: its mark sits on the line's middle.
    private static var padding: CGFloat { 5 }
    private static var lineHeight: CGFloat { 16 }

    var body: some View {
        HStack(alignment: .top, spacing: WindowStyle.wordsEdge - WindowStyle.lane.width) {
            marked.frame(width: WindowStyle.lane.width, height: Self.lineHeight)
            VStack(alignment: .leading, spacing: 3) {
                Text(text).foregroundStyle(WindowStyle.threadText).after(word)
                    .font(WindowStyle.ui(13))
                    .lineLimit(isOpen ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isOpen)
                    .frame(minHeight: Self.lineHeight)
                if isOpen {
                    VStack(alignment: .leading, spacing: 2) { detail() }
                        .font(WindowStyle.ui(12))
                        .foregroundStyle(WindowStyle.soft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Words.age(at, at: now))
                .font(WindowStyle.ui(12).monospacedDigit())
                .foregroundStyle(WindowStyle.dim)
                .frame(width: WindowStyle.turnTimeLane, height: Self.lineHeight, alignment: .trailing)
                .accessibilityLabel(Spoken.age(at, at: now))
        }
        .padding(.vertical, Self.padding)
        .background(alignment: .leading) {
            ThreadRule(from: thread.isFirst ? Self.padding + Self.lineHeight / 2 : nil, to: thread.isLast ? Self.padding + Self.lineHeight / 2 : nil)
                .stroke(WindowStyle.threadRule, lineWidth: 1)
                .frame(width: WindowStyle.lane.width)
        }
    }

    private var marked: some View {
        ZStack {
            switch mark {
            case .asked:
                Circle().fill(WindowStyle.black).frame(width: 9, height: 9)
                Circle().strokeBorder(WindowStyle.threadMark, lineWidth: 1.3).frame(width: 7, height: 7)
            case .line:
                Circle().fill(WindowStyle.black).frame(width: 11, height: 11)
                Circle().fill(WindowStyle.threadMark).frame(width: 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

extension ThreadLine where Detail == EmptyView {
    init(mark: Mark, word: String? = nil, text: String, at: Date, now: Date, thread: OnThread) {
        self.init(mark: mark, word: word, text: text, at: at, now: now, thread: thread) { EmptyView() }
    }
}

/// The thread's line down a line of What happened's marks, from the top of its row, or from its mark at this height,
/// to the foot of its row, or to its mark.
private struct ThreadRule: Shape {
    let from: CGFloat?
    let to: CGFloat?

    func path(in rect: CGRect) -> Path {
        Path { path in
            let top = from.map { rect.minY + $0 } ?? rect.minY
            let bottom = to.map { rect.minY + $0 } ?? rect.maxY

            if bottom > top {
                path.move(to: CGPoint(x: rect.midX, y: top))
                path.addLine(to: CGPoint(x: rect.midX, y: bottom))
            }
        }
    }
}

/// A heading of a session's page, Now or What happened: its name, 13 semibold, and a few quiet words on its right; to
/// VoiceOver one heading, the words as `spoken` says them where they read as symbols.
struct PageHeading: View {
    let name: String
    var note: String?
    var spoken: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(WindowStyle.ui(13, .semibold))
                .spacing(-0.005, of: 13)
                .foregroundStyle(WindowStyle.headingText)
            Spacer()
            if let note {
                Text(note).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.dim)
            }
        }
        .frame(height: 16)
        .padding(.bottom, 8)
        .spoken(Spoken.heading(name, note: spoken ?? note))
        .accessibilityAddTraits(.isHeader)
    }
}

private extension Text {
    /// These words after a quieter word, where there is one: "next", "later", "Asked".
    func after(_ word: String?) -> Text {
        guard let word else {
            return self
        }
        return Text("\(Text(word).foregroundStyle(WindowStyle.dim)) \(self)")
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
/// opens: a press opens it in place, its line whole and its detail under it, and a second closes it, at once, with no
/// motion of its words or of the lines below. Opened, it shows nothing behind it. One with no detail is a button only
/// while its line is cut short; whole, it is the line alone, which opens to nothing and takes no keyboard stop. Its
/// highlight reaches past the column's edges, so the line keeps its place beside the heading.
private struct Opening<Line: View>: View {
    let item: Item
    let opened: Set<Item>
    var hasMore = false
    @ViewBuilder let line: (Bool) -> Line

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
            line(isOpen)
                .padding(.horizontal, WindowStyle.reach)
                .contentShape(Rectangle())
        }
        .rowButton(radius: 6, highlights: !isOpen)
        .padding(.horizontal, -WindowStyle.reach)
    }
}

/// A line of a section, on the one grid every line of a session's Now and resolved asks and a project's Notes and
/// Parked keeps, opened or closed: its bullet in a lane, then its words, then its time on the first line. Its session's
/// name, where it is a project's, leads its words, quieter, in their own flow, so a line that wraps comes back to the
/// words' edge; or a quieter word does, "next" or "later". Opened, its words wrap whole, and its detail sits close
/// under them from the same edge, a size smaller, in the secondary colour.
struct SectionLine<Detail: View>: View {
    let bullet: String
    var bulletColour = WindowStyle.soft
    var lead: String?
    var word: String?
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
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(text).foregroundStyle(textColour).led(by: lead).after(word)
                    .font(WindowStyle.ui(13))
                    .lineLimit(isOpen ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isOpen)
                if isOpen {
                    VStack(alignment: .leading, spacing: 2) { detail() }
                        .font(WindowStyle.ui(12))
                        .foregroundStyle(WindowStyle.soft)
                        .fixedSize(horizontal: false, vertical: true)
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
        bullet: String, bulletColour: Color = WindowStyle.soft, lead: String? = nil, word: String? = nil, text: String,
        textColour: Color = WindowStyle.text, time: String? = nil, isOpen: Bool = false
    ) {
        self.init(
            bullet: bullet, bulletColour: bulletColour, lead: lead, word: word, text: text, textColour: textColour,
            time: time, isOpen: isOpen
        ) { EmptyView() }
    }
}
