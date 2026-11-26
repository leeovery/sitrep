import CoreGraphics
import Foundation

/// The screen the panel is on, in its stage coordinates: y runs down from the screen's top.
public struct Stage: Equatable, Sendable {
    public var height: Double
    /// The screen's visible frame, below the menu bar and above the Dock: the panel keeps 40 points inside it.
    public var visibleTop: Double
    public var visibleBottom: Double
    /// The notch's home along the edge, its centre.
    public var notchY: Double

    public init(height: Double, visibleTop: Double, visibleBottom: Double, notchY: Double) {
        self.height = height
        self.visibleTop = visibleTop
        self.visibleBottom = visibleBottom
        self.notchY = notchY
    }

    /// The band the panel keeps inside.
    var bandTop: Double { visibleTop + Tuning.margin }
    var bandBottom: Double { visibleBottom - Tuning.margin }

    /// Where a shape this tall centres when it would centre at y: inside the band, or the band's middle when the band
    /// can't hold it, so a shape springing a little past the band's length doesn't jump.
    func centre(_ h: Double, near y: Double) -> Double {
        bandBottom - bandTop >= h ? clamp(y, bandTop + h / 2, bandBottom - h / 2) : (bandTop + bandBottom) / 2
    }

    /// A place along the edge, kept where this much either side of it fits inside the band.
    func keep(_ y: Double, half: Double) -> Double {
        clamp(y, bandTop + half, max(bandTop + half, bandBottom - half))
    }
}

/// What the view tells the model each frame.
public struct Input {
    /// A clock in ms that only runs forward. A frame more than 50ms after the last moves the model on by 50.
    public var time: Double
    /// The pointer in stage coordinates of the edge: x its depth from the screen's edge (a pointer held at the edge
    /// is at 0), y down from the screen's top; nil while it is on another screen.
    public var pointer: CGPoint?
    /// When the pointer was read, on the same clock: the pointer's trail measures its speed in its own time, as the
    /// prototype's `trackPointer` stamps each sample, never in the frame's, which may be stamped ahead of it. Nil, the
    /// frame's time.
    public var pointerAt: Double?
    /// Whether anything needs Lee: the notch rests at 7 × 76 when nothing does, and 15 × 124 when something does.
    public var needsLee: Bool
    public var stage: Stage
    public var content: Content
    /// Whether to reduce motion, as the Mac or SitRep asks: then nothing springs, and shapes cross-fade.
    public var reducesMotion: Bool
    /// A panel beside the open one, the asks panel, and while the pointer is on its way there, the way to it: the
    /// pointer on it is on the panel, so leaving both is leaving the panel, and the open edge never clings to it.
    public var beside: CGPath?
    /// Whether `pointer` is a place a menu holds the panel open at, as if the pointer rested there, and not the
    /// pointer's own: no move of the pointer's.
    public var pointerIsHeld = false

    public init(
        time: Double, pointer: CGPoint?, pointerAt: Double? = nil, needsLee: Bool, stage: Stage, content: Content,
        reducesMotion: Bool = false, beside: CGPath? = nil
    ) {
        self.time = time
        self.pointer = pointer
        self.pointerAt = pointerAt
        self.needsLee = needsLee
        self.stage = stage
        self.content = content
        self.reducesMotion = reducesMotion
        self.beside = beside
    }

    /// When the pointer was read.
    var pointerTime: Double { pointerAt ?? time }
}

/// What the view draws for one frame, in stage coordinates of the edge: x from the screen's edge into the screen,
/// y down from the screen's top.
public struct Frame {
    /// The sim clock, ms, which `light.lastAsk` is stamped on.
    public let time: Double
    public let phase: Phase
    /// The black, notch or panel: one closed path, starting and ending a little past the screen's edge.
    public let outline: CGPath
    /// How opaque it is: below 1 only while it cross-fades in under reduced motion, ...
    public let outlineAlpha: Double
    /// ... from the outline it was, fading out.
    public let fading: Fading?
    /// The panel's content, while it is out.
    public let panel: Panel?
    public let light: Light
    /// Where the pointer touches the notch: the live notch and a little, reaching past the screen's edge; only a sliver
    /// once the panel is out.
    public let hitRect: CGRect
    /// Whether anything can still change with the pointer held still: when it is false, frames can stop until the
    /// pointer moves (`wakes`) or Lee acts.
    public let isMoving: Bool
    /// How far a drag has lifted the notch off the edge, 0 to 1: its shadow, 4 down and blurred 12 at 0.4 at full.
    public let lift: Double
    /// The notch has drained into this edge after a drag let it go across the screen's middle: from this frame it
    /// grows out of the other, where the view moves it now.
    public let swapsEdge: Bool

    init(
        time: Double, phase: Phase, outline: CGPath, outlineAlpha: Double = 1, fading: Fading? = nil, panel: Panel?,
        light: Light, hitRect: CGRect, isMoving: Bool, lift: Double = 0, swapsEdge: Bool = false
    ) {
        self.time = time
        self.phase = phase
        self.outline = outline
        self.outlineAlpha = outlineAlpha
        self.fading = fading
        self.panel = panel
        self.light = light
        self.hitRect = hitRect
        self.isMoving = isMoving
        self.lift = lift
        self.swapsEdge = swapsEdge
    }

