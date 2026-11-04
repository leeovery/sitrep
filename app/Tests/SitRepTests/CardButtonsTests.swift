import AppKit
@testable import SitRep
import SitRepWindow
import SwiftUI
import Testing

/// A card's buttons as Paper's board I1 ("Answer buttons") lays them out: on one line while they fit; else its answers
/// one under another, each as wide as its words, wrapping only past 480 or the card, the rest on a line 12 after them.
struct CardButtonsTests {
    private static let choice: [Card.Button] = [
        .option("Mint a token"), .option("Reuse"), .option("Ask each time"), .inClaude(.comment), .ignore, .snooze,
    ]

    private static func ideal(_ widths: [CGFloat]) -> [CGSize] {
        widths.map { CGSize(width: $0, height: 26) }
    }

    /// Its one-line size within a width it fits, else that width's lines, 4 short of it, 16 a line under the first.
    private static func within(_ ideal: [CGSize]) -> (Int, ProposedViewSize) -> CGSize {
        { offset, proposal in
            let words = ideal[offset], width = proposal.width ?? .infinity

            guard words.width > width else {
                return words
            }
            return CGSize(width: width - 4, height: words.height + 16 * (words.width / width).rounded(.up) - 16)
        }
    }

    private static func places(_ widths: [CGFloat], in width: CGFloat) -> [CardButtons.Place] {
        let ideal = ideal(widths)

        return CardButtons(buttons: choice).places(width, ideal: ideal, within: within(ideal))
    }

    private static func frames(_ widths: [CGFloat], in width: CGFloat) -> [CGRect] {
        places(widths, in: width).map(\.frame)
    }

    @Test func buttonsThatFitSitSideBySideAtTheirOwnWidths() {
        let frames = Self.frames([90, 50, 100, 140, 50, 70], in: 700)

        #expect(frames.map(\.minX) == [0, 98, 156, 264, 412, 470])
        #expect(frames.map(\.width) == [90, 50, 100, 140, 50, 70])
        #expect(frames.map(\.minY) == Array(repeating: 0, count: 6))
    }

    @Test func aLongChoicesAnswersStandOneUnderAnotherEachAsWideAsItsWords() {
        let frames = Self.frames([300, 120, 200, 140, 50, 70], in: 600)

        #expect(frames[0 ..< 3].map(\.width) == [300, 120, 200])
        #expect(frames[0 ..< 3].map(\.minX) == [0, 0, 0])
        #expect(frames[0 ..< 3].map(\.minY) == [0, 32, 64])
    }

    @Test func theRestGoOnALine12AfterTheAnswersAtTheirOwnWidths() {
        let frames = Self.frames([300, 120, 200, 140, 50, 70], in: 600)
        let line: CGFloat = 64 + 26 + 12

        #expect(frames[3...].map(\.minX) == [0, 148, 206])
        #expect(frames[3...].map(\.width) == [140, 50, 70])
        #expect(frames[3...].map(\.minY) == [line, line, line])
    }

    @Test func anAnswerWrapsOnlyPast480OnAWideCard() {
        let places = Self.places([620, 120, 200, 140, 50, 70], in: 700)

        #expect(places[0].frame == CGRect(x: 0, y: 0, width: 476, height: 42))
        #expect(places[1].frame.minY == 48)
        #expect(places[0 ..< 3].map(\.proposal.width) == [480, 120, 200])
    }

    @Test func aRowIsPlacedWithTheWidthItWasMeasuredAtNotItsFrames() {
        let places = Self.places([620, 120, 200, 140, 50, 70], in: 700)

        #expect(places[0].proposal == ProposedViewSize(width: 480, height: nil))
        #expect(places[3...].map(\.proposal) == Array(repeating: .unspecified, count: 3))
    }

    @Test func onANarrowCardAnAnswerWrapsAtTheCardsWidth() {
        let places = Self.places([450, 120, 200, 140, 50, 70], in: 400)

        #expect(places[0].frame == CGRect(x: 0, y: 0, width: 396, height: 42))
        #expect(places[0].proposal.width == 400)
    }

    @Test func whereTheRestOverflowTooEveryButtonIsARowAsWideAsItsWords() {
        let frames = Self.frames([200, 120, 180, 140, 50, 70], in: 250)

        #expect(frames.map(\.width) == [200, 120, 180, 140, 50, 70])
        #expect(frames.map(\.minX) == [0, 0, 0, 0, 0, 0])
        #expect(frames.map(\.minY) == [0, 32, 64, 96, 128, 160])
    }
}

/// A card's pill that wraps: as wide as its words, never the width it is given, wrapping only within it.
@MainActor
struct WrappingPillTests {
    private static func size(_ words: String, in width: CGFloat) -> CGSize {
        NSHostingController(rootView: Pill(words: words, look: .white, wraps: true) {})
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

    @Test func wrappedThenGivenItsOwnWidthBackItKeepsItsSize() {
        let wrapped = Self.size(Self.long, in: 300)

        #expect(Self.size(Self.long, in: wrapped.width) == wrapped)
    }
}

/// One look per role, whatever the ask (board I1, drawn again by A1 and A2 revised): an answer given here white,
/// what leaves for Claude outlined with its ↗, Ignore in Snooze's soft grey.
struct CardButtonLookTests {
    @Test func aYesAndAnOptionShareTheWhiteLook() {
        #expect(Pill.Look(.yes("Merge it")) == .white)
        #expect(Pill.Look(.option("Left")) == .white)
    }

    @Test func commentAndAnswerInClaudeShareTheOutlinedLook() {
        #expect(Pill.Look(.inClaude(.comment)) == .outlined)
        #expect(Pill.Look(.inClaude(.answer)) == .outlined)
    }

    @Test func onlyWhatLeavesForClaudeHasItsArrowWhateverAnAnswersWords() {
        #expect(Card.Button.inClaude(.comment).leaves)
        #expect(Card.Button.inClaude(.answer).leaves)
        #expect(!Card.Button.option("Open it ↗").leaves)
        #expect(!Card.Button.yes("Ship ↗").leaves)
    }

    @Test func ignoreRestsInTheSoftGreyAsSnoozeDoes() {
        #expect(Pill.Look(.ignore) == .quiet)
        #expect(Pill.Look.quiet.ink(.none) == WindowStyle.soft)
        #expect(Pill.Look.quiet.ink(.hover) == WindowStyle.text)
    }
}
