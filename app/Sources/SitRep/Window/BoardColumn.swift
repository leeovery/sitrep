import SitRepWindow
import SwiftUI

/// The board down the left: the head, every project with something open and its sessions under it, and the quiet
/// projects folded into a line at the foot. A press on a session picks it; on a project's name, its own or a quiet
/// one's, opens the project. Every row highlights under the pointer, and the one picked stays highlighted.
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
                QuietFoot(quiet: listed.quiet, pick: pick)
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
            .rowButton(isPicked: pick == .project(project.id))
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
            .contentShape(Rectangle())
        }
        .rowButton(isPicked: isPicked)
    }

    private var isWashing: Bool { row.washed != nil }
}

/// The quiet projects, folded into the foot: how many, then each name, which opens its project, highlighted under the
/// pointer and kept highlighted while its project is picked.
private struct QuietFoot: View {
    let quiet: [Listed.Quiet]
    let pick: Pick?

    @Environment(\.windowActions) private var act

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Words.quiet(quiet.count))
                .font(WindowStyle.ui(12, .semibold))
                .foregroundStyle(WindowStyle.soft)
                .padding(.horizontal, 10)
            Flow(spacing: 2) {
                ForEach(quiet) { project in
                    Button { act.pick(project.pick) } label: {
                        Text(project.name)
                            .font(WindowStyle.ui(12, .medium))
                            .foregroundStyle(WindowStyle.soft)
                            .lineLimit(1)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                    }
                    .rowButton(isPicked: pick == project.pick, radius: 6)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .overlay(alignment: .top) { Rectangle().fill(WindowStyle.line).frame(height: 1).padding(.horizontal, -10) }
    }
}

/// Subviews side by side from the left, a line wrapping onto the next where it runs out of width.
private struct Flow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let frames = frames(proposal.width ?? .infinity, subviews)

        return CGSize(width: proposal.width ?? frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (subview, frame) in zip(subviews, frames(bounds.width, subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(_ width: CGFloat, _ subviews: Subviews) -> [CGRect] {
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0

        return subviews.map { subview in
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))

            if x > 0, x + size.width > width {
                x = 0
                y += line + spacing
                line = 0
            }
            defer {
                x += size.width + spacing
                line = max(line, size.height)
            }
            return CGRect(origin: CGPoint(x: x, y: y), size: size)
        }
    }
}
