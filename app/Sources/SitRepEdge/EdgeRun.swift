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

/// What frames showed that the drawing must show once, though it draws only some of them: the edge swapped, and when
/// a click's jump first drained, the panel going in or the strip's spin over.
public struct RunShown: Equatable, Sendable {
    public var swappedEdge = false
    public var drained: Double?
}

/// A drag let go: the settings with its new place, and whether that is on the other edge.
public struct RunDrop: Equatable, Sendable {
    public let settings: EdgeSettings
    public let isAcross: Bool
}

/// The display's clock as a run has it, ms: it never goes back. The main link's frames are stamped up to a refresh
/// ahead of what comes between them, and an input after one takes its time.
struct RunClock {
    private(set) var time: Double

    init(_ time: Double) {
        self.time = time
    }

    /// This time, or the latest already taken, if that is later.
    mutating func take(_ time: Double) -> Double {
        self.time = max(self.time, time)
        return self.time
    }
}

/// A run: its model, framed by its own `step`, and run on while hidden by its `catchUp`.
protocol EdgeRun: AnyObject {
    associatedtype Setting: Sendable

    func step(_ moment: RunMoment<Setting>)
    func catchUp(_ moment: RunMoment<Setting>)
}

extension EdgeRun {
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
