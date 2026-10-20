import CoreGraphics

/// The screen the strip is on, in its stage coordinates: x into the screen from its edge, y down from its top.
public struct StripStage: Equatable, Sendable {
    public var width: Double
    public var height: Double
    /// The menu bar's height: the strip starts under it.
    public var menu: Double

    public init(width: Double, height: Double, menu: Double) {
        self.width = width
        self.height = height
        self.menu = menu
    }
}

/// What the view tells the strip each frame.
public struct StripInput {
    /// A clock in ms that only runs forward. A frame more than 50ms after the last moves the model on by 50.
    public var time: Double
    /// The pointer in stage coordinates; nil while it is on another screen.
    public var pointer: CGPoint?
    public var stage: StripStage
    /// Whether to reduce motion, as the Mac or SitRep asks: then nothing springs, and shapes cross-fade.
    public var reducesMotion: Bool

    public init(time: Double, pointer: CGPoint?, stage: StripStage, reducesMotion: Bool = false) {
        self.time = time
        self.pointer = pointer
        self.stage = stage
        self.reducesMotion = reducesMotion
    }
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
