import SitRepCore
import SitRepWindow
import SwiftUI

/// A project, filling the window, as A3 revised draws it, under the band beside the traffic lights: its title and its
/// counts; Sessions, a row each, where it stands in the middle; Waiting on you, a row per line across them; Now, a card
/// per session; Log, each session's newest lines under its card; and, under a rule, what it parked. A press on a
/// session's row or a line pushes the session's page; on "N parked", Parked narrowed to the project.
struct ProjectPageView: View {
    let page: ProjectPage
    let now: Date

    @Environment(\.windowActions) private var act

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            header.padding(.bottom, Self.sectionGap)
            if !page.sessions.isEmpty {
                sessions
            }
            if !page.waiting.isEmpty {
                waiting.padding(.top, Self.sectionGap)
            }
            if !page.sessions.isEmpty {
                nowCards.padding(.top, Self.sectionGap)
            }
            if page.hasLog {
                log.padding(.top, Self.sectionGap)
            }
            if let parkedRow = page.parkedRow {
                parked(parkedRow).padding(.top, Self.parkedGap)
            }
        }
        .padding(.bottom, 34)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(page.name)
                .font(WindowStyle.ui(34, .bold))
                .spacing(-0.03, of: 34)
                .foregroundStyle(WindowStyle.text)
                .accessibilityAddTraits(.isHeader)
            if !page.counts.isEmpty {
                Text(page.counts.joined(separator: " · "))
                    .font(WindowStyle.ui(13))
                    .foregroundStyle(Ink.rest)
                    .spoken(Spoken.counts(page))
            }
        }
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(name: "Sessions")
            ForEach(page.sessions) { session in
                lineButton(spoken: Spoken.session(session, at: now)) { act.openSession(session.id) } label: {
                    ProjectSessionRow(session: session, now: now)
                }
            }
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(name: "Waiting on you", count: page.waitingCount)
            ForEach(page.waiting) { line in
                lineButton(spoken: Spoken.waiting(line, at: now)) { act.openSession(line.session) } label: {
                    WaitingRow(line: line, now: now)
                }
                .modifier(Washed(since: line.line.washed, now: now, radius: Self.radius))
            }
        }
    }

    private var nowCards: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(name: "Now", under: Self.gridHeadingGap)
            PageGrid {
                ForEach(page.sessions) { NowCard(session: $0, now: now) }
            }
        }
    }

    private var log: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(name: "Log", under: Self.gridHeadingGap)
            PageGrid {
                ForEach(page.sessions) { LogGroup(session: $0, now: now) }
            }
        }
    }

    /// A rule, then "◇ N parked ›".
    private func parked(_ words: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(Ink.rule).frame(height: 1)
            lineButton(spoken: words) { act.openParked(.project(page.key)) } label: {
                HStack(spacing: Self.gap) {
                    Diamond()
                        .stroke(Ink.mark, style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                        .frame(width: 8, height: 8)
                        .frame(width: WindowStyle.lane.width)
                    Text(words).font(WindowStyle.ui(13)).foregroundStyle(Ink.parked)
                    Chevron(isFolded: true).foregroundStyle(Ink.chevron)
                }
                .frame(height: 26)
            }
        }
    }

    /// A line of the page that a press acts on, its hover fill reaching past the column's edges so its words keep
    /// their place under the headings; to VoiceOver one element, a button, read as given.
    private func lineButton(
        spoken: String, action: @escaping () -> Void, @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: action) {
            label()
                .padding(.horizontal, WindowStyle.reach)
                .contentShape(Rectangle())
                .spoken(spoken)
        }
        .rowButton(radius: Self.radius)
        .padding(.horizontal, -WindowStyle.reach)
    }

    static let sectionGap: CGFloat = 22
    static let gridHeadingGap: CGFloat = 8
    static let parkedGap: CGFloat = 14
    static let gap: CGFloat = 10
    static let radius: CGFloat = 8
    /// A row of Sessions or Waiting on you, 32 tall: its first words, the session's name or the line's, in a lane of
    /// their own, so the next words line up; its time in a lane of 30.
    static let rowHeight: CGFloat = 32
    static let nameLane: CGFloat = 280
    static let ageLane: CGFloat = 30
}

/// A session's row in Sessions, 32 tall: its mark, the pip where no terminal shows it; its name in a lane of 280; where
/// it stands, a working line's lead shimmering as its list row's does, and "not on screen" where no terminal shows it;
/// and its time. While no window holds it, its name and where it stands dim as one (`Away`), its time staying.
struct ProjectSessionRow: View {
    let session: ProjectPage.Session
    let now: Date

