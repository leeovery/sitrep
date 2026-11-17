import AppKit
@testable import SitRep
@testable import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// The strip's tab on glass says what the black's says, in the black's own type and spacing, and fits the room the
/// black measures for it: a tab sized to its words with no slack draws its title whole on glass, as wide as the
/// black's, each read from its pixels at 2×.
@MainActor
@Suite(.backstop)
struct StripGlassWordsTests {
    private static let ground = CGPoint(x: 1, y: 1)
    private static let tall = 46.0
    private static let scene = StripScene.resting()

    /// A tab as wide as its row's words need, its time's lane after them, with none of the tab's slack.
    private static func tight(_ s: Session) -> CGSize {
        let words = StripWordsLayer.rowWidth(s, at: scene.now)
        let age = StripRowLayout.ageWidth(scene.note.age(s, at: scene.now))
        let pad = StripRowLayout.pad

        return CGSize(width: pad.left + words + StripRowLayout.gap + age + pad.right, height: tall)
    }

    /// A count's tab as wide as its row's words need.
    private static func tight(rows s: Session) -> CGSize {
        let pad = StripRowLayout.pad

        return CGSize(width: pad.left + StripWordsLayer.countRowWidth(s, at: scene.now) + pad.right, height: 60)
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
    private static func inked(_ drawn: Drawn, in box: CGRect, sourceLocation: SourceLocation = #_sourceLocation) throws -> CGRect {
        try #require(drawn.drawnBox(in: box.insetBy(dx: -2, dy: -2), ground: ground), sourceLocation: sourceLocation)
    }

    /// A tab's title on glass inked as wide as the black's, never cut short of it: in a tab as wide as its words need,
    /// or with slack, where glass setting its words wider would show past the black's.
    @available(macOS 26, *)
    private static func expectTabAsTheBlacks(
        _ s: Session, slack: Double = 0, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var size = tight(s)

        size.width += slack

        let box = StripRowLayout(s, note: scene.note, in: size, now: scene.now).title
        let glass = try inked(Drawn(GlassRow(session: s, size: size, pressed: false, scene: scene), size: size), in: box)
        let black = try inked(black(.row(s), in: size), in: box)

        #expect(glass.width >= black.width - 0.5, "glass \(glass.width), black \(black.width)", sourceLocation: sourceLocation)
        #expect(abs(glass.maxX - black.maxX) <= 1, "glass \(glass.maxX), black \(black.maxX)", sourceLocation: sourceLocation)
    }

    /// Working with a subject plain after its verb: both say it, and glass draws it whole in the room the black
    /// measures.
    @available(macOS 26, *)
    @Test func aWorkingTabsSubjectIsSaidAndDrawnWholeOnGlass() throws {
        let s = Session(
            id: "w", project: "Coho", kind: .working, title: "Reading ", subject: "AVAVA Tower Wolf", sub: "Coho · Fix",
            since: 0
        )

        let verb = TextLine.width(TextLine.text("Reading ", EdgeStyle.title, EdgeStyle.ink))

        #expect(StripWordsLayer.rowWidth(s, at: Self.scene.now) > verb + 40, "the black says its subject")
        try Self.expectTabAsTheBlacks(s)
    }

    /// On its own work, what it waits on spaced tight, as the black spaces it, drawn whole on glass.
    @available(macOS 26, *)
    @Test func anOnItsWorkTabsSubjectIsSpacedAsTheBlacksOnGlass() throws {
        let s = Session(
            id: "o", project: "Lucerne", kind: .onItsWork, title: "Waiting on ", subject: "Lucerne Publishing review",
            sub: "Lucerne · Review", since: 0
        )

        try Self.expectTabAsTheBlacks(s)
    }

    /// A Needs you tab's count 6 after its name on glass, as on the black, not a pair of spaces' width: in a tab with room
    /// to spare, it ends where the black's ends.
    @available(macOS 26, *)
    @Test func aTabsCountIs6AfterItsTitleOnGlass() throws {
        let s = Session(
            id: "q", project: "Alpine", name: "Lift schedule", kind: .needs,
            lines: (0 ..< 3).map { Session.Line(ask: "k\($0)", title: "Ask \($0)", since: 0) }, sub: "Alpine"
        )

        try #require(s.more == "3")

        try Self.expectTabAsTheBlacks(s, slack: 40)
    }

    /// A count's row's subject in the black's 13 medium on glass, drawn whole in the room the black measures.
    @available(macOS 26, *)
    @Test func aCountRowsSubjectIsSetAsTheBlacksOnGlass() throws {
        let s = Session(
            id: "w", project: "Coho", kind: .working, title: "Reading ", subject: "AVAVA Tower Wolf", sub: "Coho · Fix",
            since: 0
        )
        let size = Self.tight(rows: s)
        let box = StripRowsLayout(0, width: size.width)
        let title = box.title.offsetBy(dx: box.box.minX, dy: box.box.minY)
        let rows = GlassRows(sessions: [s], width: size.width, lit: nil, pressed: false, now: Self.scene.now)
        let glass = try Self.inked(
            Drawn(rows.frame(width: size.width, height: size.height, alignment: .topLeading), size: size), in: title
        )
        let black = try Self.inked(Self.black(.rows([s]), in: size), in: title)

        #expect(glass.width >= black.width - 0.5, "glass \(glass.width), black \(black.width)")
        #expect(abs(glass.maxX - black.maxX) <= 1, "glass \(glass.maxX), black \(black.maxX)")
    }
}
