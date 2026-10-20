import CoreGraphics
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import Testing

/// The notch swells for what a line's `new` says, and never for a first line, which `watch` leaves empty.
struct TellTests {
    private static func board(_ lines: String...) -> PanelBoard {
        var last = LastBoard()

        for line in lines {
            _ = last.hear(.line(line), at: .now)
        }

        return PanelBoard(last)
    }

    /// `watchLine`'s board as a run's first line: the same rows, nothing new on it.
    private static let first = board(watched(new: []))

    @Test func aRowNewOnTheBoardSwellsTheNotch() {
        let notch = Told()

        Self.board(watchLine).tell(notch, after: Self.first)

        #expect(notch.told == ["newAsk"])
    }

    @Test func theBoardGoingStaleSwellsNothingAgain() {
        let notch = Told()
        var last = LastBoard()
        _ = last.hear(.line(watchLine), at: .now)
        let current = PanelBoard(last)
        _ = last.hear(.exited(.status(1), stderr: ""), at: .now)
        let stale = PanelBoard(last)
        _ = last.hear(.exited(.status(1), stderr: ""), at: .now)

        stale.tell(notch, after: current)
        PanelBoard(last).tell(notch, after: stale)

        #expect(notch.told.isEmpty)
    }

    @Test func theFirstBoardNeedingLeeLightsTheNotchWithNoSwell() {
        let notch = Told()

        Self.first.tell(notch, after: PanelBoard())

        #expect(Self.first.new.isEmpty)
        #expect(notch.told == ["needsLeeQuietly"])
    }

    @Test func aBoardStillNeedingLeeWithNothingNewTellsNothing() {
        let notch = Told()

        Self.first.tell(notch, after: Self.first)

        #expect(notch.told.isEmpty)
    }

    @Test func aBoardAllClearTellsNothing() {
        let notch = Told()

        Self.board(allClearLine).tell(notch, after: Self.first)

        #expect(notch.told.isEmpty)
    }
}

/// A notch that only notes what it was told.
private final class Told: Notch {
    private(set) var told: [String] = []

    let phase = Phase.closed
    let items: [Item] = []
    let field = 0.0
    let notchY = 0.0

    func frame(_ input: Input) -> Frame {
        Meniscus(input).frame(input)
    }

    func newAsk() { told.append("newAsk") }
    func needsLeeQuietly() { told.append("needsLeeQuietly") }
    func clickRow(_ index: Int) -> Bool {
        told.append("clickRow")
        return false
    }

    func jumpAnswered() { told.append("jumpAnswered") }
    func clickElsewhere() { told.append("clickElsewhere") }
    func carry() { told.append("carry") }
    func carried(to y: Double) { told.append("carried") }
    func drop(across: Bool) { told.append("drop") }
    func restingOutline(at y: Double) -> CGPath { CGMutablePath() }
}
