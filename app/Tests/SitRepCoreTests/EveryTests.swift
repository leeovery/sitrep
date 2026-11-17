import SitRepTestSupport
import Testing

/// A check of each item: none fails, as a check of nothing hides the bug that left it nothing, and a failure names each
/// item that does not hold.
@Suite(.backstop)
struct EveryTests {
    private static func says(_ words: String, _ issue: Issue) -> Bool {
        issue.comments.map(\.rawValue) == [words]
    }

    @Test func itemsThatAllHoldPass() {
        expectEvery([2, 4, 6]) { $0.isMultiple(of: 2) }
    }

    @Test func nothingToCheckFails() {
        withKnownIssue {
            expectEvery([Int](), "the marks") { _ in true }
        } matching: {
            Self.says("There was nothing to check (the marks).", $0)
        }
    }

    @Test func aFailureNamesEachItemThatDoesNotHoldByItsPlace() {
        withKnownIssue {
            expectEvery([2, 3, 4, 5]) { $0.isMultiple(of: 2) }
        } matching: {
            Self.says("2 of 4 do not hold, by place: 1: 3; 3: 5", $0)
        }
    }

    @Test func aFailureIsTheCallers() {
        let line = #_sourceLocation.line + 3

        withKnownIssue {
            expectEvery([1]) { _ in false }
        } matching: {
            $0.sourceLocation?.line == line
        }
    }
}