    var body: some View {
        PageRow(age: Words.age(session.since, at: now)) {
            PageMark(mark: session.mark, isOffScreen: session.isOffScreen)
            Group {
                Text(session.name)
                    .font(WindowStyle.ui(13, .medium))
                    .spacing(-0.01, of: 13)
                    .foregroundStyle(Ink.words)
                    .lineLimit(1)
                    .frame(width: ProjectPageView.nameLane, alignment: .leading)
                standing.frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(Away.dimming(session.isAway))
        }
    }

    private var standing: some View {
        HStack(spacing: 0) {
            if case let .doing(kind, line) = session.standing {
                DoingLine(kind: kind, line: line, now: now)
            } else {
                Text(session.standing.parts(at: now).joined(separator: " · "))
            }
            if session.isOffScreen {
                // kept whole as the rest is cut short: it says a jump to the session would fail
                Text(" · \(Words.notOnScreen)").layoutPriority(1)
            }
        }
        .font(WindowStyle.ui(13))
        .foregroundStyle(Ink.rest)
        .lineLimit(1)
    }
}

/// A working or on its own work's line: its lead, shimmering while it works; then what it acts on, a command in mono, a
/// wake counted down.
private struct DoingLine: View {
    let kind: Doing.Kind
    let line: Board.Row.Words
    let now: Date

    var body: some View {
        HStack(spacing: 5) {
            if kind == .working {
                ShimmeringLead { isLit in
                    Text(line.lead).foregroundStyle(isLit ? WindowStyle.text : Ink.rest)
                }
            } else {
                Text(line.lead)
            }
            if let mono = line.mono {
                Text(mono).font(WindowStyle.mono(12))
            } else if let subject = Words.subject(line, at: now) {
                Text(subject)
            }
        }
    }
}

/// A line of Waiting on you, 32 tall: its mark; its words in a lane of 280, a command in mono; its session; and how
/// long it has waited. Dimmed as one where no window holds its session; faint, a tick for its mark, where it closed
/// while the page held.
private struct WaitingRow: View {
    let line: ProjectPage.Line
    let now: Date

    var body: some View {
        PageRow(age: Words.age(line.line.since, at: now)) {
            if line.isClosed {
                ClosedTick(colour: WindowStyle.faint)
            } else {
                PageMark(mark: line.mark, isOffScreen: line.isOffScreen)
            }
            Group {
                words
                    .spacing(-0.01, of: 13)
                    .foregroundStyle(line.isClosed ? WindowStyle.faint : Ink.words)
                    .lineLimit(1)
                    .frame(width: ProjectPageView.nameLane, alignment: .leading)
                Text(line.sessionName)
                    .font(WindowStyle.ui(13))
                    .foregroundStyle(line.isClosed ? WindowStyle.faint : Ink.rest)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(Away.dimming(line.isAway))
        }
    }

    private var words: Text {
        let lead = Text(line.line.lead).font(WindowStyle.ui(13))
        let code = line.line.code.map { Text(" \($0)").font(WindowStyle.mono(12)) }
        let subject = line.line.subject(at: now).map { Text(" \($0)").font(WindowStyle.ui(13)) }

        return [code, subject].compactMap(\.self).reduce(lead) { Text("\($0)\($1)") }
    }
}

/// A row of Sessions or Waiting on you: its parts 10 apart, then its time, 12 in tabular figures.
private struct PageRow<Content: View>: View {
    let age: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: ProjectPageView.gap) {
            content
            Text(age)
                .font(WindowStyle.ui(12))
                .monospacedDigit()
                .foregroundStyle(Ink.age)
                .frame(width: ProjectPageView.ageLane, alignment: .trailing)
        }
        .frame(height: ProjectPageView.rowHeight)
    }
}

/// A session's card in Now: its mark and name; its now lines; what comes next; and when its status last changed.
private struct NowCard: View {
    let session: ProjectPage.Session
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PageMark(mark: session.mark, isOffScreen: session.isOffScreen, ground: WindowStyle.raise)
                Text(session.name)
                    .font(WindowStyle.ui(13, .semibold))
                    .spacing(-0.01, of: 13)
                    .foregroundStyle(WindowStyle.text)
                    .lineLimit(1)
            }
            .frame(height: 16)
            ForEach(Array(session.now.enumerated()), id: \.offset) { _, line in
                Text(line).font(WindowStyle.ui(13)).foregroundStyle(Ink.now).lineLimit(2)
            }
            if let next = session.next {
                Text("\(Text("next ").foregroundStyle(Ink.faint))\(next)")
                    .font(WindowStyle.ui(12))
                    .foregroundStyle(Ink.rest)
                    .lineLimit(2)
            }
            Text(Words.ago(session.updated, at: now))
                .font(WindowStyle.ui(11))
                .foregroundStyle(Ink.faint)
                .padding(.top, 2)
        }
        .opacity(Away.dimming(session.isAway))
        .padding(.top, 12)
        .padding(.horizontal, 14)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

            shape.fill(WindowStyle.raise).overlay(shape.strokeBorder(Ink.cardRing, lineWidth: 0.5))
        }
        .spoken(Spoken.nowCard(session, at: now))
    }
}

