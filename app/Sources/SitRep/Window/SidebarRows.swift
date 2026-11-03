import struct SitRepPanel.Earlier
import enum SitRepPanel.SnoozeChoice
import enum SitRepPanel.WakeTime
import SitRepWindow
import SwiftUI

/// A line of the sidebar's list as its kind draws it: a heading that folds, a session's row as its section draws it,
/// Your turn's "N earlier", and a project's row. Its words are in the system's label colours and board D's whites, and
/// on the accent of its pick in board D's whites; its orange stays orange.
struct SidebarLine: View {
    let line: Sidebar.Line
    /// The heading after Needs you, which the rule after it sits over (`Sidebar.ruled`).
    let isRuled: Bool
    let picked: PickedRow?
    let filter: Filter
    let now: Date

    @Environment(\.wakeCalendar) private var calendar

    var body: some View {
        switch line {
        case let .heading(heading):
            FoldHeading(heading: heading, isRuled: isRuled)
        case let .session(row):
            SidebarSessionRow(row: row, filter: filter, now: now)
                .modifier(RowContextMenu(row: row))
                .spoken(Spoken.row(row, at: now, in: calendar))
                .modifier(SpokenActions(row: row, now: now))
                .sidebarRow(row.pick, picked: picked, washed: row.washed, now: now)
        case let .earlier(earlier):
            EarlierRow(earlier: earlier).sidebarRow(nil, picked: picked, now: now)
        case let .project(project):
            ProjectRow(project: project, filter: filter)
                .spoken(Spoken.project(project))
                .sidebarRow(project.pick, picked: picked, now: now)
        }
    }
}

/// The row showing the pick (`Sidebar.row(showing:)`), drawn picked: the list's selection, which the system draws; or
/// a project's row standing in for a session with no row of its own, which the list does not select, so SitRep draws
/// the selection on it as the system would, emphasized while the list has focus in the key window.
enum PickedRow: Equatable {
    case selected(Pick)
    case standIn(Pick, isEmphasized: Bool)

    var pick: Pick {
        switch self {
        case let .selected(pick), let .standIn(pick, _): pick
        }
    }
}

/// A section's heading, or Projects': its name, its count 6 after it, in orange for Needs you and white at 30% for the
/// others, and a chevron saying which way it is, faint, a step brighter under the pointer. A click anywhere on it folds
/// or unfolds what is under it, at once, and never moves the pick; the list never selects it. The heading after Needs
/// you carries the rule after it, 11.5 under Needs you's last row and 10 over its own words, drawn behind the row so
/// the list adds no line of its own, whose insets a live window could move; the pointer, a click and VoiceOver know
/// only the heading's 24.
struct FoldHeading: View {
    let heading: Sidebar.Heading
    let isRuled: Bool

