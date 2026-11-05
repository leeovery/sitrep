import enum SitRepPanel.SnoozeTime
import enum SitRepPanel.WakeTime
import SitRepWindow
import SwiftUI

/// What the list beside the page shows, item by item, as its kind draws it: a row, Needs you's line or a session's in
/// Working or Your turn, with its menu, its words to VoiceOver and its actions; or the fold at the list's foot. Its
/// words are in the system's label colours and board D's whites, and on the accent of its pick in board D's whites;
/// its orange stays orange.
struct ListLine: View {
    let item: PlaceList.Item
    let place: Place
    /// The row the list picked, as it shows it: drawn picked as a still, and left to the system's selection live.
    let picked: ListPick?
    let filter: Filter
    let now: Date

    @Environment(\.wakeCalendar) private var calendar

    var body: some View {
        switch item {
        case let .row(row):
            ListRow(row: row, filter: filter, now: now)
                .modifier(RowContextMenu(row: row))
                .spoken(Spoken.row(row, at: now, in: calendar))
                .modifier(SpokenActions(row: row, now: now))
                .listRow(row.pick, isPicked: row.pick == picked, washed: row.washed, now: now)
        case let .fold(fold):
            FoldRow(fold: fold, place: place).listRow(ListPick?.none, isPicked: false, now: now)
        }
    }
}

/// A row as its place draws it, in the card's type: Needs you's line, its session over its words; Working's verb and
/// what it acts on over its project and session; Your turn's words on one line with its project. Under the pointer, a
/// row of a session a window holds gives its time's place to its button, which jumps there (`HoverJump`).
struct ListRow: View {
    let row: PlaceList.Row
    let filter: Filter
    let now: Date

    var body: some View {
        Group {
            switch row {
            case let .line(line): LineRowView(row: line, filter: filter, now: now)
            case let .session(session) where session.section == .working:
                WorkingRow(row: session, filter: filter, now: now)
            case let .session(session): TurnRow(row: session, filter: filter, now: now)
            }
        }
        .modifier(HoverJump(session: row.session, jumps: row.jumps))
    }
}

/// A line waiting on Lee in Needs you, an ask or a window's stop, a row of its own, as A1 revised draws it: 54 tall,
/// its words 10 from its top; its mark in the mark's slot; its session's name, medium in white at 85%, and its age, its
/// own, orange while it washes; under them its words, in white at 55%, a command in mono. While no window holds its
/// session, its mark is the away ring and its words dim as one (`Away`). On the accent of the pick its name goes white,
/// the rest white at 80%, away or not; its mark stays orange. An ask asleep, under "N snoozed", is the same row
/// quieted: its mark the clock, its name at 60%, its words at 35%, and in its age's place when it wakes, soft; a turn
/// asleep the same, its mark the faint ring, its words what Claude left Lee, and "until it moves" where it has no time.
struct LineRowView: View {
    let row: PlaceList.LineRow
    let filter: Filter
    let now: Date

    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.wakeCalendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: WindowStyle.lineGap) {
            HStack(alignment: .top, spacing: WindowStyle.slotGap) {
                RowMark(mark: row.mark)
                Name(row.session.name, litBy: filter, tone: row.isAsleep ? .quiet : .text, onPick: onPick)
                    .font(WindowStyle.ui(WindowStyle.titleSize, .medium))
                    .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: WindowStyle.titleLine, maxHeight: WindowStyle.titleLine, alignment: .leading)
                    .opacity(awayDim)
                RowTime(time, washed: row.line.washed, onPick: onPick)
                    .frame(height: WindowStyle.titleLine)
                    .opacity(awayDim)
            }
            HStack(spacing: WindowStyle.slotGap) {
                Color.clear.frame(width: WindowStyle.slot.width, height: WindowStyle.titleLine)
                LineWords(line: row.line, filter: filter, tone: row.isAsleep ? .dim : .soft, onPick: onPick, now: now)
                    .frame(maxWidth: .infinity, minHeight: WindowStyle.titleLine, maxHeight: WindowStyle.titleLine, alignment: .leading)
            }
            .opacity(awayDim)
        }
        .padding(.top, WindowStyle.lineTop)
        .frame(height: WindowStyle.lineHeight, alignment: .top)
    }

    /// Picked, on the accent: what its words and its soft words are drawn in.
    private var onPick: Bool { prominence == .increased }

    /// Its words, each dimmed by the one factor while no window holds its session, its time too, which would otherwise
    /// read brighter than its name; not asleep, quieted already, nor on the accent of the pick, whose whites are the
    /// system's.
    private var awayDim: Double {
        Away.dimming(row.session.isAway && !row.isAsleep && !onPick)
    }

    /// Its age, or asleep when it wakes, "until it moves" for a turn with no time.
    private var time: String {
        row.line.wakesAt.map { WakeTime.words($0, at: now, in: calendar) }
            ?? (row.isTurn ? WakeTime.untilItMoves : Words.age(row.line.since, at: now))
    }
}

