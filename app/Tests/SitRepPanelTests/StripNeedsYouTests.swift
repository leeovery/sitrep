@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The strip's one Needs you (14 November 2026): the stopped join the asks over the hairline, a session stopping moves
/// in at once as an ask does, flashing only where Lee has Pulse when Claude stops on, one working again leaves at once,
/// and needs you's count folds the end of its order, blue while all it holds are stopped and orange while it holds an
/// ask.
@Suite(.backstop)
struct StripNeedsYouTests {
    /// A turn ends: the first working session's mark moves into needs you at once, before the stopped, and grows into
    /// its place there, its ring flashing twice where the pulse is on and not at all where it is off; it is never
    /// washed, as only an ask's arrival is.
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

    /// A stopped session whose turn ends, Claude working again, changes group: it moves back under the hairline at
    /// once, as an answered ask does (Lee, 14 November 2026; until then it changed in place and moved at the re-sort).
    @Test func aStoppedSessionWorkingAgainMovesUnderTheHairlineAtOnce() {
        var lab = StripLab()
        lab.stop(StripLab.stopped)
        lab.settle()
        var working = StripLab.stopped
        working.kind = .working

        lab.change(working)

        #expect(lab.model.display == ["s1", "s2", "s3", "s4", "s5", "s6", "s8", "s7"])
        lab.settle()
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
        var lab = StripLab(sessions: StripLab.prototype + StripLab.asks.prefix(2), length: .grows, maxMarks: 6)
        lab.open(.count(.needsYou))

        guard case let .rows(rows) = lab.live!.current!.content else {
            Issue.record("the count's tab holds rows")
            return
        }
        #expect(rows.map(\.id) == ["s10", "s4", "s5", "s6"])
        #expect(rows.map(\.need) == [.ask, .ask, .turn, .turn])
    }

    /// Sessions working again leave needs you's count at once: the two asks that landed there answered, it holds the
    /// stopped alone and turns blue (Lee, 14 November 2026; until then they stayed in it till the re-sort, keeping it
    /// orange).
    @Test func asksAnsweredInNeedsYousCountLeaveItAtOnce() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(2).forEach(lab.newAsk)
        #expect(lab.model.layout.rest(of: .needsYou) == ["s9", "s10", "s5", "s6"])

        for id in ["s9", "s10"] {
            var working = lab.model.session(id)!
            working.kind = .working
            lab.change(working)
        }
        lab.step()

