import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepLines
import enum SitRepPanel.BoardSection
import struct SitRepPanel.Earlier
@testable import SitRepWindow
import Testing

/// The sidebar's one list, the card's sections at the window's size: Needs you, Working and Your turn, each under a
/// heading with its count, each session once; then Projects; and the folds, kept across launches.
struct SidebarTests {
    /// Harness's three asks, Switchboard's ask and prompt and Goosemates' away ask; SitRep working, Kit on its own work;
    /// Fumi's turn; six projects.
    private static let bySession = Listed(heard(.line(Lines.bySession[0])))
    /// Three sessions needing Lee, Request ledger's turn, nothing working; four projects, Kit's quiet.
    private static let first = Listed(heard(line(0)))

    private static func ids(_ listed: Listed = bySession, folds: Folds = Folds()) -> [Sidebar.Line.ID] {
        Sidebar(listed, folds: folds).lines.map(\.id)
    }

    private static func session(_ id: String) -> Sidebar.Line.ID {
        .pick(.session(id))
    }

    private static let needsYou = Sidebar.Line.ID.fold(.section(.needsYou))
    private static let working = Sidebar.Line.ID.fold(.section(.working))
    private static let yourTurn = Sidebar.Line.ID.fold(.section(.yourTurn))
    private static let projects = Sidebar.Line.ID.fold(.projects)
    private static let earlier = Sidebar.Line.ID.fold(.earlier)

