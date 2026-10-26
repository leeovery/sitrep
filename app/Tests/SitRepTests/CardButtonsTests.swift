import AppKit
@testable import SitRep
import SitRepWindow
import SwiftUI
import Testing

/// A card's buttons as Paper's board I1 ("Answer buttons") lays them out: on one line while they fit; else its answers
/// one under another, each as wide as its words, wrapping only past 480 or the card, the rest on a line after them.
struct CardButtonsTests {
    private static let choice: [Card.Button] = [
        .option("Mint a token"), .option("Reuse"), .option("Ask each time"), .inClaude(.comment), .ignore, .snooze,
    ]

    private static func ideal(_ widths: [CGFloat]) -> [CGSize] {
        widths.map { CGSize(width: $0, height: 26) }
    }

    /// Its one-line size within a width it fits, else that width's lines, 4 short of it, 16 a line under the first.
    private static func within(
        _ ideal: [CGSize], asked: @escaping (CGFloat) -> Void = { _ in }
    ) -> (Int, CGFloat) -> CGSize {
        { offset, width in
            asked(width)
            let words = ideal[offset]

            guard words.width > width else {
                return words
            }
            return CGSize(width: width - 4, height: words.height + 16 * (words.width / width).rounded(.up) - 16)
        }
    }

    private static func frames(_ buttons: [Card.Button], _ widths: [CGFloat], in width: CGFloat) -> [CGRect] {
        let ideal = ideal(widths)

        return CardButtons(buttons: buttons).frames(width, ideal: ideal, within: within(ideal))
    }

    @Test func buttonsThatFitSitSideBySideAtTheirOwnWidths() {
        let frames = Self.frames(Self.choice, [90, 50, 100, 140, 50, 70], in: 700)

        #expect(frames.map(\.minX) == [0, 98, 156, 264, 412, 470])
        #expect(frames.map(\.width) == [90, 50, 100, 140, 50, 70])
        #expect(frames.map(\.minY) == Array(repeating: 0, count: 6))
    }

    @Test func aLongChoicesAnswersStandOneUnderAnotherEachAsWideAsItsWords() {
        let frames = Self.frames(Self.choice, [300, 120, 200, 140, 50, 70], in: 600)

        #expect(frames[0 ..< 3].map(\.width) == [300, 120, 200])
        #expect(frames[0 ..< 3].map(\.minX) == [0, 0, 0])
        #expect(frames[0 ..< 3].map(\.minY) == [0, 32, 64])
    }

    @Test func theRestGoOnALineAfterTheAnswersAtTheirOwnWidths() {
        let frames = Self.frames(Self.choice, [300, 120, 200, 140, 50, 70], in: 600)

        #expect(frames[3...].map(\.minX) == [0, 148, 206])
        #expect(frames[3...].map(\.width) == [140, 50, 70])
        let line: CGFloat = 64 + 26 + 8

        #expect(frames[3...].map(\.minY) == [line, line, line])
    }

    @Test func anAnswerWrapsOnlyPast480OnAWideCard() {
        let ideal = Self.ideal([620, 120, 200, 140, 50, 70])
        var asked: [CGFloat] = []
        let frames = CardButtons(buttons: Self.choice).frames(700, ideal: ideal, within: Self.within(ideal) { asked.append($0) })

        #expect(asked == [480, 120, 200])
        #expect(frames[0] == CGRect(x: 0, y: 0, width: 476, height: 42))
        #expect(frames[1].minY == 48)
    }

    @Test func onANarrowCardAnAnswerWrapsAtTheCardsWidth() {
        let frames = Self.frames(Self.choice, [450, 120, 200, 140, 50, 70], in: 400)

        #expect(frames[0] == CGRect(x: 0, y: 0, width: 396, height: 42))
    }

    @Test func whereTheRestOverflowTooEveryButtonIsARowAsWideAsItsWords() {
        let frames = Self.frames(Self.choice, [200, 120, 180, 140, 50, 70], in: 250)

        #expect(frames.map(\.width) == [200, 120, 180, 140, 50, 70])
        #expect(frames.map(\.minX) == [0, 0, 0, 0, 0, 0])
        #expect(frames.map(\.minY) == [0, 32, 64, 96, 128, 160])
    }
}

/// A card's pill that wraps: as wide as its words, never the width it is given, wrapping only within it.
@MainActor
struct WrappingPillTests {
    private static func size(_ words: String, in width: CGFloat) -> CGSize {
        NSHostingController(rootView: Pill(words: words, look: .option, wraps: true) {})
            .sizeThatFits(in: CGSize(width: width, height: 1000))
    }

    private static let long = "Mint a Sanctum token per MCP user on first connect, scoped to the tools that user may call"

    @Test func givenMoreThanItsWordsItKeepsTheirWidthOnOneLine() {
        let short = Self.size("Reuse", in: .infinity)

        #expect(Self.size("Reuse", in: 480) == short)
        #expect(short.width < 100)
    }

    @Test func givenItsOwnWidthItStaysOneLine() {
        let one = Self.size(Self.long, in: .infinity)

        #expect(Self.size(Self.long, in: one.width) == one)
    }

    @Test func givenLessItWrapsItsWordsWithinIt() {
        let one = Self.size(Self.long, in: .infinity)
        let wrapped = Self.size(Self.long, in: 300)

        #expect(one.width > 300)
        #expect(wrapped.width <= 300)
        #expect(wrapped.height > one.height)
    }
}

/// One look per role, whatever the ask (board I1): an answer given here on the option's fill, what leaves for Claude
/// outlined, Ignore in Snooze's soft grey.
struct CardButtonLookTests {
    @Test func aYesAndAnOptionShareTheOptionsLook() {
        #expect(Pill.Look(.yes("Merge it")) == .option)
        #expect(Pill.Look(.option("Left")) == .option)
    }

    @Test func commentAndAnswerInClaudeShareTheOutlinedLook() {
        #expect(Pill.Look(.inClaude(.comment)) == .outlined)
        #expect(Pill.Look(.inClaude(.answer)) == .outlined)
    }

    @Test func ignoreRestsInTheSoftGreyAsSnoozeDoes() {
        #expect(Pill.Look(.ignore) == .quiet)
        #expect(Pill.Look.quiet.ink(.none) == WindowStyle.soft)
        #expect(Pill.Look.quiet.ink(.hover) == WindowStyle.text)
    }
}
