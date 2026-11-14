import CoreGraphics
@testable import SitRepPanel
import Testing

/// The strip's sections (14 November 2026): Needs you, Working and Snoozed in the panel's order, a hairline between
/// each two that show; a section folded is one count of all its sessions, numbered without a plus and coloured as its
/// section, which pours them all as rows and unfolds at a click; Snoozed's marks dimmed, each a click to its session;
/// and past its room each section keeps a place for each after it, Snoozed last.
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
        #expect(lab.model.layout.places.allSatisfy { !held.contains($0.id) })
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
        #expect(lab.model.layout.places.allSatisfy { $0.id != "s7" && $0.id != "s8" })
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

    @Test(arguments: [BoardSection.needsYou, .working, .snoozed])
    func aClickOnAFoldedCountUnfoldsItsSection(_ section: BoardSection) {
        var lab = Self.snoozedUnfolded()
        lab.fold(section)
        lab.settle()

        #expect(lab.model.click(at: lab.on(.count(section))) == .unfold(section))
        #expect(!lab.model.folded.contains(section))
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
        #expect(looks.allSatisfy { $0?.need == nil && $0?.isAsleep == true })
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
        #expect(marks.count == 1 && marks.allSatisfy { !$0.removing })
        lab.settle()
        #expect(lab.model.mark(.session("s9"))?.op.x == 1)
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
        #expect(layout.counts.allSatisfy { $0.value.isFolded == folded.contains($0.key) })
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

    /// The brightest a mark's ring flashed, or its inside washed, over this long.
    private static func flash(of id: String, in lab: inout StripLab, for ms: Double) -> Double {
        var flash = 0.0
        lab.wait(ms) { lab in
            let mark = lab.frame.marks.first { $0.key == .session(id) }
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
