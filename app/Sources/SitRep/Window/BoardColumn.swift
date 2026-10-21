import SitRepWindow
import SwiftUI

/// The board down the left, in the system's sidebar: the head, the Filter field and the switch between the two views,
/// then the rows. Projects lists every project with something open and its sessions under it, and the quiet projects
/// at the foot; Needs you every session, flat, in the panel's order, its project's name under its own. The filter
/// narrows the view chosen in place, the words typed lit in the names that hold them; with nothing kept, one line says
/// so. Its rows are a list whose selection is the session or project picked, drawn by the system, which the pointer
/// and the arrow keys move alike, and which never empties; a project's name, its own or a quiet one's, opens the
/// project. A row under the pointer that is not the one picked shows a quiet fill behind it. The head stays put while
/// the rows scroll, and the row picked is scrolled into view whenever the pick or the order changes: a pick made
/// elsewhere, by a jump, a notification or the menu, or a resort.
struct BoardColumn: View {
    let listed: Listed
    let pick: Pick?
    let sidebar: Sidebar
    let filter: Filter
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @Environment(\.isStill) private var isStill
    /// The row picked as the list holds it: the pick, put back whenever the list lets go of it, as a click in its
    /// blank space or on the row picked does, so its selection never empties while something is picked.
    @State private var selection: Pick?

    var body: some View {
        if isStill {
            standIn
        } else {
            VStack(alignment: .leading, spacing: 0) {
                head
                FilterField(text: filter.text).padding(.horizontal, WindowStyle.selectionInset)
                views
                list.overlay {
                    if isUnmatched {
                        noMatch
                    }
                }
            }
        }
    }

    /// The filter keeps nothing of the view chosen: one line says so, over the list, left in place, empty, so it hears
    /// the pointer leave as ever and the order it holds settles.
    private var isUnmatched: Bool {
        !filter.isEmpty && listed.isEmpty(in: sidebar)
    }

    private var noMatch: some View {
        Text(Words.noMatch(filter))
            .font(WindowStyle.ui(13))
            .foregroundStyle(WindowStyle.soft)
            .lineLimit(1)
            .padding(.horizontal, WindowStyle.rowInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The switch between the two views, the system's segmented control.
    private var views: some View {
        Picker(Spoken.sidebar, selection: Binding(get: { sidebar }, set: { act.choose($0) })) {
            ForEach(Sidebar.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WindowStyle.selectionInset)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var list: some View {
        ScrollViewReader { scroller in
            List(selection: $selection) { rows }
                .listStyle(.sidebar)
                .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: order)
                .onHover { act.pointer($0) }
                .onChange(of: selection) { _, selected in
                    guard let selected else {
                        selection = pick
                        return
                    }
                    if selected != pick {
                        act.pickInList(selected)
                    }
                }
                .onChange(of: pick, initial: true) { _, pick in
                    selection = pick
                    reveal(pick, in: scroller)
                }
                .onChange(of: order) { reveal(pick, in: scroller) }
        }
    }

    /// The rows in the order they show, which moves the row picked when the list resorts.
    private var order: [String] {
        switch sidebar {
        case .projects: listed.projects.flatMap { [$0.id] + $0.sessions.map(\.id) } + listed.quiet.map(\.id)
        case .needsYou: listed.flat.map(\.id)
        }
    }

    /// The row picked scrolled into view, only as far as it needs.
    private func reveal(_ pick: Pick?, in scroller: ScrollViewProxy) {
        if let pick {
            scroller.scrollTo(pick)
        }
    }

    @ViewBuilder private var rows: some View {
        switch sidebar {
        case .projects:
            ForEach(listed.projects) { project in
                Section {
                    ProjectRows(project: project, pick: pick, filter: filter, now: now)
                }
            }
            if !listed.quiet.isEmpty {
                Section {
                    QuietRows(quiet: listed.quiet, pick: pick, filter: filter, now: now)
                } header: {
                    QuietHeading(count: listed.quiet.count)
                }
                .collapsible(false)
            }
        case .needsYou:
            FlatRows(rows: listed.flat, pick: pick, filter: filter, now: now)
        }
    }

    /// A stand-in for the sidebar, drawn as a still: an image renderer draws no list, nor the sidebar it sits in, nor
    /// AppKit's controls. Below the bar the traffic lights sit in, its head, a stand-in for the field and the switch,
    /// and its rows are laid out as the system's list sets them, its picked row on a stand-in for the selection, all on
    /// the panel's black with a hairline beside it.
    private var standIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            head
            StillControls(sidebar: sidebar, filter: filter)
            if isUnmatched {
                noMatch
            } else {
                standInRows
                Spacer(minLength: 0)
            }
        }
        .background(WindowStyle.black)
        .overlay(alignment: .trailing) { Rectangle().fill(WindowStyle.line).frame(width: 1) }
    }

    @ViewBuilder private var standInRows: some View {
        switch sidebar {
        case .projects:
            VStack(alignment: .leading, spacing: WindowStyle.sectionGap) {
                ForEach(listed.projects) { project in
                    VStack(alignment: .leading, spacing: 0) {
                        ProjectRows(project: project, pick: pick, filter: filter, now: now)
                    }
                }
                if !listed.quiet.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        QuietHeading(count: listed.quiet.count)
                            .padding(.horizontal, WindowStyle.rowInset)
                            .padding(.bottom, 4)
                        QuietRows(quiet: listed.quiet, pick: pick, filter: filter, now: now)
                    }
                }
            }
        case .needsYou:
            VStack(alignment: .leading, spacing: 0) {
                FlatRows(rows: listed.flat, pick: pick, filter: filter, now: now)
            }
        }
    }

    private var head: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(listed.head.title)
                .font(WindowStyle.ui(15, .semibold))
                .spacing(-0.01, of: 15)
                .foregroundStyle(WindowStyle.text)
                .lineLimit(1)
            Spacer()
            Text(listed.head.count).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
        }
        .padding(.horizontal, WindowStyle.rowInset)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

