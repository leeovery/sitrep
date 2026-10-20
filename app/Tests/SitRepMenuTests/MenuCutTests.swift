import SitRepMenu
import Testing

/// The menu's words cut to their share of its width, measured run by run in each one's face: here a point a
/// character, two in mono, half in a subtitle, and an ellipsis in the face it ends.
struct MenuCutTests {
    private static let cut = MenuCut(title: 20, subtitle: 10) { text, face in
        Double(text.count) * (face == .mono ? 2 : face == .subtitle ? 0.5 : 1)
    }

    @Test func aTitleThatFitsIsLeftWhole() {
        let title = MenuTitle(words: "Allow Bash: ", mono: "ls", more: nil, isFaint: false)

        #expect(title.cut(by: Self.cut) == title)
    }

    @Test func aTitlePastTheWidthIsCutAtItsTailWithAnEllipsis() {
        let title = MenuTitle(words: "Choose which edge the strip takes", mono: nil, more: nil, isFaint: true)

        #expect(title.cut(by: Self.cut) == MenuTitle(words: "Choose which edge t…", mono: nil, more: nil, isFaint: true))
    }

    @Test func theCutDropsTheSpaceBeforeTheEllipsis() {
        #expect(Self.cut.fit("Choose which edges  more", in: .words) == "Choose which edges…")
    }

    @Test func aSubjectIsMeasuredInMonoAndCutInIt() {
        let title = MenuTitle(words: "Allow Bash: ", mono: "gh pr create", more: nil, isFaint: false)

        #expect(title.cut(by: Self.cut) == MenuTitle(words: "Allow Bash: ", mono: "gh…", more: nil, isFaint: false))
    }

    @Test func aCutInTheWordsDropsTheSubjectAfterThem() {
        let title = MenuTitle(words: "Allow the long running thing: ", mono: "ls", more: nil, isFaint: false)

        #expect(title.cut(by: Self.cut) == MenuTitle(words: "Allow the long runn…", mono: nil, more: nil, isFaint: false))
    }

    @Test func aQuestionsCountIsKeptWholeAfterTheCut() {
        let title = MenuTitle(words: "Which edge does the strip take?", mono: nil, more: " +2", isFaint: false)

        #expect(title.cut(by: Self.cut) == MenuTitle(words: "Which edge does…", mono: nil, more: " +2", isFaint: false))
    }

    @Test func everyCutFitsTheWidth() {
        for length in 0 ... 60 {
            let line = String(repeating: "ab ", count: length)

            #expect(Self.cut.fit(line, in: .words).count <= 20)
        }
    }

    @Test func aLineUnderTheTitleIsCutInItsOwnFaceToItsOwnWidth() {
        #expect(Self.cut.fit("SitRep · Build the Mac app", in: .subtitle) == "SitRep · Build the…")
        #expect(Self.cut.fit("SitRep · Build the Mac app and more", in: .words) == "SitRep · Build the…")
    }
}
