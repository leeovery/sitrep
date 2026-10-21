import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepLines
@testable import SitRepWindow
import Testing

/// The sidebar's two views, Projects and Needs you, over the first line the real `watch` printed, and the view kept.
struct SidebarTests {
    private static let listed = Listed(heard(line(0)))

    @Test func needsYouListsEverySessionInThePanelsOrderThenTheAwayOnesWithNothingWaiting() {
        // Goosemates' away ask after the live ones, then Request ledger's turn, then quiet Kit's away session
        #expect(Self.listed.flat.map(\.name) == [
            "The Mac app", "Dashboard redesign", "Settle the older open questions", "Request ledger", "The bootstrap",
        ])
    }

    @Test func aNeedsYouRowNamesItsProjectAndKeepsItsMarkAndTime() throws {
        let ledger = try #require(Self.listed.flat.first { $0.id == "sr-rq7dgr" })

        #expect(Self.listed.flat.map(\.project) == ["SitRep", "Switchboard", "Goosemates", "Switchboard", "Kit"])
        #expect(ledger == Self.listed.sessions.first { $0.id == "sr-rq7dgr" })
    }

    @Test func aSessionWithNoRowComesAfterThoseWithRowsWhereverItsProjectSits() throws {
        let board = try Board.read(projects(["kit", "sitrep", "switchboard", "goosemates"]))

        #expect(Listed.flat(board).map(\.id) == ["sr-macapp", "sr-dash02", "sr-gs7kq2", "sr-rq7dgr", "sr-k7t001"])
    }

    /// SitRep's away session, a minute older than Kit's, comes after it, though SitRep comes first on the board.
    @Test func theSessionsWithNoRowComeTheLatestUpdatedFirstAcrossProjects() throws {
        let line = edited(Lines.watch[0]) { board in
            var projects = board["projects"] as! [[String: Any]]
            var older = (projects[3]["sessions"] as! [[String: Any]])[0]

            older["id"] = "sr-old001"
            older["updatedAt"] = (older["updatedAt"] as! Double) - 60000
            projects[0]["sessions"] = (projects[0]["sessions"] as! [[String: Any]]) + [older]
            board["projects"] = projects
        }

        #expect(Listed.flat(try Board.read(line)).suffix(2).map(\.id) == ["sr-k7t001", "sr-old001"])
    }

    @Test func aViewIsEmptyOnlyWithNothingInIt() {
        let none = Self.listed.narrowed(by: Filter("zzz"))

        #expect(!Self.listed.isEmpty(in: .projects))
        #expect(!Self.listed.isEmpty(in: .needsYou))
        #expect(none.isEmpty(in: .projects))
        #expect(none.isEmpty(in: .needsYou))
        #expect(Listed().isEmpty(in: .needsYou))
    }

    @Test func theViewsAreNamedAsTheSwitchShowsThem() {
        #expect(Sidebar.allCases.map(\.title) == ["Projects", "Needs you"])
    }
}

/// The view chosen, kept across launches in a saved value of its own.
struct WindowSettingsTests {
    private static func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "com.leeovery.sitrep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    @Test func nothingSavedIsProjects() {
        Self.withDefaults { defaults in
            #expect(SavedSettings<WindowSettings>(defaults).read().sidebar == .projects)
        }
    }

    @Test func theViewChosenIsReadBackUnderItsOwnKey() {
        Self.withDefaults { defaults in
            var settings = WindowSettings()

            settings.sidebar = .needsYou
            SavedSettings(defaults).save(settings)

            #expect(SavedSettings<WindowSettings>(defaults).read().sidebar == .needsYou)
            #expect(defaults.data(forKey: "window") != nil)
        }
    }

    /// What the window does as Lee chooses a view.
    @Test func choosingAViewSavesIt() {
        Self.withDefaults { defaults in
            SavedSettings<WindowSettings>(defaults).save(.needsYou)
            #expect(SavedSettings<WindowSettings>(defaults).read().sidebar == .needsYou)
            SavedSettings<WindowSettings>(defaults).save(.projects)
            #expect(SavedSettings<WindowSettings>(defaults).read().sidebar == .projects)
        }
    }

    @Test func aViewItDoesNotKnowIsProjects() {
        Self.withDefaults { defaults in
            defaults.set(Data(#"{"sidebar":"byAge"}"#.utf8), forKey: WindowSettings.key)

            #expect(SavedSettings<WindowSettings>(defaults).read().sidebar == .projects)
        }
    }
}
