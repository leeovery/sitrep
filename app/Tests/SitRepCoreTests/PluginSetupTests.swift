import Foundation
import os
@testable import SitRepCore
import Testing

struct PluginSetupTests {
    private static let path = "/opt/homebrew/bin:/usr/bin:/bin"

    /// The setup over the scratch folder's copies, with the fake as the one `claude` there is, or none, and every
    /// folder marketplace's plugin at its root.
    private static func setup(
        _ scratch: Scratch, _ fake: FakeClaude?, home: String = "/Users/me", remembered: RememberedPlugin = RememberedPlugin.inMemory().remembered
    ) -> PluginSetup {
        let isThere = fake != nil

        return PluginSetup(
            copies: scratch.copies, remembered: remembered, home: home, path: { path }, environment: ["HOME": home],
            run: fake?.run ?? Self.unrun, isExecutable: { isThere && $0 == "\(home)/.local/bin/claude" },
            entry: { _ in .within("./") }
        )
    }

    private static let unrun: Runner = { _ in
        Issue.record("Nothing is run with no claude")
        return Ran(status: 1, stdout: "", stderr: "")
    }

    private static func own(_ scratch: Scratch, version: String = "0.2.0") -> (marketplaces: String, plugins: String) {
        (
            ClaudeLists.list(ClaudeLists.folderMarketplace(path: scratch.own.path)),
            ClaudeLists.list(ClaudeLists.plugin(version: version, readFrom: scratch.own.path))
        )
    }

    // MARK: Lee's Mac

    @Test func onLeesMacOnlyTheListsRunAndNothingIsCopied() async throws {
        let scratch = Scratch()
        let fake = FakeClaude(marketplaces: CloneClaude.marketplaces, plugins: CloneClaude.plugins)
        let (remembered, read) = RememberedPlugin.inMemory()

        try scratch.plugin("0.3.0", at: scratch.carried)

        let standing = await Self.setup(scratch, fake, home: CloneClaude.home, remembered: remembered).look()

        #expect(fake.runs == ["plugin marketplace list --json", "plugin list --json"])
        #expect(standing == .running(.folder("~/Code/sitrep"), folder: "/Users/me/Code/sitrep"))
        #expect(!FileManager.default.fileExists(atPath: scratch.own.deletingLastPathComponent().path))
        #expect(read() == "/Users/me/Code/sitrep")
    }

    // MARK: Installing and refreshing its own

