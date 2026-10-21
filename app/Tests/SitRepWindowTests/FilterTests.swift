import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// The Filter field's rule, over the first line the real `watch` printed: every word typed, in any case and with or
/// without its accents, somewhere in a session's name or its project's; the words lit where they appear.
struct FilterTests {
    private static let listed = Listed(heard(line(0)))

    private static func lit(_ text: String) -> Filter.Run { Filter.Run(text: text, isLit: true) }
    private static func soft(_ text: String) -> Filter.Run { Filter.Run(text: text, isLit: false) }

    @Test(arguments: ["ledg", "LEDG", "lédg", "Ledg  "])
    func aWordMatchesWhateverItsCaseAndAccents(_ typed: String) {
        #expect(Filter(typed).matches("Request ledger"))
    }

    @Test func everyWordMustAppearInTheSessionsNameOrItsProjects() {
        #expect(Filter("switch ledg").matches("Request ledger", "Switchboard"))
        #expect(!Filter("ledg kit").matches("Request ledger", "Switchboard"))
    }

    @Test func nothingButSpacesIsNoFilter() {
        #expect(Filter("   ").isEmpty)
        #expect(Self.listed.narrowed(by: Filter("  ")) == Self.listed)
    }

    @Test func inProjectsAMatchStaysUnderItsProjectWhoseCountIsStillOfAllItsSessions() throws {
        let narrowed = Self.listed.narrowed(by: Filter("ledg"))
        let switchboard = try #require(narrowed.projects.first)

        #expect(narrowed.projects.map(\.id) == ["switchboard"])
        #expect(switchboard.sessions.map(\.name) == ["Request ledger"])
        #expect(switchboard.waiting == 2)
        #expect(narrowed.quiet.isEmpty)
    }

    @Test func inNeedsYouTheMatchesKeepThePanelsOrder() {
        #expect(Self.listed.narrowed(by: Filter("e")).flat.map(\.id) == [
            "sr-macapp", "sr-dash02", "sr-gs7kq2", "sr-rq7dgr", "sr-k7t001",
        ])
        #expect(Self.listed.narrowed(by: Filter("le")).flat.map(\.id) == ["sr-gs7kq2", "sr-rq7dgr"])
    }

    @Test func typingAProjectsNameListsItsSessions() {
        let narrowed = Self.listed.narrowed(by: Filter("switchboard"))

        #expect(narrowed.sessions.map(\.id) == ["sr-dash02", "sr-rq7dgr"])
        #expect(narrowed.flat.map(\.id) == ["sr-dash02", "sr-rq7dgr"])
    }

    @Test func aQuietProjectShowsWhileItsNameHoldsEveryWord() {
        let narrowed = Self.listed.narrowed(by: Filter("kit"))

        #expect(narrowed.quiet.map(\.name) == ["Kit"])
        #expect(narrowed.projects.isEmpty)
        #expect(narrowed.flat.map(\.name) == ["The bootstrap"])
        #expect(Self.listed.narrowed(by: Filter("kit ledg")).quiet.isEmpty)
    }

    @Test(arguments: ["ledg", "LÉDG"])
    func theMatchedLettersAreLitAndTheRestSoft(_ typed: String) {
        #expect(Filter(typed).runs(of: "Request ledger") == [Self.soft("Request "), Self.lit("ledg"), Self.soft("er")])
    }

    @Test func aNameWithoutTheWordIsAllSoft() {
        #expect(Filter("ledg").runs(of: "Switchboard") == [Self.soft("Switchboard")])
    }

    @Test func everyWordIsLitWhereverItAppearsWordsThatMeetLitAsOne() {
        #expect(Filter("led dge").runs(of: "ledger") == [Self.lit("ledge"), Self.soft("r")])
        #expect(Filter("e").runs(of: "Settle") == [
            Self.soft("S"), Self.lit("e"), Self.soft("ttl"), Self.lit("e"),
        ])
        #expect(Filter("set  le").runs(of: "Settle") == [Self.lit("Set"), Self.soft("t"), Self.lit("le")])
    }

    /// Foundation finds "ß" first at the "St" of a name, which is not where it is, nor anywhere in "Stop the build".
    @Test func aWordWhoseFoldingChangesItsLengthMatchesOnlyWhereItIs() {
        #expect(!Filter("ß").matches("Stop the build"))
        #expect(!Filter("ße").matches("Stem cells"))
        #expect(Filter("ß").matches("Straße"))
        #expect(Filter("ß").matches("the strasse"))
    }

    @Test func aWordWhoseFoldingChangesItsLengthLightsOnlyWhereItIs() {
        #expect(Filter("ß").runs(of: "Straße") == [Self.soft("Stra"), Self.lit("ß"), Self.soft("e")])
        #expect(Filter("ß").runs(of: "the strasse") == [Self.soft("the stra"), Self.lit("ss"), Self.soft("e")])
        #expect(Filter("ss").runs(of: "Straße") == [Self.soft("Stra"), Self.lit("ß"), Self.soft("e")])
    }

    @Test func aQuietProjectShowsInProjectsWhileOneOfItsSessionsMatches() {
        let narrowed = Self.listed.narrowed(by: Filter("boot"))

        #expect(narrowed.quiet.map(\.name) == ["Kit"])
        #expect(!narrowed.isEmpty(in: .projects))
        #expect(narrowed.first(in: .projects) == .project("kit"))
        #expect(narrowed.flat.map(\.name) == ["The bootstrap"])
    }

    @Test(arguments: [(Tone.text, Tone.soft, Tone.text), (.soft, .soft, .text), (.faint, .faint, .soft)])
    func theLitWordsAreAStepBrighterThanTheRestWhichIsNoBrighterThanSoft(tone: Tone, rest: Tone, lit: Tone) {
        #expect(tone.rest == rest)
        #expect(tone.lit == lit)
    }

    @Test func noMatchSaysWhatWasTyped() {
        #expect(Words.noMatch(Filter("ledg")) == "No sessions match “ledg”")
        #expect(Words.noMatch(Filter(" led g ")) == "No sessions match “led g”")
    }
}
