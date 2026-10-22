import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepLines
@testable import SitRepWindow
import Testing

/// The sidebar's one list, over the first line the real `watch` printed: Needs you, then the projects under their
/// headings, then the quiet projects; and the folds, kept across launches.
struct SidebarTests {
    private static let listed = Listed(heard(line(0)))

    private static func lines(_ listed: Listed = listed, folds: Folds = Folds()) -> [Sidebar.Line.ID] {
        Sidebar(listed, folds: folds).lines.map(\.id)
    }

    @Test func needsYouHoldsEverySessionWithAnAskTheOldestFirstAndNoOther() {
        // the Mac app's ask is the oldest, then Dashboard redesign's, then Goosemates' away one; Request ledger's turn
        // and Kit's away session wait on nothing
        #expect(Self.listed.needsYou.map(\.name) == [
            "The Mac app", "Dashboard redesign", "Settle the older open questions",
        ])
        #expect(Self.listed.needsYou.allSatisfy { $0.mark == .needs })
    }

    @Test func needsYousOrderIsTheAsksWhereverTheirProjectsSit() throws {
        let board = try Board.read(projects(["kit", "goosemates", "switchboard", "sitrep"]))

        #expect(Listed.needsYou(board).map(\.id) == ["sr-macapp", "sr-dash02", "sr-gs7kq2"])
    }

    @Test func aNeedsYouRowIsItsSessionsRowNamingItsProject() throws {
        let asking = try #require(Self.listed.needsYou.first)

        #expect(asking.project == "SitRep")
        #expect(asking == Self.listed.sessions.first { $0.id == asking.id })
    }

    @Test func theListIsNeedsYouThenEachProjectThenTheQuietProjects() {
        #expect(Self.lines() == [
            .needsYou,
            .spot(.needsYou("sr-macapp")), .spot(.needsYou("sr-dash02")), .spot(.needsYou("sr-gs7kq2")),
            .spot(.board(.project("sitrep"))), .spot(.board(.session("sr-macapp"))),
            .spot(.board(.project("switchboard"))), .spot(.board(.session("sr-dash02"))),
            .spot(.board(.session("sr-rq7dgr"))),
            .spot(.board(.project("goosemates"))), .spot(.board(.session("sr-gs7kq2"))),
            .quietHeading, .spot(.board(.project("kit"))),
        ])
    }

    /// The arrow keys walk the list's own rows, a session with an ask under Needs you and again under its project.
    @Test func theRowsThatPickAreEveryRowButTheHeadings() {
        let picks = Sidebar(Self.listed, folds: Folds()).picks

        #expect(picks == Sidebar(Self.listed, folds: Folds()).lines.filter { !Self.isHeading($0) }.compactMap(\.spot))
        #expect(picks == [
            .needsYou("sr-macapp"), .needsYou("sr-dash02"), .needsYou("sr-gs7kq2"),
            .board(.session("sr-macapp")), .board(.session("sr-dash02")), .board(.session("sr-rq7dgr")),
            .board(.session("sr-gs7kq2")), .board(.project("kit")),
        ])
    }

    @Test func theRuleAfterNeedsYouSitsOverTheFirstLineAfterItsRows() {
        #expect(Sidebar(Self.listed, folds: Folds()).ruled == .spot(.board(.project("sitrep"))))
    }

    @Test func withNoAskOrNothingAfterNeedsYouNoLineIsRuled() {
        var asksAlone = Self.listed
        var noAsk = Self.listed

        asksAlone.projects = []
        asksAlone.quiet = []
        noAsk.needsYou = []
        #expect(Sidebar(asksAlone, folds: Folds()).ruled == nil)
        #expect(Sidebar(noAsk, folds: Folds()).ruled == nil)
    }

    @Test func withNoAskNeedsYouGoesAndAProjectsHeadingHeadsTheList() {
        var listed = Self.listed

        listed.needsYou = []
        #expect(Self.lines(listed).first == .spot(.board(.project("sitrep"))))
        #expect(!Self.lines(listed).contains(.needsYou))
    }

    @Test func aFoldedProjectShowsItsHeadingAloneItsAskStillUnderNeedsYou() {
        let lines = Self.lines(folds: Self.folded(.project("sitrep")))

        #expect(lines.contains(.spot(.board(.project("sitrep")))))
        #expect(!lines.contains(.spot(.board(.session("sr-macapp")))))
        #expect(lines.contains(.spot(.needsYou("sr-macapp"))))
    }

    @Test func theQuietProjectsFoldAsAProjectDoes() {
        let lines = Self.lines(folds: Self.folded(.quiet))

        #expect(lines.last == .quietHeading)
        #expect(!lines.contains(.spot(.board(.project("kit")))))
    }

    /// SitRep's one session holds three asks, and Switchboard's two sessions one between them.
    @Test func aFoldedProjectCountsItsSessionsWithAnAskAndOnlyWhileFolded() throws {
        let open = Self.headings(Sidebar(Self.listed, folds: Folds()))
        let folded = Self.headings(Sidebar(Self.listed, folds: Self.folded(.project("sitrep"), .project("switchboard"))))

        #expect(open.map(\.count) == [nil, nil, nil, nil])
        #expect(folded.map(\.count) == [1, 1, nil, nil])
        #expect(folded.map(\.waiting) == [3, 2, 1, 0])
    }

    @Test func aFoldedProjectWithNoAskShowsNoCount() {
        let folded = Self.headings(Sidebar(Self.listed, folds: Self.folded(.quiet)))

        #expect(folded.last?.isFolded == true)
        #expect(folded.last?.count == nil)
    }

    /// A heading shows a project's page as picked; Needs you's and the quiet projects' show no pick at all.
    @Test func onlyAProjectsHeadingShowsAPick() {
        let headings = Sidebar(Self.listed, folds: Folds()).lines.filter(Self.isHeading)

        #expect(headings.map(\.spot) == [
            nil, .board(.project("sitrep")), .board(.project("switchboard")), .board(.project("goosemates")), nil,
        ])
    }

    @Test func anEmptyBoardListsNothing() {
        #expect(Sidebar().isEmpty)
        #expect(!Sidebar(Self.listed, folds: Folds()).isEmpty)
    }

    @Test func theListsFirstRowThatPicksIsUnderNeedsYouElseUnderItsProjectElseAQuietProject() {
        var listed = Self.listed
        let first = { (folds: Folds) in Sidebar(listed, folds: folds).first }

        #expect(first(Folds()) == .session("sr-macapp"))
        listed.needsYou = []
        listed.projects.removeFirst()
        #expect(first(Folds()) == .session("sr-dash02"))
        // a folded project's rows are hidden, so the next project's come first
        #expect(first(Self.folded(.project("switchboard"))) == .session("sr-gs7kq2"))
        listed.projects = []
        #expect(first(Folds()) == .project("kit"))
        #expect(first(Self.folded(.quiet)) == nil)
        listed.quiet = []
        #expect(first(Folds()) == nil)
    }

    /// The arrow keys from a heading that shows its project's page, which the list selects no row for.
    @Test func fromAPickedHeadingAStepGoesToTheRowAfterItOrBeforeIt() {
        let sidebar = Sidebar(Self.listed, folds: Folds())

        #expect(sidebar.step(from: .board(.project("switchboard")), down: true) == .to(.board(.session("sr-dash02"))))
        #expect(sidebar.step(from: .board(.project("switchboard")), down: false) == .to(.board(.session("sr-macapp"))))
        #expect(sidebar.step(from: .board(.project("sitrep")), down: false) == .to(.needsYou("sr-gs7kq2")))
    }

    @Test func fromAFoldedHeadingAStepGoesPastItsHiddenRows() {
        let sidebar = Sidebar(Self.listed, folds: Self.folded(.project("goosemates")))

        #expect(sidebar.step(from: .board(.project("goosemates")), down: true) == .to(.board(.project("kit"))))
    }

    /// A pick a fold hides stands at the heading it is folded under, its project's or the quiet projects'.
    @Test func fromAPickAFoldHidesAStepGoesFromItsHeading() {
        let projects = Sidebar(Self.listed, folds: Self.folded(.project("switchboard")))

        #expect(projects.step(from: .board(.session("sr-rq7dgr")), down: true) == .to(.board(.session("sr-gs7kq2"))))
        #expect(projects.step(from: .board(.session("sr-rq7dgr")), down: false) == .to(.board(.session("sr-macapp"))))

        let quiet = Sidebar(Self.listed, folds: Self.folded(.quiet))

        #expect(quiet.step(from: .board(.project("kit")), down: false) == .to(.board(.session("sr-gs7kq2"))))
        #expect(quiet.step(from: .board(.project("kit")), down: true) == .stays)
    }

    /// Past the ends there is no row to go to, and the pick stays where it is.
    @Test func fromAHeadingAtAnEndAStepStays() {
        var listed = Self.listed

        listed.needsYou = []
        listed.quiet = []

        #expect(Sidebar(listed, folds: Folds()).step(from: .board(.project("sitrep")), down: false) == .stays)
        #expect(Sidebar(listed, folds: Self.folded(.project("goosemates")))
            .step(from: .board(.project("goosemates")), down: true) == .stays)
    }

    /// The list's own keys move from a row it selects, from a pick it does not show, and from none.
    @Test func fromARowTheListSelectsOrAPickItDoesNotShowTheStepIsTheListsOwn() {
        let sidebar = Sidebar(Self.listed, folds: Folds())

        #expect(sidebar.step(from: .board(.session("sr-dash02")), down: true) == .listsOwn)
        #expect(sidebar.step(from: .needsYou("sr-macapp"), down: false) == .listsOwn)
        #expect(sidebar.step(from: .board(.project("kit")), down: true) == .listsOwn)
        #expect(sidebar.step(from: .board(.session("sr-gone")), down: true) == .listsOwn)
        #expect(sidebar.step(from: .board(.settings), down: true) == .listsOwn)
        #expect(sidebar.step(from: nil, down: true) == .listsOwn)
    }

    @Test func aFoldTogglesAndTheQuietProjectsFoldOfTheirOwn() {
        var folds = Folds()

        folds.toggle(.project("kit"))
        folds.toggle(.quiet)
        #expect(folds.contains(.project("kit")) && folds.contains(.quiet))
        #expect(!folds.contains(.project("sitrep")))
        folds.toggle(.project("kit"))
        #expect(folds == Self.folded(.quiet))
    }

    private static func folded(_ folds: Fold...) -> Folds {
        folds.reduce(into: Folds()) { $0.toggle($1) }
    }

    private static func headings(_ sidebar: Sidebar) -> [Sidebar.Heading] {
        sidebar.lines.compactMap { line in
            if case let .heading(heading) = line {
                return heading
            }
            return nil
        }
    }

    private static func isHeading(_ line: Sidebar.Line) -> Bool {
        switch line {
        case .needsYou, .heading: true
        case .asking, .session, .quiet: false
        }
    }
}

