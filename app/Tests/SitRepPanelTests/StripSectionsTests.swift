import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The strip's sections (14 November 2026): Needs you, Working and Snoozed in the panel's order, a hairline between
/// each two that show; a section folded is one count of all its sessions, numbered without a plus and coloured as its
/// section, which pours them all as rows and unfolds at a click; Snoozed's marks dimmed, each a click to its session;
/// and past its room each section keeps a place for each after it, Snoozed last.
@Suite(.backstop)
struct StripSectionsTests {
    // MARK: The sections

    @Test func theThreeSectionsShowInThePanelsOrderAHairlineBetweenEachTwo() {
        var lab = Self.snoozedUnfolded()
        let layout = lab.model.layout

        #expect(layout.places.map(\.id) == Self.prototypeIDs + Self.snoozedMarks)
        #expect(layout.y(of: "s6")! < layout.hairs[.working]! && layout.hairs[.working]! < layout.y(of: "s7")!)
        #expect(layout.y(of: "s8")! < layout.hairs[.snoozed]! && layout.hairs[.snoozed]! < layout.y(of: "snoozed:s9")!)
        lab.settle()
        #expect(lab.frame.hairlines.map(\.alpha) == [1, 1])
        #expect(lab.frame.hairlines.map(\.y) == [layout.hairs[.working]!, layout.hairs[.snoozed]!])
    }

    /// With Working gone, the hairline between Needs you and Snoozed is Snoozed's, and Working's goes; with Needs you
    /// alone, there is none.
    @Test func aHairlineShowsOnlyBetweenTwoSectionsThatShow() {
        var lab = Self.snoozedUnfolded()

        lab.remove(["s7", "s8"])
        lab.settle()
        #expect(lab.model.layout.hairs[.working] == nil)
        #expect(lab.model.layout.y(of: "s6")! < lab.model.layout.hairs[.snoozed]!)
        #expect(lab.frame.hairlines.map(\.alpha) == [0, 1])

        lab.remove(["s9", "s10", "s11"])
        lab.settle()
        #expect(lab.model.layout.hairs.isEmpty)
        #expect(lab.frame.hairlines.map(\.alpha) == [0, 0])
    }

    // MARK: A section folded

    @Test(arguments: [
        (BoardSection.needsYou, ["s1", "s2", "s3", "s4", "s5", "s6"], StripFrame.Mark.Look.needsCount),
        (.working, ["s7", "s8"], .count),
        (.snoozed, ["snoozed:s9", "snoozed:s10", "snoozed:s11"], .snoozedCount),
    ])
    func aFoldedSectionIsOneCountOfAllItsSessions(
        _ section: BoardSection, _ held: [String], _ look: StripFrame.Mark.Look
    ) throws {
        var lab = Self.snoozedUnfolded()

        lab.fold(section)
        lab.settle()

        let count = try #require(lab.model.layout.counts[section])
        let mark = try #require(lab.frame.marks.first { $0.key == .count(section) })

        #expect(count.isFolded && count.held == held)
        expectEvery(lab.model.layout.places) { !held.contains($0.id) }
        #expect(mark.text == "\(held.count)" && mark.look == look)
    }

    /// A count beside marks of its section says how many more, with a plus; one holding them all, folded or with no
    /// room for any beside it, says how many, without.
    @Test func onlyACountBesideItsSectionsMarksHasAPlus() throws {
        var full = StripLab()
        full.add(StripLab.tooMany)
        full.settle()
        let beside = try #require(full.frame.marks.first { $0.key == .count(.working) })
        #expect(beside.text == "+\(full.model.layout.rest(of: .working).count)")

        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.settle()
        expectEvery(lab.model.layout.places) { $0.id != "s7" && $0.id != "s8" }
        #expect(try #require(lab.frame.marks.first { $0.key == .count(.working) }).text == "2")
        lab.fold(.working)
        lab.settle()
        #expect(try #require(lab.frame.marks.first { $0.key == .count(.working) }).text == "2")
    }

    /// Needs you folded is orange while it holds an ask, and blue once all it holds are stopped.
    @Test func foldedNeedsYouIsBlueWhileAllItHoldsAreStopped() {
        var lab = StripLab(length: .grows)

        lab.fold(.needsYou)
        lab.remove(["s1", "s2", "s3", "s4"])
        lab.settle()
        #expect(lab.frame.marks.first { $0.key == .count(.needsYou) }?.look == .stoppedCount)

        lab.add([StripLab.ask])
        lab.settle()
        #expect(lab.frame.marks.first { $0.key == .count(.needsYou) }?.look == .needsCount)
    }

