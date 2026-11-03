import SitRepWindow
import SwiftUI

/// A project, opened from its name: its sessions, each with what it is doing and what waits there; every session's
/// asks, the newest first, each one line that a press opens in place into its card, one asleep quieted as its card is;
/// their notes and their parked items in two columns. Each line names its session, where the project has several.
struct ProjectPageView: View {
    let page: ProjectPage
    let now: Date

    @Environment(\.windowActions) private var act

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            VStack(alignment: .leading, spacing: 6) {
                PageTitle(words: page.name)
                Text(Words.project(waiting: page.waiting, open: page.open))
                    .font(WindowStyle.ui(14))
                    .foregroundStyle(WindowStyle.soft)
            }
            .padding(.top, 6)
            .padding(.bottom, 26)
            sessions.padding(.bottom, 26)
            if !page.asks.isEmpty {
                asks.padding(.bottom, 26)
            }
            TwoColumns {
                VStack(alignment: .leading) {
                    if !page.notes.isEmpty {
                        NotesSection(notes: page.notes, opened: page.opened, now: now)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !page.parked.isEmpty {
                    ParkedSection(parked: page.parked, opened: page.opened, now: now)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.bottom, 34)
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Sessions", note: "\(page.open) open").padding(.bottom, 8)
            ForEach(page.sessions) { session in
                Button { act.pick(.session(session.id)) } label: {
                    ProjectSessionRow(session: session, now: now).padding(.horizontal, WindowStyle.reach)
                }
                .rowButton()
                .padding(.horizontal, -WindowStyle.reach)
            }
        }
    }

    private var asks: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(
                name: "Asks", note: page.asksWaiting > 0 ? Words.waiting(page.asksWaiting) : nil, isOrange: true
            )
            .padding(.bottom, 8)
            ForEach(page.asks) { ask in
                if ask.isOpened {
                    CardView(card: ask.card, session: ask.session, now: now) { act.toggle(ask.id) }
                        .padding(.vertical, 4)
                } else {
                    Button { act.toggle(ask.id) } label: {
                        HStack(spacing: 10) {
                            if ask.card.isClosed {
                                ClosedTick()
                            } else {
                                MarkView(mark: ask.card.mark)
                            }
                            Text(ask.card.title)
                                .foregroundStyle(Self.ink(ask.card))
                                .led(by: ask.session)
                                .font(WindowStyle.ui(13))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Words.age(ask.card.since, at: now)).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, WindowStyle.reach)
                        .contentShape(Rectangle())
                    }
                    .rowButton(radius: 6)
                    .padding(.horizontal, -WindowStyle.reach)
                }
            }
        }
    }

    /// An ask's line's title: faint once closed, soft while asleep.
    private static func ink(_ card: Card) -> Color {
        card.isClosed ? WindowStyle.faint : card.snoozedUntil == nil ? WindowStyle.text : WindowStyle.soft
    }
}

/// A project's session: its mark, its name, and what it is doing beneath, a working one's lead shimmering as its
/// sidebar row's does; what waits there in orange, else its time. While no window holds it, its name and what it is
/// doing dim as one (`Away`).
private struct ProjectSessionRow: View {
    let session: ProjectPage.Session
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MarkView(mark: session.mark)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(WindowStyle.ui(14, .semibold))
                    .spacing(-0.01, of: 14)
                    .foregroundStyle(WindowStyle.text)
                doing.font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.soft).lineLimit(1)
            }
            .opacity(awayDim)
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if session.waiting > 0 {
                    Text(Words.waiting(session.waiting)).foregroundStyle(WindowStyle.orange)
                } else {
                    Text(Words.age(session.since, at: now)).foregroundStyle(WindowStyle.faint)
                }
            }
            .font(WindowStyle.ui(12))
            .frame(height: 18)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var awayDim: Double {
        session.isAway ? Away.dim : 1
    }

    private var doing: some View {
        HStack(spacing: 6) {
            if session.doing.kind == .working {
                ShimmeringLead { isLit in
                    Text(session.doing.line.lead).font(WindowStyle.ui(12)).lineLimit(1)
                        .foregroundStyle(isLit ? WindowStyle.text : WindowStyle.soft)
                }
            } else {
                Text(session.doing.line.lead)
            }
            if let mono = session.doing.line.mono {
                Text(mono).font(WindowStyle.mono(12))
            } else if let subject = Words.subject(session.doing.line, at: now) {
                Text(subject)
            }
        }
    }
}
