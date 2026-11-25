import AppKit
@testable import SitRep
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// An answer's words on its row in the asks panel, as Paper's board H3 sets them: wrapped to two lines at most, the
/// second cut short with "…" past them; Claude's pick's "  ·  Recommended" after its words on their last line, alone on
/// the next while there is one, else after its words cut short before it, so it always shows; and the lines the layout
/// leaves room for, measured so.
@MainActor
@Suite(.backstop)
struct AsksAnswerLinesTests {
    private static let width = AsksLayout.answerWidth
    private static let long = "Pair each one with a lead for five shifts, then let them take tickets alone, "
        + "and check in with them at the end of each of those shifts"

    private static func lines(_ answer: String, isPick: Bool, width: Double = width) -> [AsksPanelParts.AnswerLine] {
        AsksPanelParts.answerLines(answer, isPick: isPick, width: width, most: AsksLayout.answerMost)
    }

    /// How wide a line is set: its words, and its tag after them where it has one.
    private static func setWidth(_ line: AsksPanelParts.AnswerLine) -> Double {
        let words = TextLine.width(AsksPanelParts.answerText(line.words, colour: EdgeStyle.ink))
        let tag = line.tag.map { TextLine.width(TextLine.text($0, EdgeStyle.asksNote, EdgeStyle.ink)) } ?? 0

        return words + tag
    }

    /// The words that fill a line all but the room the tag takes, so the tag goes to the next line.
    private static func fillingALine() -> String {
        var words = "Shadow"

        while TextLine.width(AsksPanelParts.answerText(words + " queue", colour: EdgeStyle.ink)) < width - 4 {
            words += " queue"
        }
        return words
    }

    @Test func aShortAnswerIsOneLineAndClaudesPickHasItsTagAfterIt() {
        #expect(Self.lines("Flat", isPick: false) == [.init(words: "Flat", tag: nil)])
        #expect(Self.lines("Threaded", isPick: true) == [.init(words: "Threaded", tag: AsksPanelParts.pickTag)])
        #expect(AsksPanelParts.pickTag == "  ·  Recommended")
    }

    /// Words past one line wrap to a second at a space, nothing cut, the tag after them there.
    @Test func anAnswerWrapsToASecondLineItsTagAfterItsWords() throws {
        let answer = "Pair each one with a lead for five shifts, then let them take tickets alone"
        let pick = Self.lines(answer, isPick: true)

        #expect(pick.count == 2 && pick.map(\.tag) == [nil, AsksPanelParts.pickTag])
        #expect(pick.map(\.words).joined(separator: " ") == answer)
        #expect(pick.allSatisfy { Self.setWidth($0) <= Self.width })
    }

    /// Words filling their one line leave the tag no room after them: it goes alone on the line after, the words whole.
    @Test func aTagWithNoRoomAfterTheWordsGoesOnTheNextLine() {
        let words = Self.fillingALine()

        #expect(Self.lines(words, isPick: true) == [
            .init(words: words, tag: nil), .init(words: "", tag: AsksPanelParts.pickTagAlone),
        ])
        #expect(Self.lines(words, isPick: false) == [.init(words: words, tag: nil)])
    }

    /// The tag alone on its line, as the pick's words fill theirs, is lowered onto the words' baseline: its box drops
    /// by as much as an 11pt line's baseline sits above a 13pt one's.
    @Test func aTagAloneOnItsLineSitsOnTheWordsBaseline() throws {
        let words = Self.fillingALine()
        let ask = PanelAsk(
            id: "k1", title: "Shadow?", wants: .choice, answers: [words, "Flat"], recommended: words, since: 0
        )
        let layout = AsksLayout(ask, measure: .drawn)
        let session = Session(
            id: "sr-nw0001", project: "Northwind", name: "Help desk redesign", kind: .needs, title: "",
            sub: "Northwind", since: 0
        )
        let asks = AsksShown(
            row: "needs:sr-nw0001", session: session, ask: ask, page: 0, pages: 1, layout: layout,
            frame: CGRect(origin: .zero, size: layout.size), sending: nil, hover: nil
        )
        let shown = AsksPanelParts.answerLines(0, of: asks)
        let boxes = AsksLayout.answerBoxes(in: layout.answers[0].size, lines: 2)
        let drop = TextLine.drop(of: EdgeStyle.asksNote, to: EdgeStyle.asksLabel, lineHeight: AsksLayout.answerLine)

        try #require(shown.count == 2)
        #expect(drop > 0)
        #expect(shown[0].box.minY == boxes[0].minY && shown[1].box.minY == boxes[1].minY + drop)
    }

    /// Past two lines, the second ends in "…" where the words run past it; Claude's pick's cut short before its tag,
    /// which always shows.
    @Test(arguments: [false, true])
    func pastTwoLinesTheSecondIsCutShortTheTagStillShowing(isPick: Bool) throws {
        let lines = Self.lines(Self.long, isPick: isPick), last = try #require(lines.last)

        #expect(lines.count == 2)
        #expect(last.words.hasSuffix("…") && last.tag == (isPick ? AsksPanelParts.pickTag : nil))
        #expect(lines.allSatisfy { Self.setWidth($0) <= Self.width })
        #expect(Self.long.hasPrefix(lines[0].words + " " + last.words.dropLast()))
    }

    /// Lines Core Text broke that still measure past the width, short of the most it may take, as mixed
    /// right-to-left words can: the last is cut short after those kept, never read past the breaks.
    @Test func aLastLineWiderThanItsBreakIsCutShortOfTheMost() {
        let lines = AsksPanelParts.answerLines("ab", isPick: false, width: 1, most: 3)

        #expect(lines.count == 2 && lines.first?.words == "a" && lines.last?.words.hasSuffix("…") == true)
    }

    /// The drawn measure leaves room for as many lines as the words are set on, at most two, Claude's pick's tag
    /// counted.
    @Test func theDrawnMeasureCountsTheLinesTheWordsTake() {
        let measure = AsksMeasure.drawn

        #expect(measure.answerLines("Flat", false) == 1)
        #expect(measure.answerLines(Self.fillingALine(), false) == 1)
        #expect(measure.answerLines(Self.fillingALine(), true) == 2)
        #expect(measure.answerLines(Self.long, true) == 2)
    }
}
