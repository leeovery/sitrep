import Foundation
import SitRepTestSupport
import Testing

/// The recordings' lists hold their values and nothing more: one left over fails the decoding, not passes unread.
@Suite(.backstop)
struct StripRecordedTests {
    private static let frame = #"{"t": 16, "p": [18, 213], "hair": [191.5, 1, 1], "ends": [26, 600, 0], "#
        + #""tabs": [{"key": "s5", "phase": "open", "w": 1, "h": 24, "y": 213, "press": 0, "alpha": 1, "#
        + #""words": [["s5", 0.2]], "top": [36, 191, 10, 90, "edge"], "bottom": [36, 235, 10, 90, "s"]}], "#
        + #""marks": [[251.42, 1, 1], null], "more": [3, 400, 1, 1], "moreNeeds": [2, 420, 1, 1]}"#

    private func decode(_ json: String) throws -> StripRecorded {
        try JSONDecoder().decode(StripRecorded.self, from: Data(json.utf8))
    }

    @Test func aFrameWithEachListAtItsLengthDecodes() throws {
        let frame = try decode(Self.frame)

        #expect(frame.p == CGPoint(x: 18, y: 213) && frame.hair.op == 1 && frame.ends.drawnIn == 0)
        #expect(frame.tabs[0].words == [StripRecorded.Words(key: "s5", alpha: 0.2)] && frame.tabs[0].bottom?.on == .s)
        #expect(frame.marks[1] == nil && frame.more?.n == 3 && frame.moreNeeds?.mark.y == 420)
    }

    @Test(arguments: [
        ("[18, 213]", "[18, 213, 5]"),
        ("\"hair\": [191.5, 1, 1]", "\"hair\": [191.5, 1, 1, 999]"),
        ("[26, 600, 0]", "[26, 600, 0, 1]"),
        ("[\"s5\", 0.2]", "[\"s5\", 0.2, 1]"),
        ("[36, 191, 10, 90, \"edge\"]", "[36, 191, 10, 90, \"edge\", 1]"),
        ("[3, 400, 1, 1]", "[3, 400, 1, 1, 1]"),
    ])
    func aListWithAValueLeftOverFails(list: String, long: String) {
        #expect(Self.frame.contains(list))
        #expect(throws: DecodingError.self) { try decode(Self.frame.replacingOccurrences(of: list, with: long)) }
    }
}
