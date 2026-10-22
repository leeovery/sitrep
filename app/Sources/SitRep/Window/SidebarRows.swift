import SitRepWindow
import SwiftUI

/// A line of the sidebar's list as its kind draws it: Needs you's heading, a heading that folds, a session's row under
/// Needs you, two lines, or under its project, one, and a quiet project's row. Its words are in the system's label
/// colours, so the list's emphasized selection turns them white by itself; its orange stays orange.
struct SidebarLine: View {
    let line: Sidebar.Line
    /// The first line after Needs you, which the rule after it sits over (`Sidebar.ruled`).
    let isRuled: Bool
    let spot: Spot?
    /// The list has the key window's focus, so a selection shows in the accent.
    let isEmphasized: Bool
    let filter: Filter
    let now: Date

    var body: some View {
        switch line {
        case .needsYou:
            NeedsYouHeading().sidebarCell()
        case let .heading(heading):
            FoldHeading(
                heading: heading, isRuled: isRuled, isPicked: line.spot.map { $0 == spot } ?? false,
                isEmphasized: isEmphasized, filter: filter
            )
        case let .asking(row):
            picking(session(row, showsProject: true), washed: row.washed)
        case let .session(row):
            picking(session(row, showsProject: false), washed: row.washed)
        case let .quiet(project):
            picking(QuietRow(project: project, filter: filter).spoken(Spoken.quiet(project)))
        }
    }

    private func session(_ row: Listed.Row, showsProject: Bool) -> some View {
        SidebarSessionRow(row: row, filter: filter, showsProject: showsProject, now: now)
            .spoken(Spoken.row(row, at: now))
    }

    /// A row that picks, tagged with the line's own spot (`Sidebar.Line.spot`), so the model says what each row picks.
    @ViewBuilder private func picking(_ content: some View, washed: Date? = nil) -> some View {
        if let place = line.spot {
            content.sidebarRow(place, picked: spot, washed: washed, now: now)
        }
    }
}

