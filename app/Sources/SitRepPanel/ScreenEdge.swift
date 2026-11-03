import CoreGraphics
import Foundation

/// The edge of the screen the panel is on, between AppKit's screen coordinates (y up, from the main screen's
/// bottom) and the model's stage (x into the screen from its edge, y down from its top). It is the one place the
/// edge is mapped: the model never knows which edge it is on, and the right mirrors x here.
public struct ScreenEdge: Equatable, Sendable {
    /// The screen's frame and its visible frame, below the menu bar and above the Dock, in screen coordinates.
    public let frame: CGRect
    public let visible: CGRect
    public let edge: EdgeSettings.Edge
    /// How far down the screen the notch's home is, from 0 at its top to 1 at its bottom.
    public let along: Double

    public init(
        frame: CGRect, visible: CGRect, edge: EdgeSettings.Edge = .left, along: Double = EdgeSettings().along
    ) {
        self.frame = frame
        self.visible = visible
        self.edge = edge
        self.along = along
    }

    /// The display's edge as the settings choose it.
    public init(_ display: Display, _ settings: EdgeSettings) {
        self.init(frame: display.frame, visible: display.visible, edge: settings.edge, along: settings.along)
    }

    /// The same screen with the notch's home this far down it.
    public func moved(along: Double) -> ScreenEdge {
        ScreenEdge(frame: frame, visible: visible, edge: edge, along: along)
    }

    /// The same screen's other side, where a drag's ghost shows.
    public var across: ScreenEdge {
        ScreenEdge(frame: frame, visible: visible, edge: edge.other, along: along)
    }

    /// The screen as the model sees it, the notch's home where the settings put it.
    public var stage: Stage {
        Stage(
            height: frame.height, visibleTop: frame.maxY - visible.maxY, visibleBottom: frame.maxY - visible.minY,
            notchY: frame.height * along
        )
    }

    /// A point in screen coordinates on the stage; nil when it is on another screen. The pointer held against the
    /// left edge is at x = 0, and against the right within a point of it.
    public func stagePoint(_ point: CGPoint) -> CGPoint? {
        // AppKit's pointer reaches the screen's top as y = maxY, so the top is in and the bottom row is minY
        guard point.x >= frame.minX, point.x < frame.maxX, point.y >= frame.minY, point.y <= frame.maxY else {
            return nil
        }

        let x = edge == .left ? point.x - frame.minX : frame.maxX - point.x
        return CGPoint(x: x, y: frame.maxY - point.y)
    }

    /// A box on the stage in screen coordinates, the way back from `stagePoint`: on the right, mirrored across the
    /// screen.
    public func screenRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: edge == .left ? frame.minX + rect.minX : frame.maxX - rect.maxX, y: frame.maxY - rect.maxY,
            width: rect.width, height: rect.height
        )
    }

    /// The window: against the edge, the screen's full height, and `depth` into the screen. Its flipped content is
    /// the stage, mirrored on the right (`mirror`).
    public var window: CGRect { against(depth: Self.depth, height: frame.height) }

    /// The stage into the window's flipped content: as it is on the left; on the right, x mirrored across the window,
    /// so the edge is the window's right side.
    public var mirror: CGAffineTransform { mirror(depth: Self.depth) }

    /// The screen as the strip sees it: the menu bar the difference between its top and the visible frame's.
    public var stripStage: StripStage {
        StripStage(width: frame.width, height: frame.height, menu: frame.maxY - visible.maxY)
    }

    /// The strip's window: against the edge, from under the menu bar to the screen's bottom, as deep as its tabs reach.
    /// Its flipped content is the stage from under the menu bar.
    public var stripWindow: CGRect { against(depth: Strip.depth, height: visible.maxY - frame.minY) }

    /// The strip's stage into its window's flipped content, as `mirror` is the notch's.
    public var stripMirror: CGAffineTransform { mirror(depth: Strip.depth) }

    /// A window this deep against the edge, from the screen's bottom.
    private func against(depth: Double, height: Double) -> CGRect {
        CGRect(x: edge == .left ? frame.minX : frame.maxX - depth, y: frame.minY, width: depth, height: height)
    }

    private func mirror(depth: Double) -> CGAffineTransform {
        edge == .left ? .identity : CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: depth, ty: 0)
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

/// A display the edge can be on: the id the app gives it, and its frame and visible frame in screen coordinates.
public struct Display: Equatable, Sendable {
    public let id: String
    public let frame: CGRect
    public let visible: CGRect

    public init(id: String, frame: CGRect, visible: CGRect) {
        self.id = id
        self.frame = frame
        self.visible = visible
    }

    /// The display the settings choose, among those connected, the main one first: the one chosen while it is
    /// connected, else the main one. Nil with none.
    public static func chosen(_ id: String?, among displays: [Display]) -> Display? {
        displays.first { $0.id == id } ?? displays.first
    }
}
