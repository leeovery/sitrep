import CoreGraphics
@testable import SitRepPanel

/// A screen like Lee's main display: the menu bar's 24 points above the visible frame, the Dock hidden, the lip
/// centred on the screen.
let screen = Stage(height: 982, visibleTop: 24, visibleBottom: 982, lipY: 491)

/// The model driven as the view will drive it: a frame every 1/60s, the pointer moved along a path between them.
/// A scenario reads as the pointer's path, and what the model did on it.
struct Lab {
    static let frameMS = 1000.0 / 60

    let model: Meniscus
    var now = 1000.0
    var pointer: CGPoint?
    var needsLee: Bool
    private(set) var frame: Frame

    init(settings: Settings = Settings(), needsLee: Bool = false, pointer: CGPoint? = nil) {
        self.needsLee = needsLee
        self.pointer = pointer
        let input = Input(time: now, pointer: pointer, needsLee: needsLee, stage: screen)
        model = Meniscus(settings: settings, input)
        frame = model.frame(input)
    }

    var lipY: Double { model.lipY }

    var phase: Phase { model.phase }

    /// The lip or panel as drawn this frame.
    var shape: Geometry { model.geometry() }

    mutating func step() {
        now += Self.frameMS
        frame = model.frame(Input(time: now, pointer: pointer, needsLee: needsLee, stage: screen))
    }

    /// Frames with the pointer where it is, for up to this long or until the condition holds: whether it did.
    @discardableResult
    mutating func wait(_ ms: Double, until done: (Lab) -> Bool = { _ in false }) -> Bool {
        let end = now + ms
        while now < end {
            step()
            if done(self) {
                return true
            }
        }
        return false
    }

    /// The pointer straight to a point at this speed in points per ms, a frame at a time, until it is there or the
    /// condition holds: whether it did.
    @discardableResult
    mutating func move(to target: CGPoint, speed: Double, until done: (Lab) -> Bool = { _ in false }) -> Bool {
        let from = pointer ?? target
        let length = hypot(target.x - from.x, target.y - from.y)
        let frames = max(1, Int((length / (speed * Self.frameMS)).rounded(.up)))
        for i in 1 ... frames {
            let k = Double(i) / Double(frames)
            pointer = CGPoint(x: from.x + (target.x - from.x) * k, y: from.y + (target.y - from.y) * k)
            step()
            if done(self) {
                return true
            }
        }
        return false
    }

    /// Frames until nothing moves, up to a limit: whether it came to rest.
    @discardableResult
    mutating func settle(within ms: Double = 5000) -> Bool {
        wait(ms) { !$0.frame.isMoving }
    }

    /// The pointer set down on the lip, as from another screen, and held there until the panel is open.
    mutating func openByTouch() {
        pointer = CGPoint(x: 3, y: lipY)
        wait(1000) { $0.phase == .open }
    }
}
