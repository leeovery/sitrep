import SitRepWindow
import SwiftUI

/// An ask as a card: its mark, title and time, after its session's name where it is a project's; where to look and
/// what its words are; its buttons; and where Lee's answer is. One closed while it showed keeps its place, faint and
/// without buttons, saying how it closed. Opened in place in a project's view, its head, and only its head, closes
/// it again.
struct CardView: View {
    let card: Card
    var session: String?
    let now: Date
    var closesBack: (() -> Void)?

    @Environment(\.windowActions) private var act
    @Environment(\.isJumping) private var isJumping

    var body: some View {
        if card.lines == [.closed(.sent)] {
            head(sent)
        } else {
            VStack(alignment: .leading, spacing: card.isClosed ? 8 : 10) {
                head(title)
                details
                if !card.buttons.isEmpty {
                    buttons
                }
                ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                    CardLine(line: line, now: now)
                }
            }
            .padding(.top, 13)
            .padding(.bottom, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Washed(since: card.washed, now: now, radius: 14))
            .background(RoundedRectangle(cornerRadius: 14).fill(card.isClosed ? .clear : WindowStyle.raise))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(WindowStyle.line, lineWidth: card.isClosed ? 1 : 0))
        }
    }

    /// Closed by Lee's answer: one faint line, "sent, and Claude has it".
    private var sent: some View {
        HStack(spacing: 10) {
            Text("✓").font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.text).frame(width: WindowStyle.lane.width)
            titled(WindowStyle.faint)
                .font(WindowStyle.ui(14, .semibold))
                .spacing(-0.01, of: 14)
                .lineLimit(1)
            Text(Words.closed(.sent))
                .font(WindowStyle.ui(12))
                .foregroundStyle(WindowStyle.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
    }

    private var title: some View {
        HStack(spacing: 10) {
            if card.isClosed {
                Text("✓").font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.soft).frame(width: WindowStyle.lane.width)
            } else {
                MarkView(mark: .needs)
            }
            titled(card.isClosed ? WindowStyle.faint : WindowStyle.text)
                .font(WindowStyle.ui(14, .semibold))
                .spacing(-0.01, of: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Words.age(card.since, at: now)).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint)
        }
    }

    /// Its head, which closes it back to its line where it can.
    @ViewBuilder private func head(_ content: some View) -> some View {
        if let closesBack {
            Button(action: closesBack) { content.contentShape(Rectangle()) }.buttonStyle(.plain)
        } else {
            content
        }
    }

    /// Its title in this colour, after its session's name where it is a project's.
    private func titled(_ colour: Color) -> Text {
        (session.map { Text("\($0): ").foregroundStyle(WindowStyle.soft) } ?? Text(""))
            + Text(card.title).foregroundStyle(colour)
    }

    @ViewBuilder private var details: some View {
        if !card.isClosed {
            if let needs = card.needs {
                HStack(spacing: 5) {
                    Text("needs:").foregroundStyle(WindowStyle.faint)
                    Text(needs).foregroundStyle(WindowStyle.soft)
                }
                .font(WindowStyle.ui(12))
                .padding(.leading, 22)
            }
            if let place = card.where {
                Text(place).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.soft).padding(.leading, 22)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            ForEach(card.buttons, id: \.self) { button in
                Pill(words: Words.button(button), look: Self.look(button)) { act.press(button, card.id) }
                    .disabled(button.answer == nil && isJumping)
            }
        }
        .padding(.leading, 22)
        .padding(.top, 4)
    }

    /// The yes, and an answer only Claude Code's prompt takes, white; an option on its fill; a comment outlined;
    /// ignore, quiet.
    private static func look(_ button: Card.Button) -> Pill.Look {
        switch button {
        case .yes, .inClaude(.answer): .white
        case .option: .option
        case .inClaude(.comment): .outlined
        case .ignore: .quiet
        }
    }
}

/// A line under a card's buttons: the answer as the board words it, bright, then where it is, faint; while it waits
/// its two seconds, a line under it draining.
private struct CardLine: View {
    let line: Card.Line
    let now: Date

    var body: some View {
        let (answer, words) = Words.line(line)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let answer {
                    Text(answer).font(WindowStyle.ui(12, .semibold)).foregroundStyle(WindowStyle.text)
                }
                Text(words).font(WindowStyle.ui(12)).foregroundStyle(isFaint ? WindowStyle.faint : WindowStyle.soft)
            }
            if case let .waiting(pending) = line {
                Draining(left: 1 - pending.waited(at: now))
            }
        }
        .padding(.leading, 22)
    }

    private var isFaint: Bool {
        switch line {
        case .closed, .refused: false
        default: true
        }
    }
}

/// What is left of an answer's two seconds, as a line that drains.
private struct Draining: View {
    let left: Double

    var body: some View {
        GeometryReader { size in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(WindowStyle.line)
                RoundedRectangle(cornerRadius: 1).fill(WindowStyle.text).frame(width: size.size.width * left)
            }
        }
        .frame(height: 2)
    }
}
