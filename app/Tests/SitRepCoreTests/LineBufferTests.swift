import Foundation
@testable import SitRepCore
import Testing

struct LineBufferTests {
    @Test func aChunkGivesTheLinesItEnds() {
        var buffer = LineBuffer()

        #expect(buffer.lines(adding: Data("one\ntwo\n".utf8)) == ["one", "two"])
        #expect(buffer.rest() == nil)
    }

    @Test func aLineSplitAcrossChunksIsGivenOnceItsNewlineComes() {
        var buffer = LineBuffer()
        let given = ["{\"v\":1,", "\"at\":17", "92445574706}\n{\"v\""].map { buffer.lines(adding: Data($0.utf8)) }

        #expect(given == [[], [], [#"{"v":1,"at":1792445574706}"#]])
        #expect(buffer.rest() == #"{"v""#)
        #expect(buffer.rest() == nil)
    }

    @Test func aCharacterSplitAcrossChunksIsGivenWhole() {
        var buffer = LineBuffer()
        let dot = Array("·\n".utf8)

        #expect(buffer.lines(adding: Data(dot.prefix(1))) == [])
        #expect(buffer.lines(adding: Data(dot.dropFirst())) == ["·"])
    }

    @Test func blankLinesAreDropped() {
        var buffer = LineBuffer()

        #expect(buffer.lines(adding: Data("\none\n\n\ntwo\n".utf8)) == ["one", "two"])
    }
}