/// The Filter field and the switch as a still draws them, which renders no AppKit control: at their sizes, the field's
/// words or its placeholder, the view chosen raised.
private struct StillControls: View {
    let sidebar: Sidebar
    let filter: Filter

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(WindowStyle.soft)
                Text(filter.text.isEmpty ? Words.filter : filter.text)
                    .foregroundStyle(filter.text.isEmpty ? WindowStyle.faint : WindowStyle.text)
                Spacer(minLength: 0)
            }
            .font(WindowStyle.ui(13))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            HStack(spacing: 0) {
                ForEach(Sidebar.allCases) { view in
                    Text(view.title)
                        .font(WindowStyle.ui(13, .medium))
                        .foregroundStyle(view == sidebar ? WindowStyle.text : WindowStyle.soft)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(Capsule().fill(view == sidebar ? Color(hex: 0x5A5A5F) : .clear))
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, WindowStyle.selectionInset)
    }
}

/// A project's name, what waits there in orange, and its sessions: a row each.
private struct ProjectRows: View {
    let project: Listed.Project
    let pick: Pick?
    let filter: Filter
    let now: Date

    var body: some View {
        HStack {
            Text(project.name, litBy: filter, tone: .soft)
            Spacer()
            if project.waiting > 0 {
                Text("\(project.waiting)").foregroundStyle(WindowStyle.orange)
            }
        }
        .font(WindowStyle.ui(12, .semibold))
        .spoken(Spoken.project(project))
        .accessibilityAddTraits(.isHeader)
        .sidebarRow(.project(project.id), pick: pick, now: now)
        ForEach(project.sessions) { row in
            SessionRowView(row: row, isPicked: pick == .session(row.id), filter: filter, now: now)
                .spoken(Spoken.row(row, at: now))
                .sidebarRow(.session(row.id), pick: pick, washed: row.washed, now: now)
        }
    }
}

/// The Needs you view's rows, flat: each session's name, and its project's under it.
private struct FlatRows: View {
    let rows: [Listed.Row]
    let pick: Pick?
    let filter: Filter
    let now: Date

    var body: some View {
        ForEach(rows) { row in
            SessionRowView(row: row, isPicked: pick == .session(row.id), filter: filter, showsProject: true, now: now)
                .spoken(Spoken.row(row, at: now))
                .sidebarRow(.session(row.id), pick: pick, washed: row.washed, now: now)
        }
    }
}

