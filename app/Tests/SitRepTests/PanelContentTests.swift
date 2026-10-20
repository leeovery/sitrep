import CoreGraphics
@testable import SitRep
import SitRepPanel
import Testing

/// The black panel's rows under the pointer: the row there lifts, and comes down as the pointer leaves it, whatever
/// the board did to the rows meanwhile.
@MainActor
struct PanelContentTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)

    private static func row(_ id: String, _ title: String = "Your turn") -> Item {
        .session(Session(id: id, project: "SitRep", kind: .turn, title: title, sub: "SitRep · Build", since: 0))
    }

    private static func list(_ items: Item...) -> PanelList {
        PanelList(head: Head(needYou: 0, sessions: items.count), content: Content(laying: items))
    }

    /// A frame of Meniscus's with its panel out over this list, opened by the pointer held on the notch.
    private static func open(_ list: PanelList) -> Frame {
        var time = 0.0, frame: Frame
        let input = { (time: Double) in
            Input(
                time: time, pointer: CGPoint(x: 3, y: stage.notchY), needsLee: false, stage: stage,
                content: list.content
            )
        }
        let notch = Meniscus(input(time))

        repeat {
            time += 1000 / 60
            frame = notch.frame(input(time))
        } while notch.phase != .open && time < 2000

        return frame
    }

    /// A frame with the panel in.
    private static func closed() -> Frame {
        let input = Input(time: 0, pointer: nil, needsLee: false, stage: stage, content: Content(laying: []))

        return Meniscus(input).frame(input)
    }

    private static func scene(_ frame: Frame, hover: Int?) -> NotchScene {
        NotchScene(frame: frame, hover: hover, scroll: 0, time: 0, now: 0, mirror: .identity)
    }

    @Test func aRowLiftedComesDownAsThePointerLeavesAfterTheBoardChangedAnother() throws {
        let content = PanelContent(), first = Self.list(Self.row("a"), Self.row("b"))
        let frame = Self.open(first)

        content.show(first)
        content.show(Self.scene(frame, hover: 0))
        #expect(content.rows["a"]?.row.isHighlighted == true)

        content.show(Self.list(Self.row("a"), Self.row("b", "Changed")))
        content.show(Self.scene(frame, hover: nil))

        #expect(content.rows["a"]?.row.isHighlighted == false)
    }

    @Test func aRowLiftedComesDownAsThePanelGoesIn() {
        let content = PanelContent(), list = Self.list(Self.row("a"))
        let frame = Self.open(list)

        content.show(list)
        content.show(Self.scene(frame, hover: 0))
        content.show(Self.list(Self.row("a"), Self.row("b")))
        content.show(Self.scene(Self.closed(), hover: nil))

        #expect(content.rows["a"]?.row.isHighlighted == false)
    }

    @Test func aRowMadeAnewUnderThePointerLifts() {
        let content = PanelContent(), list = Self.list(Self.row("a"))
        let frame = Self.open(list)

        content.show(list)
        content.show(Self.scene(frame, hover: 0))
        content.show(Self.list(Self.row("a", "Changed")))
        content.show(Self.scene(frame, hover: 0))

        #expect(content.rows["a"]?.row.isHighlighted == true)
    }
}