/// A line's words on one line: its lead in its tone and weight, and 5 after it what it acts on in white at 35%, a
/// command in mono at 11, anything else, a wake's countdown among them, at 13. A working row's verb shimmers while it
/// works.
private struct LineWords: View {
    let line: Listed.Line
    let filter: Filter
    let tone: Tone
    var weight = Font.Weight.regular
    let onPick: Bool
    let now: Date
    var shimmers = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: WindowStyle.verbGap) {
            if shimmers {
                ShimmeringLead { isLit in lead(isLit: isLit) }
            } else {
                lead(isLit: false)
            }
            if let code = line.code {
                Name(code, litBy: filter, tone: .dim, onPick: onPick).font(WindowStyle.mono(WindowStyle.smallSize))
            } else if let subject = line.subject(at: now) {
                Name(subject, litBy: filter, tone: .dim, onPick: onPick)
                    .font(WindowStyle.ui(WindowStyle.titleSize))
                    .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
            }
        }
        .lineLimit(1)
    }

    /// Its lead in its tone, or lit by the shimmer's light.
    private func lead(isLit: Bool) -> some View {
        Name(line.lead, litBy: filter, tone: isLit ? .text : tone, onPick: onPick)
            .font(WindowStyle.ui(WindowStyle.titleSize, weight))
            .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
            .lineLimit(1)
    }
}

/// A session's row under Working, as board D draws it, two lines in the system's two-line row: its mark, the working
/// arc turning, or on its own work's dotted ring, still; its verb, medium in white at 55%, shimmering while it works,
/// as the panel's, and what it acts on 5 after it, a command in mono at 11, anything else at 13, both in white at 35%;
/// how long its turn has run, or since it ended; then its project and session. It needs nothing of Lee, so it is
/// greyer than the rest. On the accent of the pick its verb goes white, the rest white at 80%.
struct WorkingRow: View {
    let row: Listed.Row
    let filter: Filter
    let now: Date

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .top, spacing: WindowStyle.slotGap) {
                RowMark(mark: row.mark)
                row.lines.first.map { line in
                    LineWords(
                        line: line, filter: filter, tone: onPick ? .text : .soft, weight: .medium, onPick: onPick, now: now,
                        shimmers: row.mark == .working
                    )
                }
                .frame(maxWidth: .infinity, minHeight: WindowStyle.titleLine, maxHeight: WindowStyle.titleLine, alignment: .leading)
                RowTime(Words.age(row.since, at: now), washed: nil, onPick: onPick)
                    .frame(height: WindowStyle.titleLine)
            }
            SecondLine("\(row.project) · \(row.name)", filter: filter, onPick: onPick)
        }
        .padding(.top, WindowStyle.twoLineTop)
        .frame(height: WindowStyle.twoLineHeight, alignment: .top)
    }

    private var onPick: Bool { prominence == .increased }
}

