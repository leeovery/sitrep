import CoreGraphics

/// The screen the strip is on, in its stage coordinates: x into the screen from its edge, y down from its top.
public struct StripStage: Equatable, Sendable {
    public var width: Double
    public var height: Double
    /// The menu bar's height: the strip starts under it.
    public var menu: Double
    /// How far down the screen's visible frame ends, above the Dock where it shows: the lowest the asks panel stands.
    public var visibleBottom: Double

    /// The visible frame running to the screen's bottom where `visibleBottom` is nil.
    public init(width: Double, height: Double, menu: Double, visibleBottom: Double? = nil) {
        self.width = width
        self.height = height
        self.menu = menu
        self.visibleBottom = visibleBottom ?? height
    }
}

/// What the view tells the strip each frame.
public struct StripInput {
    /// A clock in ms that only runs forward. A frame more than 50ms after the last moves the model on by 50.
    public var time: Double
    /// The pointer in stage coordinates; nil while it is on another screen.
    public var pointer: CGPoint?
    /// When the pointer was read, on the same clock, which its trail measures its speed by, as the notch's
    /// (`Input.pointerAt`). Nil, the frame's time.
    public var pointerAt: Double?
    public var stage: StripStage
    /// Whether to reduce motion, as the Mac or SitRep asks: then nothing springs, and shapes cross-fade.
    public var reducesMotion: Bool
    /// A panel beside the open tab, the asks panel, and while the pointer is on its way there, the way to it: the
    /// pointer on it is on the tab, so leaving both is leaving the tab, as the notch's `Input.beside`.
    public var beside: CGPath?

    public init(
        time: Double, pointer: CGPoint?, pointerAt: Double? = nil, stage: StripStage, reducesMotion: Bool = false,
        beside: CGPath? = nil
    ) {
        self.time = time
        self.pointer = pointer
        self.pointerAt = pointerAt
        self.stage = stage
        self.reducesMotion = reducesMotion
        self.beside = beside
    }

    /// When the pointer was read.
    var pointerTime: Double { pointerAt ?? time }
}

/// How wide a tab's words are, as the view sets them, before the tab's slack and its limits: one session's row, a
/// count's rows, or the notch at rest's.
public struct StripMeasure {
    public var row: (Session) -> Double
    public var rows: ([Session]) -> Double
    public var idle: () -> Double

    public init(
        row: @escaping (Session) -> Double, rows: @escaping ([Session]) -> Double,
        idle: @escaping () -> Double
    ) {
        self.row = row
        self.rows = rows
        self.idle = idle
    }
}
