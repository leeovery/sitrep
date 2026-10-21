import SitRepWindow
import SwiftUI

/// The board down the left, in the system's sidebar: the head, then every project with something open and its
/// sessions under it, and the quiet projects at the foot. Its rows are a list whose selection is the session or
/// project picked, drawn by the system, which the pointer and the arrow keys move alike, and which never empties; a
/// project's name, its own or a quiet one's, opens the project. A row under the pointer that is not the one picked
/// shows a quiet fill behind it. The head stays put while the rows scroll, and the row picked is scrolled into view
/// whenever the pick or the order changes: a pick made elsewhere, by a jump, a notification or the menu, or a resort.
/// Settings sits at the sidebar's foot, which never scrolls; while it shows, nothing on the board is picked.
struct BoardColumn: View {
    let listed: Listed
    let pick: Pick?
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @Environment(\.isStill) private var isStill
    /// The row picked as the list holds it: the pick, put back whenever the list lets go of it, as a click in its
    /// blank space or on the row picked does, so its selection never empties while something on it is picked.
    @State private var selection: Pick?

    var body: some View {
        if isStill {
            standIn
        } else {
            VStack(alignment: .leading, spacing: 0) {
                head
                list
            }
        }
    }

    private var list: some View {
        ScrollViewReader { scroller in
            List(selection: $selection) { rows }
                .listStyle(.sidebar)
                .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: listed.sessions.map(\.id))
                .onHover { act.pointer($0) }
                .foot { SettingsFooter(pick: pick, now: now) }
                .onChange(of: selection) { _, selected in
                    guard let selected else {
                        selection = pick?.listRow
                        return
                    }
                    if selected != pick {
                        act.pickInList(selected)
                    }
                }
                .onChange(of: pick, initial: true) { _, pick in
                    selection = pick?.listRow
                    reveal(pick?.listRow, in: scroller)
                }
                .onChange(of: order) { reveal(pick?.listRow, in: scroller) }
        }
    }

    /// The rows in the order they show, which moves the row picked when the list resorts.
    private var order: [String] {
        listed.projects.flatMap { [$0.id] + $0.sessions.map(\.id) } + listed.quiet.map(\.id)
    }

    /// The row picked scrolled into view, only as far as it needs.
    private func reveal(_ pick: Pick?, in scroller: ScrollViewProxy) {
        if let pick {
            scroller.scrollTo(pick)
        }
    }

    @ViewBuilder private var rows: some View {
        ForEach(listed.projects) { project in
            Section {
                ProjectRows(project: project, pick: pick, now: now)
            }
        }
        if !listed.quiet.isEmpty {
            Section {
                QuietRows(quiet: listed.quiet, pick: pick, now: now)
            } header: {
                QuietHeading(count: listed.quiet.count)
            }
            .collapsible(false)
        }
    }

    /// A stand-in for the sidebar, drawn as a still: an image renderer draws no list, nor the sidebar it sits in. Below
    /// the bar the traffic lights sit in, its head and its rows are laid out as the system's list sets them, its
    /// picked row on a stand-in for the selection, all on the panel's black with a hairline beside it.
    private var standIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            head
            VStack(alignment: .leading, spacing: WindowStyle.sectionGap) {
                ForEach(listed.projects) { project in
                    VStack(alignment: .leading, spacing: 0) {
                        ProjectRows(project: project, pick: pick, now: now)
                    }
                }
                if !listed.quiet.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        QuietHeading(count: listed.quiet.count)
                            .padding(.horizontal, WindowStyle.rowInset)
                            .padding(.bottom, 4)
                        QuietRows(quiet: listed.quiet, pick: pick, now: now)
                    }
                }
            }
            Spacer(minLength: 0)
            SettingsFooter(pick: pick, now: now)
        }
        .background(WindowStyle.black)
        .overlay(alignment: .trailing) { Rectangle().fill(WindowStyle.line).frame(width: 1) }
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

/// A project's name, what waits there in orange, and its sessions: a row each.
private struct ProjectRows: View {
    let project: Listed.Project
    let pick: Pick?
    let now: Date

    var body: some View {
        HStack {
            Text(project.name).foregroundStyle(WindowStyle.soft)
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
            SessionRowView(row: row, isPicked: pick == .session(row.id), now: now)
                .spoken(Spoken.row(row, in: project.name, at: now))
                .sidebarRow(.session(row.id), pick: pick, washed: row.washed, now: now)
        }
    }
}

/// A session's row: a small panel row, its mark in its lane, its name on one line, the panel row's time.
private struct SessionRowView: View {
    let row: Listed.Row
    let isPicked: Bool
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            MarkView(mark: row.mark)
            Text(row.name)
                .font(WindowStyle.ui(13, isPicked || isWashing ? .semibold : .medium))
                .spacing(-0.005, of: 13)
                .foregroundStyle(row.isAway ? WindowStyle.faint : WindowStyle.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Words.age(row.since, at: now))
                .font(WindowStyle.ui(12))
                .foregroundStyle(isWashing ? WindowStyle.orange : WindowStyle.faint)
                .frame(width: 28, alignment: .trailing)
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
    let now: Date

    var body: some View {
        ForEach(quiet) { project in
            Text(project.name)
                .font(WindowStyle.ui(12, .medium))
                .foregroundStyle(WindowStyle.soft)
                .lineLimit(1)
                .spoken(Spoken.quiet(project))
                .sidebarRow(project.pick, pick: pick, now: now)
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
                    .frame(height: WindowStyle.rowHeight)
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

private extension View {
    /// A foot the list runs on under: on macOS 26 the system's own bar, whose scroll edge fades the list where it
    /// passes beneath; before it, the list's inset.
    @ViewBuilder func foot(@ViewBuilder _ foot: () -> some View) -> some View {
        if #available(macOS 26, *) {
            safeAreaBar(edge: .bottom, spacing: 0, content: foot)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0, content: foot)
        }
    }
}

/// Settings at the sidebar's foot, under a hairline, fixed as the list runs on under it: a list of its one row, so it
/// takes the system's own selection while Settings shows, as a picked session's row does, and is a stop of its own for
/// the keys. Drawn as a still, its row alone, as the board's rows are.
private struct SettingsFooter: View {
    let pick: Pick?
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill
    /// The row as the list holds it, put back whenever the list lets go of it while Settings shows.
    @State private var selection: Pick?

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            if isStill {
                row.padding(.top, 8).padding(.bottom, 10)
            } else {
                List(selection: $selection) { row }
                    .listStyle(.sidebar)
                    .scrollDisabled(true)
                    .frame(height: WindowStyle.footerHeight)
                    .onChange(of: selection) { _, selected in
                        if selected == .settings, pick != .settings {
                            act.pick(.settings)
                        } else if selected == nil, pick == .settings {
                            selection = .settings
                        }
                    }
                    .onChange(of: pick, initial: true) { _, pick in
                        selection = pick == .settings ? .settings : nil
                    }
            }
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            Image(systemName: "gear")
                .font(.system(size: 14))
                .frame(width: 16, height: 18)
                .accessibilityHidden(true)
            Text("Settings")
                .font(WindowStyle.ui(13, .medium))
                .spacing(-0.005, of: 13)
        }
        .foregroundStyle(WindowStyle.text)
        .sidebarRow(.settings, pick: pick, now: now)
    }
}