        #expect(lab.model.layout.rest(of: .needsYou) == ["s5", "s6"])
        #expect(lab.model.slot["s9"] == .working && lab.model.slot["s10"] == .working)
        #expect(lab.frame.marks.first { $0.key == .count(.needsYou) }?.look == .stoppedCount)
    }

    /// A session gone back to work, its turn ended or its ask answered, stopping again moves back among the stopped at
    /// once, flashing with the pulse on, and quiet with it off.
    @Test(arguments: [("s7", true), ("s7", false), ("s1", true)])
    func aSessionWorkingAgainThenStoppingMovesBackAtOnceFlashingWithThePulse(id: String, pulses: Bool) {
        var lab = StripLab()
        if id == "s7" {
            lab.stop(StripLab.stopped)
            lab.settle()
        }
        var session = lab.model.session(id)!
        session.kind = .working
        lab.change(session)
        lab.step()
        #expect(lab.model.slot[id] == .working)

        session.kind = .turn
        lab.stop(session, pulses: pulses)
        lab.wait(1500)

        #expect(lab.model.display == StripLab.core(lab.model.sessions).map(\.id))
        #expect(lab.model.slot[id] == .needsYou)
        #expect(lab.model.mark(.session(id))!.flashes.count == (pulses ? 2 : 0))
    }

    /// Landing back in needs you's count, it flashes the count instead.
    @Test func aSessionInTheCountStoppingAgainFlashesTheCount() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        var s5 = lab.model.session("s5")!
        s5.kind = .working
        lab.change(s5)
        lab.step()

        s5.kind = .turn
        lab.stop(s5, pulses: true)

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
        #expect(marks == nil || lab.model.layout.rest(of: .needsYou).contains("s9"))
        var flash = 0.0, wash = 0.0
        lab.wait(2500) { lab in
            flash = max(flash, lab.frame.marks.map(\.flash).max() ?? 0)
            wash = max(wash, lab.frame.marks.map(\.wash).max() ?? 0)
            return false
        }

        #expect(lab.model.slot["s9"] == .needsYou)
        #expect(marks != nil || lab.model.mark(.session("s9"))!.sc.x == 1)
        #expect(lab.model.counts[.needsYou]?.flashes == count)
        #expect(flash == 0 && wash == 0)
    }

    /// Its ask answered, a session stopping with the pulse off ends its ask's flash, which never runs on in its blue,
    /// its mark kept through each move.
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
        expectEvery(tabs) { $0.phase == .closing }
    }

    /// The stopped mark pushed out is the last stopped one showing, wherever its stop puts it: with the first stopped
    /// away, last of them and so in the count, the third.
    @Test func theMarkPushedOutIsTheLastStoppedOneShowing() {
        var sessions = Self.full(asks: 3, stopped: 4)
        sessions[3].away = true
        let lab = StripLab(sessions: sessions, length: .grows, maxMarks: 6)
        let places = lab.model.layout.places
        let stays = places.filter { $0.id != "t2" }.dropFirst(3)

        lab.newAsk(Self.newest)

        #expect(lab.model.layout.rest(of: .needsYou).first == "t2")
        #expect(lab.model.layout.rest(of: .needsYou).last == "t0")
        #expect(lab.model.layout.y(of: "n") == places[3].y)
        expectEvery(stays) { lab.model.layout.places.map(\.id).contains($0.id) }
    }

    /// A session stopping while the asks' order waits for the re-sort goes under every ask, though the ask the panel's
    /// order has above it stands first among them: the stopped keep to their own run of needs you.
    @Test func aSessionStoppingWhileTheAsksOrderWaitsGoesUnderEveryAsk() {
        let working = Session(id: "w", project: "Work", kind: .working, title: "", sub: "", since: 0)
        var lab = StripLab(sessions: Self.full(asks: 2, stopped: 2) + [working])
        var again = lab.model.session("a0")!
        again.lines[0].since = 5
        lab.change(again)
        lab.step()
        #expect(lab.model.display.prefix(2) == ["a0", "a1"])
        var stopping = working
        stopping.kind = .turn
        stopping.lines[0].since = 10

        lab.stop(stopping)

        #expect(lab.model.display == ["a0", "a1", "w", "t0", "t1"])
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

    /// An ask whose landing the count flashes, answered, and so out of it, then stopping with the pulse off, landing
    /// there again: the count's flash for it ends; another session landing quietly leaves it be.
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
        expectEvery(places) { lab.model.layout.y(of: $0.id) == $0.y }
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
        expectEvery(looks) { $0 == need }
        #expect(lab.model.counts[.needsYou] == nil)
    }

    /// One update's moves judge needs you's room with them all counted. At Max 5 needs you shows three asks, its two
    /// stopped in its count, and Working its one session; that session stops as the first ask is answered. Needs you's
    /// room stays three, so the stop lands in the count and the stopped mark first there comes out in the answered
    /// ask's place; a settle after, the panel's order shows the stop over it.
    @Test func oneUpdatesMovesAreAllCountedForNeedsYousRoom() {
        let asks = (1 ... 3).map { Session(id: "a\($0)", project: "Ask", kind: .needs, title: "", sub: "", since: 0) }
        let stopped = (1 ... 2).map {
            Session(id: "s\($0)", project: "Stop", kind: .turn, title: "", sub: "", since: -Double($0))
        }
        let x = Session(id: "x", project: "Work", kind: .working, title: "", sub: "", since: 0)
        var lab = StripLab(sessions: asks + stopped + [x], length: .grows, maxMarks: 5)
        #expect(lab.model.layout.places.map(\.id) == ["a1", "a2", "a3", "x"])
        #expect(lab.model.layout.rest(of: .needsYou) == ["s1", "s2"])
        var answered = asks[0], stopping = x
        answered.kind = .working
        stopping.kind = .turn
        stopping.lines[0].since = 5

        lab.model.show(StripLab.core([answered] + asks.dropFirst() + stopped + [stopping]), new: [], stopped: ["x"])

        #expect(lab.model.layout.places.map(\.id) == ["a2", "a3", "s1", "a1"])
        #expect(lab.model.layout.rest(of: .needsYou) == ["x", "s2"])
        lab.wait(StripFeel.lees.settle + 100)
        #expect(lab.model.layout.places.map(\.id) == ["a2", "a3", "x", "a1"])
        #expect(lab.model.layout.rest(of: .needsYou) == ["s1", "s2"])
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

    /// The stop's session working again within the flash leaves the count at once, and the count's flash for it ends:
    /// a count left holding asks flashes for no session gone from it.
    @Test func aCountsFlashForASessionGoneFromItEnds() throws {
        var lab = StripLab(sessions: Self.full(asks: 7, stopped: 0) + [Self.working], length: .grows, maxMarks: 6)
        var stopping = Self.working
        stopping.kind = .turn
        lab.stop(stopping, pulses: true)
        let count = try #require(lab.model.counts[.needsYou])
        #expect(count.shows == .stop && count.arrivalOf == "w")
        lab.wait(200)

        lab.change(Self.working)

        #expect(!lab.model.layout.rest(of: .needsYou).contains("w"))
        #expect(count.shows == .quiet && count.arrivalOf == nil && count.flashes.isEmpty)
        var flash = 0.0
        lab.wait(1500) { lab in
            flash = max(flash, lab.frame.marks.first { $0.key == .count(.needsYou) }?.flash ?? 0)
            return false
        }
        #expect(flash == 0)
    }
}
