import AppKit
@testable import SitRep
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// A strip title's runs: its count 6 after the last of its words, kept whole as the words before it give way, and on a
/// working tab the light falling on its verb alone, as on the card.
@MainActor
@Suite(.backstop)
struct StripTitleTests {
    private static let ground = CGPoint(x: 1, y: 1)

    private static func working(subject: String?, code: String? = nil, more: String? = "+2") -> Session {
        Session(
            id: "w", project: "Coho", kind: .working, title: "Reading ", code: code, subject: subject, more: more,
            sub: "Coho · Fix", since: 0
        )
    }

    private static func set(_ title: StripTitle) -> NSMutableAttributedString { title.text { _ in .black } }

    /// The gap before the count spans the whole of the last character, two UTF-16 units for an emoji, not its last
    /// unit alone.
    @Test func theCountsGapFollowsTheWholeLastCharacter() throws {
        let text = Self.set(.tab(Self.working(subject: "Wolf 🐺"), saying: "Wolf 🐺"))
        let emoji = (text.string as NSString).range(of: "🐺")

        try #require(emoji.length == 2)
        for unit in emoji.location ..< NSMaxRange(emoji) {
            #expect(text.attribute(.kern, at: unit, effectiveRange: nil) as? CGFloat == StripTitle.countGap)
        }
    }

    /// Nothing said after the verb leaves the count its gap, after the verb, as with no subject at all.
    @Test(arguments: [true, false])
    func anEmptyRunKeepsTheCountsGapOnTheWordsBefore(isTab: Bool) {
        let make: (Session, String?) -> StripTitle = isTab ? StripTitle.tab : StripTitle.row
        let empty = make(Self.working(subject: ""), "")
        let none = make(Self.working(subject: nil), nil)

        #expect(empty.width == none.width)
        #expect(empty.runs.first?.gap == StripTitle.countGap)
        #expect(empty.runs.compactMap(\.gap) == [StripTitle.countGap])
    }

    /// A subject too long for the room gives way, cut with an ellipsis, before the count does: the count ends the
    /// title whole, and the title fits.
    @Test(arguments: [StripTuning.tabMin - 80, StripTuning.tabMax - 80, 140])
    func aLongSubjectGivesWayBeforeTheCount(room: Double) throws {
        let subject = "the whole of the board's long history, every session it has held and every ask"
        let fitted = StripTitle.tab(Self.working(subject: subject), saying: subject).fitting(room)
        let follows = try #require(fitted.runs.first { $0.part == .follows })

        #expect(fitted.width <= room)
        #expect(fitted.runs.last?.words == "+2")
        #expect(follows.words.hasSuffix("…") && follows.words.count > 1)
        #expect(subject.hasPrefix(String(follows.words.dropLast())))
    }

    /// A command gives way before the count as a subject does; with no room for any of it, none of it is said.
    @Test func aCommandGivesWayAndWithNoRoomGoes() {
        let s = Self.working(subject: nil, code: "swift test --package-path app --filter StripTitleTests")
        let title = StripTitle.tab(s, saying: nil)
        let bare = StripTitle.tab(Self.working(subject: nil), saying: nil)

        #expect(title.fitting(bare.width + 30).runs[1].words.hasSuffix("…"))
        #expect(title.fitting(bare.width + 30).width <= bare.width + 30)
        #expect(title.fitting(bare.width).runs[1].words.isEmpty)
    }

    /// A title that fits, or has no count to keep, is as it was, for the line to cut at its end.
    @Test func aTitleWithRoomOrNoCountIsLeftAsItIs() {
        let subject = "the whole of the board's long history"
        let counted = StripTitle.tab(Self.working(subject: subject), saying: subject)
        let uncounted = StripTitle.tab(Self.working(subject: subject, more: nil), saying: subject)

        #expect(counted.fitting(counted.width).runs.map(\.words) == counted.runs.map(\.words))
        #expect(uncounted.fitting(40).runs.map(\.words) == uncounted.runs.map(\.words))
    }

    /// On the black, a working tab's light shows its verb alone: what follows is drawn grey beneath and never lit.
    @Test func aWorkingTabsLightFallsOnItsVerbAlone() throws {
        let s = Self.working(subject: "AVAVA Tower Wolf", more: nil)
        let scene = StripScene.resting()
        let size = CGSize(width: 340, height: 46)
        let tab = CGRect(origin: .zero, size: size)
        let words = StripFrame.Words(
            id: 1, key: .count(.working), content: .row(s), frame: tab, scroll: 0, alpha: 1, dy: 0, isPressed: false,
            pressedRow: nil
        )
        let layer = StripWordsLayer(words, in: tab, scene).layer
        let lit = try #require(Self.masked(in: layer))
        let grey = try #require(lit.superlayer?.sublayers?.first)

        lit.mask = nil
        let litInk = try #require(Drawn(lit).drawnBox(in: lit.bounds, ground: Self.ground))
        let greyInk = try #require(Drawn(grey).drawnBox(in: grey.bounds, ground: Self.ground))
        let verb = StripTitle.tab(Self.working(subject: nil, more: nil), saying: nil).width

        #expect(litInk.maxX <= verb + 1, "lit to \(litInk.maxX), the verb \(verb)")
        #expect(greyInk.maxX > verb + 40, "grey to \(greyInk.maxX)")
    }

    /// The layer the shimmer's band masks: its lit title.
    private static func masked(in layer: CALayer) -> CALayer? {
        if layer.mask != nil {
            return layer
        }
        return layer.sublayers?.lazy.compactMap(masked(in:)).first
    }
}
