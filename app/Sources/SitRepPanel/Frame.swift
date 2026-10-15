import CoreGraphics
import Foundation

/// The screen the panel is on, in its stage coordinates: y runs down from the screen's top.
public struct Stage: Equatable, Sendable {
    public var height: Double
    /// The screen's visible frame, below the menu bar and above the Dock: the panel keeps 40 points inside it.
    public var visibleTop: Double
    public var visibleBottom: Double
    /// The lip's home along the edge, its centre.
    public var lipY: Double

    public init(height: Double, visibleTop: Double, visibleBottom: Double, lipY: Double) {
        self.height = height
        self.visibleTop = visibleTop
        self.visibleBottom = visibleBottom
        self.lipY = lipY
    }

    /// The band the panel keeps inside.
    var bandTop: Double { visibleTop + Tuning.margin }
    var bandBottom: Double { visibleBottom - Tuning.margin }

    /// Where a shape this tall centres when it would centre at y: inside the band, or the screen's middle when the
    /// band can't hold it.
    func centre(_ h: Double, near y: Double) -> Double {
        bandBottom - bandTop >= h ? clamp(y, bandTop + h / 2, bandBottom - h / 2) : height / 2
    }

    /// The lip's home, kept where even its swell fits inside the band.
    func clampLipY(_ y: Double) -> Double {
        let half = LipShape.swell.h / 2
        return clamp(y, bandTop + half, max(bandTop + half, bandBottom - half))
    }
}

/// What the view tells the model each frame.
public struct Input {
    /// A clock in ms that only runs forward. A frame more than 50ms after the last moves the model on by 50.
    public var time: Double
    /// The pointer in stage coordinates of the edge: x its depth from the screen's edge (a pointer held at the edge
    /// is at 0), y down from the screen's top; nil while it is on another screen.
    public var pointer: CGPoint?
    /// Whether anything needs Lee: the lip rests at 7 × 76 when nothing does, and 15 × 124 when something does.
    public var needsLee: Bool
    public var stage: Stage
    public var content: Content

    public init(time: Double, pointer: CGPoint?, needsLee: Bool, stage: Stage, content: Content = .css) {
        self.time = time
        self.pointer = pointer
        self.needsLee = needsLee
        self.stage = stage
        self.content = content
    }
}

/// What the view draws for one frame, in stage coordinates of the edge: x from the screen's edge into the screen,
/// y down from the screen's top.
public struct Frame {
    /// The sim clock, ms: the light breathes and flashes on it.
    public let time: Double
    public let phase: Phase
    /// The black, lip or panel: one closed path, starting and ending a little past the screen's edge.
    public let outline: CGPath
    /// The panel's content, while it is out.
    public let panel: Panel?
    public let light: Light
    /// Where the pointer touches the lip: the live lip and a little, reaching past the screen's edge; only a sliver
    /// once the panel is out.
    public let hitRect: CGRect
    /// Whether anything can still change with the pointer held still: when it is false, frames can stop until the
    /// pointer moves or Lee acts.
    public let isMoving: Bool

    /// Whether a click here is the panel's (on the black, or on the lip's hit area); anywhere else it passes through.
    public func hits(_ point: CGPoint) -> Bool {
        outline.contains(point) || inRect(Vec(point.x, point.y), hitRect)
    }

    /// Whether the view should keep frames coming: while anything moves, while the pointer is near the edge by the
    /// lip (within the attraction's field from it, and a margin, and its reach along it), or while it is over the
    /// open panel. Otherwise frames can stop until the pointer comes near or Lee acts.
    public func wantsFrames(pointer: CGPoint?, field: Double) -> Bool {
        guard !isMoving else {
            return true
        }
        guard let pointer else {
            return false
        }

        let nearLip = pointer.x <= field + Self.nearMargin && abs(pointer.y - light.centre.y) <= Tuning.fieldY
        return nearLip || panel != nil && outline.contains(pointer)
    }

    /// How far past the field a pointer still counts as near the edge.
    static let nearMargin = 24.0

    /// The panel's content and how much of it shows.
    public struct Panel {
        /// The content's own frame: the panel's depth (372) wide from the edge, its top on its own spring.
        public let frame: CGRect
        /// The part of it shown: the black's body between the flares, short of its front, less any dent.
        public let clip: CGRect
        /// The clip's front corners: its top's and its bottom's.
        public let topRadius: Double
        public let bottomRadius: Double
        public let head: Paint
        /// One for each of the model's `items`.
        public let items: [Paint]

        /// Whether a point is on the content as shown: inside the clip, and inside the rounding of its front corners.
        public func contains(_ point: CGPoint) -> Bool {
            guard inRect(Vec(point.x, point.y), clip) else {
                return false
            }

            let front = clip.maxX
            if point.y < clip.minY + topRadius, point.x > front - topRadius {
                return hypot(point.x - (front - topRadius), point.y - (clip.minY + topRadius)) <= topRadius
            }
            if point.y > clip.maxY - bottomRadius, point.x > front - bottomRadius {
                return hypot(point.x - (front - bottomRadius), point.y - (clip.maxY - bottomRadius)) <= bottomRadius
            }
            return true
        }
    }

    /// How a row (or the head) shows as it lands or fades: its opacity, and how far below its place it still is.
    public struct Paint: Equatable {
        public let alpha: Double
        public let rise: Double
    }

    /// The light in the lip.
    public struct Light {
        /// The Live light's bar, its long side along the edge.
        public static let size = CGSize(width: 2.5, height: 36)

