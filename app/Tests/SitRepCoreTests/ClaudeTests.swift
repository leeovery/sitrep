import Foundation
@testable import SitRepCore
import Testing

struct ClaudeTests {
    private static let path = "/Users/lee/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"

    private static func claude(_ fake: FakeClaude) -> Claude {
        Claude(executable: fake.executable, path: path, environment: ["HOME": "/Users/lee", "PATH": "/usr/bin:/bin"], run: fake.run)
    }

    private static func failing(_ ran: Ran) -> Runner {
        { _ in ran }
    }

    // MARK: Finding it

    @Test func itIsFoundWhereItsInstallersPutItBeforeLeesPath() {
        let found = Claude.find(home: "/Users/lee", path: "/Users/lee/.local/share/switchboard/bin:/opt/homebrew/bin") { _ in true }

        #expect(found?.path == "/Users/lee/.local/bin/claude")
    }

    @Test func eachInstallersPlaceIsTriedInTurn() {
        let found = Claude.find(home: "/Users/lee", path: "/usr/bin") { $0 == "/usr/local/bin/claude" }

        #expect(found?.path == "/usr/local/bin/claude")
    }

    @Test func elseItIsFoundOnLeesPath() {
        let found = Claude.find(home: "/Users/lee", path: "/Users/lee/.npm/bin:/opt/other/bin") { $0 == "/opt/other/bin/claude" }

        #expect(found?.path == "/opt/other/bin/claude")
    }

    @Test func withNoneThereIsNone() {
        #expect(Claude.find(home: "/Users/lee", path: "/usr/bin:/bin") { _ in false } == nil)
    }

    // MARK: What it runs

    @Test func eachStepIsTheCommandClaudesHelpGivesWithJsonAndLeesPath() async throws {
        let fake = FakeClaude(marketplaces: "[]", plugins: "[]")
        let claude = Self.claude(fake)

        _ = try await claude.marketplaces()
        _ = try await claude.plugins()
        try await claude.addMarketplace("/Users/lee/Library/Application Support/sitrep")
        try await claude.updateMarketplace("sitrep")
        try await claude.install("sitrep@sitrep")
        try await claude.update("sitrep@sitrep")

        #expect(fake.programs.map(\.arguments) == [
            ["plugin", "marketplace", "list", "--json"],
            ["plugin", "list", "--json"],
            ["plugin", "marketplace", "add", "/Users/lee/Library/Application Support/sitrep", "--json"],
            ["plugin", "marketplace", "update", "sitrep", "--json"],
            ["plugin", "install", "sitrep@sitrep", "--json"],
            ["plugin", "update", "sitrep@sitrep", "--json"],
        ])
        #expect(fake.programs.allSatisfy {
            $0.executable == fake.executable && $0.environment == ["HOME": "/Users/lee", "PATH": Self.path] && $0.limit == Claude.limit
        })
    }

    @Test func theListsReadAsLeesMacPrintedThem() async throws {
        let claude = Self.claude(FakeClaude(marketplaces: LeesClaude.marketplaces, plugins: LeesClaude.plugins))
        let sitrep = try await claude.marketplaces().first { $0.name == "sitrep" }
        let plugin = try await claude.plugins().first { $0.id == "sitrep@sitrep" }

        #expect(sitrep?.source == "directory")
        #expect(sitrep?.path == "/Users/leeovery/Code/sitrep")
        #expect(plugin?.readFromFolder == "/Users/leeovery/Code/sitrep")
        #expect(plugin?.version == "0.1.0")
    }

    @Test func aListItCannotReadFails() async {
        let claude = Self.claude(FakeClaude(marketplaces: "Configured marketplaces:", plugins: "[]"))

        await #expect(throws: PluginTrouble.failed("claude plugin marketplace list --json printed what SitRep can't read.")) {
            try await claude.marketplaces()
        }
    }

    // MARK: Its failures, in its words

    @Test func aFailureIsTheMessageOfTheLineJsonEndsOn() async {
        let ran = Ran(
            status: 1,
            stdout: #"{"command":"marketplace-add","outcome":"failed","message":"Path does not exist: /nowhere","failureCode":"invalid_source"}"# + "\n",
            stderr: "✘ Path does not exist: /nowhere\n"
        )
        let claude = Claude(executable: URL(fileURLWithPath: "/claude"), path: Self.path, environment: [:], run: Self.failing(ran))

        await #expect(throws: PluginTrouble.failed("Path does not exist: /nowhere")) { try await claude.addMarketplace("/nowhere") }
    }

    @Test func withNoJsonItIsTheLastLineOnStderrWithoutItsCross() {
        let ran = Ran(status: 1, stdout: "Installing plugin \"sitrep@sitrep\"...\n", stderr: "✘ Failed to install plugin \"sitrep@sitrep\": not found\n\n")

        #expect(Claude.complaint(ran) == "Failed to install plugin \"sitrep@sitrep\": not found")
    }

    @Test func sayingNothingItIsTheStatus() async {
        let claude = Claude(executable: URL(fileURLWithPath: "/claude"), path: Self.path, environment: [:], run: Self.failing(Ran(status: 3, stdout: "", stderr: " \n")))

        await #expect(throws: PluginTrouble.failed("claude plugin install sitrep@sitrep --json ended with status 3.")) {
            try await claude.install("sitrep@sitrep")
        }
    }

    @Test func oneThatCannotRunSaysWhy() async {
        let claude = Claude(executable: URL(fileURLWithPath: "/claude"), path: Self.path, environment: [:]) { _ in
            throw RunError.timedOut(60)
        }

        await #expect(throws: PluginTrouble.failed("claude plugin list --json did not answer within 60 seconds.")) {
            try await claude.plugins()
        }
    }
}