    @Test(arguments: [(BoardSection.working, ["s7", "s8"]), (.snoozed, ["s9", "s10", "s11"])])
    func aFoldedCountPoursEveryOneOfItsSessionsAsRows(_ section: BoardSection, _ ids: [String]) throws {
        var lab = StripLab(length: .grows)
        (0 ..< 3).forEach { _ in lab.snooze() }
        if section == .working {
            lab.fold(.working)
        }
        lab.settle()

        lab.open(.count(section))

        let tab = try #require(lab.frame.tabs.first { $0.isLive })
        guard case let .rows(sessions) = try #require(tab.words.last).content else {
            Issue.record("the folded count's tab pours no rows")
            return
        }
        #expect(tab.key == .count(section))
        #expect(sessions.map(\.id) == ids)
    }

    /// A click on a folded count asks for its section to unfold, folding nothing itself: its caller sets the fold where
    /// the card reads it too, and the section comes out.
    @Test(arguments: [BoardSection.needsYou, .working, .snoozed])
    func aClickOnAFoldedCountUnfoldsItsSection(_ section: BoardSection) {
        var lab = Self.snoozedUnfolded()
        lab.fold(section)
        lab.settle()

        #expect(lab.model.click(at: lab.on(.count(section))) == .unfold(section))
        #expect(lab.model.folded.contains(section))
        lab.model.folded.remove(section)
        lab.settle()
        #expect(lab.model.layout.counts[section] == nil)
        #expect(lab.model.layout.places.map(\.id) == Self.prototypeIDs + Self.snoozedMarks)
    }

    /// A right-click on a count's row names its session with the section the strip has it in, and whether that is
    /// folded: Working folded, or past its room.
    @Test(arguments: [true, false])
    func aRightClickOnACountsRowNamesItsSessionAndItsSectionsFold(folded: Bool) throws {
        var lab = folded ? StripLab(length: .grows) : StripLab(length: .grows, maxMarks: 6)
        if folded {
            lab.fold(.working)
        }
        lab.settle()
        lab.open(.count(.working))

        let tab = try #require(lab.frame.tabs.first { $0.isLive }), words = try #require(tab.words.last)
        let pitch = StripTuning.rowHeight + StripTuning.rowGap
        let row = CGPoint(
            x: tab.box.midX,
            y: tab.box.minY + words.frame.minY + StripTuning.rowsPad + pitch + StripTuning.rowHeight / 2 - words.scroll
        )
        let s8 = try #require(lab.model.sessions.first { $0.id == "s8" })

        #expect(lab.model.target(at: row) == .session(s8, section: .working, isFolded: folded))
    }

    /// Past its room a count's click opens its tab, folding nothing.
    @Test func aClickOnACountPastItsRoomOpensItsTab() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.settle()

        #expect(lab.model.click(at: lab.on(.count(.working))) == .nothing)
        #expect(lab.model.folded == [.snoozed])
        #expect(lab.live?.key == .count(.working))
    }

    // MARK: Snoozed's marks

    /// Each dimmed as its Snoozed row is, an ask's ring orange and a turn's blue, coming in unflashed and unwashed.
    @Test func snoozedMarksAreDimmedAsSnoozedRows() {
        var lab = Self.snoozedUnfolded(settled: false)
        var flash = 0.0

        lab.wait(1500) { lab in
            flash = max(flash, lab.frame.marks.filter(\.look.isAsleep).map { max($0.flash, $0.wash) }.max() ?? 0)
            return false
        }

        let looks = Self.snoozedMarks.map { id in lab.frame.marks.first { $0.key == .session(id) }?.look }

        #expect(looks == [.snoozed, .snoozedTurn, .snoozed])
        expectEvery(looks) { $0?.need == nil && $0?.isAsleep == true }
        #expect(flash == 0)
    }

    /// A click on a Snoozed mark jumps to its session, by its own id.
    @Test func aClickOnASnoozedMarkJumpsToItsSession() {
        var lab = Self.snoozedUnfolded()
        lab.pointer = lab.on("snoozed:s9")
        lab.wait(50)

        let jump = lab.model.click(at: lab.pointer!).session

        #expect(jump?.id == "s9" && jump?.isSnoozed == true)
    }

    // MARK: A snooze or a wake

    /// Wake now on a session's asks, or its turn: its mark moves into Needs you at once, where the panel's order puts
    /// it, though the pointer rests on the strip, unflashed and unwashed, out of Snoozed's count, folded or not.
    @Test(arguments: [Session.Kind.needs, .turn], [false, true])
    func aSessionLeeWakesMovesIntoNeedsYouAtOnceUnflashed(kind: Session.Kind, snoozedFolded: Bool) throws {
        var lab = StripLab(length: .grows)
        if !snoozedFolded {
            lab.fold(.snoozed)
        }
        lab.snooze()
        lab.settle()
        lab.pointer = lab.on("s1")
        lab.wait(400)
        let mark = try #require(lab.model.mark(.session("snoozed:s9")))

        lab.change(Self.woken("s9", kind))

        #expect(lab.model.mark(.session("s9")) === mark)
        #expect(lab.model.slot["s9"] == .needsYou)
        #expect(lab.model.display == StripLab.core(lab.model.sessions).map(\.markID))
        #expect(try #require(lab.model.layout.y(of: "s9")) < #require(lab.model.layout.hairs[.working]))
        #expect(lab.model.layout.counts[.snoozed] == nil)
        #expect(Self.flash(of: "s9", in: &lab, for: 1500) == 0)
    }

    /// Lee snoozes a Needs you session's asks, or its turn: its mark moves into Snoozed at once, where its order puts
    /// it, though the pointer rests on the strip, out of Needs you and its count, folded or not.
    @Test(arguments: [Session.Kind.snoozed, .snoozedTurn], [false, true])
    func aNeedsYouMarkLeeSnoozesMovesIntoSnoozedAtOnce(kind: Session.Kind, needsFolded: Bool) throws {
        var lab = StripLab(length: .grows)
        lab.fold(.snoozed)
        if needsFolded {
            lab.fold(.needsYou)
        }
        lab.settle()
        lab.pointer = lab.on("s7")
        lab.wait(400)
        let id = kind == .snoozed ? "s2" : "s5"
        let mark = try #require(lab.model.mark(.session(id)))

        lab.change(Self.asleep(StripLab.prototype.first { $0.id == id }!, kind))

        #expect(lab.model.mark(.session("snoozed:\(id)")) === mark)
        #expect(lab.model.slot["snoozed:\(id)"] == .snoozed)
        #expect(lab.model.display == StripLab.core(lab.model.sessions).map(\.markID))
        #expect(try #require(lab.model.layout.y(of: "snoozed:\(id)")) > #require(lab.model.layout.hairs[.snoozed]))
        #expect(!lab.model.layout.rest(of: .needsYou).contains { $0.hasSuffix(id) })
        #expect(Self.flash(of: "snoozed:\(id)", in: &lab, for: 1500) == 0)
    }

    /// A wake renaming a mark onto a key whose mark is still fading out, the session's row in Needs you gone a moment
    /// before, leaves one mark by that key, the one that moves, which stays.
    @Test func aWakeOntoAFadingMarksKeyLeavesOneMarkByIt() throws {
        var lab = StripLab(length: .grows)
        lab.fold(.snoozed)
        lab.snooze()
        lab.add([Self.woken("s9", .needs)])
        lab.settle()

        lab.model.show(StripLab.core(lab.model.sessions.filter { $0.markID != "s9" }), new: [])
        lab.wait(50)
        #expect(lab.model.marks.contains { $0.key == .session("s9") && $0.removing })
        lab.change(Self.woken("s9", .needs))

        let marks = lab.model.marks.filter { $0.key == .session("s9") }
        #expect(marks.count == 1)
        expectEvery(marks) { !$0.removing }
        lab.settle()
        #expect(lab.model.mark(.session("s9"))?.op.x == 1)
    }

    /// A session's row in Snoozed going and coming back within its mark's fade, its other row kept, so nothing renamed:
    /// the row back has a mark of its own, placed, which stays, never the fading one.
    @Test func aSnoozedRowBackWithinItsMarksFadeHasAMarkOfItsOwn() throws {
        let asking = Session(id: "x", project: "Ask", kind: .needs, title: "", sub: "", since: -2)
        var lab = StripLab(sessions: Array(Self.asksAndTurns.prefix(2)) + [asking, Self.asleep(asking, .snoozed)])
        lab.fold(.snoozed)
        lab.settle()
        let board = lab.model.sessions

        lab.model.show(board.filter { $0.markID != "snoozed:x" }, new: [])
        lab.wait(50)
        #expect(lab.model.marks.contains { $0.key == .session("snoozed:x") && $0.removing })
        lab.model.show(board, new: [])

        let marks = lab.model.marks.filter { $0.key == .session("snoozed:x") }
        #expect(marks.count == 1)
        expectEvery(marks) { !$0.removing }
        lab.settle()
        #expect(lab.model.layout.y(of: "snoozed:x") != nil)
        #expect(lab.model.mark(.session("snoozed:x"))?.op.x == 1)
        #expect(lab.frame.marks.contains { $0.key == .session("snoozed:x") })
    }

    /// A row pressed in on Snoozed's count's tab, its jump spinning, as a wake renames its mark: the press and the jump
    /// go by its new key.
    @Test func aWakeRenamesARowPressedOnACountsTab() throws {
        var lab = StripLab(length: .grows)
        lab.snooze()
        lab.settle()
        lab.open(.count(.snoozed))
        let tab = try #require(lab.frame.tabs.first { $0.isLive }), words = try #require(tab.words.last)
        let row = CGPoint(
            x: tab.box.midX,
            y: tab.box.minY + words.frame.minY + StripTuning.rowsPad + StripTuning.rowHeight / 2 - words.scroll
        )
        #expect(lab.model.click(at: row).session?.id == "s9")

        lab.change(Self.woken("s9", .needs))

        #expect(lab.model.tabs.flatMap(\.words).contains { $0.pressedRow == "s9" })
        #expect(!lab.model.tabs.flatMap(\.words).contains { $0.pressedRow == "snoozed:s9" })
        guard case let .tab(_, id)? = lab.model.jumping else {
            Issue.record("the jump ended with the wake")
            return
        }
        #expect(id == "s9")
    }

    /// One a wake at its time brings back, which `new` names, arrives as a new needs you does, its ring flashing.
    @Test func aSessionWokenAtItsTimeArrivesFlashing() {
        var lab = StripLab(length: .grows)
        lab.snooze()
        lab.settle()

        lab.arrive(Self.woken("s9", .needs))

        #expect(lab.model.slot["s9"] == .needsYou)
        #expect(Self.flash(of: "s9", in: &lab, for: 1500) > 0.9)
    }

    /// Needs you folded, its last ask snoozed: its count turns blue at once, holding the stopped alone; and a new ask
    /// on a full strip pushes the last stopped mark showing into the count, never a turn Lee snoozed, which went into
    /// Snoozed.
    @Test func neitherTheCountsColourNorThePushRuleSeesASnoozedRow() throws {
        var folded = StripLab(sessions: Self.asksAndTurns, length: .grows, maxMarks: 5)
        folded.fold(.needsYou)
        folded.settle()
        #expect(folded.frame.marks.first { $0.key == .count(.needsYou) }?.look == .needsCount)
        folded.pointer = folded.on(.count(.needsYou))
        folded.change(Self.asleep(Self.asksAndTurns[0], .snoozed))
        folded.step()
        #expect(folded.frame.marks.first { $0.key == .count(.needsYou) }?.look == .stoppedCount)

        var full = StripLab(sessions: Self.asksAndTurns, length: .grows, maxMarks: 5)
        full.settle()
        full.pointer = full.on("a0")
        full.change(Self.asleep(Self.asksAndTurns[3], .snoozedTurn))
        full.newAsk(Session(id: "n", project: "New", kind: .needs, title: "", sub: "", since: 1))

        #expect(full.model.slot["snoozed:t2"] == .snoozed)
        #expect(full.model.layout.rest(of: .needsYou) == ["t0", "t1"])
        #expect(full.model.display.prefix(2) == ["a0", "n"])
    }

    /// An ask Lee wakes into a full Needs you takes its place there as any ask does, pushing the stopped marks into
    /// the count, unflashed; Snoozed, holding another, keeps its place.
    @Test func anAskWokenIntoAFullNeedsYouPushesTheStoppedIntoTheCount() throws {
        let z0 = Session(id: "z0", project: "Ask", kind: .needs, title: "", sub: "", since: 1)
        let z1 = Session(id: "z1", project: "Ask", kind: .needs, title: "", sub: "", since: 2)
        let sessions = Array(Self.asksAndTurns.prefix(3)) + [Self.asksAndTurns[4]] + [z0, z1].map {
            Self.asleep($0, .snoozed)
        }
        var lab = StripLab(sessions: sessions, length: .grows, maxMarks: 5)
        lab.settle()
        #expect(lab.model.layout.places.map(\.id) == ["a0", "t0", "t1", "w0"])
        lab.pointer = lab.on("a0")
        lab.wait(400)

        lab.change(z0)

        #expect(lab.model.layout.places.map(\.id) == ["a0", "z0", "w0"])
        #expect(lab.model.layout.rest(of: .needsYou) == ["t0", "t1"])
        #expect(lab.model.layout.rest(of: .snoozed) == ["snoozed:z1"])
        #expect(Self.flash(of: "z0", in: &lab, for: 1500) == 0)
    }

    /// An ask Lee wakes into Needs you folded lands in its count, which stays unflashed.
    @Test func anAskWokenIntoNeedsYouFoldedLandsInItsCountUnflashed() {
        var lab = StripLab(length: .grows)
        lab.fold(.needsYou)
        lab.snooze()
        lab.settle()
        lab.pointer = lab.on("s7")
        lab.wait(400)

        lab.change(Self.woken("s9", .needs))

        #expect(lab.model.layout.rest(of: .needsYou).contains("s9"))
        #expect(Self.flash(of: .count(.needsYou), in: &lab, for: 1500) == 0)
    }

    // MARK: One rule moves them

    /// Lee wakes a session stopped on a prompt: its row in Snoozed goes, and its row in Needs you, its turn's until
    /// then, becomes an ask's, nothing renamed: its mark moves among the asks at once, though the pointer rests on the
    /// strip, unflashed.
    @Test func aWakeTurningARowsTurnIntoAnAsksMovesItAmongTheAsksAtOnce() throws {
        let prompt = Session(id: "p", project: "Prompt", kind: .turn, title: "", sub: "", since: -2)
        var lab = StripLab(
            sessions: Array(Self.asksAndTurns.prefix(2)) + [prompt, Self.asleep(prompt, .snoozed)], length: .grows
        )
        lab.settle()
        #expect(lab.model.display == ["a0", "t0", "p", "snoozed:p"])
        lab.pointer = lab.on("a0")
        lab.wait(400)
        let mark = try #require(lab.model.mark(.session("p")))
        var asking = prompt
        asking.kind = .needs

        lab.wake(asking)

        #expect(lab.model.mark(.session("p")) === mark)
        #expect(lab.model.display == ["p", "a0", "t0"])
        #expect(lab.model.layout.places.map(\.id) == ["p", "a0", "t0"])
        #expect(Self.flash(of: "p", in: &lab, for: 1500) == 0)
    }

    /// A snooze ended by Lee's prompt is a wake: a turn Lee snoozed, its session back at work, moves into Working at
    /// once, though the pointer rests on the strip, unflashed, out of Snoozed's count, folded or not.
    @Test(arguments: [false, true])
    func aSnoozedTurnGoingBackToWorkMovesIntoWorkingAtOnce(snoozedFolded: Bool) throws {
        var lab = StripLab(length: .grows)
        if !snoozedFolded {
            lab.fold(.snoozed)
        }
        lab.snooze()
        lab.snooze()
        lab.settle()
        lab.pointer = lab.on("s1")
        lab.wait(400)
        let mark = try #require(lab.model.mark(.session("snoozed:s10")))
        #expect(mark.session?.kind == .snoozedTurn)

        lab.change(Self.woken("s10", .working))

        #expect(lab.model.mark(.session("s10")) === mark)
        #expect(lab.model.slot["s10"] == .working)
        #expect(lab.model.display == StripLab.core(lab.model.sessions).map(\.markID))
        #expect(try #require(lab.model.layout.y(of: "s10")) > #require(lab.model.layout.hairs[.working]))
        #expect(!lab.model.layout.rest(of: .snoozed).contains("snoozed:s10"))
        #expect(Self.flash(of: "s10", in: &lab, for: 1500) == 0)
    }

    /// An ask answered, Claude working again, leaves Needs you for Working at once, under the session the panel's
    /// order has above it there, though the pointer rests on the strip (Lee, 14 November 2026; until then its mark
    /// changed in place and moved once the pointer had been off the strip for Settle).
    @Test func anAskAnsweredLeavesNeedsYouAtOnce() throws {
        var lab = StripLab(length: .grows)
        lab.settle()
        lab.pointer = lab.on("s7")
        lab.wait(400)
        var answered = StripLab.prototype[0]
        answered.kind = .working

        lab.change(answered)

        #expect(lab.model.slot["s1"] == .working)
        #expect(lab.model.display == StripLab.core(lab.model.sessions).map(\.markID))
        lab.settle()
        #expect(try #require(lab.model.layout.y(of: "s1")) > #require(lab.model.layout.hairs[.working]))
    }

    /// The first of a stopped session's two asks asleep waking at its time: its row in Snoozed stays, holding the
    /// other, and its row in Needs you becomes an ask's, which `new` names, nothing renamed: its mark moves among the
    /// asks at once, though the pointer rests on the strip, flashing and washed as an ask's arrival is.
    @Test func aPartialWakeOnAStoppedSessionMovesItAmongTheAsksAtOnceFlashing() throws {
        let prompt = Session(id: "p", project: "Prompt", kind: .turn, title: "", sub: "", since: -2)
        var both = Self.asleep(prompt, .snoozed)
        both.lines.append(both.lines[0])
        var lab = StripLab(sessions: Array(Self.asksAndTurns.prefix(2)) + [prompt, both], length: .grows)
        lab.fold(.snoozed)
        lab.settle()
        lab.pointer = lab.on("a0")
        lab.wait(400)
        let mark = try #require(lab.model.mark(.session("p")))
        var asking = prompt
        asking.kind = .needs

        lab.model.show(StripLab.core([asking, Self.asleep(prompt, .snoozed)] + Self.asksAndTurns.prefix(2)), new: ["p"])

        #expect(lab.model.mark(.session("p")) === mark)
        #expect(lab.model.display == ["p", "a0", "t0", "snoozed:p"])
        var wash = 0.0
        lab.wait(1500) { lab in
            wash = max(wash, lab.frame.marks.first { $0.key == .session("p") }?.wash ?? 0)
            return false
        }
        #expect(mark.flashes.count == 2 && wash > 0.9)
        #expect(lab.model.layout.places.map(\.id) == ["p", "a0", "t0", "snoozed:p"])
    }

    /// A session's asleep ask answered as it stops, Claude working until then: its row in Snoozed goes, and its row in
    /// Working becomes its turn's, nothing renamed: its mark moves among the stopped at once, flashing with the pulse,
    /// as a stop's arrival does, and its asleep row's mark fades.
    @Test func anAsleepAskAnsweredAsItsSessionStopsMovesItAmongTheStoppedAtOnce() throws {
        let running = Session(id: "x", project: "Run", kind: .working, title: "", sub: "", since: -5)
        let others = Array(Self.asksAndTurns.prefix(2)) + [Self.asksAndTurns[4]]
        var lab = StripLab(sessions: others + [running, Self.asleep(running, .snoozed)], length: .grows)
        lab.fold(.snoozed)
        lab.settle()
        lab.pointer = lab.on("a0")
        lab.wait(400)
        let mark = try #require(lab.model.mark(.session("x")))
        var stopped = running
        stopped.kind = .turn
        stopped.lines[0].since = 0

        lab.model.show(StripLab.core(others + [stopped]), new: [], stopped: ["x"], pulses: [.ask, .turn])

        #expect(lab.model.mark(.session("x")) === mark)
        #expect(lab.model.display == ["a0", "x", "t0", "w0"])
        #expect(lab.model.marks.contains { $0.key == .session("snoozed:x") && $0.removing })
        lab.wait(1500)
        #expect(mark.flashes.count == 2)
        #expect(lab.model.layout.places.map(\.id) == ["a0", "x", "t0", "w0"])
    }

    /// Lee snoozes a session's asks while Claude still works on it: its row in Needs you becomes a Working one, and its
    /// asks' row comes into Snoozed, nothing renamed. Its mark moves into Working at once, the new row's comes in at
    /// its place in Snoozed, and nothing else re-sorts, the asks' order changed a moment before waiting for the
    /// pointer to have been off the strip for Settle.
    @Test func aSnoozeOfASessionStillWorkingMovesItsMarkAloneAtOnce() throws {
        var lab = StripLab(length: .grows)
        lab.fold(.snoozed)
        lab.settle()
        lab.pointer = lab.on("s7")
        lab.wait(400)
        var askedAgain = StripLab.prototype[0]
        askedAgain.lines[0].since = 0
        lab.change(askedAgain)
        let s3 = StripLab.prototype[2]
        var working = s3
        working.kind = .working

        lab.model.show(
            StripLab.core(lab.model.sessions.map { $0.id == s3.id ? working : $0 } + [Self.asleep(s3, .snoozed)]),
            new: []
        )

        #expect(lab.model.slot["s3"] == .working && lab.model.slot["snoozed:s3"] == .snoozed)
        #expect(lab.model.display == ["s1", "s2", "s4", "s5", "s6", "s7", "s3", "s8", "snoozed:s3"])
        lab.settle()
        #expect(try #require(lab.model.layout.y(of: "snoozed:s3")) > #require(lab.model.layout.hairs[.snoozed]))
        #expect(lab.model.display.prefix(2) == ["s1", "s2"])

        lab.pointer = nil
        lab.wait(StripFeel.lees.settle + 100)

        #expect(lab.model.display.prefix(2) == ["s2", "s1"])
    }

    /// One board snoozing a stopped session and bringing a new ask, at Max 5 a full strip: Snoozed takes its place,
    /// the ask takes one under the ask above it, and the stopped go into Needs you's count.
    @Test func aSnoozeAndANewAskInOneBoardEachTakeTheirPlace() {
        var lab = StripLab(sessions: Self.asksAndTurns, length: .grows, maxMarks: 5)
        lab.settle()
        lab.pointer = lab.on("a0")
        lab.wait(400)
        let n = Session(id: "n", project: "New", kind: .needs, title: "", sub: "", since: 1)
        let snoozed = lab.model.sessions.map { $0.id == "t2" ? Self.asleep($0, .snoozedTurn) : $0 }

        lab.model.show(StripLab.core(snoozed + [n]), new: ["n"])

        #expect(lab.model.layout.places.map(\.id) == ["a0", "n", "w0"])
        #expect(lab.model.layout.rest(of: .needsYou) == ["t0", "t1"])
        #expect(lab.model.layout.rest(of: .snoozed) == ["snoozed:t2"])
    }

    /// A mark going into a count takes its tab back with it, the pointer still where it was: Collapse on its section,
    /// or a snooze whose Snoozed takes a place, pushing it in.
    @Test(arguments: [true, false])
    func aMarkGoingIntoACountTakesItsTabBack(collapse: Bool) throws {
        var lab = StripLab(sessions: Self.asksAndTurns, length: .grows, maxMarks: 5)
        lab.settle()
        lab.open("t2")
        let tab = try #require(lab.model.liveTab())
        #expect(tab.key == .session("t2") && tab.phase == .open)

        if collapse {
            lab.fold(.needsYou)
        } else {
            lab.snooze()
        }

        #expect(lab.model.layout.y(of: "t2") == nil)
        #expect(tab.phase == .closing)
        lab.wait(1000)
        #expect(!lab.model.tabs.contains { $0.key == .session("t2") && $0.phase != .closing })
    }

    /// The menu's Jump on a session folded into a count, no tab out, presses the count in, never a mark unseen.
    @Test func aMenusJumpOnASessionFoldedPressesItsCount() throws {
        var lab = StripLab(length: .grows)
        lab.fold(.needsYou)
        lab.settle()
        let s2 = try #require(lab.model.sessions.first { $0.id == "s2" })

        #expect(lab.model.jump(to: s2) == s2)

        guard case let .mark(key)? = lab.model.jumping else {
            Issue.record("the menu's jump pressed nothing in")
            return
        }
        #expect(key == .count(.needsYou))
        #expect(lab.model.counts[.needsYou]?.sc.target == StripTuning.markPress)
    }

    // MARK: Too many

    /// Max 6: each section takes its places in its turn, keeping one for each after it that holds any; folded, one.
    /// Needs you's asks shown and folded, Working's, then Snoozed's.
    @Test(arguments: [
        ([], 9, 4, 3, [3, 9 - 3, 0, 4, 0, 3]),
        ([], 2, 4, 3, [2, 0, 2, 2, 0, 3]),
        ([], 2, 2, 3, [2, 0, 2, 0, 1, 2]),
        ([], 2, 2, 0, [2, 0, 2, 0, 0, 0]),
        ([.working], 2, 4, 3, [2, 0, 0, 4, 3, 0]),
        ([.needsYou, .snoozed], 9, 9, 3, [0, 9, 3, 6, 0, 3]),
        ([.needsYou, .working, .snoozed], 9, 9, 3, [0, 9, 0, 9, 0, 3]),
        ([.snoozed], 1, 1, 3, [1, 0, 1, 0, 0, 3]),
    ] as [(Set<BoardSection>, Int, Int, Int, [Int])])
    func tooManyKeepsAPlaceForEachSectionAfter(
        _ folded: Set<BoardSection>, _ asks: Int, _ working: Int, _ snoozed: Int, _ expected: [Int]
    ) {
        let lab = StripLab(sessions: Self.sessions(asks, working, snoozed), length: .grows, maxMarks: 6)

        lab.model.folded = folded

        let layout = lab.model.layout
        let shown = ["a", "w", "snoozed:z"].map { prefix in layout.places.filter { $0.id.hasPrefix(prefix) }.count }
        let counted = BoardSection.allCases.map { layout.counts[$0]?.n ?? 0 }

        #expect([shown[0], counted[0], shown[1], counted[1], shown[2], counted[2]] == expected)
        #expect(layout.places.count + layout.counts.count <= 6)
        #expect(layout.counts.filter { $0.value.isFolded != folded.contains($0.key) }.map(\.key) == [])
    }

    // MARK: Needs you folded

    /// A new ask lands in Needs you folded, which flashes; a session stopping lands there quietly unless Lee has
    /// Pulse when Claude stops on, as a mark's arrival does.
    @Test(arguments: [(false, 0), (true, 2)])
    func aStopLandingInNeedsYouFoldedFlashesAsLeesPulseSays(pulses: Bool, flashes: Int) {
        var lab = StripLab(length: .grows)
        lab.fold(.needsYou)
        lab.settle()

        lab.stop(StripLab.stopped, pulses: pulses)
        lab.settle()

        #expect(lab.model.layout.rest(of: .needsYou).contains("s7"))
        #expect(lab.model.counts[.needsYou]!.flashes.count == flashes)
    }

    // MARK: Helpers

    private static let prototypeIDs = StripLab.prototype.map(\.id)
    /// The prototype's three snoozed, by their marks' keys.
    private static let snoozedMarks = ["snoozed:s9", "snoozed:s10", "snoozed:s11"]

    /// At Grows, the prototype's three sessions snoozed and Snoozed unfolded, come to rest unless not.
    private static func snoozedUnfolded(settled: Bool = true) -> StripLab {
        var lab = StripLab(length: .grows)

        lab.fold(.snoozed)
        (0 ..< 3).forEach { _ in lab.snooze() }
        if settled {
            lab.settle()
        }
        return lab
    }

    /// An ask, three turns and a working session, at Max 5 a full strip.
    private static let asksAndTurns = [
        Session(id: "a0", project: "Ask", kind: .needs, title: "", sub: "", since: 0),
        Session(id: "t0", project: "Turn", kind: .turn, title: "", sub: "", since: -1),
        Session(id: "t1", project: "Turn", kind: .turn, title: "", sub: "", since: -2),
        Session(id: "t2", project: "Turn", kind: .turn, title: "", sub: "", since: -3),
        Session(id: "w0", project: "Work", kind: .working, title: "", sub: "", since: 0),
    ]

    /// A session's row as Lee's snooze leaves it: in Snoozed, its asks asleep or its turn.
    private static func asleep(_ session: Session, _ kind: Session.Kind) -> Session {
        var s = session
        s.kind = kind
        s.wakesAt = 1
        return s
    }

    /// The prototype's first session snoozed, by this id, as a wake leaves it: back needing Lee, an ask or a turn.
    private static func woken(_ id: String, _ kind: Session.Kind) -> Session {
        var s = StripLab.snoozed[0].with(id: id)
        s.kind = kind
        s.wakesAt = nil
        return s
    }

    /// The brightest a session's mark's ring flashed, or its inside washed, over this long.
    private static func flash(of id: String, in lab: inout StripLab, for ms: Double) -> Double {
        flash(of: .session(id), in: &lab, for: ms)
    }

    /// The brightest a mark's ring flashed, or its inside washed, over this long.
    private static func flash(of key: MarkKey, in lab: inout StripLab, for ms: Double) -> Double {
        var flash = 0.0
        lab.wait(ms) { lab in
            let mark = lab.frame.marks.first { $0.key == key }
            flash = max(flash, mark.map { max($0.flash, $0.wash) } ?? 0)
            return false
        }
        return flash
    }

    private static func sessions(_ asks: Int, _ working: Int, _ snoozed: Int) -> [Session] {
        func made(_ prefix: String, _ kind: Session.Kind, _ n: Int) -> [Session] {
            (0 ..< n).map {
                Session(id: "\(prefix)\($0)", project: "P", kind: kind, title: "", sub: "", since: Double($0))
            }
        }
        let asleep = made("z", .snoozed, snoozed).enumerated().map { i, s in
            var s = s
            s.wakesAt = Double(i)
            return s
        }
        return made("a", .needs, asks) + made("w", .working, working) + asleep
    }
}