    @Environment(\.windowActions) private var act
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Text(heading.title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(heading.count)")
                .monospacedDigit()
                .foregroundStyle(countInk)
                .padding(.leading, WindowStyle.countGap)
            Spacer(minLength: 0)
            Chevron(isFolded: heading.isFolded)
                .foregroundStyle(isHovered || isHoveredStill ? .secondary : .tertiary)
                .frame(width: WindowStyle.chevronSlot.width, height: WindowStyle.chevronSlot.height)
        }
        .font(WindowStyle.ui(WindowStyle.smallSize, .semibold))
        .padding(.trailing, -(WindowStyle.rowInset - WindowStyle.selectionInset - WindowStyle.headingTrailing))
        .frame(height: WindowStyle.headingHeight)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { act.fold(heading.fold) }
        .spoken(Spoken.heading(heading))
        .accessibilityAddTraits([.isHeader, .isButton])
        .accessibilityAction { act.fold(heading.fold) }
        .padding(.top, gap)
        .selectionDisabled()
        .sidebarCell {
            if isRuled {
                SidebarRule()
                    .padding(.top, WindowStyle.ruleGap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// What is over its words: 10, or after Needs you its rule, 11.5 under the rows before it, and 10 more.
    private var gap: CGFloat {
        isRuled ? WindowStyle.ruleGap + WindowStyle.rule + WindowStyle.headingGap : WindowStyle.headingGap
    }

    /// Its count in orange for Needs you, in board H's white at 35% for Snoozed, else white at 30%.
    private var countInk: Color {
        switch heading.fold {
        case .section(.needsYou): WindowStyle.orange
        case .section(.snoozed): WindowStyle.dim
        default: WindowStyle.count
        }
    }
}

/// The sidebar's rule: 0.5 in the separator's colour, inside the sidebar's 10 either side; nothing to VoiceOver.
struct SidebarRule: View {
    var body: some View {
        Rectangle()
            .fill(WindowStyle.separator)
            .frame(height: WindowStyle.rule)
            .padding(.horizontal, WindowStyle.selectionInset)
            .accessibilityHidden(true)
    }
}

/// A fill shaped as the system's selection: rounded, and in from the sidebar's edges.
struct SelectionShaped: View {
    let fill: Color
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .padding(.horizontal, WindowStyle.selectionInset)
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

/// A session's row as its section draws it, in the card's type: Needs you's session over its project, and Snoozed's
/// quieted; Working's verb and what it acts on over its project and session; Your turn's words on one line with its
/// project. Under the pointer, a row a window holds gives its time's place to its button, which jumps there
/// (`HoverJump`).
struct SidebarSessionRow: View {
    let row: Listed.Row
    let filter: Filter
    let now: Date

    var body: some View {
        Group {
            switch row.section {
            case .needsYou, .snoozed: NeedsYouRow(row: row, filter: filter, now: now)
            case .working: WorkingRow(row: row, filter: filter, now: now)
            case .yourTurn: TurnRow(row: row, filter: filter, now: now)
            }
        }
        .modifier(HoverJump(row: row))
    }
}

/// A session's row under Needs you, as Paper's board F draws it, in the system's two-line row: its dot in the mark's
/// slot; its session's name, medium, and a quiet "+2" 5 after it for its lines waiting after the first, none for one;
/// its age, its oldest line's, orange while a new line washes the row; then its project, 1 under. The asks are read on
/// its page. While no window holds it, its mark is the away ring and its words dim as one (`Away`). On the accent
/// of the pick its name goes white, the rest white at 80%, away or not; its mark stays orange. A row in Snoozed is the
/// same row quieted, as Paper's board H draws it: its dot faint and unlit, its name at 60%, its "+2" and its project at
/// 35%, and in its age's place when its soonest ask wakes, soft.
struct NeedsYouRow: View {
    let row: Listed.Row
    let filter: Filter
    let now: Date

    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.wakeCalendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .top, spacing: WindowStyle.slotGap) {
                SidebarMark(mark: row.mark)
                title
                    .frame(maxWidth: .infinity, minHeight: WindowStyle.titleLine, maxHeight: WindowStyle.titleLine, alignment: .leading)
                    .opacity(awayDim)
                SidebarTime(time, washed: row.lineWashed, onPick: onPick)
                    .frame(height: WindowStyle.titleLine)
                    .opacity(awayDim)
            }
            SecondLine(row.project, filter: filter, tone: isSnoozed ? .dim : .soft, onPick: onPick)
                .opacity(awayDim)
        }
        .padding(.top, WindowStyle.twoLineTop)
        .frame(height: WindowStyle.twoLineHeight, alignment: .top)
    }

    /// Picked, on the accent: what its words and its soft words are drawn in.
    private var onPick: Bool { prominence == .increased }

    private var isSnoozed: Bool { row.section == .snoozed }

    /// Its words, each dimmed by the one factor while no window holds it, its time too, which would otherwise read
    /// brighter than its name; not in Snoozed, quieted already, nor on the accent of the pick, whose whites are the
    /// system's.
    private var awayDim: Double {
        Away.dimming(row.isAway && !isSnoozed && !onPick)
    }

    /// Its oldest line's age, or in Snoozed when its soonest ask wakes.
    private var time: String {
        row.wakesAt.map { WakeTime.words($0, at: now, in: calendar) } ?? Words.age(row.since, at: now)
    }

    /// Its session's name, cut short before its "+2", in tabular figures on the name's baseline.
    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: WindowStyle.moreGap) {
            Name(row.name, litBy: filter, tone: isSnoozed ? .quiet : .text, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.titleSize, .medium))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
            if let more = row.more {
                Name(more, litBy: filter, tone: isSnoozed ? .dim : .soft, onPick: onPick)
                    .font(WindowStyle.ui(WindowStyle.moreSize, .medium).monospacedDigit())
                    .fixedSize()
            }
        }
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
                SidebarMark(mark: row.mark)
                row.lines.first.map(doing)
                    .frame(maxWidth: .infinity, minHeight: WindowStyle.titleLine, maxHeight: WindowStyle.titleLine, alignment: .leading)
                SidebarTime(Words.age(row.since, at: now), washed: nil, onPick: onPick)
                    .frame(height: WindowStyle.titleLine)
            }
            SecondLine("\(row.project) · \(row.name)", filter: filter, onPick: onPick)
        }
        .padding(.top, WindowStyle.twoLineTop)
        .frame(height: WindowStyle.twoLineHeight, alignment: .top)
    }

    private var onPick: Bool { prominence == .increased }

    /// Its verb, and what it acts on at this time: a command or a path in mono, a wake's countdown or anything else
    /// plain.
    private func doing(_ line: Listed.Line) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: WindowStyle.verbGap) {
            if row.mark == .working {
                ShimmeringLead { isLit in verb(line, isLit: isLit) }
            } else {
                verb(line, isLit: false)
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

    /// Its verb, soft, or lit by the shimmer's light; white on the accent of the pick.
    private func verb(_ line: Listed.Line, isLit: Bool) -> some View {
        Name(line.lead, litBy: filter, tone: isLit || onPick ? .text : .soft, onPick: onPick)
            .font(WindowStyle.ui(WindowStyle.titleSize, .medium))
            .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
            .lineLimit(1)
    }
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
            SidebarMark(mark: row.mark)
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
            SidebarTime(Words.age(row.since, at: now), washed: nil, onPick: onPick)
                .frame(width: WindowStyle.turnTimeLane, alignment: .trailing)
        }
        .frame(height: WindowStyle.oneLineHeight)
    }

    private var onPick: Bool { prominence == .increased }
}

