import SitRepWindow
import SwiftUI

/// The board down the left, in the system's sidebar: the head, every project with something open and its sessions
/// under it, and the quiet projects at the foot. Its rows are a list whose selection is the session or project picked,
/// drawn by the system, which the pointer and the arrow keys move alike; a project's name, its own or a quiet one's,
/// opens the project. A row under the pointer that is not the one picked shows a quiet fill behind it.
struct BoardColumn: View {
    let listed: Listed
    let pick: Pick?
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @Environment(\.isStill) private var isStill

    var body: some View {
        if isStill {
            still
        } else {
            list
        }
    }

    private var list: some View {
        List(selection: selection) {
            ForEach(listed.projects) { project in
                Section {
                    ProjectRows(project: project, pick: pick, now: now)
                }
            }
            if !listed.quiet.isEmpty {
                Section {
                    QuietRows(quiet: listed.quiet, pick: pick)
                } header: {
                    QuietHeading(count: listed.quiet.count)
                }
            }
        }
        .listStyle(.sidebar)
        .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: listed.sessions.map(\.id))
        .onHover { act.pointer($0) }
        .safeAreaInset(edge: .top, spacing: 0) { head }
    }

    /// The list laid out whole as a still, which renders no list: below the bar the traffic lights sit in, on the
    /// panel's black with a hairline beside it, as before macOS 26.
    private var still: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            head
            VStack(alignment: .leading, spacing: 14) {
                ForEach(listed.projects) { project in
                    VStack(alignment: .leading, spacing: 0) {
                        ProjectRows(project: project, pick: pick, now: now)
                    }
                }
                if !listed.quiet.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        QuietHeading(count: listed.quiet.count).padding(.horizontal, WindowStyle.rowInset).padding(.bottom, 4)
                        QuietRows(quiet: listed.quiet, pick: pick)
                    }
                }
            }
            .padding(.horizontal, WindowStyle.selectionInset)
            Spacer(minLength: 0)
        }
        .background(WindowStyle.black)
        .overlay(alignment: .trailing) { Rectangle().fill(WindowStyle.line).frame(width: 1) }
    }

    /// Lee's press or arrow key on a row, picking it; the list never picks nothing.
    private var selection: Binding<Pick?> {
        Binding(get: { pick }, set: { picked in
            if let picked, picked != pick {
                act.pick(picked)
            }
        })
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
        .padding(.horizontal, WindowStyle.selectionInset + WindowStyle.rowInset)
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
        .sidebarRow(.project(project.id), pick: pick)
        ForEach(project.sessions) { row in
            SessionRowView(row: row, isPicked: pick == .session(row.id), now: now)
                .sidebarRow(.session(row.id), pick: pick)
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
        .modifier(Washed(since: row.washed, now: now, radius: 6))
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

    var body: some View {
        ForEach(quiet) { project in
            Text(project.name)
                .font(WindowStyle.ui(12, .medium))
                .foregroundStyle(WindowStyle.soft)
                .lineLimit(1)
                .sidebarRow(project.pick, pick: pick)
        }
    }
}

private extension View {
    /// A row of the sidebar's list, picked as `pick` (`BoardColumn`).
    func sidebarRow(_ row: Pick, pick: Pick?) -> some View {
        modifier(SidebarRow(row: row, isPicked: row == pick))
    }
}

/// A row of the sidebar's list, tagged with what it picks. Under the pointer, and not the one picked, it shows a quiet
/// fill behind its words, as the row's own background, which the system's selection leaves alone. Drawn as a still,
/// which renders no list, it is laid out as the list lays it out, the picked one on a stand-in for the selection.
private struct SidebarRow: ViewModifier {
    let row: Pick
    let isPicked: Bool

    @Environment(\.isStill) private var isStill

    func body(content: Content) -> some View {
        Highlighted(isPicked: isPicked) { highlight in
            let fill = WindowStyle.sidebarFill(highlight, isStill: isStill).map(Self.fill)
            let words = content.frame(maxWidth: .infinity, minHeight: WindowStyle.lane.height, alignment: .leading)
                .contentShape(Rectangle())

            if isStill {
                words
                    .padding(.vertical, 5)
                    .padding(.horizontal, WindowStyle.rowInset)
                    .background { fill }
            } else {
                words.listRowBackground(fill.map { $0.padding(.horizontal, WindowStyle.selectionInset) })
            }
        }
        .tag(row)
    }

    private static func fill(_ colour: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(colour)
    }
}
