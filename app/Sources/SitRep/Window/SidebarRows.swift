import struct SitRepPanel.Earlier
import SitRepWindow
import SwiftUI

/// A line of the sidebar's list as its kind draws it: a heading that folds, a session's row as its section draws it,
/// Your turn's "N earlier", and a project's row. Its words are in the system's label colours and board D's whites, and
/// on the accent of its pick in board D's whites; its orange stays orange.
struct SidebarLine: View {
    let line: Sidebar.Line
    /// The heading after Needs you, which the rule after it sits over (`Sidebar.ruled`).
    let isRuled: Bool
    let pick: Pick?
    let filter: Filter
    let now: Date

    var body: some View {
        switch line {
        case let .heading(heading):
            FoldHeading(heading: heading, isRuled: isRuled)
        case let .session(row):
            SidebarSessionRow(row: row, filter: filter, now: now)
                .spoken(Spoken.row(row, at: now))
                .sidebarRow(row.pick, picked: pick, washed: row.washed, now: now)
        case let .earlier(earlier):
            EarlierRow(earlier: earlier).sidebarRow(nil, picked: pick, now: now)
        case let .project(project):
            ProjectRow(project: project, filter: filter)
                .spoken(Spoken.project(project))
                .sidebarRow(project.pick, picked: pick, now: now)
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
                .foregroundStyle(heading.isNeedsYou ? WindowStyle.orange : WindowStyle.count)
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

/// A session's row as its section draws it, in the card's type: Needs you's lines over its project and session;
/// Working's verb and what it acts on over them; Your turn's words on one line with its project.
struct SidebarSessionRow: View {
    let row: Listed.Row
    let filter: Filter
    let now: Date

    var body: some View {
        switch row.section {
        case .needsYou: NeedsYouRow(row: row, filter: filter, now: now)
        case .working: WorkingRow(row: row, filter: filter, now: now)
        case .yourTurn: TurnRow(row: row, filter: filter, now: now)
        }
    }
}

/// A session's row under Needs you, one shape however many lines it has, as board D draws it: each ask or stop
/// waiting on Lee a line of its own, its dot in the mark's slot, its words medium and its age, 3 apart; then its
/// project and session, 1 under them. One line is the system's two-line row, 39 tall, as built; each line more adds
/// its 16 and the 3 over it. A new line's age is orange while the row washes, so the new one shows among the rest. On
/// the accent of the pick its words go white, its second line and its ages white at 80%; its dots stay orange.
struct NeedsYouRow: View {
    let row: Listed.Row
    let filter: Filter
    let now: Date

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            VStack(alignment: .leading, spacing: WindowStyle.waitingGap) {
                ForEach(row.lines) { line in
                    HStack(alignment: .top, spacing: WindowStyle.slotGap) {
                        SidebarMark(mark: .needs)
                        words(line)
                            .frame(maxWidth: .infinity, minHeight: WindowStyle.titleLine, maxHeight: WindowStyle.titleLine, alignment: .leading)
                        SidebarAge(since: line.since, washed: line.washed, now: now, onPick: onPick)
                            .frame(height: WindowStyle.titleLine)
                    }
                }
            }
            SecondLine(row: row, filter: filter, onPick: onPick)
        }
        .padding(.top, WindowStyle.twoLineTop)
        .frame(height: WindowStyle.needsYouHeight(lines: row.lines.count), alignment: .top)
    }

    /// Picked, on the accent: what its words and its soft words are drawn in.
    private var onPick: Bool { prominence == .increased }

    /// A line's words: its lead, medium, dim while no window holds its session, then a command or a path in mono, and a
    /// question's "+2".
    private func words(_ line: Listed.Line) -> some View {
        let lead = Name(line.lead, litBy: filter, tone: row.isAway ? .faint : .text, onPick: onPick)
            .font(WindowStyle.ui(WindowStyle.titleSize, .medium))
            .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)

        return HStack(spacing: WindowStyle.slotGap) {
            lead
            if let code = line.code {
                Name(code, litBy: filter, tone: .soft, onPick: onPick).font(WindowStyle.mono(WindowStyle.smallSize))
            }
            if let more = line.more {
                Name(more, litBy: filter, tone: .soft, onPick: onPick)
                    .font(WindowStyle.ui(WindowStyle.titleSize, .medium))
                    .fixedSize()
            }
        }
        .lineLimit(1)
    }
}

