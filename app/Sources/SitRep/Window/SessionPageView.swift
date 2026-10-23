import SitRepCore
import SitRepWindow
import SwiftUI

/// The session picked, at window size, under the empty band beside the traffic lights: its project's name as an
/// eyebrow, where a project's page has its title, which a press opens; its name, and "Open in Ghostty ↗" on its row
/// while a window holds it; its summary; what its window is doing, or the stop that takes that line's place; then
/// Asks, and Status, Notes, Parked and Resolved in two columns; and, away, finishing it.
struct SessionPageView: View {
    let page: SessionPage
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.pressedJump) private var pressedJump

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Button(page.projectName) { act.pick(.project(page.projectKey)) }
                        .wordsButton()
                        .font(WindowStyle.ui(15, .semibold))
                        .accessibilityAddTraits(.isHeader)
                    TitleRow {
                        PageTitle(words: page.name)
                        if page.jumps {
                            jump
                        }
                    }
                }
                Text(page.summary).font(WindowStyle.ui(14)).foregroundStyle(WindowStyle.soft)
            }
            .padding(.top, 6)
            doing
            if !page.asks.isEmpty {
                asks.padding(.bottom, 28)
            }
            details
            if let finish = page.finish {
                FinishFoot(session: page.id, name: page.name, finish: finish).padding(.top, 30)
            }
        }
        .padding(.bottom, 34)
    }

    private var jump: some View {
        Button { act.jump(.open(page.id)) } label: {
            HStack(spacing: 6) {
                Text(Words.jump).foregroundStyle(WindowStyle.text)
                Text("↗").foregroundStyle(WindowStyle.soft).accessibilityHidden(true)
            }
            .font(WindowStyle.ui(12, .medium))
            .padding(.vertical, 5)
            .padding(.leading, 11)
            .padding(.trailing, 10)
        }
        .jumpButton()
        .disabled(pressedJump == .open(page.id))
    }

    @ViewBuilder private var doing: some View {
        if page.doing.isStopped {
            StopCard(stop: page.doing, session: page.id, now: now).padding(.top, 20).padding(.bottom, 28)
        } else {
            HStack(spacing: 8) {
                MarkView(mark: page.doing.mark)
                switch page.doing.kind {
                case .away:
                    Text(page.doing.line.lead).font(WindowStyle.ui(13)).foregroundStyle(WindowStyle.faint)
                case .onItsWork:
                    Text(page.doing.line.lead).font(WindowStyle.ui(13, .medium)).foregroundStyle(WindowStyle.soft)
                default:
                    ShimmeringLead(text: page.doing.line.lead, isOn: page.doing.kind == .working)
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
            .padding(.top, 14)
            .padding(.bottom, 26)
        }
    }

    private var asks: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(
                name: "Asks", note: page.waiting > 0 ? Words.waiting(page.waiting) : nil, isOrange: true,
                aside: Words.snoozed(page.snoozed)
            )
            .padding(.bottom, 4)
            ForEach(page.asks) { card in
                CardView(card: card, now: now)
            }
        }
    }

    /// Its board's sections as last read, under why the latest read failed, if it did.
    @ViewBuilder private var details: some View {
        if let failure = page.failure {
            Text(failure).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint).padding(.bottom, 20)
        }
        if page.isRead {
            TwoColumns {
                VStack(alignment: .leading, spacing: 26) {
                    StatusSection(status: page.status, opened: page.opened, now: now)
                    if !page.notes.isEmpty {
                        NotesSection(notes: page.notes, opened: page.opened, now: now)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !page.parked.isEmpty || !page.resolved.isEmpty {
                    VStack(alignment: .leading, spacing: 26) {
                        if !page.parked.isEmpty {
                            ParkedSection(parked: page.parked, opened: page.opened, now: now)
                        }
                        if !page.resolved.isEmpty {
                            ResolvedSection(resolved: page.resolved, opened: page.opened, now: now)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// A working line's lead, grey with a slow sweep of white along it, as Claude Code's own; your turn's, still and
/// white. Still, as under reduced motion, the sweep holds where the drawing has it, a little before the middle.
struct ShimmeringLead: View {
    let text: String
    let isOn: Bool

    @Environment(\.reducesWindowMotion) private var reducesMotion
    /// Where the sweep's band starts, in widths of the words: off them at -0.6 and at 1.
    @State private var sweep = Self.still

    var body: some View {
        let words = Text(text).font(WindowStyle.ui(13, .medium)).lineLimit(1)

        if isOn {
            words
                .foregroundStyle(WindowStyle.soft)
                .overlay {
                    GeometryReader { size in
                        words
                            .foregroundStyle(WindowStyle.text)
                            .mask(alignment: .leading) {
                                LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                                    .frame(width: size.size.width * 0.6)
                                    .offset(x: sweep * size.size.width)
                            }
                    }
                }
                .onAppear(perform: follow)
                .onChange(of: reducesMotion, follow)
        } else {
            words.foregroundStyle(WindowStyle.text)
        }
    }

    /// Sweeping, or held where the drawing has it the moment motion is reduced.
    private func follow() {
        withTransaction(\.disablesAnimations, true) { sweep = reducesMotion ? Self.still : -0.6 }
        if !reducesMotion {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { sweep = 1 }
        }
    }

    private static let still = 0.12
}

/// A permission prompt or a question, in the state line's place, washed orange as the panel row that brought it: the
/// tool and what it would run, that it is answered in Claude Code, and the jump there.
private struct StopCard: View {
    let stop: Doing
    let session: String
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.pressedJump) private var pressedJump

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                MarkView(mark: .needs)
                Text(stop.line.lead)
                    .font(WindowStyle.ui(14, .semibold))
                    .spacing(-0.01, of: 14)
                    .foregroundStyle(WindowStyle.text)
                    .lineLimit(1)
                Group {
                    if let mono = stop.line.mono {
                        Text(mono).font(WindowStyle.mono(12))
                    } else if let more = stop.line.more {
                        Text(more).font(WindowStyle.ui(14, .semibold))
                    }
                }
                .foregroundStyle(WindowStyle.soft)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Words.age(stop.since, at: now)).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
            }
            if let stopped = Words.stopped(stop.kind) {
                Text(stopped)
                    .font(WindowStyle.ui(12))
                    .foregroundStyle(WindowStyle.soft)
                    .padding(.leading, 22)
            }
            Pill(words: Words.button(.inClaude(.answer)), look: .white) { act.jump(.stop(session)) }
                .disabled(pressedJump == .stop(session))
                .padding(.leading, 22)
                .padding(.top, 4)
        }
        .padding(.top, 13)
        .padding(.bottom, 14)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(WindowStyle.wash))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(WindowStyle.washRing, lineWidth: 1))
    }
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
