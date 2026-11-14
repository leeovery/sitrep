@testable import SitRepPanel
import Testing

/// The strip's one Needs you (14 November 2026): the stopped join the asks over the hairline, a session stopping moves
/// in at once as an ask does, flashing only where Lee has Pulse when Claude stops on, and needs you's count folds the
/// end of its order, orange while it holds any ask and blue holding only the stopped.
struct StripNeedsYouTests {
    /// A turn ends: DocMan's mark moves into needs you at once, before the stopped, and grows into its place there,
    /// its ring flashing twice where the pulse is on and not at all where it is off; it is never washed, as only an
    /// ask's arrival is.
    @Test(arguments: [true, false])
    func aSessionStoppingMovesIntoNeedsYouAtOnceFlashingOnlyWithThePulse(pulses: Bool) {
        var lab = StripLab()

        lab.stop(StripLab.stopped, pulses: pulses)

        #expect(lab.model.display == ["s1", "s2", "s3", "s4", "s7", "s5", "s6", "s8"])
        #expect(lab.model.needsSlot.contains("s7"))
        var flash = 0.0, wash = 0.0
        lab.wait(2500) { lab in
            let mark = lab.frame.marks.first { $0.key == .session("s7") }!
            flash = max(flash, mark.flash)
            wash = max(wash, mark.wash)
            return false
        }
        let mark = lab.model.mark(.session("s7"))!
        #expect(mark.sc.x == 1 && lab.model.layout.y(of: "s7")! < lab.model.layout.hair!)
        #expect(mark.flashes.count == (pulses ? 2 : 0))
        #expect((flash > 0.5) == pulses)
        #expect(wash == 0)
    }

    /// Past needs you's room a session stopping lands in its count, which flashes where the pulse is on, unwashed.
    @Test(arguments: [true, false])
    func aSessionStoppingPastItsRoomLandsInTheCountFlashingOnlyWithThePulse(pulses: Bool) {
        var lab = StripLab(length: .grows, maxMarks: 6)

        lab.stop(StripLab.stopped, pulses: pulses)
        lab.wait(2500)

        let count = lab.model.moreNeeds!
        #expect(lab.model.layout.restNeeds == ["s7", "s5", "s6"])
        #expect(count.flashes.count == (pulses ? 2 : 0) && !count.washes)
    }

    /// A stopped session whose turn ends, Claude working again, changes in place, and moves back under the hairline at
    /// the re-sort, as an answered ask does.
    @Test func aStoppedSessionWorkingAgainChangesInPlaceAndMovesAtTheReSort() {
        var lab = StripLab()
        lab.stop(StripLab.stopped)
        lab.settle()
        var working = StripLab.stopped
        working.kind = .working

        lab.change(working)
        lab.step()
        #expect(lab.model.display == ["s1", "s2", "s3", "s4", "s7", "s5", "s6", "s8"])

        lab.wait(1500)

        #expect(lab.model.display.suffix(2) == ["s8", "s7"])
        #expect(lab.model.layout.y(of: "s7")! > lab.model.layout.hair!)
    }

    /// Past its room needs you folds the end of its order: the stopped while every ask still shows, then the away ask.
    @Test(arguments: [(6, ["s5", "s6"]), (5, ["s4", "s5", "s6"])])
    func needsYouFoldsTheEndOfItsOrderTheStoppedFirst(max: Int, folded: [String]) {
        let lab = StripLab(length: .grows, maxMarks: max)

        #expect(lab.model.layout.restNeeds == folded)
        #expect(lab.model.layout.moreNeeds!.n == folded.count)
    }

    /// Needs you's count is blue holding only the stopped, and orange holding any ask, with the stopped or alone.
    @Test(arguments: [
        ([Session](), StripFrame.Mark.Look.stoppedCount),
        (Array(StripLab.asks.prefix(2)), .needsCount),
    ])
    func needsYousCountIsOrangeWithAnyAskAndBlueWithOnlyTheStopped(added: [Session], look: StripFrame.Mark.Look) {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.add(added)
        lab.settle()

        #expect(lab.frame.marks.first { $0.key == .moreNeeds }?.look == look)
    }

    @Test func needsYousCountHoldingOnlyAsksIsOrange() {
        let asks = (0 ..< 8).map { Session(id: "a\($0)", project: "Ask", kind: .needs, title: "", sub: "", since: 0) }
        let lab = StripLab(sessions: asks, length: .grows, maxMarks: 5)

        #expect(lab.frame.marks.first { $0.key == .moreNeeds }?.look == .needsCount)
    }

    /// The count's tab lists what it holds as rows, the asks and the stopped each its own session's row.
    @Test func needsYousCountsTabListsItsAsksAndItsStoppedAsRows() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.add(Array(StripLab.asks.prefix(2)))
        lab.open(.moreNeeds)

        guard case let .rows(rows) = lab.live!.current!.content else {
            Issue.record("the count's tab holds rows")
            return
        }
        #expect(rows.map(\.id) == ["s10", "s4", "s5", "s6"])
        #expect(rows.map(\.need) == [.ask, .ask, .turn, .turn])
    }
}
