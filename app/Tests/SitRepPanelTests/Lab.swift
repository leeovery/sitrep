import CoreGraphics
@testable import SitRepPanel

/// A screen like Lee's main display: the menu bar's 24 points above the visible frame, the Dock hidden, the notch
/// centred on the screen.
let screen = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)

typealias Lab = NotchLab<Meniscus>
typealias CardLab = NotchLab<Card>

/// A notch driven as the view will drive it: a frame every 1/60s, the pointer moved along a path between them.
/// A scenario reads as the pointer's path, and what the model did on it.
struct NotchLab<Model: NotchModel> {
    static var frameMS: Double { 1000.0 / 60 }

    let model: Model
    var now = 1000.0
    var pointer: CGPoint?
    var needsLee: Bool
    var content: Content
    var reducesMotion: Bool
    private(set) var frame: Frame

    init(
        needsLee: Bool, pointer: CGPoint?, content: Content = .css, reducesMotion: Bool = false,
        _ make: (Input) -> Model
    ) {
        self.needsLee = needsLee
        self.pointer = pointer
        self.content = content
        self.reducesMotion = reducesMotion
        let input = Input(
            time: now, pointer: pointer, needsLee: needsLee, stage: screen, content: content,
            reducesMotion: reducesMotion
        )
        model = make(input)
        frame = model.frame(input)
    }

    var notchY: Double { model.notchY }

    var phase: Phase { model.phase }

    mutating func step() {
        step(at: now + Self.frameMS)
    }

    /// One frame at this time on the view's clock.
    mutating func step(at time: Double) {
        now = time
        frame = model.frame(Input(
            time: now, pointer: pointer, needsLee: needsLee, stage: screen, content: content,
            reducesMotion: reducesMotion
        ))
    }

    /// Frames with the pointer where it is, for up to this long or until the condition holds: whether it did.
    @discardableResult
    mutating func wait(_ ms: Double, until done: (Self) -> Bool = { _ in false }) -> Bool {
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
    mutating func move(to target: CGPoint, speed: Double, until done: (Self) -> Bool = { _ in false }) -> Bool {
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

    /// The pointer set down on the notch, as from another screen, and held there until the panel is open.
    mutating func openByTouch() {
        pointer = CGPoint(x: 3, y: notchY)
        wait(1000) { $0.phase == .open }
    }
}

extension NotchLab where Model == Meniscus {
    init(feel: MeniscusFeel = .lees, needsLee: Bool = false, pointer: CGPoint? = nil, reducesMotion: Bool = false) {
        self.init(needsLee: needsLee, pointer: pointer, reducesMotion: reducesMotion) { Meniscus(feel: feel, $0) }
    }

    /// The notch or panel as drawn this frame.
    var shape: MeniscusGeometry { model.geometry() }
}

extension NotchLab where Model == Card {
    init(
        feel: CardFeel = .lees, needsLee: Bool = false, pointer: CGPoint? = nil,
        content: Content = .css, reducesMotion: Bool = false
    ) {
        self.init(needsLee: needsLee, pointer: pointer, content: content, reducesMotion: reducesMotion) {
            Card(feel: feel, $0)
        }
    }

    /// The card as drawn this frame.
    var shape: CardGeometry { model.geometry() }
}