/// A session's row under Working, as board D draws it, two lines in the system's two-line row: its mark, the working
/// arc or on its own work's dotted ring, still; its verb, medium in white at 55%, and what it acts on 5 after it, a
/// command in mono at 11, anything else at 13, both in white at 35%; how long its turn has run, or since it ended; then
/// its project and session. It needs nothing of Lee, so it is greyer than the rest. On the accent of the pick its verb
/// goes white, the rest white at 80%.
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
                SidebarAge(since: row.since, washed: nil, now: now, onPick: onPick)
                    .frame(height: WindowStyle.titleLine)
            }
            SecondLine(row: row, filter: filter, onPick: onPick)
        }
        .padding(.top, WindowStyle.twoLineTop)
        .frame(height: WindowStyle.twoLineHeight, alignment: .top)
    }

    private var onPick: Bool { prominence == .increased }

    /// Its verb, and what it acts on at this time: a command or a path in mono, a wake's countdown or anything else
    /// plain.
    private func doing(_ line: Listed.Line) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: WindowStyle.verbGap) {
            Name(line.lead, litBy: filter, tone: onPick ? .text : .soft, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.titleSize, .medium))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
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
            SidebarAge(since: row.since, washed: nil, now: now, onPick: onPick)
                .frame(width: WindowStyle.turnTimeLane, alignment: .trailing)
        }
        .frame(height: WindowStyle.oneLineHeight)
    }

    private var onPick: Bool { prominence == .increased }
}

/// A row's second line, under its first, from its words' edge: its project and its session, 11 in white at 55%.
private struct SecondLine: View {
    let row: Listed.Row
    let filter: Filter
    let onPick: Bool

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Color.clear.frame(width: WindowStyle.slot.width, height: WindowStyle.smallLine)
            Name("\(row.project) · \(row.name)", litBy: filter, tone: .soft, onPick: onPick)
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

/// A project's row under Projects, which opens its page: its name, after an empty slot, on one line, 28 tall.
private struct ProjectRow: View {
    let project: Listed.Project
    let filter: Filter

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Color.clear.frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
            Name(project.name, litBy: filter, tone: .text, onPick: prominence == .increased)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .lineLimit(1)
        }
        .frame(height: WindowStyle.oneLineHeight)
    }
}

/// How long something has stood, in tabular figures: orange while its row washes, as what needs Lee stays orange; else
/// soft, or on the accent of its row's pick, white at 80%.
private struct SidebarAge: View {
    let since: Date
    let washed: Date?
    let now: Date
    let onPick: Bool

    var body: some View {
        Text(Words.age(since, at: now))
            .font(WindowStyle.ui(WindowStyle.ageSize).monospacedDigit())
            .foregroundStyle(ink)
    }

    private var ink: AnyShapeStyle {
        if washed != nil {
            return AnyShapeStyle(WindowStyle.orange)
        }
        return onPick ? AnyShapeStyle(WindowStyle.picked(.soft)) : AnyShapeStyle(.secondary)
    }
}

/// A session's mark in its slot, drawn still: needs you an orange dot; your turn a soft ring; working a still arc on
/// its faint track; on its own work the dotted ring; away a faint dot.
struct SidebarMark: View {
    let mark: Mark

    var body: some View {
        Group {
            switch mark {
            case .needs: Circle().fill(WindowStyle.orange).frame(width: 7, height: 7)
            case .turn: Circle().stroke(.secondary, lineWidth: 1.5).frame(width: 7.5, height: 7.5)
            case .working:
                ZStack {
                    Circle().stroke(WindowStyle.sidebarTrack, lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: 1 / 3)
                        .stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 8.5, height: 8.5)
            case .onItsWork: DottedRingView(ring: .sidebar, ink: WindowStyle.sidebarDotted)
            case .away: Circle().fill(.tertiary).frame(width: 5, height: 5)
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
    /// A row of the sidebar's list: one that shows `pick`, the one picked while it is `picked`, washed orange from
    /// `washed` as it comes; or with no pick, "N earlier", which the list never selects. Its tag is the list's
    /// selection's own type, so no row can carry one it ignores.
    func sidebarRow(_ pick: Pick?, picked: Pick?, washed: Date? = nil, now: Date) -> some View {
        modifier(SidebarRow(pick: pick, isPicked: pick != nil && pick == picked, washed: washed, now: now))
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
/// as a still, the selection's stand-in.
private struct SidebarRow: ViewModifier {
    let pick: Pick?
    let isPicked: Bool
    let washed: Date?
    let now: Date

    @Environment(\.isStill) private var isStill
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isOverWords = false
    @State private var isOverRow = false

    func body(content: Content) -> some View {
        let highlight = Highlight.of(
            isPicked: isPicked, isPressed: false, isHovered: isOverWords || isOverRow || isHoveredStill
        )
        let row = content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isOverWords = $0 }
            .sidebarCell {
                RowBackground(
                    fill: WindowStyle.sidebarFill(highlight, isStill: isStill), washed: washed, now: now,
                    isOver: $isOverRow
                )
            }

        if let pick {
            row.tag(pick)
        } else {
            row.selectionDisabled()
        }
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