/// A session's row under Your turn, on one line, 28 tall, as board D draws it: its open ring; what Claude left Lee, in
/// white at 85%, cut short; its project at its right, 11 in white at 35%, its own width, never cut; and how long since
/// its turn ended, in a 30 lane. On the accent of the pick its words go white, the rest white at 80%.
struct TurnRow: View {
    let row: Listed.Row
    let filter: Filter
    let now: Date

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            RowMark(mark: row.mark)
            Name(row.lines.first?.lead ?? row.name, litBy: filter, tone: .text, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Name(row.project, litBy: filter, tone: .dim, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.smallSize))
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, WindowStyle.turnProjectGap)
            RowTime(Words.age(row.since, at: now), washed: nil, onPick: onPick)
                .frame(width: WindowStyle.turnTimeLane, alignment: .trailing)
        }
        .frame(height: WindowStyle.oneLineHeight)
    }

    private var onPick: Bool { prominence == .increased }
}

/// A row's second line, under its first, from its words' edge: its project and its session, 11 in white at 55%.
private struct SecondLine: View {
    let words: String
    let filter: Filter
    let onPick: Bool

    init(_ words: String, filter: Filter, onPick: Bool) {
        self.words = words
        self.filter = filter
        self.onPick = onPick
    }

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Color.clear.frame(width: WindowStyle.slot.width, height: WindowStyle.smallLine)
            Name(words, litBy: filter, tone: .soft, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.smallSize))
                .lineLimit(1)
                .frame(height: WindowStyle.smallLine)
        }
    }
}

/// The fold at the list's foot, on one line, 28 tall, as board D draws "N earlier": its mark, Your turn's ring in
/// white at 25% or the snoozed clock; "8 earlier" or "2 snoozed", 13 in white at 55%; "N earlier"'s projects, each
/// once, 11 in white at 25%, cut short; and a chevron, right while it is folded, down while open. A click anywhere on
/// it opens its rows under it in place, or folds them, at once; the list never selects it.
struct FoldRow: View {
    let fold: PlaceList.Fold
    let place: Place

    @Environment(\.windowActions) private var act

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            mark.frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
            Text(fold.title)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(projects)
                .font(WindowStyle.ui(WindowStyle.smallSize))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.leading, WindowStyle.earlierProjectsGap)
                .frame(maxWidth: .infinity, alignment: .leading)
            Chevron(isFolded: !fold.isOpen)
                .foregroundStyle(.tertiary)
                .frame(width: WindowStyle.chevronSlot.width, height: WindowStyle.chevronSlot.height)
        }
        .padding(.trailing, -(WindowStyle.rowInset - WindowStyle.selectionInset - WindowStyle.headingTrailing))
        .frame(height: WindowStyle.oneLineHeight)
        .contentShape(Rectangle())
        .onTapGesture { act.toggleFold(place) }
        .spoken(Spoken.fold(fold))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { act.toggleFold(place) }
    }

    @ViewBuilder private var mark: some View {
        switch fold.kind {
        case .earlier: Circle().stroke(.tertiary, lineWidth: 1.5).frame(width: 7.5, height: 7.5)
        case .snoozed: SnoozedClock()
        }
    }

    private var projects: String {
        fold.kind == .earlier ? fold.earlier.projects.joined(separator: ", ") : ""
    }
}

/// A chevron as drawn: down while open, 10 by 6; right while folded, 6 by 10; its stroke 1.5, round.
struct Chevron: View {
    let isFolded: Bool

    var body: some View {
        Path { path in
            if isFolded {
                path.addLines([CGPoint(x: 1.2, y: 1.2), CGPoint(x: 4.8, y: 5), CGPoint(x: 1.2, y: 8.8)])
            } else {
                path.addLines([CGPoint(x: 1.2, y: 1.2), CGPoint(x: 5, y: 4.8), CGPoint(x: 8.8, y: 1.2)])
            }
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: isFolded ? 6 : 10, height: isFolded ? 10 : 6)
        .accessibilityHidden(true)
    }
}

