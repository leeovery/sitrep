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
                        MarkedLine(mark: .now, text: line, textColour: WindowStyle.headingText, size: size, isOpen: isOpen)
                    }
                }
                if let next = page.status.next {
                    Opening(item: .next(next), opened: page.opened) { isOpen in
                        MarkedLine(
                            mark: .next, word: Words.next, text: next, textColour: WindowStyle.soft, size: size,
                            isOpen: isOpen
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

    /// Its lines as each mode draws them: a little taller beside the list (A1 revised) than filling the window (A2).
    private var size: LineSize {
        LineSize(line: 18, row: page.mode == .detail ? 28 : 26)
    }

    /// "later N parked ›", which opens Parked narrowed to the session.
    private var later: some View {
        Button { act.openParked(.session(page.id)) } label: {
            HStack(spacing: 8) {
                MarkedLine(
                    mark: .later, word: Words.later, text: Words.parkedCount(page.parked), textColour: WindowStyle.soft,
                    size: size
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

/// A session page's What happened: one thread, the newest first, filling the window its asks, "Asked …", on hollow
/// marks, and its log's lines on dots, on one line down their marks; each line opens in place to the whole of it and
/// its detail. At its end "N resolved", folded, opens in place to its resolved asks, the newest closed first, each
/// opening to how it closed.
struct HappenedSection: View {
    let page: SessionPage
    let now: Date

    @Environment(\.windowActions) private var act

    private var showsResolved: Bool {
        page.opened.contains(.resolvedFold)
    }

    /// Its lines as each mode draws them: a little taller beside the list (A1 revised) than filling the window (A2).
    private var size: LineSize {
        LineSize(line: 16, row: page.mode == .detail ? 28 : 26)
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
            Opening(item: .asked(asked.id), opened: page.opened) { isOpen in
                MarkedLine(
                    mark: .asked, word: Words.asked, text: asked.title, textColour: WindowStyle.threadText, size: size,
                    at: asked.at, now: now, thread: thread, isOpen: isOpen
                )
            }
        case let .line(note):
            NoteLine(note: note, opened: page.opened, size: size, now: now, thread: thread)
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
        .accessibilityLabel(Words.resolved(page.resolved.count))
        .accessibilityValue(showsResolved ? "expanded" : "collapsed")
    }
}

/// A parked item's "Since it was parked" (A4 revised): its session's log lines written since, the newest first, on one
/// line down their marks as What happened's, each in a row of 26, opening in place to the whole of it and its detail;
/// under them, where its session's board carries no line from before it was parked, that only the newest show.
struct SinceParkedSection: View {
    let page: ParkedPage
    let now: Date

    private let size = LineSize(line: 16, row: 26)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(name: Words.sinceParked)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(page.since.enumerated()), id: \.element.id) { offset, note in
                    NoteLine(
                        note: note, opened: page.opened, size: size, now: now,
                        thread: OnThread(isFirst: offset == 0, isLast: offset == page.since.count - 1)
                    )
                }
                if page.isSinceCut {
                    Text(Words.sinceCut)
                        .font(WindowStyle.ui(12))
                        .foregroundStyle(WindowStyle.faint)
                        .padding(.leading, WindowStyle.wordsEdge)
                        .padding(.top, 4)
                }
            }
            .padding(.leading, WindowStyle.sectionIndent)
        }
    }
}

/// A line of a session's log on a thread, on its dot, opening in place to the whole of it and its detail.
private struct NoteLine: View {
    let note: Note
    let opened: Set<Item>
    let size: LineSize
    let now: Date
    let thread: OnThread

    var body: some View {
        Opening(item: .note(note.id), opened: opened, hasMore: note.hasMore) { isOpen in
            MarkedLine(
                mark: .line, text: note.text, textColour: WindowStyle.threadText, size: size, at: note.at, now: now,
                thread: thread, isOpen: isOpen
            ) {
                ForEach(Array(note.detail.enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
        }
    }
}

/// A marked line's first line's height, which its mark sits in the middle of, and its row's.
private struct LineSize {
    let line: CGFloat
    let row: CGFloat
}

/// Where a line of What happened stands on the thread's line: the first's runs down from its mark, the last's up to it.
private struct OnThread {
    let isFirst: Bool
    let isLast: Bool
}

/// A line of a session's Now or What happened, as A1 and A2 revised draw them: its mark in its lane, Now's dot, next's
/// ring or later's diamond, or on the thread's line an ask's hollow ring or a log line's dot, each ringed in the page's
/// black so the line breaks round it; a quieter word before its words, "next", "later" or "Asked"; its words; and on
/// the thread its time in a lane of its own. Opened, its words wrap whole, and its detail sits close under them, as a
/// section's line's. To VoiceOver its words and its time are one element.
private struct MarkedLine<Detail: View>: View {
    enum Mark {
        case now, next, later, asked, line
    }

    let mark: Mark
    var word: String?
    let text: String
    let textColour: Color
    let size: LineSize
    var at: Date?
    var now = Date.distantPast
    var thread: OnThread?
    var isOpen = false
    @ViewBuilder var detail: () -> Detail

    private var padding: CGFloat { (size.row - size.line) / 2 }

    var body: some View {
        HStack(alignment: .top, spacing: WindowStyle.wordsEdge - WindowStyle.lane.width) {
            marked.frame(width: WindowStyle.lane.width, height: size.line)
            VStack(alignment: .leading, spacing: 3) {
                Text(text).foregroundStyle(textColour).after(word)
                    .font(WindowStyle.ui(13))
                    .lineLimit(isOpen ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isOpen)
                    .frame(minHeight: size.line)
                if isOpen {
                    VStack(alignment: .leading, spacing: 2) { detail() }
                        .font(WindowStyle.ui(12))
                        .foregroundStyle(WindowStyle.soft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let at {
                Text(Words.age(at, at: now))
                    .font(WindowStyle.ui(12).monospacedDigit())
                    .foregroundStyle(WindowStyle.dim)
                    .frame(width: WindowStyle.turnTimeLane, height: size.line, alignment: .trailing)
                    .accessibilityLabel(Spoken.age(at, at: now))
            }
        }
        .padding(.vertical, padding)
        .background(alignment: .leading) {
            if let thread {
                ThreadRule(
                    from: thread.isFirst ? padding + size.line / 2 : nil, to: thread.isLast ? padding + size.line / 2 : nil
                )
                .stroke(WindowStyle.threadRule, lineWidth: 1)
                .frame(width: WindowStyle.lane.width)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var marked: some View {
        ZStack {
            switch mark {
            case .now:
                Circle().fill(WindowStyle.nowMark).frame(width: 5, height: 5)
            case .next:
                Circle().strokeBorder(WindowStyle.nextMark, lineWidth: 1.2).frame(width: 6, height: 6)
            case .later:
                Diamond().stroke(WindowStyle.laterMark, style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                    .frame(width: 8, height: 8)
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

extension MarkedLine where Detail == EmptyView {
    init(
        mark: Mark, word: String? = nil, text: String, textColour: Color, size: LineSize, at: Date? = nil,
        now: Date = .distantPast, thread: OnThread? = nil, isOpen: Bool = false
    ) {
        self.init(
            mark: mark, word: word, text: text, textColour: textColour, size: size, at: at, now: now, thread: thread,
            isOpen: isOpen
        ) { EmptyView() }
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

/// A line of a section, on the one grid every line that opens keeps, opened or closed: its bullet in a lane, then its
/// words, then its time on the first line. Opened, its words wrap whole, and its detail sits close under them from the
/// same edge, a size smaller, in the secondary colour.
struct SectionLine<Detail: View>: View {
    let bullet: String
    var bulletColour = WindowStyle.soft
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
                Text(text).foregroundStyle(textColour)
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
        bullet: String, bulletColour: Color = WindowStyle.soft, text: String,
        textColour: Color = WindowStyle.text, time: String? = nil, isOpen: Bool = false
    ) {
        self.init(
            bullet: bullet, bulletColour: bulletColour, text: text, textColour: textColour, time: time,
            isOpen: isOpen
        ) { EmptyView() }
    }
}