    /// Whether a click here lands on the black, or the notch's hit area, rather than on what is beneath: only a row
    /// does anything with it, and anywhere else it passes through.
    public func hits(_ point: CGPoint) -> Bool {
        outline.contains(point) || inRect(Vec(point.x, point.y), hitRect)
    }

    /// How far out the black is, from 0 at the notch at rest to 1 with the panel's full depth out; 1 throughout the
    /// open phase, as the panel's front springs short of its depth and back.
    public var openness: Double { phase == .open ? 1 : Self.openness(outline) }

    /// How far out a notch's outline is: its reach into the screen past the notch's at rest, over the panel's.
    public static func openness(_ outline: CGPath) -> Double {
        let rest = NotchShape.rest.w

        return clamp((outline.boundingBoxOfPath.maxX - rest) / (Tuning.panelDepth - rest), 0, 1)
    }

    /// Whether a move of the pointer, from where this frame saw it to here, should start frames again, once they have
    /// stopped with nothing moving: a pointer resting anywhere, by the notch or on the open panel, changes nothing
    /// until it moves. While the panel is out, every move wakes them, since only the model can tell that the pointer
    /// has left it (rows going from under a still pointer, under reduced motion, leave the panel out with nothing
    /// moving); else a move near the notch, to it or from it, as the notch leaning toward a pointer must see it go.
    public func wakes(from last: CGPoint?, to pointer: CGPoint?, field: Double) -> Bool {
        phase != .closed || isNear(pointer, field: field) || isNear(last, field: field)
    }

    /// Whether the pointer is near the edge by the notch: within the attraction's field from it, and a margin, and its
    /// reach along it.
    func isNear(_ pointer: CGPoint?, field: Double) -> Bool {
        pointer.map { $0.x <= field + Self.nearMargin && abs($0.y - light.centre.y) <= Tuning.fieldY } ?? false
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
        /// The row a click is jumping to, by its item's key: pressed in and spinning until the panel has drained.
        public let pressed: String?

        /// Whether a point is on the content as shown: inside the clip, and inside the rounding of its front corners.
        public func contains(_ point: CGPoint) -> Bool {
            frontRounded(clip, top: topRadius, bottom: bottomRadius, contains: point)
        }

        /// Where the content is drawn in the window, through the edge's mirror (`ScreenEdge.mirror`).
        public func drawn(_ mirror: CGAffineTransform) -> CGRect { frame.applying(mirror) }

        /// A point on the stage in the content's own frame, as drawn through the edge's mirror and scrolled this far:
        /// the content reads left to right on either edge.
        public func contentPoint(_ point: CGPoint, mirror: CGAffineTransform, scroll: Double) -> CGPoint {
            let drawn = drawn(mirror), at = point.applying(mirror)
            return CGPoint(x: at.x - drawn.minX, y: at.y - drawn.minY + scroll)
        }

        /// A point in the content's own frame on the stage, the way back from `contentPoint`.
        public func stagePoint(_ point: CGPoint, mirror: CGAffineTransform, scroll: Double) -> CGPoint {
            let drawn = drawn(mirror)

            return CGPoint(x: point.x + drawn.minX, y: point.y + drawn.minY - scroll).applying(mirror.inverted())
        }
    }

    /// How a row (or the head) shows as it lands or fades: its opacity, and how far below its place it still is.
    public struct Paint: Equatable {
        public let alpha: Double
        public let rise: Double
    }

    /// An outline fading out, and how opaque it still is.
    public struct Fading {
        public let outline: CGPath
        public let alpha: Double
    }

    /// The light in the notch.
    public struct Light {
        /// The Live light's bar, its long side along the edge.
        public static let size = CGSize(width: 2.5, height: 36)

        /// On the notch's centre line, halfway into its depth: a tongue reaching for the pointer leaves it where it is.
        public let centre: CGPoint
        /// 0 to 1: whether anything needs Lee, dimmed to 0 while the panel is out.
        public let level: Double
        /// The sim time of the last new ask, which flashes it.
        public let lastAsk: Double?
    }
}

/// Whether a point is inside a rectangle whose two front corners, away from the screen's edge, are rounded.
func frontRounded(_ rect: CGRect, top: Double, bottom: Double, contains point: CGPoint) -> Bool {
    guard inRect(Vec(point.x, point.y), rect) else {
        return false
    }

    let front = rect.maxX
    if point.y < rect.minY + top, point.x > front - top {
        return hypot(point.x - (front - top), point.y - (rect.minY + top)) <= top
    }
    if point.y > rect.maxY - bottom, point.x > front - bottom {
        return hypot(point.x - (front - bottom), point.y - (rect.maxY - bottom)) <= bottom
    }
    return true
}