/// A row's second line, under its first, from its words' edge: its project, and on Working its session, 11 in white at
/// 55%, or in Snoozed at 35%.
private struct SecondLine: View {
    let words: String
    let filter: Filter
    let tone: Tone
    let onPick: Bool

    init(_ words: String, filter: Filter, tone: Tone = .soft, onPick: Bool) {
        self.words = words
        self.filter = filter
        self.tone = tone
        self.onPick = onPick
    }

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Color.clear.frame(width: WindowStyle.slot.width, height: WindowStyle.smallLine)
            Name(words, litBy: filter, tone: tone, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.smallSize))
                .lineLimit(1)
                .frame(height: WindowStyle.smallLine)
        }
    }
}

/// Your turn's "N earlier", as board D draws it, on one line, 28 tall: its ring in white at 25%; "8 earlier", 13 in
/// white at 55%; its sessions' projects, each once, 11 in white at 25%, cut short; and a chevron, right while it is
/// folded, down while open. A click anywhere on it opens the sessions under it in place, or folds them, at once; the
/// list never selects it.
struct EarlierRow: View {
    let earlier: Earlier

    @Environment(\.windowActions) private var act

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Circle().stroke(.tertiary, lineWidth: 1.5).frame(width: 7.5, height: 7.5)
                .frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
            Text(earlier.title)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(earlier.projects.joined(separator: ", "))
                .font(WindowStyle.ui(WindowStyle.smallSize))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.leading, WindowStyle.earlierProjectsGap)
                .frame(maxWidth: .infinity, alignment: .leading)
            Chevron(isFolded: !earlier.isOpen)
                .foregroundStyle(.tertiary)
                .frame(width: WindowStyle.chevronSlot.width, height: WindowStyle.chevronSlot.height)
        }
        .padding(.trailing, -(WindowStyle.rowInset - WindowStyle.selectionInset - WindowStyle.headingTrailing))
        .frame(height: WindowStyle.oneLineHeight)
        .contentShape(Rectangle())
        .onTapGesture { act.fold(.earlier) }
        .spoken(Spoken.earlier(earlier))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { act.fold(.earlier) }
    }
}