/// A session's newest log lines, under its card in Now, 22 tall each: its words, cut short, and how long ago. To
/// VoiceOver a group named for its session, each line one element.
private struct LogGroup: View {
    let session: ProjectPage.Session
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(session.log) { note in
                HStack(spacing: 8) {
                    Text(note.text)
                        .font(WindowStyle.ui(12))
                        .foregroundStyle(Ink.log)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Words.age(note.at, at: now))
                        .font(WindowStyle.ui(11))
                        .monospacedDigit()
                        .foregroundStyle(Ink.faint)
                        .frame(width: 28, alignment: .trailing)
                }
                .frame(height: 22)
                .spoken(Spoken.log(note, at: now))
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.name)
    }
}

/// A heading of the page, 13 semibold, and Waiting on you's count in orange after it, the one count that needs Lee;
/// to VoiceOver one heading, as "Waiting on you, 3".
private struct PageHeading: View {
    let name: String
    var count: Int?
    var under: CGFloat = 6

    var body: some View {
        HStack(spacing: 6) {
            Text(name).foregroundStyle(Ink.words)
            if let count {
                Text("\(count)").monospacedDigit().foregroundStyle(WindowStyle.orange)
            }
        }
        .font(WindowStyle.ui(13, .semibold))
        .spacing(-0.005, of: 13)
        .frame(height: 16)
        .padding(.bottom, under)
        .spoken(Spoken.heading(name, note: count.map(String.init)))
        .accessibilityAddTraits(.isHeader)
    }
}

/// A session's mark, with a pip on its corner where no terminal shows the session: white at 65% in a ring of what is
/// behind it, so it reads apart from the mark (the marks sheet's "Not on screen", a corner pip).
private struct PageMark: View {
    let mark: Mark
    let isOffScreen: Bool
    var ground = WindowStyle.black

    var body: some View {
        MarkView(mark: mark).overlay {
            if isOffScreen {
                Circle()
                    .fill(Ink.pip)
                    .frame(width: 5, height: 5)
                    .background(Circle().fill(ground).frame(width: 8, height: 8))
                    .offset(x: 3, y: 3)
            }
        }
    }
}

/// Now's cards and Log's groups: as many across as fit in the width (`ProjectPage.columns(across:)`), so the two
/// always agree and a session's log sits under its card; the columns as wide as each other, each row as tall as its
/// tallest, every cell given that height.
private struct PageGrid: Layout {
    private static let gap = CGFloat(ProjectPage.gridGap)

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = TitleRow.finite(proposal.width) ?? Self.widest
        let heights = rowHeights(width, subviews)

        return CGSize(width: width, height: heights.reduce(0, +) + Self.gap * CGFloat(max(heights.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let columns = Self.columns(bounds.width)
        let cell = Self.cell(bounds.width)
        var y = bounds.minY

        for (row, height) in rowHeights(bounds.width, subviews).enumerated() {
            for (column, index) in (row * columns ..< min((row + 1) * columns, subviews.count)).enumerated() {
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (cell + Self.gap), y: y),
                    proposal: ProposedViewSize(width: cell, height: height)
                )
            }
            y += height + Self.gap
        }
    }

    /// Each row's height: its tallest cell's, at the column's width.
    private func rowHeights(_ width: CGFloat, _ subviews: Subviews) -> [CGFloat] {
        let columns = Self.columns(width)
        let cell = ProposedViewSize(width: Self.cell(width), height: nil)

        return stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start ..< min(start + columns, subviews.count)].map { $0.sizeThatFits(cell).height }.max() ?? 0
        }
    }

    private static func columns(_ width: CGFloat) -> Int {
        ProjectPage.columns(across: Double(width))
    }

    private static func cell(_ width: CGFloat) -> CGFloat {
        let columns = CGFloat(columns(width))

        return (width - gap * (columns - 1)) / columns
    }

    /// With no width given: three across, each at its narrowest.
    private static var widest: CGFloat {
        CGFloat(ProjectPage.narrowestCard) * 3 + gap * 2
    }
}

/// The page's inks, as A3 revised draws them, in white over its black.
private enum Ink {
    /// A session's name, a line's words, a heading.
    static let words = Color.white.opacity(0.85)
    /// Where a session stands, a line's session, the header's counts, what comes next.
    static let rest = Color.white.opacity(0.45)
    static let age = Color.white.opacity(0.35)
    /// A card's now lines.
    static let now = Color.white.opacity(0.7)
    /// A log line.
    static let log = Color.white.opacity(0.6)
    /// "next", a card's time and a log line's.
    static let faint = Color.white.opacity(0.3)
    static let parked = Color.white.opacity(0.55)
    static let mark = Color.white.opacity(0.45)
    static let chevron = Color.white.opacity(0.3)
    static let rule = Color.white.opacity(0.08)
    static let cardRing = Color.white.opacity(0.05)
    static let pip = Color.white.opacity(0.65)
}
