import CoreGraphics
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// A new row's wash: it runs from the time it is given, never the last frame's, which after frames have slept is
/// minutes old; and a row made anew mid-wash carries it on.
@MainActor
@Suite(.backstop)
struct WashTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
    /// Ten minutes on from the last frame, at 0, ms.
    private static let later = 600_000.0

    private static func row(_ id: String, _ title: String = "Running the tests") -> Item {
        .session(Session(id: id, project: "Trey Research", kind: .working, title: title, sub: "Trey Research · Build", since: 0))
    }

    private static func list(_ items: Item...) -> PanelList {
        PanelList(head: Head(needYou: 0, sessions: items.count), content: Content(laying: items))
    }

    /// The last frame, long ago, at 0.
    private static func lastFrame() -> NotchScene {
        let input = Input(time: 0, pointer: nil, needsLee: false, stage: stage, content: Content(laying: []))

        return NotchScene(frame: Meniscus(input).frame(input), hover: nil, scroll: 0, time: 0, now: 0, mirror: .identity)
    }

    /// When a row's wash began, ms on the display's clock, while one runs.
    private static func began(_ row: SessionRow?) -> Double? {
        row?.washing.map { $0.beginTime * 1000 }
    }

    @Test func aBoardAfterALongIdleWashesInFullInBlack() {
        let content = PanelContent(), list = Self.list(Self.row("a"), Self.row("b"))

        content.show(list)
        content.show(Self.lastFrame())
        content.wash(["a"], at: Self.later)

        #expect(Self.began(content.rows["a"]?.row).map { abs($0 - Self.later) < 1e-3 } == true)
        #expect(content.rows["b"]?.row.washing == nil)
    }

    @Test func aRowMadeAnewMidWashCarriesItsWashOnInBlack() {
        let content = PanelContent()

        content.show(Self.list(Self.row("a"), Self.row("b")))
        content.wash(["a"], at: Self.later)

        let washing = content.rows["a"]?.row

        content.show(Self.list(Self.row("a", "Changed"), Self.row("b", "Changed")))

        #expect(content.rows["a"]?.row !== washing)
        #expect(Self.began(content.rows["a"]?.row).map { abs($0 - Self.later) < 1e-3 } == true)
        #expect(content.rows["b"]?.row.washing == nil)
    }
}
