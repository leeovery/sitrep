import CoreGraphics
import SitRepPanel

/// When an input comes to a run, the notch's or the strip's: the time, the pointer on the stage and when it was read,
/// whether it shows, and what it runs in.
public struct RunMoment<Setting: Sendable>: Sendable {
    public var time: Double
    public var pointer: CGPoint?
    /// When the pointer was read, which its trail measures its speed by (`Input.pointerAt`); nil, `time`.
    public var pointerAt: Double?
    public var isShown: Bool
    public var setting: Setting

    public init(time: Double, pointer: CGPoint?, pointerAt: Double? = nil, isShown: Bool = true, setting: Setting) {
        self.time = time
        self.pointer = pointer
        self.pointerAt = pointerAt
        self.isShown = isShown
        self.setting = setting
    }
}

/// What frames showed that the drawing must show once, though it draws only some of them.
public struct RunShown: Equatable, Sendable {
    /// The notch or the strip swapped edges, after a drop across.
    public var swappedEdge = false
    /// When a click's jump drained, the panel going in or the strip's spin over: what the caption waits for.
    public var jumpDrained: Double?
}

/// A drag let go: where it left it, and whether that is on the other edge.
public struct RunDrop: Equatable, Sendable {
    public let move: EdgeMove
    public let isAcross: Bool
}

/// What the notch's run and the strip's keep alike: the display's clock, which never goes back; the clicks that ask
/// for a jump, the latest's answer the one heard; and what frames showed for the drawing to show once. Each run adds
/// its model and what its inputs mean.
public class EdgeRun<Setting: Sendable> {
    public typealias Moment = RunMoment<Setting>
    public typealias Shown = RunShown
    public typealias Drop = RunDrop

    /// The display's clock, ms, as the frames and what comes between them have it: it never goes back. The main
    /// link's frames are stamped up to a refresh ahead of what comes between them, and an input after one takes its
    /// time.
    public private(set) var time: Double
    private var clicks = 0
    private var shown = Shown()
    /// Whether the last frame had a click's jump drained, or none under way.
    private var drained = true

    init(at time: Double) {
        self.time = time
    }

    /// Whether this click is the latest: an answer to an earlier one changes nothing.
    public func isLatest(_ click: Int) -> Bool {
        click == clicks
    }

    /// What frames have shown since this was last asked, for the drawing to show once.
    public func takeShown() -> Shown {
        defer { shown = Shown() }
        return shown
    }

    /// This time on the run's clock, or the latest already taken, if that is later.
    func clock(_ time: Double) -> Double {
        self.time = max(self.time, time)
        return self.time
    }

    /// A new click asking for a jump, its number; any drain before it is not its own.
    func click() -> Int {
        clicks += 1
        shown.jumpDrained = nil
        return clicks
    }

    /// A frame at this time: whether it swapped edges, and whether a click's jump is drained in it, latched as it
    /// first is.
    func latch(swapsEdge: Bool, drained: Bool, at time: Double) {
        shown.swappedEdge = shown.swappedEdge || swapsEdge
        if drained, !self.drained {
            shown.jumpDrained = time
        }
        self.drained = drained
    }
}

/// A run's model, framed by its own `step`, and run on while hidden by its `catchUp`.
protocol Framed: AnyObject {
    associatedtype Setting: Sendable

    func step(_ moment: RunMoment<Setting>)
    func catchUp(_ moment: RunMoment<Setting>)
}

extension Framed {
    /// The model brought up to an input's moment before the input reaches it: a frame then, or, hidden, its time run
    /// on to then.
    func upToNow(_ moment: RunMoment<Setting>) {
        if moment.isShown {
            step(moment)
        } else {
            catchUp(moment)
        }
    }
}
