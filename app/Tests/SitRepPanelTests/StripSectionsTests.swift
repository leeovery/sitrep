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

    /// Past its room a count says how many more, with a plus; folded it says how many, without.
    @Test func onlyACountPastItsRoomHasAPlus() throws {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.settle()

        #expect(try #require(lab.frame.marks.first { $0.key == .count(.working) }).text == "+2")
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

    /// A session snoozed keeps its mark, now its Snoozed one, in place until the re-sort, when it slides there
    /// unfaded; woken, it is its mark again.
    @Test func aSessionSnoozedOrWokenKeepsItsMark() throws {
        var lab = StripLab(length: .grows)
        lab.fold(.snoozed)
        lab.settle()
        let working = try #require(lab.model.mark(.session("s8"))), place = working.y.target

        lab.change(Self.snoozedRow(of: StripLab.prototype[7]))
        #expect(lab.model.mark(.session("s8")) == nil)
        #expect(lab.model.mark(.session("snoozed:s8")) === working)
        #expect(working.y.target == place)
        var dipped = false
        lab.wait(3000) { lab in
            dipped = dipped || working.op.x < 1
            return false
        }
        lab.settle()
        #expect(!dipped && abs(working.y.x - lab.model.layout.y(of: "snoozed:s8")!) < 0.01)

        lab.change(StripLab.prototype[7])
        #expect(lab.model.mark(.session("s8")) === working)
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

    /// A session's row as its turn snoozed leaves it: in Snoozed.
    private static func snoozedRow(of session: Session) -> Session {
        var s = session
        s.kind = .snoozedTurn
        s.wakesAt = 1
        return s
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
