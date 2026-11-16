@testable import SitRepCore
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct PluginPlanTests {
    private static let home = "/Users/me"
    private static let own = "/Users/me/Library/Application Support/sitrep"
    private static let clone = "/Users/me/Code/sitrep"
    private static let litware = "/Users/me/.config/litware/plugins"
    private static let cache = "/Users/me/.claude/plugins/cache/sitrep/sitrep/0.1.0"

    /// What each folder marketplace's own `marketplace.json` says of sitrep: the clone's and SitRep's own `./`, and
    /// Litware's `./sitrep`.
    private static let entries: [String: MarketplaceEntry] = [own: .within("./"), clone: .within("./"), litware: .within("./sitrep")]

    private static func copy(_ version: String?, build: String? = nil) -> OwnPlugin.Copy? {
        version.map { OwnPlugin.Copy(version: $0, build: build) }
    }

    private static func plan(
        _ marketplaces: String, _ plugins: String = "[]", carried: OwnPlugin.Copy? = copy("0.2.0"),
        copied: OwnPlugin.Copy? = copy("0.2.0"), entries: [String: MarketplaceEntry] = entries
    ) -> PluginPlan {
        PluginPlan(
            marketplaces: ClaudeLists.marketplaces(marketplaces), plugins: ClaudeLists.plugins(plugins),
            own: OwnPlugin(folder: own, carried: carried, copied: copied), home: home, entry: { entries[$0] }
        )
    }

    private static let ownMarketplace = ClaudeLists.list(ClaudeLists.folderMarketplace(path: own))
    private static let ownInstalled = ClaudeLists.list(ClaudeLists.plugin(readFrom: own))
    private static let cloneMarketplace = ClaudeLists.list(ClaudeLists.folderMarketplace(path: clone))
    private static let cloneInstalled = ClaudeLists.list(ClaudeLists.plugin(readFrom: clone))

    // MARK: A sitrep marketplace that is a checkout

    @Test(arguments: [("0.2.0", nil), ("0.3.0", nil), ("0.2.0", "0.1.0"), (nil, nil)] as [(String?, String?)])
    func onLeesMacTheClonesMarketplaceIsLeftAsItIsWhateverSitRepCarries(carried: String?, copied: String?) {
        let clone = "/Users/me/Code/sitrep"
        let plan = PluginPlan(
            marketplaces: ClaudeLists.marketplaces(CloneClaude.marketplaces), plugins: ClaudeLists.plugins(CloneClaude.plugins),
            own: OwnPlugin(folder: "\(CloneClaude.home)/Library/Application Support/sitrep", carried: Self.copy(carried), copied: Self.copy(copied)),
            home: CloneClaude.home, entry: { $0 == clone ? .within("./") : nil }
        )

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .running(.folder("~/Code/sitrep"), folder: clone))
    }

    // MARK: Neither list has anything of sitrep

    @Test func withNothingOfSitrepItCopiesItsOwnAddsItAsTheMarketplaceAndInstallsThePlugin() {
        let plan = Self.plan(ClaudeLists.list(ClaudeLists.folderMarketplace("litware", path: Self.litware)), copied: nil)

        #expect(plan.steps == [.copy, .addMarketplace, .install])
        #expect(plan.standing == .running(.own, folder: Self.own))
    }

    @Test func aFirstInstallCopiesAfreshOverACopyLeftFromBefore() {
        #expect(Self.plan("[]").steps == [.copy, .addMarketplace, .install])
    }

    @Test func withNothingOfSitrepAndNothingCarriedThereIsNothingToInstall() {
        let plan = Self.plan("[]", carried: nil, copied: nil)

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .trouble(.uncarried, folder: nil))
    }

    // MARK: Anything of sitrep SitRep did not install

    @Test func aPluginInstalledFromTheCloneWhoseMarketplaceIsNotListedIsLeftAndRunFromTheClone() {
        // As when known_marketplaces.json is gone: `marketplace list` says [], and the plugin still reads from the
        // clone. Adding SitRep's own would re-point the clone's marketplace.
        let plan = Self.plan("[]", Self.cloneInstalled, copied: nil)

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .running(.folder("~/Code/sitrep"), folder: Self.clone))
    }

    @Test func aSitrepFromAnotherMarketplaceIsLeftAndNoSecondInstalledBesideIt() {
        let marketplaces = ClaudeLists.list(ClaudeLists.folderMarketplace("litware", path: Self.litware))
        let plan = Self.plan(marketplaces, ClaudeLists.list(ClaudeLists.plugin("sitrep@litware", readFrom: "\(Self.litware)/sitrep")))

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .running(.folder("~/.config/litware/plugins"), folder: "\(Self.litware)/sitrep"))
    }

    @Test func aForeignSitrepBesideItsOwnMarketplaceLeavesEverythingAsItIs() {
        let marketplaces = ClaudeLists.list(ClaudeLists.folderMarketplace(path: Self.own), ClaudeLists.folderMarketplace("litware", path: Self.litware))
        let plugins = ClaudeLists.list(ClaudeLists.plugin(readFrom: Self.own), ClaudeLists.plugin("sitrep@litware", readFrom: "\(Self.litware)/sitrep"))

        #expect(Self.plan(marketplaces, plugins, carried: Self.copy("0.3.0")).steps.isEmpty)
    }

    @Test func aPluginOfAnotherNameIsNoSitrep() {
        let plugins = ClaudeLists.list(ClaudeLists.plugin("sitrepper@litware"), ClaudeLists.plugin("review@northwind"))

        #expect(Self.plan("[]", plugins).steps == [.copy, .addMarketplace, .install])
    }

    @Test func aFolderMarketplaceElsewhereIsLeftAndItsPluginRunFromItsFolder() {
        let plan = Self.plan(Self.cloneMarketplace, Self.cloneInstalled, carried: Self.copy("0.3.0"), copied: Self.copy("0.1.0"))

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .running(.folder("~/Code/sitrep"), folder: Self.clone))
    }

    @Test func aFolderMarketplacesPluginIsRunFromItsPlaceInTheFolder() {
        let plan = Self.plan(Self.cloneMarketplace, Self.cloneInstalled, entries: [Self.clone: .within("plugins/sitrep")])

        #expect(plan.standing == .running(.folder("~/Code/sitrep"), folder: "\(Self.clone)/plugins/sitrep"))
    }

    @Test func aCloneWhoseMarketplaceFileIsGoneIsNeverRunFromClaudesCache() {
        let plan = Self.plan(Self.cloneMarketplace, ClaudeLists.list(ClaudeLists.unloaded()), entries: [:])

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .trouble(.unfound(.folder("~/Code/sitrep")), folder: nil))
    }

    @Test func aFolderMarketplacesPluginFetchedFromElsewhereIsRunFromClaudesCopy() {
        let plan = Self.plan(Self.cloneMarketplace, ClaudeLists.list(ClaudeLists.unloaded()), entries: [Self.clone: .fetched])

        #expect(plan.standing == .running(.folder("~/Code/sitrep"), folder: Self.cache))
    }

    @Test func aGithubMarketplaceIsLeftAndItsPluginRunFromClaudesCopy() {
        let plan = Self.plan(ClaudeLists.list(ClaudeLists.github), ClaudeLists.list(ClaudeLists.plugin(version: "0.2.0")), copied: nil)

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .running(.github("leeovery/sitrep"), folder: "/Users/me/.claude/plugins/cache/sitrep/sitrep/0.2.0"))
    }

    @Test func aGithubMarketplaceWithThePluginNotInstalledIsLeftWithNothingToRun() {
        let plan = Self.plan(ClaudeLists.list(ClaudeLists.github))

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .trouble(.unfound(.github("leeovery/sitrep")), folder: nil))
    }

    @Test func anyOtherSourceIsNamedByWhereItIs() {
        let git = ClaudeLists.list(#"{"name": "sitrep", "source": "git", "url": "https://example.com/sitrep.git", "installLocation": "/tmp/sitrep"}"#)

        #expect(Self.plan(git, ClaudeLists.list(ClaudeLists.plugin())).standing
            == .running(.other("https://example.com/sitrep.git"), folder: "/Users/me/.claude/plugins/cache/sitrep/sitrep/0.2.0"))
    }

    @Test func aForeignPluginWhoseMarketplaceIsNotListedNorReadsIsTrouble() {
        #expect(Self.plan("[]", ClaudeLists.list(ClaudeLists.unloaded("sitrep@litware"))).standing == .trouble(.unfound(.other("litware")), folder: nil))
    }

    // MARK: The sitrep marketplace is SitRep's own copy

    @Test func itsOwnAtTheBuildItCarriesIsLeftAlone() {
        let plan = Self.plan(Self.ownMarketplace, Self.ownInstalled)

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .running(.own, folder: Self.own))
    }

    @Test func itsOwnAtAnotherVersionIsReplacedAndTheMarketplaceAndPluginUpdated() {
        #expect(Self.plan(Self.ownMarketplace, Self.ownInstalled, carried: Self.copy("0.3.0")).steps == [.copy, .updateMarketplace, .update])
        #expect(Self.plan(Self.ownMarketplace, Self.ownInstalled, carried: Self.copy("0.1.0")).steps == [.copy, .updateMarketplace, .update])
    }

    @Test func aRebuildAtTheSameVersionIsCopiedByItsBuildAndNeedsNoUpdate() {
        let plan = Self.plan(Self.ownMarketplace, Self.ownInstalled, carried: Self.copy("0.2.0", build: "b2"), copied: Self.copy("0.2.0", build: "b1"))

        #expect(plan.steps == [.copy])
        #expect(Self.plan(Self.ownMarketplace, Self.ownInstalled, carried: Self.copy("0.2.0", build: "b1"), copied: Self.copy("0.2.0", build: "b1")).steps.isEmpty)
    }

    @Test func aCopyMadeBeforeStampsIsReplacedByAStampedOne() {
        #expect(Self.plan(Self.ownMarketplace, Self.ownInstalled, carried: Self.copy("0.2.0", build: "b1")).steps == [.copy])
    }

    @Test func aRefreshCutShortAfterItsCopyIsFinishedAtTheNextStart() {
        let behind = ClaudeLists.list(ClaudeLists.plugin(version: "0.2.0", readFrom: Self.own))

        #expect(Self.plan(Self.ownMarketplace, behind, carried: Self.copy("0.3.0"), copied: Self.copy("0.3.0")).steps == [.updateMarketplace, .update])
    }

    @Test func itsOwnWithItsCopyGoneIsCopiedAgain() {
        let unloaded = ClaudeLists.list(ClaudeLists.unloaded(version: "0.2.0"))

        #expect(Self.plan(Self.ownMarketplace, unloaded, copied: nil).steps == [.copy])
    }

    @Test func itsOwnWithThePluginNotInstalledInstallsIt() {
        #expect(Self.plan(Self.ownMarketplace).steps == [.install])
        #expect(Self.plan(Self.ownMarketplace, carried: Self.copy("0.3.0")).steps == [.copy, .updateMarketplace, .install])
    }

    @Test func itsOwnPluginWhoseMarketplaceIsNotListedIsRunAndLeft() {
        let plan = Self.plan("[]", Self.ownInstalled, carried: Self.copy("0.3.0"))

        #expect(plan.steps.isEmpty)
        #expect(plan.standing == .running(.own, folder: Self.own))
    }

    @Test func itsOwnIsKnownByItsFolderHoweverClaudeWritesIt() {
        let marketplace = ClaudeLists.list(ClaudeLists.folderMarketplace(path: "/Users/me/Library/Application Support/./sitrep/"))

        #expect(Self.plan(marketplace, Self.ownInstalled).standing == .running(.own, folder: Self.own))
    }

    @Test func itsOwnWithNothingCarriedIsLeftAsItIs() {
        #expect(Self.plan(Self.ownMarketplace, Self.ownInstalled, carried: nil).steps.isEmpty)
        #expect(Self.plan(Self.ownMarketplace, Self.ownInstalled, carried: nil, copied: nil).steps.isEmpty)
    }
}
