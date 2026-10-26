import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import Testing

/// The edge's other windows host their layers top-down, as the stage is, in windows that never show, the ghost's never
/// ordered in and the caption's clear: the drag's ghost lands on the other edge where the stage puts it, not mirrored
/// about the window's middle; and the jump's caption drifts up its window as it lifts.
@MainActor
struct StageHostTests {
    private static let display = Display(
        id: "A", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visible: CGRect(x: 0, y: 0, width: 1512, height: 958)
    )

    @Test(arguments: [EdgeSettings.Edge.left, .right])
    func theGhostLandsWhereTheOtherEdgesStagePutsIt(side: EdgeSettings.Edge) throws {
        let edge = ScreenEdge(frame: Self.display.frame, visible: Self.display.visible, edge: side), other = edge.across
        let input = Input(time: 0, pointer: nil, needsLee: true, stage: edge.stage, content: Content(laying: []))
        let outline = Meniscus(input).restingOutline(at: edge.stage.notchY)
        let ghost = GhostEdge()

        ghost.carried(across: true, outline: outline, on: edge)
        ghost.window.displayIfNeeded()

        let content = try #require(ghost.window.contentView)
        let base = try #require(content.superview?.layer)
        let shape = try #require(content.layer.flatMap(Self.shape(under:)))
        let centre = CGPoint(x: outline.boundingBoxOfPath.midX, y: outline.boundingBoxOfPath.midY)
        // the window's own coordinates, y up from its bottom, as AppKit's are whatever its views
        let inWindow = shape.convert(centre, to: base)

        #expect(ghost.window.frame == other.window)
        #expect(abs(inWindow.x - centre.applying(other.mirror).x) < 1e-6)
        #expect(abs(inWindow.y - (other.window.height - centre.y)) < 1e-6)
    }

    @Test func theCaptionDriftsUpItsWindowAsItLifts() throws {
        let caption = CaptionWindow()

        defer { caption.window.close() }
        caption.window.setFrame(CGRect(x: 0, y: 0, width: 200, height: 100), display: false)
        caption.window.displayIfNeeded()

        let content = try #require(caption.window.contentView)
        let base = try #require(content.superview?.layer)
        let pill = try #require(content.layer?.sublayers?.first)
        let place = CGPoint(x: 40, y: 40)

        pill.frame = CGRect(x: 32, y: 32, width: 120, height: 32)

        let before = pill.convert(place, to: base)

        pill.setAffineTransform(CGAffineTransform(translationX: 0, y: CaptionWindow.drift(10)))

        let after = pill.convert(place, to: base)

        #expect(abs(after.y - before.y - 10) < 1e-6)
    }

    private static func shape(under layer: CALayer) -> CAShapeLayer? {
        layer as? CAShapeLayer ?? layer.sublayers?.lazy.compactMap(shape(under:)).first
    }
}