/// An ask asleep's mark, a clock, faint and unlit, as A1 revised draws Snoozed.
private struct SnoozedClock: View {
    var body: some View {
        Image(systemName: "clock")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
    }
}

/// How long something has stood, or asleep when it wakes, in tabular figures: orange while its row washes, as what
/// needs Lee stays orange; else soft, or on the accent of its row's pick, white at 80%.
struct RowTime: View {
    let text: String
    let washed: Date?
    let onPick: Bool

    @Environment(\.showsJump) private var showsJump

    init(_ text: String, washed: Date?, onPick: Bool) {
        self.text = text
        self.washed = washed
        self.onPick = onPick
    }

    var body: some View {
        Text(text)
            .font(WindowStyle.ui(WindowStyle.ageSize).monospacedDigit())
            .foregroundStyle(ink)
            .opacity(showsJump ? 0 : 1)
    }

    private var ink: AnyShapeStyle {
        if washed != nil {
            return AnyShapeStyle(WindowStyle.orange)
        }
        return onPick ? AnyShapeStyle(WindowStyle.picked(.soft)) : AnyShapeStyle(.secondary)
    }
}

/// Under the pointer, a row of a session a window holds shows its button where its time was, which gives way to it: 22
/// square, on the row's middle, its right where the time's lane ends, as Paper's board F draws it. A click on the
/// button jumps to the session's window, and moves no pick and opens no page, which a click anywhere else on the row
/// does. An away row, which no window holds, shows none.
private struct HoverJump: ViewModifier {
    let session: String
    let jumps: Bool

    @Environment(\.isRowHovered) private var isRowHovered

    func body(content: Content) -> some View {
        let shows = isRowHovered && jumps

        content
            .environment(\.showsJump, shows)
            .overlay(alignment: .trailing) {
                if shows {
                    RowJump(session: session)
                }
            }
    }
}

/// A row's button that jumps to its session's window: white at 10%, its corners 6, its arrow in white at 80%.
private struct RowJump: View {
    let session: String

    @Environment(\.windowActions) private var act

