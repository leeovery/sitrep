import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The black strip draws top-down, as the stage is, in an edge's window never shown, on either edge: its black and
/// its marks land in the window where the model puts them, hung from the menu bar the window starts under, not
/// mirrored about the window's middle.
@MainActor
struct StripViewTests {
    private static let edge = ScreenEdge(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visible: CGRect(x: 0, y: 0, width: 1512, height: 958)
    )

    private static let sessions = ["a", "b", "c"].map {
        Session(id: $0, project: "SitRep", kind: .turn, title: "Your turn", sub: "SitRep · Build", since: 0)
    }

    @Test(arguments: [EdgeSettings.Edge.left, .right])
    func itsBlackAndItsMarksLandWhereTheModelPutsThem(side: EdgeSettings.Edge) throws {
        let edge = side == .left ? Self.edge : Self.edge.across
        let stage = edge.stripStage
        let input = StripInput(time: 0, pointer: nil, stage: stage)
        let measure = StripMeasure.uniform(200)
        let strip = Strip(
            length: .full, maxLength: .full, along: 0.42, sessions: Self.sessions, measure: measure, input
        )
        let frame = strip.frame(input)
        let view = StripView()
        let window = EdgeWindow(frame: edge.stripWindow, view: view)

        defer { window.close() }
        window.displayIfNeeded()
        view.show(StripScene(
            frame: frame, hoverRow: nil, note: StripNote(), now: 0, mirror: edge.stripMirror, menu: stage.menu,
            reducesMotion: false
        ))

        let base = try #require(view.superview?.layer)
        let black = try #require(view.layer.flatMap { Self.shape(drawing: frame.strip, under: $0) })
        let drawn = frame.strip.boundingBoxOfPath
        let centre = CGPoint(x: drawn.midX, y: drawn.midY)

        try #require(frame.marks.count == Self.sessions.count)
        Self.expect(black.convert(centre, to: base), at: centre, in: window, edge)
        for mark in frame.marks {
            let at = mark.centre.applying(edge.stripMirror)
            let placed = try #require(view.layer.flatMap { Self.layer(at: at, under: $0) })

            Self.expect(placed.superlayer?.convert(placed.position, to: base), at: mark.centre, in: window, edge)
        }
    }

    /// A point on the stage, as the window has it: y up from its bottom, which is the screen's, the stage starting a
    /// menu bar above the window's top.
    private static func expect(
        _ point: CGPoint?, at onStage: CGPoint, in window: NSWindow, _ edge: ScreenEdge,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let x = onStage.applying(edge.stripMirror).x, y = window.frame.height - (onStage.y - edge.stripStage.menu)

        #expect(
            point.map { abs($0.x - x) < 1e-6 && abs($0.y - y) < 1e-6 } == true, "\(String(describing: point))",
            sourceLocation: sourceLocation
        )
    }

    private static func shape(drawing path: CGPath, under layer: CALayer) -> CAShapeLayer? {
        (layer as? CAShapeLayer).flatMap { $0.path == path ? $0 : nil }
            ?? layer.sublayers?.lazy.compactMap { shape(drawing: path, under: $0) }.first
    }

    /// A mark's layer, by where the view placed it: at its centre through the mirror, with its ring and its letters.
    private static func layer(at position: CGPoint, under layer: CALayer) -> CALayer? {
        if layer.position == position, layer.sublayers?.isEmpty == false {
            return layer
        }
        return layer.sublayers?.lazy.compactMap { self.layer(at: position, under: $0) }.first
    }
}
