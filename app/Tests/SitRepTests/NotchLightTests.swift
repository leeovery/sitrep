import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The light where the notch is, in black and in glass: drawn in an edge's window offscreen, on either edge, its bar
/// lies inside the notch's outline in the window, where the black is drawn and the pointer touches it, at rest, as
/// the notch reaches for the pointer and as the panel pours; and it is hidden once the panel is out.
@MainActor
@Suite(.backstop)
struct NotchLightTests {
    private static let display = Display(
        id: "A", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visible: CGRect(x: 0, y: 0, width: 1512, height: 958)
    )

    private static let content = Content(laying: [.session(Session(
        id: "a", project: "Trey Research", kind: .needs, title: "Approve the plan", sub: "Trey Research · Build", since: 0
    ))])

    @Test(arguments: [EdgeSettings.Material.black, .glass], NotchApproach.Style.allCases)
    func theLightLiesInsideTheNotchAsItIsDrawn(material: EdgeSettings.Material, style: NotchApproach.Style) throws {
        for side in [EdgeSettings.Edge.left, .right] {
            let edge = ScreenEdge(frame: Self.display.frame, visible: Self.display.visible, edge: side)
            let surface = NotchSurface()
            let window = EdgeWindow(frame: edge.window, view: surface)
            var seen = Seen()

            defer { window.close() }

            surface.material = material
            window.displayIfNeeded()
            for frame in NotchApproach.frames(style, needsLee: true, on: edge.stage, content: Self.content) {
                surface.show(NotchScene(frame: frame, hover: nil, scroll: 0, time: 0, now: 0, mirror: edge.mirror))
                surface.showLight(frame.light, outline: frame.outline, colours: LiveLight(
                    time: frame.time, sinceAsk: nil, reducesMotion: false
                ))

                let light = try #require(surface.layer.flatMap(Self.light(under:)))

                #expect(light.isHidden == (frame.light.level <= 0.001))
                if !light.isHidden {
                    for corner in try Self.corners(of: light, in: window) {
                        let onStage = surface.convert(corner, from: nil).applying(edge.mirror)

                        #expect(frame.outline.contains(onStage), "\(side) \(frame.phase) at \(frame.time)")
                    }
                }
                seen.saw(frame)
            }
            #expect(seen.everyMoment, "\(side)")
        }
    }

    /// Which moments a run of frames came through: lit at rest, lit reaching for the pointer, lit as the panel
    /// opens, and the panel out.
    private struct Seen {
        var rest = false, reaching = false, opening = false, open = false

        var everyMoment: Bool { rest && reaching && opening && open }

        /// The notch needing Lee at rest is a little open already, 15 deep to the rest's 7.
        private static let needsOpenness = 0.03

        mutating func saw(_ frame: Frame) {
            let lit = frame.light.level > 0.001

            switch frame.phase {
            case .closed where lit && frame.openness > Self.needsOpenness:
                reaching = true
            case .closed where lit:
                rest = true
            case .opening where lit:
                opening = true
            case .open:
                open = true
            default:
                break
            }
        }
    }

    private static func light(under layer: CALayer) -> LightLayer? {
        layer as? LightLayer ?? layer.sublayers?.lazy.compactMap(light(under:)).first
    }

    /// The light's bar's corners in the window, as its layers place it.
    private static func corners(
        of light: LightLayer, in window: NSWindow, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> [CGPoint] {
        let base = try #require(window.contentView?.superview?.layer, sourceLocation: sourceLocation)
        let bar = light.convert(LiveLight.bar, to: base)

        return [
            CGPoint(x: bar.minX, y: bar.minY), CGPoint(x: bar.maxX, y: bar.minY),
            CGPoint(x: bar.minX, y: bar.maxY), CGPoint(x: bar.maxX, y: bar.maxY),
        ]
    }
}
