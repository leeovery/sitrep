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

    /// Blue only while every session it holds is stopped: asks answered in it, working until the re-sort, or a stopped
    /// one working again, keep it orange.
    @Test(arguments: [["s9", "s10"], ["s5"]])
    func needsYousCountHoldingSessionsWorkingAgainIsOrange(working ids: [String]) {
        var lab = StripLab(length: .grows, maxMarks: 6)
        if ids.contains("s9") {
            StripLab.asks.prefix(2).forEach(lab.newAsk)
            lab.settle()
        }

        for id in ids {
            var working = lab.model.session(id)!
            working.kind = .working
            lab.change(working)
        }
        lab.step()

        #expect(ids.allSatisfy(lab.model.layout.restNeeds.contains))
        #expect(lab.frame.marks.first { $0.key == .moreNeeds }?.look == .needsCount)
    }

    /// A session still on the needs you side, its turn ended or its ask answered before the re-sort, stopping again
    /// flashes where it is, with the pulse on, and stays quiet with it off.
    @Test(arguments: [("s7", true), ("s7", false), ("s1", true)])
    func aSessionStoppingOnTheNeedsYouSideFlashesWhereItIsWithThePulse(id: String, pulses: Bool) {
        var lab = StripLab()
        if id == "s7" {
            lab.stop(StripLab.stopped)
            lab.settle()
        }
        var session = lab.model.session(id)!
        session.kind = .working
        lab.change(session)
        lab.step()
        let order = lab.model.display

        session.kind = .turn
        lab.stop(session, pulses: pulses)
        lab.step()

        #expect(lab.model.display == order)
        #expect(lab.model.mark(.session(id))!.flashes.count == (pulses ? 2 : 0))
    }

    /// Folded into needs you's count, it flashes the count instead.
    @Test func aSessionInTheCountStoppingAgainFlashesTheCount() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        var fumi = lab.model.session("s5")!
        fumi.kind = .working
        lab.change(fumi)
        lab.step()

        fumi.kind = .turn
        lab.stop(fumi, pulses: true)

        #expect(lab.model.layout.restNeeds.contains("s5"))
        #expect(lab.model.moreNeeds!.flashes.count == 2 && !lab.model.moreNeeds!.washes)
    }

    /// With "Pulse for a new ask" off, a new ask still moves in at once, but unflashed and unwashed, as a mark or landing
    /// in the count.
    @Test(arguments: [nil, 6])
    func withItsPulseOffANewAskMovesInUnflashed(marks: Int?) {
        var lab = StripLab(length: .grows, maxMarks: marks)
        let count = lab.model.moreNeeds?.flashes

        lab.newAsk(StripLab.ask, pulses: [.turn])
        var flash = 0.0, wash = 0.0
        lab.wait(2500) { lab in
            flash = max(flash, lab.frame.marks.map(\.flash).max() ?? 0)
            wash = max(wash, lab.frame.marks.map(\.wash).max() ?? 0)
            return false
        }

        #expect(lab.model.needsSlot.contains("s9"))
        #expect(marks == nil ? lab.model.mark(.session("s9"))!.sc.x == 1 : lab.model.layout.restNeeds.contains("s9"))
        #expect(lab.model.moreNeeds?.flashes == count)
        #expect(flash == 0 && wash == 0)
    }

    /// Its ask answered before the re-sort, a session stopping with the pulse off ends its ask's flash, which never
    /// runs on in its blue.
    @Test func aQuietStopEndsAnEarlierAsksFlash() {
        var lab = StripLab()
        var asking = lab.model.session("s7")!
        asking.kind = .needs
        lab.arrive(asking)
        lab.wait(1000) { $0.model.mark(.session("s7"))!.arrived > -1e8 }
        var answered = asking
        answered.kind = .working
        lab.change(answered)
        lab.step()

        answered.kind = .turn
        lab.stop(answered)
        var flash = 0.0
        lab.wait(800) { lab in
            flash = max(flash, lab.frame.marks.first { $0.key == .session("s7") }!.flash)
            return false
        }

        #expect(lab.model.mark(.session("s7"))!.flashes.isEmpty)
        #expect(flash == 0)
    }

    // MARK: A new ask on a full strip (Lee, 14 November 2026)

    /// These asks, a0 the oldest, then these stopped, t0 the newest.
    private static func full(asks: Int, stopped: Int) -> [Session] {
        (0 ..< asks).map { Session(id: "a\($0)", project: "Ask", kind: .needs, title: "", sub: "", since: Double($0)) }
            + (0 ..< stopped).map {
                Session(id: "t\($0)", project: "Stop", kind: .turn, title: "", sub: "", since: -Double($0 + 1))
            }
    }

    /// A new ask newer than every other.
    private static let newest = Session(id: "n", project: "New", kind: .needs, title: "", sub: "", since: 10)

    /// Max 6, needs you's count showing: with stopped marks showing, two or one, a new ask takes its place among the
    /// asks, the marks under it sliding down, and the last stopped mark showing goes into the count; the pointer on
    /// the strip changes none of it.
    @Test(arguments: [(3, 4, false), (4, 3, false), (3, 4, true)])
    func aNewAskOnAFullStripPushesTheLastStoppedMarkShowingIntoTheCount(asks: Int, stopped: Int, hovered: Bool) {
        var lab = StripLab(sessions: Self.full(asks: asks, stopped: stopped), length: .grows, maxMarks: 6)
        if hovered {
            lab.open("a0")
        }
        let places = lab.model.layout.places
        let pushed = places.last!.id, folded = lab.model.layout.restNeeds

        lab.newAsk(Self.newest)

        #expect(pushed.hasPrefix("t") && !folded.isEmpty)
        #expect(lab.model.layout.restNeeds == [pushed] + folded)
        #expect(lab.model.layout.y(of: "n") == places[asks].y)
        #expect(places.dropLast().dropFirst(asks).allSatisfy { lab.model.layout.y(of: $0.id)! > $0.y })
        #expect(lab.frame.marks.first { $0.key == .moreNeeds }?.look == .stoppedCount)
    }

    /// With only asks showing, a new ask lands in the count, and no mark showing moves.
    @Test func aNewAskOnAFullStripOfAsksLandsInTheCount() {
        let lab = StripLab(sessions: Self.full(asks: 6, stopped: 1), length: .grows, maxMarks: 6)
        let places = lab.model.layout.places
        var ask = Self.newest
        ask.lines[0].since = 2.5

        lab.newAsk(ask)

        #expect(lab.model.layout.restNeeds.first == "n")
        #expect(places.allSatisfy { lab.model.layout.y(of: $0.id) == $0.y })
    }

    /// A session stopping on a full strip lands in the count though stopped marks show: only asks push them out.
    @Test func aSessionStoppingOnAFullStripLandsInTheCount() {
        let sessions = Self.full(asks: 3, stopped: 4) + StripLab.prototype.suffix(2)
        let lab = StripLab(sessions: sessions, length: .grows, maxMarks: 7)
        let needsYou = { lab.model.layout.places.map(\.id).filter { !$0.hasPrefix("s") } }
        let shown = needsYou()

        lab.stop(StripLab.stopped)

        #expect(shown.contains("t1"))
        #expect(lab.model.layout.restNeeds.first == "s7")
        #expect(needsYou() == shown)
    }
}
