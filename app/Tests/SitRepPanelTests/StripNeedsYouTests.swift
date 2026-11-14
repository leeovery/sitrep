@testable import SitRepPanel
import Testing

/// The strip's one Needs you (14 November 2026): the stopped join the asks over the hairline, a session stopping moves
/// in at once as an ask does, flashing only where Lee has Pulse when Claude stops on, and needs you's count folds the
/// end of its order, blue while all it holds are stopped and orange while it holds any session not stopped.
struct StripNeedsYouTests {
    /// A turn ends: DocMan's mark moves into needs you at once, before the stopped, and grows into its place there,
    /// its ring flashing twice where the pulse is on and not at all where it is off; it is never washed, as only an
    /// ask's arrival is.
    @Test(arguments: [true, false])
    func aSessionStoppingMovesIntoNeedsYouAtOnceFlashingOnlyWithThePulse(pulses: Bool) {
        var lab = StripLab()

        lab.stop(StripLab.stopped, pulses: pulses)

        #expect(lab.model.display == ["s1", "s2", "s3", "s4", "s7", "s5", "s6", "s8"])
        #expect(lab.model.slot["s7"] == .needsYou)
        var flash = 0.0, wash = 0.0
        lab.wait(2500) { lab in
            let mark = lab.frame.marks.first { $0.key == .session("s7") }!
            flash = max(flash, mark.flash)
            wash = max(wash, mark.wash)
            return false
        }
        let mark = lab.model.mark(.session("s7"))!
        #expect(mark.sc.x == 1 && lab.model.layout.y(of: "s7")! < lab.model.layout.hairs[.working]!)
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

        let count = lab.model.counts[.needsYou]!
        #expect(lab.model.layout.rest(of: .needsYou) == ["s7", "s5", "s6"])
        #expect(count.flashes.count == (pulses ? 2 : 0) && count.shows == (pulses ? .stop : .quiet))
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
        #expect(lab.model.layout.y(of: "s7")! > lab.model.layout.hairs[.working]!)
    }

    /// Past its room needs you folds the end of its order: the stopped while every ask still shows, then the away ask.
    @Test(arguments: [(6, ["s5", "s6"]), (5, ["s4", "s5", "s6"])])
    func needsYouFoldsTheEndOfItsOrderTheStoppedFirst(max: Int, folded: [String]) {
        let lab = StripLab(length: .grows, maxMarks: max)

        #expect(lab.model.layout.rest(of: .needsYou) == folded)
        #expect(lab.model.layout.counts[.needsYou]!.n == folded.count)
    }

    /// Needs you's count is blue while all it holds are stopped, and orange holding an ask, with the stopped or alone.
    @Test(arguments: [
        ([Session](), StripFrame.Mark.Look.stoppedCount),
        (Array(StripLab.asks.prefix(2)), .needsCount),
    ])
    func needsYousCountIsOrangeWithAnyAskAndBlueWithOnlyTheStopped(added: [Session], look: StripFrame.Mark.Look) {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.add(added)
        lab.settle()

        #expect(lab.frame.marks.first { $0.key == .count(.needsYou) }?.look == look)
    }

    @Test func needsYousCountHoldingOnlyAsksIsOrange() {
        let asks = (0 ..< 8).map { Session(id: "a\($0)", project: "Ask", kind: .needs, title: "", sub: "", since: 0) }
        let lab = StripLab(sessions: asks, length: .grows, maxMarks: 5)

        #expect(lab.frame.marks.first { $0.key == .count(.needsYou) }?.look == .needsCount)
    }

    /// The count's tab lists what it holds as rows, the asks and the stopped each its own session's row.
    @Test func needsYousCountsTabListsItsAsksAndItsStoppedAsRows() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.add(Array(StripLab.asks.prefix(2)))
        lab.open(.count(.needsYou))

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

        #expect(ids.allSatisfy(lab.model.layout.rest(of: .needsYou).contains))
        #expect(lab.frame.marks.first { $0.key == .count(.needsYou) }?.look == .needsCount)
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

