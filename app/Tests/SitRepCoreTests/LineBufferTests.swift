import Foundation
@testable import SitRepCore
import Testing

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

    @Test(.timeLimit(.minutes(1)))
    func outputWithNoNewlineCostsOnlyItsChunks() {
        var buffer = LineBuffer(longest: 1 << 20)
        let chunk = Data(repeating: UInt8(ascii: "a"), count: 64 * 1024)
        let clock = ContinuousClock()
        let started = clock.now

        for _ in 1...80 {
            _ = buffer.lines(adding: chunk)
        }

        #expect(clock.now - started < .seconds(1))
        #expect(buffer.rest()?.utf8.count == 1 << 20)
    }
}
