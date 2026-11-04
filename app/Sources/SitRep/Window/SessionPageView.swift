import SitRepCore
import SitRepWindow
import SwiftUI

/// A session's page under the empty band beside the traffic lights (Paper's "Window redesign", A1 and A2 revised).
/// Beside a place's list, the detail: "Project › Session" as a breadcrumb, its project's part opening the project's
/// page, and "Open in Ghostty ↗" trailing it while a window holds the session; what its window is doing; the picked
/// line's card leading. Filling the window: its project's name as an eyebrow, where a project's page has its title,
/// which a press opens; its name, "Open in Ghostty ↗" on its row; the meta line, where its window is and when it
/// started; what its window is doing, or the stop in that line's place; every ask's card. Then on both Now and What
/// happened, and, away, finishing it.
struct SessionPageView: View {
    let page: SessionPage
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.pressedJump) private var pressedJump
    @Environment(\.wakeCalendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            switch page.mode {
            case .detail: breadcrumb
            case .full: head
            }
            doing
            cards
            if let failure = page.failure {
                Text(failure).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint).padding(.top, 20)
            }
            if page.hasNow {
                NowSection(page: page, now: now).padding(.top, WindowStyle.sectionGap)
            }
            if page.hasBoard, !page.happened.isEmpty || !page.resolved.isEmpty {
                HappenedSection(page: page, now: now).padding(.top, WindowStyle.sectionGap)
            }
            if let finish = page.finish {
                FinishFoot(session: page.id, name: page.name, finish: finish).padding(.top, 30)
            }
        }
        .padding(.bottom, 34)
    }

    /// Beside the list: "Project › Session", the project's part a link to its page, and the jump trailing.
    private var breadcrumb: some View {
        TitleRow {
            HStack(spacing: 7) {
                Button(page.projectName) { act.openProject(page.projectKey) }
                    .wordsButton(WindowStyle.crumb)
                Chevron(isFolded: true).foregroundStyle(WindowStyle.dim)
                Text(page.name).foregroundStyle(WindowStyle.headingText).accessibilityAddTraits(.isHeader)
            }
            .font(WindowStyle.ui(13, .medium))
            if page.jumps {
                jump
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    /// Filling the window: the eyebrow, its name with the jump on its row, and the meta line, away its mark before it,
    /// as no doing line under it says it.
    private var head: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(page.projectName) { act.openProject(page.projectKey) }
                .wordsButton()
                .font(WindowStyle.ui(15, .semibold))
                .accessibilityAddTraits(.isHeader)
            TitleRow {
                PageTitle(words: page.name)
                if page.jumps {
                    jump
                }
            }
            if let meta = page.meta, let words = Words.meta(meta, at: now, in: calendar) {
                HStack(spacing: 8) {
                    if meta.away != nil {
                        MarkView(mark: page.mark)
                    }
                    Text(words)
                        .font(WindowStyle.ui(12))
                        .foregroundStyle(WindowStyle.dim)
                        .accessibilityLabel(Spoken.meta(meta, at: now, in: calendar))
                }
                .padding(.top, 3)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 14)
    }

    private var jump: some View {
        Button { act.jump(.open(page.id)) } label: {
            HStack(spacing: 5) {
                Text(Words.jump).foregroundStyle(WindowStyle.text)
                Text(Words.leaves).foregroundStyle(WindowStyle.soft).accessibilityHidden(true)
            }
            .font(WindowStyle.ui(12, .medium))
            .frame(height: 28)
            .padding(.horizontal, 11)
        }
        .jumpButton()
        .disabled(pressedJump == .open(page.id))
    }

    @ViewBuilder private var doing: some View {
        switch page.doingLine {
        case .line: DoingLine(page: page, now: now).padding(.bottom, 16)
        case let .stop(stop): StopCard(stop: stop, session: page.id, now: now).padding(.bottom, 10)
        case .none: EmptyView()
        }
    }

    /// Beside the list, the picked line's card, larger; filling the window, every ask's.
    @ViewBuilder private var cards: some View {
        switch page.lead {
        case let .ask(card): CardView(card: card, now: now, leads: true).id(card.id)
        case let .stop(stop): StopCard(stop: stop, session: page.id, now: now, leads: true)
        case nil:
            if !page.cards.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(page.cards) { card in
                        CardView(card: card, now: now)
                    }
                }
            }
        }
    }
}