        #expect(lab.model.layout.rest(of: .needsYou).contains("s5"))
        #expect(lab.model.counts[.needsYou]!.flashes.count == 2 && lab.model.counts[.needsYou]!.shows == .stop)
    }

    /// With "Pulse for a new ask" off, a new ask still moves in at once, but unflashed and unwashed, as a mark or landing
    /// in the count.
    @Test(arguments: [nil, 6])
    func withItsPulseOffANewAskMovesInUnflashed(marks: Int?) {
        var lab = StripLab(length: .grows, maxMarks: marks)
        let count = lab.model.counts[.needsYou]?.flashes

        lab.newAsk(StripLab.ask, pulses: [.turn])
        var flash = 0.0, wash = 0.0
        lab.wait(2500) { lab in
            flash = max(flash, lab.frame.marks.map(\.flash).max() ?? 0)
            wash = max(wash, lab.frame.marks.map(\.wash).max() ?? 0)
            return false
        }

        #expect(lab.model.slot["s9"] == .needsYou)
        let folded = lab.model.layout.rest(of: .needsYou)
        #expect(marks == nil ? lab.model.mark(.session("s9"))!.sc.x == 1 : folded.contains("s9"))
        #expect(lab.model.counts[.needsYou]?.flashes == count)
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
    /// asks, the marks under it each sliding down a place, and the last stopped mark showing goes into the count, the
    /// ask taking its place where it was the only one; the pointer on the strip changes none of it.
    @Test(arguments: [(3, 4, false), (4, 3, false), (3, 4, true)])
    func aNewAskOnAFullStripPushesTheLastStoppedMarkShowingIntoTheCount(asks: Int, stopped: Int, hovered: Bool) {
        var lab = StripLab(sessions: Self.full(asks: asks, stopped: stopped), length: .grows, maxMarks: 6)
        if hovered {
            lab.open("a0")
        }
        let places = lab.model.layout.places
        let pushed = places.last!.id, folded = lab.model.layout.rest(of: .needsYou)
        var shown = places.map(\.id).dropLast()
        shown.insert("n", at: asks)

        lab.newAsk(Self.newest)

        #expect(pushed.hasPrefix("t") && !folded.isEmpty)
        #expect(lab.model.layout.rest(of: .needsYou) == [pushed] + folded)
        #expect(lab.model.layout.places.map(\.id) == Array(shown))
        #expect(lab.model.layout.places.map(\.y) == places.map(\.y))
        #expect(lab.frame.marks.first { $0.key == .count(.needsYou) }?.look == .stoppedCount)
    }

    /// The pointer on the stopped mark an ask pushes out: its tab draws back, as a mark's leaving does.
    @Test func aPushedOutMarksTabDrawsBack() {
        var lab = StripLab(sessions: Self.full(asks: 3, stopped: 4), length: .grows, maxMarks: 6)
        lab.open("t1")

        lab.newAsk(Self.newest)

        #expect(lab.model.layout.rest(of: .needsYou).first == "t1")
        let tabs = lab.model.tabs.filter { $0.key == .session("t1") }
        #expect(!tabs.isEmpty && tabs.allSatisfy { $0.phase == .closing })
    }

    /// The stopped mark pushed out is the last stopped one showing, wherever it stands: over a session working again
    /// before the re-sort, which stays where it is, or with the first stopped away, last of them and so in the count.
    @Test(arguments: [(working: "t1", pushed: "t0"), (working: "", pushed: "t2")])
    func theMarkPushedOutIsTheLastStoppedOneShowing(working: String, pushed: String) {
        var sessions = Self.full(asks: 3, stopped: 4)
        if working.isEmpty {
            sessions[3].away = true
        }
        var lab = StripLab(sessions: sessions, length: .grows, maxMarks: 6)
        if var again = lab.model.session(working) {
            again.kind = .working
            lab.change(again)
            lab.step()
        }
        let places = lab.model.layout.places
        let stays = places.filter { $0.id != pushed }.dropFirst(3)

        lab.newAsk(Self.newest)

        #expect(lab.model.layout.rest(of: .needsYou).first == pushed)
        #expect(lab.model.layout.y(of: "n") == places[3].y)
        #expect(stays.allSatisfy { lab.model.layout.places.map(\.id).contains($0.id) })
        if !working.isEmpty {
            #expect(lab.model.layout.y(of: working) == places.first { $0.id == working }!.y)
        } else {
            #expect(lab.model.layout.rest(of: .needsYou).last == "t0")
        }
    }

    /// A stopped mark showing above the new ask's place stays: the two stopped marks under it asking before the
    /// re-sort, still in their places, the ask's place is between them, and with no stopped mark showing below it the
    /// ask lands in the count.
    @Test func aStoppedMarkShowingAboveTheAsksPlaceStays() {
        var lab = StripLab(sessions: Self.full(asks: 2, stopped: 5), length: .grows, maxMarks: 6)
        for (id, since) in [("t1", 5.0), ("t2", 6.0)] {
            var asking = lab.model.session(id)!
            asking.kind = .needs
            asking.lines[0].since = since
            lab.change(asking)
        }
        lab.step()
        let places = lab.model.layout.places.map(\.id)
        #expect(places == ["a0", "a1", "t0", "t1", "t2"])
        var ask = Self.newest
        ask.lines[0].since = 5.5

        lab.newAsk(ask)

        #expect(lab.model.layout.places.map(\.id) == places)
        #expect(lab.model.layout.rest(of: .needsYou).contains("n"))
    }

    /// The only working session asking, its place under the hairline gone: Needs you's room grows by it, so the
    /// stopped marks folded come out as it lifts, and the ask takes its place over them, pushing them back into the
    /// count, at Max 5 and on the full strip. A layout left from before the lift would have had no stopped mark
    /// showing, and the ask landing in the count.
    @Test(arguments: [(5, 3, 2, ["t0", "t1"]), (nil, 14, 2, ["t0", "t1"])])
    func theOnlyWorkingSessionAskingPushesTheLastStoppedMarkIntoTheCount(
        max: Int?, asks: Int, stopped: Int, folded: [String]
    ) {
        let working = Session(id: "w", project: "Work", kind: .working, title: "", sub: "", since: 0)
        let lab = StripLab(sessions: Self.full(asks: asks, stopped: stopped) + [working], length: .grows, maxMarks: max)
        #expect(lab.model.layout.y(of: "w") != nil && lab.model.layout.counts[.needsYou] != nil)
        var asking = working
        asking.kind = .needs
        asking.lines[0].since = 100

        lab.arrive(asking)

        let asked = (0 ..< asks).map { "a\($0)" } + ["w"]
        #expect(Array(lab.model.layout.places.map(\.id).prefix(asks + 1)) == asked)
        #expect(lab.model.layout.rest(of: .needsYou) == folded)
    }

    /// An ask whose landing the count flashes, answered there and stopping with the pulse off before the re-sort:
    /// the count's flash for it ends; another session landing quietly leaves it be.
    @Test(arguments: [true, false])
    func aQuietLandingEndsTheCountsFlashOnlyForItsOwnSession(same: Bool) {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.newAsk(StripLab.ask)
        let flashes = lab.model.counts[.needsYou]!.flashes
        #expect(lab.model.layout.rest(of: .needsYou).contains("s9") && flashes.count == 2)

        if same {
            var answered = StripLab.answered(ask: "s9")
            lab.change(answered)
            lab.step()
            answered.kind = .turn
            lab.stop(answered)
        } else {
            lab.stop(StripLab.stopped)
        }

        #expect(lab.model.counts[.needsYou]!.flashes == (same ? [] : flashes))
    }

    /// With only asks showing, a new ask lands in the count, and no mark showing moves.
    @Test func aNewAskOnAFullStripOfAsksLandsInTheCount() {
        let lab = StripLab(sessions: Self.full(asks: 6, stopped: 1), length: .grows, maxMarks: 6)
        let places = lab.model.layout.places
        var ask = Self.newest
        ask.lines[0].since = 2.5

        lab.newAsk(ask)

        #expect(lab.model.layout.rest(of: .needsYou).first == "n")
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
        #expect(lab.model.layout.rest(of: .needsYou).first == "s7")
        #expect(needsYou() == shown)
    }

    /// A working session, on the strip under Needs you.
    private static let working = Session(id: "w", project: "Work", kind: .working, title: "", sub: "", since: 0)

    /// Needs you's count going, its sessions finding room again, keeps its colour as it fades: orange as it held an
    /// ask, blue as it held only the stopped. Holding none as it goes, it would have turned blue.
    @Test(arguments: [(7, 0, "a6", Need.ask), (3, 4, "t3", .turn)])
    func aCountGoingKeepsItsColour(asks: Int, stopped: Int, leaving: String, need: Need) {
        var lab = StripLab(sessions: Self.full(asks: asks, stopped: stopped), length: .grows, maxMarks: 6)
        #expect(lab.model.layout.rest(of: .needsYou).contains(leaving))

        lab.remove([leaving])

        var looks: [Need?] = []
        lab.wait(400) { lab in
            looks += lab.frame.marks.filter { $0.key == .count(.needsYou) }.map(\.look.need)
            return false
        }
        #expect(!looks.isEmpty && looks.allSatisfy { $0 == need })
        #expect(lab.model.counts[.needsYou] == nil)
    }

    /// Two working sessions asking in one update while the grey count shows each take their place in Needs you at
    /// once: the second never goes into the grey count as the first moves in.
    @Test func twoSessionsAskingInOneUpdateEachTakeTheirPlace() {
        let working = (0 ..< 20).map {
            Session(id: "w\($0)", project: "Work", kind: .working, title: "", sub: "", since: Double($0))
        }
        let lab = StripLab(sessions: working)
        #expect(lab.model.layout.counts[.working] != nil)
        let asking = working.prefix(2).map { session in
            var asking = session
            asking.kind = .needs
            asking.lines[0].since = 100
            return asking
        }

        lab.model.show(StripLab.core(asking + working.dropFirst(2)), new: ["w0", "w1"])

        for id in ["w0", "w1"] {
            let mark = lab.model.mark(.session(id))!
            #expect(!mark.folded && mark.y.x == lab.model.layout.y(of: id))
        }
    }

    /// A session back at a turn whose end it stood at before, so not stopping anew (`LastBoard.turnsEnded`), moves
    /// into Needs you at once all the same, before the stopped, unflashed though the pulse is on.
    @Test func aTurnBackMovesInAtOnceUnflashed() {
        var lab = StripLab()

        lab.turnBack(StripLab.stopped)

        #expect(lab.model.display == ["s1", "s2", "s3", "s4", "s7", "s5", "s6", "s8"])
        #expect(lab.model.slot["s7"] == .needsYou)
        var flash = 0.0
        lab.wait(2500) { lab in
            flash = max(flash, lab.frame.marks.first { $0.key == .session("s7") }!.flash)
            return false
        }
        #expect(flash == 0 && lab.model.mark(.session("s7"))!.sc.x == 1)
    }

    /// Arrivals in one update add up in the count, an ask's over a stop's whatever the stop's pulse: an ask and a
    /// session stopping landing there together, or the ask taking the last place and folded there by the stop coming
    /// in under it, its arrival on its own mark never seen.
    @Test(arguments: [(7, true), (7, false), (5, true), (5, false)])
    func anAskAndAStopInOneUpdateShowTheAsksArrivalOnTheCount(asks: Int, pulses: Bool) {
        let lab = StripLab(sessions: Self.full(asks: asks, stopped: 0) + [Self.working], length: .grows, maxMarks: 6)
        #expect((lab.model.layout.counts[.needsYou] == nil) == (asks == 5))
        var stopping = Self.working
        stopping.kind = .turn

        lab.model.show(
            StripLab.core(lab.model.sessions.map { $0.id == "w" ? stopping : $0 } + [Self.newest]), new: ["n"],
            stopped: ["w"], pulses: pulses ? [.ask, .turn] : [.ask]
        )

        let count = lab.model.counts[.needsYou]!
        #expect(lab.model.layout.rest(of: .needsYou).suffix(2) == ["n", "w"])
        #expect(count.shows == .ask && count.arrivalOf == "n" && count.flashes.count == 2)
    }

    /// The flash follows what arrived: a stopped mark's flash ends as its session asks, a line come that isn't new,
    /// and never runs on in orange.
    @Test func aStoppedMarksFlashEndsAsItsSessionAsks() {
        var lab = StripLab()
        lab.stop(StripLab.stopped, pulses: true)
        #expect(lab.wait(1000) { !$0.model.mark(.session("s7"))!.flashes.isEmpty })
        var asking = StripLab.stopped
        asking.kind = .needs

        lab.change(asking)

        var flash = 0.0
        lab.wait(2500) { lab in
            flash = max(flash, lab.frame.marks.first { $0.key == .session("s7") }!.flash)
            return false
        }
        #expect(flash == 0)
    }

    /// A session stopping lands in a count orange with asks, which flashes for it all the same, in its orange.
    @Test func aStopLandingInACountOrangeWithAsksFlashesIt() {
        var lab = StripLab(sessions: Self.full(asks: 7, stopped: 0) + [Self.working], length: .grows, maxMarks: 6)
        var stopping = Self.working
        stopping.kind = .turn

        lab.stop(stopping, pulses: true)

        var flash = 0.0, looks: Set<StripFrame.Mark.Look> = []
        lab.wait(2500) { lab in
            let count = lab.frame.marks.first { $0.key == .count(.needsYou) }!
            flash = max(flash, count.flash)
            looks.insert(count.look)
            return false
        }
        #expect(lab.model.layout.rest(of: .needsYou).last == "w")
        #expect(flash > 0.5 && looks == [.needsCount])
    }
}