        /// On the lip's centre line, halfway into its depth: a tongue reaching for the pointer leaves it where it is.
        public let centre: CGPoint
        /// 0 to 1: whether anything needs Lee, dimmed to 0 while the panel is out.
        public let level: Double
        /// The sim time of the last new ask, which flashes it.
        public let lastAsk: Double?
    }
}

extension Meniscus {
    func render(_ g: Geometry) -> Frame {
        let moved = g.bump.map { displaced(g, outlineOf(g), $0, ringAt: ringAt) }
        let hit = hitRect(g)
        let panel = renderPanel(g, dentAt: moved?.centre)
        lastHit = hit
        if let panel {
            lastPanel = panel
        }
        return Frame(
            time: t, phase: phase, outline: shapePath(g, moved?.points), panel: panel,
            light: renderLight(g), hitRect: hit, isMoving: isMoving
        )
    }

    /// The hit area: the live lip plus a little, reaching past the edge; only a sliver once the panel is out.
    func hitRect(_ g: Geometry) -> CGRect {
        let lip = lipTarget, closed = phase == .closed
        let reach = isLive ? 4 : max(12, (closed ? g.w : lip.w) + 4)
        let into = 8.0
        let h = (closed ? g.h : lip.h) + 8
        let cy = closed ? g.cy : S.y.x
        return CGRect(x: -into, y: cy - h / 2, width: reach + into, height: h)
    }

    /// The content, clipped to the black's body; nil while closed.
    func renderPanel(_ g: Geometry, dentAt centre: OutlinePoint?) -> Frame.Panel? {
        guard phase != .closed else {
            return nil
        }

        let W = Tuning.panelDepth, H = panelHeight, top = S.ct.x
        let bodyTop = g.top + g.ft, bodyBot = g.top + g.h - g.fb
        // a dent in the edge pulls the content's clip in with it on its side, so no fading row shows past the black
        var dent = 0.0, n0 = Vec(0, 0)
        if let b = g.bump, let centre, b.a < 0 {
            dent = -b.a * centre.taper
            n0 = centre.n
        }
        let it = max(0, bodyTop - top + dent * max(0, -n0.y))
        let ib = max(0, top + H - bodyBot + dent * max(0, n0.y))
        let front = max(0, W - g.w + dent * max(0, n0.x))
        let cap = min(g.w / 2, (bodyBot - bodyTop) / 2)
        let (head, items) = renderRows()
        return Frame.Panel(
            frame: CGRect(x: 0, y: top, width: W, height: H),
            clip: CGRect(x: 0, y: top + it, width: max(0, W - front), height: max(0, H - it - ib)),
            topRadius: max(0, min(g.rt, cap)), bottomRadius: max(0, min(g.rb, cap)),
            head: head, items: items
        )
    }

    /// The head and each item as they land or fade.
    func renderRows() -> (head: Frame.Paint, items: [Frame.Paint]) {
        (paint(revealAlpha(0)), revealOrder.map { paint(revealAlpha($0)) })
    }

    /// Each item's place in the order the rows land, after the head's 0: a divider lands with the row after it.
    var revealOrder: [Int] {
        var k = 0
        return items.map { item in
            if item != .divider {
                k += 1
            }
            return item == .divider ? k + 1 : k
        }
    }

    /// Rows land from the top, 25ms apart: the head at `rowsAt`, then each row; each fades and rises in 90ms. Closing,
    /// they fade in 60ms.
    func revealAlpha(_ i: Int) -> Double {
        switch reveal {
        case let .rowsIn(t0):
            easeOut(clamp((t - t0 - Tuning.rowsAt - 25 * Double(i)) / 90, 0, 1))
        case let .rowsOut(t0):
            1 - clamp((t - t0) / 60, 0, 1)
        case .none:
            0
        }
    }

    func paint(_ a: Double) -> Frame.Paint {
        guard case .rowsIn = reveal, a < 1 else {
            return Frame.Paint(alpha: a, rise: 0)
        }

        return Frame.Paint(alpha: a, rise: (1 - a) * 4)
    }

    /// The light: on the lip's centre line, halfway into its depth at the base. Its level is only whether anything
    /// needs Lee, and the dimming while the panel is out.
    func renderLight(_ g: Geometry) -> Frame.Light {
        Frame.Light(
            centre: CGPoint(x: max(0, g.w) / 2, y: g.cy),
            level: clamp(S.light.x, 0, 1) * clamp(S.vis.x, 0, 1),
            lastAsk: flash
        )
    }

    /// Anything still moving, or able to move with the pointer held still: a spring not at rest, a timer pending, a
    /// leave still playing out, a tongue hanging at Hold, rows landing or fading, or the pointer in the attraction's
    /// field with its trail still fresh, where a snap waits on the trail going still. A pointer parked in the field
    /// changes nothing once its trail has gone still.
    var isMoving: Bool {
        Springs.all.contains { !S[keyPath: $0].isAtRest }
            || !timers.isEmpty
            || snap != nil || ends != nil || landing != nil || ringing || cling.hang != nil
            || isRevealing
            || attract.dx.isFinite && trailIsFresh
    }

    private var isRevealing: Bool {
        guard phase != .closed else {
            return false
        }

        switch reveal {
        case .rowsIn:
            return revealAlpha(revealOrder.max() ?? 0) < 1
        case .rowsOut:
            return revealAlpha(0) > 0
        case .none:
            return false
        }
    }
}