/// The folds, kept across launches in the window's saved value of its own.
struct SidebarSettingsTests {
    private static func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "com.leeovery.sitrep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    @Test func nothingSavedIsNothingFoldedTheQuietProjectsOpen() {
        Self.withDefaults { defaults in
            #expect(SavedSettings<SidebarSettings>(defaults).read().folds == Folds())
            #expect(!Folds().quiet)
        }
    }

    @Test func theFoldsAreReadBackUnderTheWindowsKey() {
        Self.withDefaults { defaults in
            var folds = Folds()

            folds.toggle(.project("fumi"))
            folds.toggle(.quiet)
            SavedSettings<SidebarSettings>(defaults).save(folds)

            #expect(SavedSettings<SidebarSettings>(defaults).read().folds == folds)
            #expect(defaults.data(forKey: "window") != nil)
        }
    }

    /// Round 7's saved view, or anything else it cannot read, gives the folds' defaults.
    @Test func whatItCannotReadIsNothingFolded() {
        Self.withDefaults { defaults in
            defaults.set(Data(#"{"sidebar":"needsYou"}"#.utf8), forKey: SidebarSettings.key)
            #expect(SavedSettings<SidebarSettings>(defaults).read().folds == Folds())

            defaults.set(Data(#"{"folds":{"projects":"kit","quiet":true}}"#.utf8), forKey: SidebarSettings.key)
            #expect(SavedSettings<SidebarSettings>(defaults).read().folds.projects.isEmpty)
            #expect(SavedSettings<SidebarSettings>(defaults).read().folds.quiet)
        }
    }
}
