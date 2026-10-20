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

/// What the notch's run and the strip's keep alike, each holding its own: the display's clock, which never goes back;
/// the clicks that ask for a jump, the latest's answer the one heard; and what frames showed for the drawing to show
/// once.
struct RunBook {
    /// The display's clock, ms, as the frames and what comes between them have it. The main link's frames are stamped
    /// up to a refresh ahead of what comes between them, and an input after one takes its time.
    private(set) var time: Double
    private var clicks = 0
    private var shown = RunShown()
    /// A click's jump waits for its drain, which the caption waits for.
    private var waits = false

    init(at time: Double) {
        self.time = time
    }

    /// This time on the clock, or the latest already taken, if that is later.
    mutating func clock(_ time: Double) -> Double {
        self.time = max(self.time, time)
        return self.time
    }

    /// A new click asking for a jump, its number: its drain is waited for, and any before it is not its own.
    mutating func click() -> Int {
        clicks += 1
        waits = true
        shown.jumpDrained = nil
        return clicks
    }

    /// Whether this click is the latest: an answer to an earlier one changes nothing.
    func isLatest(_ click: Int) -> Bool {
        click == clicks
    }

    /// A frame at this time: whether it swapped edges, and whether a click's jump that waits is drained in it.
    mutating func latch(swapsEdge: Bool, drained: Bool, at time: Double) {
        shown.swappedEdge = shown.swappedEdge || swapsEdge
        if waits, drained {
            shown.jumpDrained = time
            waits = false
        }
    }

    /// What frames have shown since this was last asked, for the drawing to show once.
    mutating func takeShown() -> RunShown {
        defer { shown = RunShown() }
        return shown
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
