import CoreGraphics
import Foundation

/// The edge of the screen the panel is on, between AppKit's screen coordinates (y up, from the main screen's
/// bottom) and the model's stage (x into the screen from its edge, y down from its top). It is the one place the
/// edge is mapped: the left edge, for now; the right would mirror x here.
public struct ScreenEdge: Equatable, Sendable {
    /// The screen's frame and its visible frame, below the menu bar and above the Dock, in screen coordinates.
    public let frame: CGRect
    public let visible: CGRect

    public init(frame: CGRect, visible: CGRect) {
        self.frame = frame
        self.visible = visible
    }

    /// The screen as the model sees it, the notch's home a little above its middle.
    public var stage: Stage {
        Stage(
            height: frame.height, visibleTop: frame.maxY - visible.maxY, visibleBottom: frame.maxY - visible.minY,
            notchY: frame.height * Tuning.notchAt
        )
    }

    /// A point in screen coordinates on the stage; nil when it is on another screen. The pointer held against the
    /// edge is at x = 0.
    public func stagePoint(_ point: CGPoint) -> CGPoint? {
        // AppKit's pointer reaches the screen's top as y = maxY, so the top is in and the bottom row is minY
        guard point.x >= frame.minX, point.x < frame.maxX, point.y >= frame.minY, point.y <= frame.maxY else {
            return nil
        }

        return CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
    }

    /// The window: against the edge, the screen's full height, and `depth` into the screen. Its flipped content is
    /// the stage itself.
    public var window: CGRect {
        CGRect(x: frame.minX, y: frame.minY, width: Self.depth, height: frame.height)
    }

    /// The screen as the strip sees it: the menu bar the difference between its top and the visible frame's.
    public var stripStage: StripStage {
        StripStage(width: frame.width, height: frame.height, menu: frame.maxY - visible.maxY)
    }

    /// The strip's window: against the edge, from under the menu bar to the screen's bottom, as deep as its tabs reach.
    /// Its flipped content is the stage from under the menu bar.
    public var stripWindow: CGRect {
        CGRect(x: frame.minX, y: frame.minY, width: Strip.depth, height: visible.maxY - frame.minY)
    }

    /// How far into the screen the black can reach: the panel, its front's give, and the edge stretched after the
    /// pointer as far as Meniscus lets it (Hold, or the cling's bow), overshooting as its springs do; and a few points
    /// spare for the curve drawn through the stretched outline. The card reaches less far.
    public static let depth: Double = {
        let feel = MeniscusFeel.lees
        let stretch = max(feel.hold, Tuning.clingA * feel.pull)
        let overshoot = [MeniscusSpring.tongue, .cling].map { overshootShare(feel.sp($0).damping) }.max() ?? 0
        return (Tuning.panelDepth + Tuning.frontGive + stretch * (1 + overshoot)).rounded(.up) + 4
    }()
}