    @Test func theListIsNeedsYouThenWorkingThenYourTurnThenProjectsFolded() {
        #expect(Self.ids() == [
            Self.needsYou, Self.session("sr-4g01a7"), Self.session("sr-dash02"), Self.session("sr-gs7kq2"),
            Self.working, Self.session("sr-macapp"), Self.session("sr-k7bt2s"),
            Self.yourTurn, Self.session("sr-v3t7a0"),
            Self.projects,
        ])
    }

    @Test func eachSessionShowsOnceInItsSection() {
        let picks = Sidebar(Self.bySession, folds: Folds()).picks

        #expect(picks.count == Set(picks).count)
        #expect(picks == Self.bySession.rows.map(\.pick))
    }

    @Test func aSectionWithNoRowsIsLeftOutHeadingAndAll() {
        let ids = Self.ids(Self.first)

        #expect(!ids.contains(Self.working))
        #expect(ids.filter { if case .fold = $0 { true } else { false } } == [Self.needsYou, Self.yourTurn, Self.projects])
    }

    /// Needs you counts its lines, Harness's three, Switchboard's two and Goosemates' one; the others their rows;
    /// Projects its projects.
    @Test func eachHeadingCountsWhatItHolds() {
        let headings = Self.headings(Sidebar(Self.bySession, folds: Folds()))

        #expect(headings.map(\.fold) == [.section(.needsYou), .section(.working), .section(.yourTurn), .projects])
        #expect(headings.map(\.count) == [6, 2, 1, 6])
        #expect(headings.map(\.title) == ["Needs you", "Working", "Your turn", "Projects"])
        #expect(headings.map(\.isNeedsYou) == [true, false, false, false])
    }

    /// Fumi's turn ended longer ago than the period: Your turn still counts it, under "N earlier".
    @Test func yourTurnsCountTakesInItsEarlierRows() {
        let headings = Self.headings(Sidebar(Self.marked(Self.bySession, earlier: ["sr-v3t7a0"]), folds: Folds()))

        #expect(headings.first { $0.fold == .section(.yourTurn) }?.count == 1)
    }

    @Test func projectsIsFoldedAtFirstItsChevronRightAndOpenListsEveryProject() {
        let folded = Sidebar(Self.first, folds: Folds())
        let open = Sidebar(Self.first, folds: Folds(projects: false))

        #expect(Self.headings(folded).last == Sidebar.Heading(fold: .projects, count: 4, isFolded: true))
        #expect(folded.lines.last?.id == Self.projects)
        #expect(Array(open.lines.suffix(5).map(\.id)) == [
            Self.projects, .pick(.project("sitrep")), .pick(.project("switchboard")), .pick(.project("goosemates")),
            .pick(.project("kit")),
        ])
    }

    @Test(arguments: [BoardSection.needsYou, .working, .yourTurn])
    func everySectionFoldsToItsHeadingAlone(section: BoardSection) {
        let sidebar = Sidebar(Self.bySession, folds: Folds(sections: [section]))
        let hidden = Self.bySession.rows(in: section).map(\.pick)

        #expect(Self.headings(sidebar).first { $0.fold == .section(section) }?.isFolded == true)
        #expect(sidebar.lines.contains { $0.id == .fold(.section(section)) })
        #expect(Set(sidebar.picks).isDisjoint(with: hidden))
    }

    @Test func theRuleSitsOverTheHeadingAfterNeedsYouFoldedOrNot() {
        #expect(Sidebar(Self.bySession, folds: Folds()).ruled == Self.working)
        #expect(Sidebar(Self.bySession, folds: Folds(sections: [.needsYou])).ruled == Self.working)
        #expect(Sidebar(Self.first, folds: Folds()).ruled == Self.yourTurn)
    }

    @Test func withNoAskOrNothingAfterNeedsYouNoHeadingIsRuled() {
        var asksAlone = Self.first
        var noAsk = Self.first

        asksAlone.rows = asksAlone.needsYou
        asksAlone.projects = []
        noAsk.rows = noAsk.rows(in: .yourTurn)
        #expect(Sidebar(asksAlone, folds: Folds()).ruled == nil)
        #expect(Sidebar(noAsk, folds: Folds()).ruled == nil)
        #expect(Self.ids(noAsk).first == Self.yourTurn)
    }

    /// Request ledger's turn past the period, Fumi's not: Request ledger folds under "N earlier" at Your turn's end,
    /// which names its project.
    @Test func yourTurnsRowsPastThePeriodFoldIntoNEarlierAtItsEnd() throws {
        var listed = Self.first

        listed.rows.append(try #require(Self.bySession.rows.last))

        let sidebar = Sidebar(Self.marked(listed, earlier: ["sr-rq7dgr"]), folds: Folds())
        let line = try #require(sidebar.lines.first { $0.id == Self.earlier })

        #expect(Array(sidebar.lines.map(\.id).drop { $0 != Self.yourTurn }.prefix(3)) == [
            Self.yourTurn, Self.session("sr-v3t7a0"), Self.earlier,
        ])
        #expect(line == .earlier(Earlier(projects: ["Switchboard"], isOpen: false)))
        #expect(!sidebar.picks.contains(.session("sr-rq7dgr")))
    }

    @Test func nEarlierOpenShowsItsRowsUnderIt() {
        let listed = Self.marked(Self.first, earlier: ["sr-rq7dgr"])
        let ids = Self.ids(listed, folds: Folds(isEarlierOpen: true))

        #expect(Array(ids.drop { $0 != Self.yourTurn }.prefix(3)) == [Self.yourTurn, Self.earlier, Self.session("sr-rq7dgr")])
    }

    @Test func withNoRowPastThePeriodThereIsNoNEarlier() {
        #expect(!Self.ids(Self.first, folds: Folds(isEarlierOpen: true)).contains(Self.earlier))
    }

    /// The list slides its rows by their order, so a resort moves them and a fold, which leaves the order alone, changes
    /// the list at once.
    @Test func aFoldLeavesTheRowsOrderAloneAResortChangesIt() {
        let open = Sidebar(Self.bySession, folds: Folds())
        let folded = Sidebar(Self.bySession, folds: Folds(sections: [.working], projects: false, isEarlierOpen: true))
        var resorted = Self.bySession

        resorted.rows.swapAt(0, 1)
        #expect(open.lines != folded.lines)
        #expect(open.order == folded.order)
        #expect(Sidebar(resorted, folds: Folds()).order != open.order)
    }

    @Test func anEmptyBoardListsNothing() {
        #expect(Sidebar().isEmpty)
        #expect(!Sidebar(Self.first, folds: Folds()).isEmpty)
    }

    /// What Return in the Filter field opens: the first row that picks, never a heading, nor a row a fold hides.
    @Test func theListsFirstRowThatPicksIsTheFirstItShows() {
        #expect(Sidebar(Self.bySession, folds: Folds()).first == .session("sr-4g01a7"))
        #expect(Sidebar(Self.bySession, folds: Folds(sections: [.needsYou])).first == .session("sr-macapp"))
        #expect(Sidebar(Self.bySession, folds: Folds(sections: [.needsYou, .working, .yourTurn])).first == nil)
        #expect(
            Sidebar(Self.bySession, folds: Folds(sections: [.needsYou, .working, .yourTurn], projects: false)).first
                == .project("harness")
        )
    }

    /// A pick a fold hides stands at the line it is folded under: its section's heading.
    @Test func fromAPickAFoldHidesAStepGoesFromItsHeading() {
        let sidebar = Sidebar(Self.bySession, folds: Folds(sections: [.working]))

        #expect(sidebar.step(from: .session("sr-k7bt2s"), down: true) == .to(.session("sr-v3t7a0")))
        #expect(sidebar.step(from: .session("sr-k7bt2s"), down: false) == .to(.session("sr-gs7kq2")))
    }

    /// A project's page shows while Projects is folded: it stands at Projects' heading, the list's last line.
    @Test func fromAProjectFoldedUnderProjectsUpGoesToTheLastRowAndDownStays() {
        let sidebar = Sidebar(Self.bySession, folds: Folds())

        #expect(sidebar.step(from: .project("kit"), down: false) == .to(.session("sr-v3t7a0")))
        #expect(sidebar.step(from: .project("kit"), down: true) == .stays)
    }

    /// Kit's away session, with no row of its own, shows at Kit's row in Projects; its project not listed, nowhere.
    @Test func aSessionWithNoRowShowsAtItsProjectsRow() {
        var unlisted = Self.first

        unlisted.projects.removeAll { $0.id == "kit" }

        let sidebar = Sidebar(Self.first, folds: Folds())

        #expect(sidebar.row(showing: .session("sr-k7t001")) == .project("kit"))
        #expect(sidebar.row(showing: .session("sr-rq7dgr")) == .session("sr-rq7dgr"))
        #expect(sidebar.row(showing: .project("goosemates")) == .project("goosemates"))
        #expect(sidebar.row(showing: nil) == nil)
        #expect(Sidebar(unlisted, folds: Folds()).row(showing: .session("sr-k7t001")) == .session("sr-k7t001"))
    }

    /// The list selects the pick's own row alone: none for Kit's away session, which Kit's row stands in for, so a
    /// click on Kit's row picks Kit.
    @Test func theListSelectsNoRowStandingInForASession() {
        let sidebar = Sidebar(Self.first, folds: Folds(projects: false))

        #expect(sidebar.selection(for: .session("sr-k7t001")) == nil)
        #expect(sidebar.selection(for: .project("kit")) == .project("kit"))
        #expect(sidebar.selection(for: .session("sr-rq7dgr")) == .session("sr-rq7dgr"))
    }

    /// Kit's away session stands at Kit's row, the list's last, which the list does not select: from it ↑ goes to
    /// Goosemates and ↓ nowhere; under Projects folded, from its heading, the list's last line; its project not listed,
    /// as today, the list's own.
    @Test func fromASessionWithNoRowAStepGoesFromItsProjectsRow() {
        var unlisted = Self.first

        unlisted.projects.removeAll { $0.id == "kit" }

        let open = Sidebar(Self.first, folds: Folds(projects: false))
        let folded = Sidebar(Self.first, folds: Folds())

        #expect(open.step(from: .session("sr-k7t001"), down: false) == .to(.project("goosemates")))
        #expect(open.step(from: .session("sr-k7t001"), down: true) == .stays)
        #expect(folded.step(from: .session("sr-k7t001"), down: false) == .to(.session("sr-rq7dgr")))
        #expect(folded.step(from: .session("sr-k7t001"), down: true) == .stays)
        #expect(Sidebar(unlisted, folds: Folds()).step(from: .session("sr-k7t001"), down: false) == .listsOwn)
    }

    @Test func fromARowUnderAFoldedNEarlierAStepGoesFromIt() {
        let sidebar = Sidebar(Self.marked(Self.first, earlier: ["sr-rq7dgr"]), folds: Folds(projects: false))

        #expect(sidebar.step(from: .session("sr-rq7dgr"), down: true) == .to(.project("sitrep")))
        #expect(sidebar.step(from: .session("sr-rq7dgr"), down: false) == .to(.session("sr-gs7kq2")))
    }

    @Test func fromAHiddenPickWithNoRowBeforeItUpStays() {
        let sidebar = Sidebar(Self.bySession, folds: Folds(sections: [.needsYou]))

        #expect(sidebar.step(from: .session("sr-dash02"), down: false) == .stays)
    }

    /// The list's own keys move from a row it selects, from a pick it does not list, and from none.
    @Test func fromARowTheListSelectsOrAPickItDoesNotListTheStepIsTheListsOwn() {
        let sidebar = Sidebar(Self.bySession, folds: Folds())

        #expect(sidebar.step(from: .session("sr-dash02"), down: true) == .listsOwn)
        #expect(sidebar.step(from: .session("sr-gone"), down: true) == .listsOwn)
        #expect(sidebar.step(from: nil, down: true) == .listsOwn)
    }

    @Test func aFoldTogglesAndNEarlierOpensOfItsOwn() {
        var folds = Folds()

        folds.toggle(.section(.needsYou))
        folds.toggle(.projects)
        folds.toggle(.earlier)
        #expect(folds == Folds(sections: [.needsYou, .snoozed], projects: false, isEarlierOpen: true))
        #expect(folds.contains(.section(.needsYou)) && !folds.contains(.projects) && !folds.contains(.earlier))
        folds.toggle(.section(.needsYou))
        #expect(!folds.contains(.section(.needsYou)))
    }

    /// These sessions' rows marked past the fold period, as the window marks them by the wall clock.
    private static func marked(_ listed: Listed, earlier: Set<String>) -> Listed {
        var marked = listed

        marked.rows = listed.rows.map { row in
            var row = row

            row.isEarlier = earlier.contains(row.id)
            return row
        }
        return marked
    }

    private static func headings(_ sidebar: Sidebar) -> [Sidebar.Heading] {
        sidebar.lines.compactMap { line in
            if case let .heading(heading) = line {
                return heading
            }
            return nil
        }
    }
}

