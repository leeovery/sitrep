import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct LineBufferTests {
    @Test func aChunkGivesTheLinesItEnds() {
        var buffer = LineBuffer(longest: 100)

        #expect(buffer.lines(adding: Data("one\ntwo\n".utf8)) == ["one", "two"])
        #expect(buffer.rest() == nil)
    }

    @Test func aLineSplitAcrossChunksIsGivenOnceItsNewlineComes() {
        var buffer = LineBuffer(longest: 100)
        let given = ["{\"v\":1,", "\"at\":17", "92445574706}\n{\"v\""].map { buffer.lines(adding: Data($0.utf8)) }

        #expect(given == [[], [], [#"{"v":1,"at":1792445574706}"#]])
        #expect(buffer.rest() == #"{"v""#)
        #expect(buffer.rest() == nil)
    }

    @Test func aCharacterSplitAcrossChunksIsGivenWhole() {
        var buffer = LineBuffer(longest: 100)
        let dot = Array("·\n".utf8)

        #expect(buffer.lines(adding: Data(dot.prefix(1))) == [])
        #expect(buffer.lines(adding: Data(dot.dropFirst())) == ["·"])
    }

    @Test func blankLinesAreDropped() {
        var buffer = LineBuffer(longest: 100)

        #expect(buffer.lines(adding: Data("\none\n\n\ntwo\n".utf8)) == ["one", "two"])
    }

    @Test func aLineIsKeptOnlyToItsLongestAcrossChunks() {
        var buffer = LineBuffer(longest: 5)
        let given = ["abc", "defg", "hi\nshort\nlonger"].map { buffer.lines(adding: Data($0.utf8)) }

        #expect(given == [[], [], ["abcde", "short"]])
        #expect(buffer.rest() == "longe")
    }

    @Test func aLineAsLongAsItsLongestIsWhole() {
        var buffer = LineBuffer(longest: 5)

        #expect(buffer.lines(adding: Data("abcde\n".utf8)) == ["abcde"])
    }

    /// However many chunks come with no newline, what it keeps of the line never grows past its longest. What each
    /// chunk costs to scan is left unpinned: no seam counts it, and a clock's measure failed on a loaded Mac.
    @Test func whatItKeepsOfALineWithNoNewlineStopsAtItsLongest() {
        var buffer = LineBuffer(longest: 1 << 20)
        let chunk = Data(repeating: UInt8(ascii: "a"), count: 64 * 1024)
        var kept: [Int] = []

        for _ in 1...80 {
            _ = buffer.lines(adding: chunk)
            kept.append(buffer.keptCount)
        }

        #expect(kept.max() == 1 << 20)
        #expect(buffer.rest()?.utf8.count == 1 << 20)
    }
}
