import SitRepWindow
import SwiftUI

/// The board down the left: the head, every project with something open and its sessions under it, and the quiet
/// projects folded into a line at the foot. A press on a session picks it; on a project's name, opens the project.
struct BoardColumn: View {
    let listed: Listed
    let pick: Pick?
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            head
            Scrolling {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(listed.projects) { project in
                        ProjectRows(project: project, pick: pick, now: now)
                    }
                }
                .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: listed.sessions.map(\.id))
            }
            .onHover { act.pointer($0) }
            if !listed.quiet.isEmpty {
                QuietFoot(names: listed.quiet)
            }
        }
        .padding(.horizontal, 10)
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
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }
}

/// A project's name, what waits there in orange, and its sessions.
private struct ProjectRows: View {
    let project: Listed.Project
    let pick: Pick?
    let now: Date

    @Environment(\.windowActions) private var act

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button { act.pick(.project(project.id)) } label: {
                HStack {
                    Text(project.name).foregroundStyle(WindowStyle.soft)
                    Spacer()
                    if project.waiting > 0 {
                        Text("\(project.waiting)").foregroundStyle(WindowStyle.orange)
                    }
                }
                .font(WindowStyle.ui(12, .semibold))
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ForEach(project.sessions) { row in
                SessionRowView(row: row, isPicked: pick == .session(row.id), now: now)
            }
        }
    }
}

/// A session's row: a small panel row, its mark in its lane, its name on one line, the panel row's time.
private struct SessionRowView: View {
    let row: Listed.Row
    let isPicked: Bool
    let now: Date

    @Environment(\.windowActions) private var act

    var body: some View {
        Button { act.pick(.session(row.id)) } label: {
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
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .modifier(Washed(since: row.washed, now: now, radius: 8))
            .background(RoundedRectangle(cornerRadius: 8).fill(isPicked ? WindowStyle.raise : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var isWashing: Bool { row.washed != nil }
}

/// The quiet projects, folded into one line at the foot.
private struct QuietFoot: View {
    let names: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Words.quiet(names.count)).font(WindowStyle.ui(12, .semibold)).foregroundStyle(WindowStyle.soft)
            Text(names.joined(separator: ", ")).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .overlay(alignment: .top) { Rectangle().fill(WindowStyle.line).frame(height: 1) }
        .padding(.horizontal, -10)
    }
}