/// A project's row under Projects, which opens its page: its name, under the heading's words, on one line, 28 tall.
private struct ProjectRow: View {
    let project: Listed.Project
    let filter: Filter

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: 0) {
            Name(project.name, litBy: filter, tone: .text, onPick: prominence == .increased)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: WindowStyle.oneLineHeight)
    }
}

/// How long something has stood, or in Snoozed when it wakes, in tabular figures: orange while its row washes, as what
/// needs Lee stays orange; else soft, or on the accent of its row's pick, white at 80%.
private struct SidebarTime: View {
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

/// Under the pointer, a row a window holds shows its button where its time was, which gives way to it: 22 square, on
/// the row's middle, its right where the time's lane ends, as Paper's board F draws it. A click on the button jumps to
/// the session's window, and moves no pick and opens no page, which a click anywhere else on the row does. An away
/// row, which no window holds, shows none.
private struct HoverJump: ViewModifier {
    let row: Listed.Row

    @Environment(\.isRowHovered) private var isRowHovered

    func body(content: Content) -> some View {
        let shows = isRowHovered && row.jumps

        content
            .environment(\.showsJump, shows)
            .overlay(alignment: .trailing) {
                if shows {
                    SidebarJump(session: row.id)
                }
            }
    }
}

/// A sidebar row's button that jumps to its session's window: white at 10%, its corners 6, its arrow in white at 80%.
private struct SidebarJump: View {
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

/// To VoiceOver, which reads the row as one element and never hovers it, a row a window holds offers its button as
/// an action, "Jump to the window", which jumps as the button does, moving no pick; a row in Snoozed, its menu's Wake
/// now; and any other whose lines hold asks, its menu's three snoozes (`Spoken.snooze`).
private struct SpokenActions: ViewModifier {
    let row: Listed.Row
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.wakeCalendar) private var calendar

    func body(content: Content) -> some View {
        content.accessibilityActions {
            if let jump = Spoken.jump(row) {
                Button(jump) { act.jump(.row(row.id)) }
            }
            if let wake = Spoken.wake(row) {
                Button(wake) { act.wakeRow(row) }
            }
            ForEach(SnoozeChoice.allCases, id: \.self) { choice in
                if let snooze = Spoken.snooze(choice, of: row, at: now, in: calendar) {
                    Button(snooze) { act.snoozeRow(row, choice) }
                }
            }
        }
    }
}

/// A session's row's right-click, or Control-click: its menu (`RowMenu`), as the card's row's but for Open in SitRep,
/// which the row is already: Jump to the window, and Snooze on a row whose lines hold asks, or Wake now in Snoozed, for
/// the asks the row shows.
private struct RowContextMenu: ViewModifier {
    let row: Listed.Row

    @Environment(\.windowActions) private var act
    @Environment(\.wakeCalendar) private var calendar

