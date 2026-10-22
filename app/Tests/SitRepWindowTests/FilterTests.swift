import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// The Filter field's rule, over the first line the real `watch` printed: every word typed, in any case and with or
/// without its accents, somewhere in a session's name, its project's or its lines' words, or in a project's name; the
/// words lit where they appear.
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

    /// A session by its name and its project's, in its section; typing a project's name lists its sessions.
    @Test func aSessionIsFoundByItsNameAndItsProjectsInItsSection() {
        let ledger = Self.listed.narrowed(by: Filter("ledg"))
        let switchboard = Self.listed.narrowed(by: Filter("switchboard"))

        #expect(ledger.rows.map(\.id) == ["sr-rq7dgr"])
        #expect(ledger.rows(in: .yourTurn).map(\.id) == ["sr-rq7dgr"])
        #expect(switchboard.rows.map(\.id) == ["sr-dash02", "sr-rq7dgr"])
    }

    /// A session by its lines' words too: the Mac app's ask about the strip's edge, Dashboard redesign's prompt to run
    /// `gh pr create`, Request ledger's turn drawing its schema.
    @Test func aSessionIsFoundByAnyOfItsLinesWords() {
        #expect(Self.listed.narrowed(by: Filter("strip edge")).rows.map(\.id) == ["sr-macapp"])
        #expect(Self.listed.narrowed(by: Filter("gh pr")).rows.map(\.id) == ["sr-dash02"])
        #expect(Self.listed.narrowed(by: Filter("schema")).rows.map(\.id) == ["sr-rq7dgr"])
    }

    /// A working row by what it acts on, as `watch` printed it: Kit's "Waiting on 3 agents".
    @Test func aWorkingSessionIsFoundByWhatItActsOn() {
        let listed = Listed(heard(.line(Lines.bySession[0])))

        #expect(listed.narrowed(by: Filter("3 agents")).rows.map(\.id) == ["sr-k7bt2s"])
    }

    @Test func eachSectionFiltersByTheSameRuleItsMatchesInTheirOrder() {
        #expect(Self.listed.narrowed(by: Filter("e")).needsYou.map(\.id) == ["sr-macapp", "sr-dash02", "sr-gs7kq2"])
        #expect(Self.listed.narrowed(by: Filter("le")).rows.map(\.id) == ["sr-gs7kq2", "sr-rq7dgr"])
        #expect(Self.listed.narrowed(by: Filter("ledg")).needsYou.isEmpty)
    }

    /// A section with no match goes, heading and all.
    @Test func aSectionWithNoMatchGoesFromTheList() {
        let sidebar = Sidebar(Self.listed.narrowed(by: Filter("ledg")), folds: .open)

        #expect(sidebar.lines.map(\.id) == [.fold(.section(.yourTurn)), .pick(.session("sr-rq7dgr"))])
    }

    /// A project by its name alone: Kit's, whose session is The bootstrap, but not by that.
    @Test func aProjectShowsInProjectsWhileItsNameHoldsEveryWord() {
        #expect(Self.listed.narrowed(by: Filter("kit")).projects.map(\.name) == ["Kit"])
        #expect(Self.listed.narrowed(by: Filter("kit")).rows.isEmpty)
        #expect(Self.listed.narrowed(by: Filter("boot")).projects.isEmpty)
        #expect(Self.listed.narrowed(by: Filter("kit ledg")).projects.isEmpty)
    }

    /// "No sessions match" shows only where nothing matches anywhere in the list.
    @Test func theListIsEmptyOnlyWithNothingMatchingAnywhere() {
        #expect(Sidebar(Self.listed.narrowed(by: Filter("zzz")), folds: .open).isEmpty)
        #expect(!Sidebar(Self.listed.narrowed(by: Filter("kit")), folds: .open).isEmpty)
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

    @Test(arguments: [
        (Tone.text, Tone.soft, Tone.text), (.soft, .soft, .text), (.dim, .dim, .soft), (.faint, .faint, .soft),
    ])
    func theLitWordsAreAStepBrighterThanTheRestWhichIsNoBrighterThanSoft(tone: Tone, rest: Tone, lit: Tone) {
        #expect(tone.rest == rest)
        #expect(tone.lit == lit)
    }

    @Test func noMatchSaysWhatWasTyped() {
        #expect(Words.noMatch(Filter("ledg")) == "No sessions match “ledg”")
        #expect(Words.noMatch(Filter(" led g ")) == "No sessions match “led g”")
    }
}