/// "Needs you", over the sessions with an ask: plain words, which neither fold nor pick, nor change under the pointer.
private struct NeedsYouHeading: View {
    var body: some View {
        Text(Words.needsYou)
            .font(WindowStyle.ui(WindowStyle.smallSize, .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: WindowStyle.headingHeight, alignment: .leading)
            .padding(.top, WindowStyle.headingGap)
            .accessibilityAddTraits(.isHeader)
            .selectionDisabled()
    }
}

/// A project's heading, or the quiet projects': its name, while folded the orange count of its sessions with an ask,
/// and a chevron saying which way it is, faint, a step brighter under the pointer. A click anywhere on it folds or
/// unfolds what is under it, and never moves the pick. The list will not select a row the pointer cannot pick, so
/// while its project's page shows it draws the system's selection itself, its words white on the accent. The first
/// after Needs you carries the rule after it, 12 under Needs you's last row and 10 over its own words, drawn behind
/// the row so the list adds no line of its own, whose insets a live window could move; the pointer, a click and
/// VoiceOver know only the heading's 24.
struct FoldHeading: View {
    let heading: Sidebar.Heading
    let isRuled: Bool
    let isPicked: Bool
    let isEmphasized: Bool
    let filter: Filter

    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill
    @Environment(\.isHoveredStill) private var isHoveredStill
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Name(heading.name, litBy: filter, tone: .soft)
                .font(WindowStyle.ui(WindowStyle.smallSize, .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let count = heading.count {
                Text("\(count)")
                    .font(WindowStyle.ui(WindowStyle.smallSize, .semibold).monospacedDigit())
                    .foregroundStyle(WindowStyle.orange)
            }
            Chevron(isFolded: heading.isFolded)
                .foregroundStyle(isHovered || isHoveredStill ? .secondary : .tertiary)
                .frame(width: WindowStyle.chevronSlot.width, height: WindowStyle.chevronSlot.height)
        }
        .padding(.trailing, -(WindowStyle.rowInset - WindowStyle.selectionInset - WindowStyle.headingTrailing))
        .frame(height: WindowStyle.headingHeight)
        .environment(\.backgroundProminence, isPicked && isEmphasized ? .increased : .standard)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { act.fold(heading.fold) }
        .spoken(Spoken.heading(heading))
        .accessibilityAddTraits(isPicked ? [.isHeader, .isButton, .isSelected] : [.isHeader, .isButton])
        .accessibilityAction { act.fold(heading.fold) }
        .padding(.top, gap)
        .selectionDisabled()
        .sidebarCell {
            ZStack(alignment: .top) {
                if isRuled {
                    SidebarRule().padding(.top, WindowStyle.ruleGap)
                }
                selection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// What is over its words: 10, or after Needs you its rule, 12 under the rows before it, and 10 more.
    private var gap: CGFloat {
        isRuled ? WindowStyle.ruleGap + WindowStyle.rule + WindowStyle.headingGap : WindowStyle.headingGap
    }

    /// The selection's shape, on the heading's own row under its gap, in from the sidebar's edges.
    @ViewBuilder private var selection: some View {
        if isPicked {
            SelectionShaped(
                fill: WindowStyle.selection(isEmphasized: isEmphasized, isStill: isStill),
                radius: WindowStyle.headingRadius
            )
            .frame(height: WindowStyle.headingHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
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

/// A heading's chevron as drawn: down while open, 10 by 6; right while folded, 6 by 10; its stroke 1.5, round.
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

/// A session's row: its mark in its slot, its name on one line, and on a row with an ask how long it has waited. Under
/// Needs you, two lines, its project's name under its own, its parts set to its top.
struct SidebarSessionRow: View {
    let row: Listed.Row
    let filter: Filter
    let showsProject: Bool
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: WindowStyle.slotGap) {
            SidebarMark(mark: row.mark)
            VStack(alignment: .leading, spacing: 1) {
                Name(row.name, litBy: filter, tone: row.isAway ? .faint : .text)
                    .font(WindowStyle.ui(WindowStyle.titleSize))
                    .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                    .lineLimit(1)
                    .frame(height: WindowStyle.titleLine)
                if showsProject {
                    Name(row.project, litBy: filter, tone: .soft)
                        .font(WindowStyle.ui(WindowStyle.smallSize))
                        .lineLimit(1)
                        .frame(height: WindowStyle.smallLine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if row.mark == .needs {
                age.frame(height: WindowStyle.titleLine)
            }
        }
        .padding(.top, showsProject ? WindowStyle.twoLineTop : (WindowStyle.rowHeight - WindowStyle.titleLine) / 2)
        .frame(height: showsProject ? WindowStyle.twoLineHeight : WindowStyle.rowHeight, alignment: .top)
    }

    /// How long its ask has waited: orange while it washes, as what needs Lee stays orange; else soft.
    private var age: some View {
        Text(Words.age(row.since, at: now))
            .font(WindowStyle.ui(WindowStyle.ageSize).monospacedDigit())
            .foregroundStyle(row.washed == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(WindowStyle.orange))
    }
}

/// A quiet project's row, which opens its project: its name, soft, after an empty slot.
private struct QuietRow: View {
    let project: Listed.Quiet
    let filter: Filter

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Color.clear.frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
            Name(project.name, litBy: filter, tone: .soft)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: WindowStyle.rowHeight, alignment: .leading)
    }
}

/// A session's mark in its slot, drawn still: needs you an orange dot; your turn a soft ring; working a still arc on
/// its faint track; away a faint dot.
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
            case .away: Circle().fill(.tertiary).frame(width: 5, height: 5)
            }
        }
        .frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
        .spoken(Spoken.mark(mark))
    }
}

/// A name in its tone; while the filter narrows the list, its words lit where they appear in it, a step brighter than
/// the rest (`Tone`), in the system's label colours.
struct Name: View {
    let name: String
    let filter: Filter
    let tone: Tone

    init(_ name: String, litBy filter: Filter, tone: Tone) {
        self.name = name
        self.filter = filter
        self.tone = tone
    }

    var body: some View {
        if filter.isEmpty {
            Text(name).foregroundStyle(WindowStyle.label(tone))
        } else {
            filter.runs(of: name).reduce(Text("")) { text, run in
                let style = WindowStyle.label(run.isLit ? tone.lit : tone.rest)

                return Text("\(text)\(Text(run.text).foregroundStyle(style))")
            }
        }
    }
}

extension View {
    /// A row of the sidebar's lists that shows the pick at `spot`, the one picked while it is `picked`, washed orange
    /// from `washed` as it comes. Its tag is the lists' selection's own type, so no row can carry one they ignore.
    func sidebarRow(_ spot: Spot, picked: Spot?, washed: Date? = nil, now: Date) -> some View {
        modifier(SidebarRow(spot: spot, isPicked: spot == picked, washed: washed, now: now))
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

/// A row of the sidebar's list, tagged with the row that shows the pick. Its background fills the whole row, so the
/// pointer is over it anywhere on the row: under the pointer, and not the one picked, it shows a quiet fill, and as it
/// comes, its wash, both shaped as the system's selection, which they leave alone. Drawn as a still, the selection's
/// stand-in.
private struct SidebarRow: ViewModifier {
    let spot: Spot
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

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isOverWords = $0 }
            .sidebarCell {
                RowBackground(
                    fill: WindowStyle.sidebarFill(highlight, isStill: isStill), washed: washed, now: now,
                    isOver: $isOverRow
                )
            }
            .tag(spot)
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