/// The folds, kept across launches in the window's saved value of its own.
struct SidebarSettingsTests {
    @Test func nothingSavedIsSnoozedAndProjectsFoldedAlone() {
        let defaults = MemoryDefaults()
        let folds = SavedSettings<SidebarSettings>(defaults).read().folds

        #expect(folds == Folds())
        #expect(folds.projects && folds.sections == [.snoozed] && !folds.isEarlierOpen)
    }

    /// Snoozed unfolded is kept, as any fold is, by the value saying so.
    @Test func snoozedUnfoldedIsReadBack() {
        let defaults = MemoryDefaults()

        SavedSettings<SidebarSettings>(defaults).save(Folds(sections: [], projects: true))

        #expect(SavedSettings<SidebarSettings>(defaults).read().folds.sections.isEmpty)
    }

    @Test func theFoldsAreReadBackUnderTheWindowsKeyEachSectionsOwn() {
        let defaults = MemoryDefaults()
        let folds = Folds(sections: [.needsYou, .yourTurn], projects: false)

        SavedSettings<SidebarSettings>(defaults).save(folds)
        #expect(SavedSettings<SidebarSettings>(defaults).read().folds == folds)
        #expect(defaults.data(forKey: "window") != nil)
    }

    /// What it holds is stale, so "N earlier" is folded each time the window opens.
    @Test func nEarlierOpenIsNeverKept() {
        let defaults = MemoryDefaults()

        SavedSettings<SidebarSettings>(defaults).save(Folds(isEarlierOpen: true))
        #expect(!SavedSettings<SidebarSettings>(defaults).read().folds.isEarlierOpen)
        #expect(Folds(sections: [.working], projects: false, isEarlierOpen: true).kept == Folds(sections: [.working], projects: false))
    }

    /// Round 7's saved view, round 8's projects folded by their keys, or a section this version doesn't know: what it
    /// cannot read gives the defaults, the rest kept, Snoozed, of which a value saved before it says nothing, folded.
    @Test func whatItCannotReadIsTheDefaults() {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"sidebar":"needsYou"}"#.utf8), forKey: SidebarSettings.key)
        #expect(SavedSettings<SidebarSettings>(defaults).read().folds == Folds())

        defaults.set(Data(#"{"folds":{"projects":["kit"],"quiet":true}}"#.utf8), forKey: SidebarSettings.key)
        #expect(SavedSettings<SidebarSettings>(defaults).read().folds == Folds())

        defaults.set(Data(#"{"folds":{"sections":["working","later"],"projects":false}}"#.utf8), forKey: SidebarSettings.key)
        #expect(SavedSettings<SidebarSettings>(defaults).read().folds == Folds(sections: [.working, .snoozed], projects: false))
    }
}