    var body: some View {
        Button { act.jump(.row(session)) } label: {
            JumpArrow()
                .stroke(WindowStyle.jumpGlyph, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: JumpArrow.side, height: JumpArrow.side)
                .frame(width: WindowStyle.jumpSide, height: WindowStyle.jumpSide)
                .background(WindowStyle.jumpFill, in: RoundedRectangle(cornerRadius: WindowStyle.jumpRadius))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// To VoiceOver, which reads the row as one element and never hovers it, a row of a session a window holds offers its
/// button as an action, "Jump to the window", which jumps as the button does, moving no pick; an ask or a turn asleep,
/// its menu's Wake now; an ask waiting, its menu's three snoozes (`Spoken.snooze`), each for that one ask; a Your turn
/// row, those and until it moves, for its turn.
private struct SpokenActions: ViewModifier {
    let row: PlaceList.Row
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.wakeCalendar) private var calendar

    func body(content: Content) -> some View {
        content.accessibilityActions {
            if let jump = Spoken.jump(row) {
                Button(jump) { act.jump(.row(row.session)) }
            }
            if let snoozable = row.snoozable {
                if let wake = Spoken.wake(row) {
                    Button(wake) { act.wakeRow(row.session, snoozable) }
                }
                ForEach(SnoozeTime.offered(forTurn: snoozable.isTurn), id: \.self) { time in
                    if let snooze = Spoken.snooze(time, of: row, at: now, in: calendar) {
                        Button(snooze) { act.snoozeRow(row.session, snoozable, time) }
                    }
                }
            }
        }
    }
}

/// A row's right-click, or Control-click: its menu (`RowMenu`), as the card's row's but for Open in SitRep, which the
/// row is already: Jump to the window; on a line that is an ask, Snooze for that one ask, on a Your turn row Snooze and
/// Until it moves for its turn, or asleep, Wake now; never its session's other asks, which have rows of their own. A
/// still has none: the menu's area is an AppKit view, which a still draws as a placeholder.
private struct RowContextMenu: ViewModifier {
    let row: PlaceList.Row

    @Environment(\.windowActions) private var act
    @Environment(\.wakeCalendar) private var calendar
    @Environment(\.isStill) private var isStill

    func body(content: Content) -> some View {
        content.overlay {
            if !isStill {
                menuArea
            }
        }
    }

    private var menuArea: some View {
        ContextMenuArea { [row, act, calendar] in
            RowMenu.make(
                for: RowMenu.Row(row), at: Date(), in: calendar,
                RowMenu.Actions(
                    jump: { act.jump(.row(row.session)) },
                    snooze: { act.snoozeRow(row.session, $0, $1) },
                    wake: { act.wakeRow(row.session, $0) }
                )
            )
        }
    }
}

private extension PlaceList.Row {
    /// The line it is, in Needs you or under "N snoozed"; none for a session's row.
    var line: PlaceList.LineRow? {
        if case let .line(line) = self {
            return line
        }
        return nil
    }

    /// When its line, new on the board, began to wash, while it does: the row and its age wash with it.
    var washed: Date? { line?.line.washed }
}

/// The arrow on a row's button, board F's, 11 square: up and to the right, its head a corner from 3.5 across to 9.5
/// and down to 7.5, its shaft from 9.2, 1.8 to 1.8, 9.2.
private struct JumpArrow: Shape {
    static let side: CGFloat = 11

    func path(in _: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 3.5, y: 1.5))
            path.addLine(to: CGPoint(x: 9.5, y: 1.5))
            path.addLine(to: CGPoint(x: 9.5, y: 7.5))
            path.move(to: CGPoint(x: 9.2, y: 1.8))
            path.addLine(to: CGPoint(x: 1.8, y: 9.2))
        }
    }
}

extension EnvironmentValues {
    /// The pointer is over the row, or it is drawn as a still with the pointer over every row.
    @Entry var isRowHovered = false
    /// The row's button shows where its time was.
    @Entry var showsJump = false
}

/// A session's mark in its slot, shared by the sidebar and the list: needs you an orange dot, and away a hollow orange
/// ring; your turn a soft ring; working the arc turning on its faint track; on its own work the dotted ring, still;
/// away with nothing waiting a faint dot; an ask asleep the clock, faint and unlit; a turn asleep your turn's ring,
/// faint, as on the card (board I).
struct RowMark: View {
    let mark: Mark

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Group {
            switch mark {
            case .needs: Circle().fill(WindowStyle.orange).frame(width: 7, height: 7)
            case .awayAsk: AwayRing(ink: WindowStyle.orange)
            case .turn: Circle().stroke(.secondary, lineWidth: 1.5).frame(width: 7.5, height: 7.5)
            case .working:
                TurningArc(
                    radius: 4.25,
                    track: WindowStyle.colour(
                        WindowStyle.sidebarTrack, on: prominence, selected: WindowStyle.selectedTrack
                    ),
                    arc: WindowStyle.colour(WindowStyle.sidebarArc, on: prominence)
                )
            case .onItsWork: DottedRingView(ring: .sidebar, ink: WindowStyle.sidebarDotted)
            case .away: Circle().fill(.tertiary).frame(width: 5, height: 5)
            case .snoozed: SnoozedClock()
            case .snoozedTurn: Circle().stroke(.tertiary, lineWidth: 1.5).frame(width: 7.5, height: 7.5)
            }
        }
        .frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
        .spoken(Spoken.mark(mark))
    }
}

/// A name in its tone; while the filter narrows the list, its words lit where they appear in it, a step brighter than
/// the rest (`Tone`), in the sidebar's greys, or on the accent of its row's pick in its whites.
struct Name: View {
    let name: String
    let filter: Filter
    let tone: Tone
    let onPick: Bool

