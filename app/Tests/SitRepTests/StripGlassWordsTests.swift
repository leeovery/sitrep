import AppKit
@testable import SitRep
@testable import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// The strip's tab on glass says what the black's says, in the black's own type and spacing, and fits the room the
/// black measures for it: a tab sized to its words as the strip sizes one, but with no slack, draws its title whole on
/// each, as it draws in a tab with room to spare, and ending where the black's ends, each read from its pixels at 2×.
@MainActor
@Suite(.backstop)
struct StripGlassWordsTests {
    private static let ground = CGPoint(x: 1, y: 1)
    private static let tall = 46.0
    private static let scene = StripScene.resting()

    /// Room to spare, past any title here.
    private static let unbounded = 400.0

    /// A tab as wide as its row's words need, its time's lane after them, rounded up to a whole point as the strip
    /// rounds it, with none of the tab's slack.
    private static func tight(_ s: Session) -> CGSize {
        let words = StripWordsLayer.rowWidth(s, at: scene.now)
        let age = StripRowLayout.ageWidth(scene.note.age(s, at: scene.now))
        let pad = StripRowLayout.pad

        return CGSize(width: (pad.left + words + StripRowLayout.gap + age + pad.right).rounded(.up), height: tall)
    }

    /// A count's tab as wide as its row's words need, as the strip rounds it.
    private static func tight(rows s: Session) -> CGSize {
        let pad = StripRowLayout.pad

        let words = StripWordsLayer.countRowWidth(s, at: scene.now)

        return CGSize(width: (pad.left + words + pad.right).rounded(.up), height: 60)
    }

    private static func black(_ content: StripFrame.Words.Content, in size: CGSize) throws -> Drawn {
        let tab = CGRect(origin: .zero, size: size)
        let words = StripFrame.Words(
            id: 1, key: .count(.working), content: content, frame: tab, scroll: 0, alpha: 1, dy: 0, isPressed: false,
            pressedRow: nil
        )

        return try Drawn(StripWordsLayer(words, in: tab, scene).layer)
    }

    /// What is inked in a title's box, a little either side of it.
    private static func inked(
        _ drawn: Drawn, in box: CGRect, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> CGRect {
        try #require(drawn.drawnBox(in: box.insetBy(dx: -2, dy: -2), ground: ground), sourceLocation: sourceLocation)
    }

    /// A tab's title inked whole on each material, as far as in a tab with room to spare, within a point, and on
    /// glass ending where the black's ends: in a tab as wide as its words need, or with slack, where glass setting its
    /// words wider would show past the black's.
    @available(macOS 26, *)
    private static func expectTabWhole(
        _ s: Session, slack: Double = 0, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let drawn = { (width: Double) throws -> (glass: CGRect, black: CGRect) in
            let size = CGSize(width: width, height: tall)
            let box = StripRowLayout(s, note: scene.note, in: size, now: scene.now).title
            let glass = try Drawn(GlassRow(session: s, size: size, pressed: false, scene: scene), size: size)

            return try (
                inked(glass, in: box, sourceLocation: sourceLocation),
                inked(black(.row(s), in: size), in: box, sourceLocation: sourceLocation)
            )
        }
        let width = tight(s).width + slack
        let tab = try drawn(width), whole = try drawn(width + unbounded)

        expectWhole(tab, as: whole, sourceLocation: sourceLocation)
    }

    /// Each material's title inked as far as when whole, and glass's ending where the black's ends.
    private static func expectWhole(
        _ tab: (glass: CGRect, black: CGRect), as whole: (glass: CGRect, black: CGRect),
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let at = sourceLocation

        #expect(abs(tab.glass.maxX - whole.glass.maxX) <= 1, "glass to \(tab.glass.maxX), whole", sourceLocation: at)
        #expect(abs(tab.black.maxX - whole.black.maxX) <= 1, "black to \(tab.black.maxX), whole", sourceLocation: at)
        #expect(abs(tab.glass.maxX - tab.black.maxX) <= 1, "glass to \(tab.glass.maxX), black", sourceLocation: at)
    }

    /// Working with a subject plain after its verb: both say it, and glass draws it whole in the room the black
    /// measures.
    @available(macOS 26, *)
    @Test func aWorkingTabsSubjectIsSaidAndDrawnWholeOnGlass() throws {
        let s = Session(
            id: "w", project: "Coho", kind: .working, title: "Reading ", subject: "AVAVA Tower Wolf",
            sub: "Coho · Fix", since: 0
        )

        let verb = TextLine.width(TextLine.text("Reading ", EdgeStyle.title, EdgeStyle.ink))

        #expect(StripWordsLayer.rowWidth(s, at: Self.scene.now) > verb + 40, "the black says its subject")
        try Self.expectTabWhole(s)
    }

    /// Working with a command after its verb, in code type: drawn whole on glass in the room the black measures.
    @available(macOS 26, *)
    @Test func aWorkingTabsCommandIsDrawnWholeOnGlass() throws {
        try Self.expectTabWhole(Self.commanding)
    }

    private static let commanding = Session(
        id: "c", project: "Coho", kind: .working, title: "Running ", code: "swift test --filter AVAVA",
        sub: "Coho · Fix", since: 0
    )

    /// On its own work, what it waits on spaced tight, as the black spaces it, drawn whole on glass.
    @available(macOS 26, *)
    @Test func anOnItsWorkTabsSubjectIsSpacedAsTheBlacksOnGlass() throws {
        let s = Session(
            id: "o", project: "Lucerne", kind: .onItsWork, title: "Waiting on ", subject: "Lucerne Publishing review",
            sub: "Lucerne · Review", since: 0
        )

        try Self.expectTabWhole(s)
    }

    /// A Needs you tab's count 6 after its name on glass, as on the black, not a pair of spaces' width: in a tab with
    /// room to spare, it ends where the black's ends.
    @available(macOS 26, *)
    @Test func aTabsCountIs6AfterItsTitleOnGlass() throws {
        let s = Session(
            id: "q", project: "Alpine", name: "Lift schedule", kind: .needs,
            lines: (0 ..< 3).map { Session.Line(ask: "k\($0)", title: "Ask \($0)", since: 0) }, sub: "Alpine"
        )

        try #require(s.more == "3")

        try Self.expectTabWhole(s, slack: 40)
    }

    /// A count's row's subject or command in the black's type on glass, drawn whole in the room the black measures.
    @available(macOS 26, *)
    @Test(arguments: [false, true])
    func aCountRowsWordsAreSetAsTheBlacksOnGlass(isCommand: Bool) throws {
        let s = isCommand ? Self.commanding : Session(
            id: "w", project: "Coho", kind: .working, title: "Reading ", subject: "AVAVA Tower Wolf",
            sub: "Coho · Fix", since: 0
        )
        let drawn = { (width: Double) throws -> (glass: CGRect, black: CGRect) in
            let size = CGSize(width: width, height: 60)
            let box = StripRowsLayout(0, width: width)
            let title = box.title.offsetBy(dx: box.box.minX, dy: box.box.minY)
            let rows = GlassRows(sessions: [s], width: width, lit: nil, pressed: false, now: Self.scene.now)
            let glass = try Drawn(rows.frame(width: width, height: size.height, alignment: .topLeading), size: size)

            return try (Self.inked(glass, in: title), Self.inked(Self.black(.rows([s]), in: size), in: title))
        }
        let width = Self.tight(rows: s).width

        try Self.expectWhole(drawn(width), as: drawn(width + Self.unbounded))
    }
}