/// What a session's window is doing, its mark beside it, a working lead turning and shimmering as its row's, then what
/// it acts on and how long its turn has run or since it ended; a stop's words where a stop's card leads elsewhere.
private struct DoingLine: View {
    let page: SessionPage
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            MarkView(mark: page.mark)
            switch page.doing.kind {
            case .away:
                Text(page.doing.line.lead).font(WindowStyle.ui(13)).foregroundStyle(WindowStyle.faint)
            case .onItsWork:
                Text(page.doing.line.lead).font(WindowStyle.ui(13, .medium)).foregroundStyle(WindowStyle.soft)
            case .working:
                ShimmeringLead { isLit in lead.foregroundStyle(isLit ? WindowStyle.text : WindowStyle.soft) }
            default:
                lead.foregroundStyle(WindowStyle.text)
            }
            if let mono = page.doing.line.mono {
                Text(mono).font(WindowStyle.mono(12)).foregroundStyle(WindowStyle.soft).lineLimit(1)
            } else if let subject = Words.subject(page.doing.line, at: now) {
                Text(subject).font(WindowStyle.ui(13)).foregroundStyle(WindowStyle.soft).lineLimit(1)
            }
            if let time = Words.turn(page.doing, at: now) {
                Text(time).font(WindowStyle.ui(13)).foregroundStyle(WindowStyle.faint).fixedSize()
            }
        }
    }

    /// What its window is doing, as the line's lead.
    private var lead: some View {
        Text(page.doing.line.lead).font(WindowStyle.ui(13, .medium)).lineLimit(1)
    }
}

/// A permission prompt or a question, washed orange as the panel row that brought it: the tool and what it would run,
/// that it is answered in Claude Code, and the jump there. Filling the window it stands in the state line's place;
/// beside the list, as the line picked, it leads, larger, as an ask's card does.
private struct StopCard: View {
    let stop: SessionPage.Stop
    let session: String
    let now: Date
    var leads = false

    @Environment(\.windowActions) private var act
    @Environment(\.pressedJump) private var pressedJump

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                MarkView(mark: .needs)
                Text(stop.line.lead)
                    .font(WindowStyle.ui(titleSize, .semibold))
                    .spacing(-0.01, of: titleSize)
                    .foregroundStyle(WindowStyle.text)
                    .lineLimit(1)
                Group {
                    if let mono = stop.line.mono {
                        Text(mono).font(WindowStyle.mono(leads ? 14 : 12))
                    } else if let more = stop.line.more {
                        Text(more).font(WindowStyle.ui(titleSize, .semibold))
                    }
                }
                .foregroundStyle(WindowStyle.soft)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Words.age(stop.since, at: now)).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
            }
            if let stopped = Words.stopped(stop.kind) {
                Text(stopped)
                    .font(WindowStyle.ui(13))
                    .foregroundStyle(WindowStyle.soft)
                    .padding(.leading, 22)
            }
            Pill(words: Words.label(.inClaude(.answer)), look: Pill.Look(.inClaude(.answer)), leaves: true) {
                act.jump(.stop(session))
            }
                .disabled(pressedJump == .stop(session))
                .padding(.leading, 22)
                .padding(.top, 4)
        }
        .padding(.top, leads ? 18 : 13)
        .padding(.bottom, leads ? 18 : 14)
        .padding(.leading, leads ? 18 : 14)
        .padding(.trailing, leads ? 20 : 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(WindowStyle.wash))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(WindowStyle.washRing, lineWidth: 1))
    }

    /// Its title's size, as an ask's card's (`CardView`).
    private var titleSize: CGFloat { leads ? 18 : 15 }
}

/// An away session's foot: "✓ Finish this session", which asks first, in place, then runs `sitrep finish`.
private struct FinishFoot: View {
    let session: String
    let name: String
    let finish: Finish

    @Environment(\.windowActions) private var act

    var body: some View {
        HStack(spacing: 14) {
            switch finish {
            case .offered:
                Pill(words: Words.finish, look: .outlined) { act.askToFinish(session) }
                note(Words.finishWhy)
            case .asking, .finishing:
                note(Words.finishing(name), colour: WindowStyle.text)
                Pill(words: "Yes, finish it", look: .white) { act.confirmFinish(session) }
                    .disabled(finish == .finishing)
                Pill(words: "Cancel", look: .quiet) { act.cancelFinish(session) }
                    .disabled(finish == .finishing)
            case let .refused(why):
                Pill(words: Words.finish, look: .outlined) { act.askToFinish(session) }
                note(why)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(WindowStyle.line).frame(height: 1) }
    }

    private func note(_ words: String, colour: Color = WindowStyle.faint) -> some View {
        Text(words).font(WindowStyle.ui(12)).foregroundStyle(colour)
    }
}

extension WindowStyle {
    // MARK: A session's page (A1 and A2 revised)

    /// The detail beside the list, in from its edges.
    static let detailInset: CGFloat = 36
    /// Above Now and above What happened.
    static let sectionGap: CGFloat = 26
    /// A section's lines in from its heading.
    static let sectionIndent: CGFloat = 14
    /// A section's heading, white at 85%, and the breadcrumb's session.
    static let headingText = Color.white.opacity(Double(0xD9) / 255)
    /// The breadcrumb's project, white at 65%.
    static let crumb = Color.white.opacity(Double(0xA6) / 255)
    /// What happened's words, white at 70%; its marks, and the line down them, white at 12%.
    static let threadText = Color.white.opacity(Double(0xB3) / 255)
    static let threadMark = Color(hex: 0x8E8E95)
    static let threadRule = Color.white.opacity(Double(0x1F) / 255)
    /// Now's marks: its lines' dot, next's ring, later's diamond in white at 45%.
    static let nowMark = Color(hex: 0xA8A8AF)
    static let nextMark = Color(hex: 0x6E6E76)
    static let laterMark = Color.white.opacity(0.45)
}