    init(_ name: String, litBy filter: Filter, tone: Tone, onPick: Bool = false) {
        self.name = name
        self.filter = filter
        self.tone = tone
        self.onPick = onPick
    }

    var body: some View {
        if filter.isEmpty {
            Text(name).foregroundStyle(ink(tone))
        } else {
            filter.runs(of: name).reduce(Text("")) { text, run in
                Text("\(text)\(Text(run.text).foregroundStyle(ink(run.isLit ? tone.lit : tone.rest)))")
            }
        }
    }

    private func ink(_ tone: Tone) -> AnyShapeStyle {
        onPick ? AnyShapeStyle(WindowStyle.picked(tone)) : WindowStyle.label(tone)
    }
}

extension View {
    /// A row of a list in the sidebar's style, the sidebar's or the one beside the page: one tagged with what it picks,
    /// the one picked while `isPicked`, washed orange from `washed` as it comes; or with no tag, a fold or a heading,
    /// which the list never selects. Its tag is the list's selection's own type, so no row can carry one it ignores.
    func listRow<Tag: Hashable>(_ tag: Tag?, isPicked: Bool, washed: Date? = nil, now: Date) -> some View {
        modifier(ListRowCell(tag: tag, isPicked: isPicked, washed: washed, now: now))
    }

    /// A line of a list in the sidebar's style, its height its own, its words 16 in from the column's edges, as the
    /// list sets them, and as a still sets them too; `background` across the whole row.
    func listCell(@ViewBuilder background: () -> some View = { EmptyView() }) -> some View {
        modifier(ListCell(background: background()))
    }
}

private struct ListCell<Background: View>: ViewModifier {
    let background: Background

    @Environment(\.isStill) private var isStill

    func body(content: Content) -> some View {
        if isStill {
            content.padding(.horizontal, WindowStyle.rowInset).background(background)
        } else {
            content.listRowInsets(EdgeInsets()).listRowBackground(background)
        }
    }
}

/// A row of a list, tagged with what it picks, or, with nothing to pick, never selected. Its background fills the
/// whole row, so the pointer is over it anywhere on the row: under the pointer, and not the one picked, it shows a
/// quiet fill, and as it comes, its wash, both shaped as the system's selection, which they leave alone. Drawn as a
/// still, picked, the selection's stand-in.
private struct ListRowCell<Tag: Hashable>: ViewModifier {
    let tag: Tag?
    let isPicked: Bool
    let washed: Date?
    let now: Date

    @Environment(\.isStill) private var isStill
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isOverWords = false
    @State private var isOverRow = false

    func body(content: Content) -> some View {
        let row = content
            .environment(\.isRowHovered, isHovered)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isOverWords = $0 }
            .listCell {
                RowBackground(fill: fill, washed: washed, now: now, isOver: $isOverRow)
            }

        if let tag {
            row.tag(tag)
        } else {
            row.selectionDisabled()
        }
    }

    private var isHovered: Bool { isOverWords || isOverRow || isHoveredStill }

    private var fill: Color? {
        WindowStyle.sidebarFill(
            Highlight.of(isPicked: isPicked, isPressed: false, isHovered: isHovered), isStill: isStill
        )
    }
}

/// What a row draws behind its words, across the whole row: its wash as it comes, and the pointer's fill, each inset
/// and rounded as the system's selection is. It hears the pointer over the row's edges, where its words are not.
private struct RowBackground: View {
    let fill: Color?
    let washed: Date?
    let now: Date
    @Binding var isOver: Bool

    var body: some View {
        ZStack {
            WashFill(since: washed, now: now, radius: WindowStyle.rowRadius)
            if let fill {
                RoundedRectangle(cornerRadius: WindowStyle.rowRadius, style: .continuous).fill(fill)
            }
        }
        .padding(.horizontal, WindowStyle.selectionInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { isOver = $0 }
    }
}