/// A session's row: a small panel row, its mark in its lane, its name on one line, the panel row's time; in the Needs
/// you view its project's name under its own, the row's parts set to its top.
private struct SessionRowView: View {
    let row: Listed.Row
    let isPicked: Bool
    let filter: Filter
    var showsProject = false
    let now: Date

    var body: some View {
        HStack(alignment: showsProject ? .top : .center, spacing: 10) {
            MarkView(mark: row.mark)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name, litBy: filter, tone: row.isAway ? .faint : .text)
                    .font(WindowStyle.ui(13, isPicked || isWashing ? .semibold : .medium))
                    .spacing(-0.005, of: 13)
                    .lineLimit(1)
                    .frame(minHeight: WindowStyle.lane.height)
                if showsProject {
                    Text(row.project, litBy: filter, tone: .soft)
                        .font(WindowStyle.ui(12))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Words.age(row.since, at: now))
                .font(WindowStyle.ui(12))
                .foregroundStyle(isWashing ? WindowStyle.orange : WindowStyle.faint)
                .frame(width: 28, alignment: .trailing)
                .frame(minHeight: WindowStyle.lane.height)
        }
    }

    private var isWashing: Bool { row.washed != nil }
}

/// "6 quiet projects", over their names.
private struct QuietHeading: View {
    let count: Int

    var body: some View {
        Text(Words.quiet(count)).font(WindowStyle.ui(12, .semibold)).foregroundStyle(WindowStyle.soft)
    }
}

/// The quiet projects, a row each, which opens its project.
private struct QuietRows: View {
    let quiet: [Listed.Quiet]
    let pick: Pick?
    let filter: Filter
    let now: Date

    var body: some View {
        ForEach(quiet) { project in
            Text(project.name, litBy: filter, tone: .soft)
                .font(WindowStyle.ui(12, .medium))
                .lineLimit(1)
                .spoken(Spoken.quiet(project))
                .sidebarRow(project.pick, pick: pick, now: now)
        }
    }
}

private extension Text {
    /// A name in its own tone; while the filter narrows the list, its words lit where they appear in it, a step
    /// brighter than the rest (`Tone`).
    init(_ name: String, litBy filter: Filter, tone: Tone) {
        guard !filter.isEmpty else {
            self = Text(name).foregroundStyle(WindowStyle.colour(tone))
            return
        }

        self = filter.runs(of: name).reduce(Text("")) { text, run in
            Text("\(text)\(Text(run.text).foregroundStyle(WindowStyle.colour(run.isLit ? tone.lit : tone.rest)))")
        }
    }
}

private extension View {
    /// A row of the sidebar's list, picked as `pick`, washed orange from `washed` as it comes (`BoardColumn`).
    func sidebarRow(_ row: Pick, pick: Pick?, washed: Date? = nil, now: Date) -> some View {
        modifier(SidebarRow(row: row, isPicked: row == pick, washed: washed, now: now))
    }
}

/// A row of the sidebar's list, tagged with what it picks, and named by it, to scroll to. Its words fill the row's
/// height, and its background the whole row, so the pointer is over it anywhere on the row: under the pointer, and not
/// the one picked, it shows a quiet fill, and as it comes, its wash, both as the row's background, shaped as the
/// system's selection, which they leave alone. Drawn as a still, it is laid out as the list lays it out.
private struct SidebarRow: ViewModifier {
    let row: Pick
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
        let background = RowBackground(
            fill: WindowStyle.sidebarFill(highlight, isStill: isStill), washed: washed, now: now, isOver: $isOverRow
        )
        let words = content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isOverWords = $0 }

        Group {
            if isStill {
                words
                    .padding(.horizontal, WindowStyle.rowInset)
                    .padding(.vertical, WindowStyle.rowPadding)
                    .frame(minHeight: WindowStyle.rowHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(background)
            } else {
                words.listRowBackground(background)
            }
        }
        .tag(row)
        .id(row)
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
            WashFill(since: washed, now: now, radius: WindowStyle.selectionRadius)
            if let fill {
                RoundedRectangle(cornerRadius: WindowStyle.selectionRadius, style: .continuous).fill(fill)
            }
        }
        .padding(.horizontal, WindowStyle.selectionInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { isOver = $0 }
    }
}