    @Test func theFirstStartCopiesItsPluginOutAddsItAsTheMarketplaceAndInstallsIt() async throws {
        let scratch = Scratch()
        let fake = FakeClaude(marketplaces: "[]", plugins: "[]")

        try scratch.plugin("0.2.0", at: scratch.carried)

        let standing = await Self.setup(scratch, fake).look()

        #expect(fake.runs == [
            "plugin marketplace list --json", "plugin list --json",
            "plugin marketplace add \(scratch.own.path) --json", "plugin install sitrep@sitrep --json",
        ])
        #expect(standing == .running(.own, folder: scratch.own.path))
        #expect(scratch.read(scratch.own.appending(path: "bin/sitrep")) == "sitrep 0.2.0")
    }

    @Test func aRelaunchAtTheSameBuildChangesNothing() async throws {
        let scratch = Scratch()
        let (marketplaces, plugins) = Self.own(scratch)
        let fake = FakeClaude(marketplaces: marketplaces, plugins: plugins)

        try scratch.plugin("0.2.0", at: scratch.carried)
        try scratch.plugin("0.2.0", at: scratch.own, cli: "as it was")

        let standing = await Self.setup(scratch, fake).look()

        #expect(fake.runs == ["plugin marketplace list --json", "plugin list --json"])
        #expect(standing == .running(.own, folder: scratch.own.path))
        #expect(scratch.read(scratch.own.appending(path: "bin/sitrep")) == "as it was")
    }

    @Test func aRelaunchAtANewerVersionReplacesTheCopyThenUpdatesTheMarketplaceAndThePlugin() async throws {
        let scratch = Scratch()
        let (marketplaces, plugins) = Self.own(scratch)
        let fake = FakeClaude(marketplaces: marketplaces, plugins: plugins)

        try scratch.plugin("0.3.0", at: scratch.carried)
        try scratch.plugin("0.2.0", at: scratch.own)

        let standing = await Self.setup(scratch, fake).look()

        #expect(fake.runs == [
            "plugin marketplace list --json", "plugin list --json",
            "plugin marketplace update sitrep --json", "plugin update sitrep@sitrep --json",
        ])
        #expect(standing == .running(.own, folder: scratch.own.path))
        #expect(scratch.read(scratch.own.appending(path: "bin/sitrep")) == "sitrep 0.3.0")
    }

    @Test func aRebuildAtTheSameVersionReplacesTheCopyByItsStamp() async throws {
        let scratch = Scratch()
        let (marketplaces, plugins) = Self.own(scratch)
        let fake = FakeClaude(marketplaces: marketplaces, plugins: plugins)

        try scratch.plugin("0.2.0", at: scratch.carried, cli: "rebuilt")
        try scratch.write("b2", to: scratch.carried.appending(path: PluginCopies.buildFile))
        try scratch.plugin("0.2.0", at: scratch.own)
        try scratch.write("b1", to: scratch.own.appending(path: PluginCopies.buildFile))

        _ = await Self.setup(scratch, fake).look()

        #expect(fake.runs == ["plugin marketplace list --json", "plugin list --json"])
        #expect(scratch.read(scratch.own.appending(path: "bin/sitrep")) == "rebuilt")
    }

    // MARK: Trouble

    @Test func withNoClaudeItSaysSoAndRunsItsOwnCopyWhereItHasOne() async throws {
        let scratch = Scratch()

        #expect(await Self.setup(scratch, nil).look() == .trouble(.noClaude, folder: nil))

        try scratch.plugin("0.2.0", at: scratch.own)

        #expect(await Self.setup(scratch, nil).look() == .trouble(.noClaude, folder: scratch.own.path))
    }

    @Test func troubleRunsThePluginOfTheLastLookThatWentWellWhileItIsThere() async throws {
        let scratch = Scratch()
        let last = scratch.folder.appending(path: "Code/sitrep")
        let failing = FakeClaude(marketplaces: "torn", plugins: "[]")

        try scratch.plugin("0.2.0", at: scratch.own)
        try scratch.plugin("0.2.0", at: last)

        let remembered = RememberedPlugin.inMemory(last.path).remembered

        #expect(await Self.setup(scratch, failing, remembered: remembered).look().folder == last.path)

        try FileManager.default.removeItem(at: last)

        #expect(await Self.setup(scratch, failing, remembered: remembered).look().folder == scratch.own.path)
    }

    @Test func aStepThatFailsStopsThereInClaudesWordsAndRunsItsOwnCopy() async throws {
        let scratch = Scratch()
        let refused = Ran(status: 1, stdout: #"{"outcome":"failed","message":"Marketplace 'sitrep' has no plugins"}"#, stderr: "")
        let fake = FakeClaude(marketplaces: "[]", plugins: "[]", answers: ["plugin marketplace add \(scratch.own.path) --json": refused])
        let (remembered, read) = RememberedPlugin.inMemory()

        try scratch.plugin("0.2.0", at: scratch.carried)

        let standing = await Self.setup(scratch, fake, remembered: remembered).look()

        #expect(fake.runs.last == "plugin marketplace add \(scratch.own.path) --json")
        #expect(standing == .trouble(.failed("Marketplace 'sitrep' has no plugins"), folder: scratch.own.path))
        #expect(read() == nil)
    }

    @Test func aListThatFailsChangesNothing() async throws {
        let scratch = Scratch()
        let fake = FakeClaude(marketplaces: "not JSON", plugins: "[]")

        try scratch.plugin("0.2.0", at: scratch.carried)

        let standing = await Self.setup(scratch, fake).look()

        #expect(fake.runs == ["plugin marketplace list --json"])
        #expect(standing == .trouble(.failed("claude plugin marketplace list --json printed what SitRep can't read."), folder: nil))
    }

    // MARK: Looking again

    @Test func afterTroubleItLooksAgainWaitingLongerEachTimeUntilALookRuns() async throws {
        let scratch = Scratch()
        let looks = OSAllocatedUnfairLock(initialState: 0)
        let waits = OSAllocatedUnfairLock<[Duration]>(initialState: [])
        let fake = FakeClaude(marketplaces: CloneClaude.marketplaces, plugins: CloneClaude.plugins)
        let setup = PluginSetup(
            copies: scratch.copies, remembered: RememberedPlugin.inMemory().remembered, home: CloneClaude.home,
            path: { Self.path }, environment: [:], run: fake.run,
            // `claude` comes at the fourth look, its installer's place the first each look tries.
            isExecutable: { place in
                place == "\(CloneClaude.home)/.local/bin/claude" && looks.withLock { looks in looks += 1; return looks > 3 }
            },
            entry: { _ in .within("./") }
        )
        var standings: [PluginStanding] = []

        for await standing in setup.standings(waiting: { wait in waits.withLock { $0.append(wait) } }) {
            standings.append(standing)
        }

        #expect(standings.map(\.trouble) == [.noClaude, .noClaude, .noClaude, nil])
        #expect(waits.withLock { $0 } == [.seconds(1), .seconds(2), .seconds(4)])
        #expect(standings.last == .running(.folder("~/Code/sitrep"), folder: "/Users/me/Code/sitrep"))
    }
}