    func body(content: Content) -> some View {
        content.overlay {
            ContextMenuArea { [row, act, calendar] in
                RowMenu.make(
                    for: RowMenu.Row(jumps: row.jumps, asks: row.asks, isSnoozed: row.section == .snoozed),
                    at: Date(), in: calendar,
                    RowMenu.Actions(
                        jump: { act.jump(.row(row.id)) }, snooze: { act.snoozeRow(row, $0) }, wake: { act.wakeRow(row) }
                    )
                )
            }
        }
    }
}

/// The arrow on a sidebar row's button, board F's, 11 square: up and to the right, its head a corner from 3.5 across
/// to 9.5 and down to 7.5, its shaft from 9.2, 1.8 to 1.8, 9.2.
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
    /// The pointer is over the sidebar row, or it is drawn as a still with the pointer over every row.
    @Entry var isRowHovered = false
    /// The row's button shows where its time was.
    @Entry var showsJump = false
}

/// A session's mark in its slot: needs you an orange dot, and away a hollow orange ring; your turn a soft ring; working
/// the arc turning on its faint track; on its own work the dotted ring, still; away with nothing waiting a faint dot;
/// in Snoozed a faint dot, a needs-you dot's size, unlit.
struct SidebarMark: View {
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
            case .snoozed: Circle().fill(.tertiary).frame(width: 7, height: 7)
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
    /// A row of the sidebar's list: one that shows `pick`, the one picked while it is `picked`'s, washed orange from
    /// `washed` as it comes; or with no pick, "N earlier", which the list never selects. Its tag is the list's
    /// selection's own type, so no row can carry one it ignores.
    func sidebarRow(_ pick: Pick?, picked: PickedRow?, washed: Date? = nil, now: Date) -> some View {
        let isPicked = pick != nil && pick == picked?.pick

        return modifier(SidebarRow(pick: pick, picked: isPicked ? picked : nil, washed: washed, now: now))
    }

    /// A line of the sidebar's list, its height its own, its words 16 in from the sidebar's edges, as the list sets
    /// them, and as a still sets them too; `background` across the whole row.
    func sidebarCell(@ViewBuilder background: () -> some View = { EmptyView() }) -> some View {
        modifier(SidebarCell(background: background()))
    }
}

private struct SidebarCell<Background: View>: ViewModifier {
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

/// A row of the sidebar's list, tagged with what it picks, or, with nothing to pick, never selected. Its background
/// fills the whole row, so the pointer is over it anywhere on the row: under the pointer, and not the one picked, it
/// shows a quiet fill, and as it comes, its wash, both shaped as the system's selection, which they leave alone. Drawn
/// as a still, the selection's stand-in; standing in for a session with no row, the selection SitRep draws, its words
/// as on the system's.
private struct SidebarRow: ViewModifier {
    let pick: Pick?
    /// Set on the row picked alone.
    let picked: PickedRow?
    let washed: Date?
    let now: Date

    @Environment(\.isStill) private var isStill
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isOverWords = false
    @State private var isOverRow = false

    func body(content: Content) -> some View {
        let row = content
            .environment(\.isRowHovered, isHovered)
            .transformEnvironment(\.backgroundProminence) { prominence in
                if case .standIn(_, isEmphasized: true) = picked {
                    prominence = .increased
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isOverWords = $0 }
            .sidebarCell {
                RowBackground(fill: fill, washed: washed, now: now, isOver: $isOverRow)
            }

        if let pick {
            row.tag(pick)
        } else {
            row.selectionDisabled()
        }
    }

    private var isHovered: Bool { isOverWords || isOverRow || isHoveredStill }

    private var fill: Color? {
        if case let .standIn(_, isEmphasized) = picked {
            return WindowStyle.selection(isEmphasized: isEmphasized, isStill: isStill)
        }

        return WindowStyle.sidebarFill(
            Highlight.of(isPicked: picked != nil, isPressed: false, isHovered: isHovered), isStill: isStill
        )
    }
}

/// What a sidebar row draws behind its words, across the whole row: its wash as it comes, and the pointer's fill,
/// each inset and rounded as the system's selection is. It hears the pointer over the row's edges, where its words
/// are not.
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
