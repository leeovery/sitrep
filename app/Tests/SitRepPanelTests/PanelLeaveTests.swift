import CoreGraphics
@testable import SitRepPanel
import Testing

/// The panel closing as the pointer leaves it, with frames paced as the view paces them (DESIGN, stage 3 step 6: on
/// the spike it once stayed open). The view runs frames only while the last frame wants them, and once they stop, a
/// move of the pointer starts them again where that frame `wakes` for it. The spike woke them only where the frame
/// wanted frames, near the notch or over the panel as drawn: under reduced motion, rows going from under a still
/// pointer leave the panel out and wanting none, and then no move away reached the model.
struct PanelLeaveTests {
    enum Leave: CaseIterable {
        /// Slowly out past the front, and on across the screen.
        case past
        /// Slowly over the top.
        case over
        /// A flick far into the screen.
        case flick
        /// Just past the front, where the edge holds it, resting there a while before going on.
        case held
        /// Onto another screen, off the stage.
        case offScreen
        /// The rows below the second go from under the pointer, resting on the panel's foot, and then it goes.
        case shrunk
    }

    @Test(arguments: Leave.allCases, [false, true])
    func meniscusCloses(_ leave: Leave, reducingMotion: Bool) {
        var paced = Paced(Lab(needsLee: true, reducesMotion: reducingMotion))

        paced.leave(leave)

        #expect(paced.lab.phase == .closed)
        #expect(!paced.isRunning)
    }

    @Test(arguments: Leave.allCases, [false, true])
    func theCardCloses(_ leave: Leave, reducingMotion: Bool) {
        var paced = Paced(CardLab(needsLee: true, reducesMotion: reducingMotion))

        paced.leave(leave)

        #expect(paced.lab.phase == .closed)
        #expect(!paced.isRunning)
    }

    @Test func wokenAsTheSpikeWokeItThePanelStayedOut() {
        var paced = Paced(Lab(needsLee: true, reducesMotion: true)) { frame, pointer, field in
            frame.wantsFrames(pointer: pointer, field: field)
        }

        paced.leave(.shrunk)

        #expect(paced.lab.phase == .open)
    }
}

/// A notch whose frames run as the view runs them: a frame a refresh while the last frame wants frames, else none
/// until a move of the pointer that wakes them.
private struct Paced<Model: NotchModel> {
    typealias Wakes = (Frame, CGPoint?, Double) -> Bool

    var lab: NotchLab<Model>
    private(set) var isRunning = true
    private let wakes: Wakes

    init(_ lab: NotchLab<Model>, wakes: @escaping Wakes = { $0.wakes(pointer: $1, field: $2) }) {
        self.lab = lab
        self.wakes = wakes
    }

    private var field: Double { lab.model.field }

    /// The panel opened by touch, the pointer moved in over its rows and rested, then the leave.
    mutating func leave(_ leave: PanelLeaveTests.Leave) {
        point(at: CGPoint(x: 3, y: lab.notchY))
        wait(1000)
        #expect(lab.phase == .open)
        move(to: CGPoint(x: 200, y: lab.notchY + 120), speed: 0.3)
        wait(2000)
        #expect(lab.phase == .open)

        switch leave {
        case .past:
            move(to: CGPoint(x: 900, y: lab.notchY), speed: 0.1)
        case .over:
            move(to: CGPoint(x: 200, y: lab.notchY - 500), speed: 0.1)
        case .flick:
            move(to: CGPoint(x: 1500, y: lab.notchY + 300), speed: 4)
        case .held:
            move(to: CGPoint(x: Tuning.panelDepth + 12, y: lab.notchY + 120), speed: 0.05)
            wait(2000)
            move(to: CGPoint(x: 900, y: lab.notchY + 120), speed: 0.3)
        case .offScreen:
            point(at: nil)
        case .shrunk:
            move(to: CGPoint(x: 200, y: lab.notchY + 180), speed: 0.1)
            lab.content = Content(laying: Array(Item.prototype.prefix(2)))
            wait(2000)
            move(to: CGPoint(x: 900, y: lab.notchY + 180), speed: 0.3)
        }
        wait(3000)
    }

    /// The pointer straight to a point at this speed, points per ms, an event a refresh.
    mutating func move(to target: CGPoint, speed: Double) {
        let from = lab.pointer ?? target
        let length = hypot(target.x - from.x, target.y - from.y)
        let events = max(1, Int((length / (speed * NotchLab<Model>.frameMS)).rounded(.up)))

        for i in 1 ... events {
            let k = Double(i) / Double(events)
            point(at: CGPoint(x: from.x + (target.x - from.x) * k, y: from.y + (target.y - from.y) * k))
        }
    }

    /// One event of the pointer's: a refresh's frame while frames run, or one it wakes.
    mutating func point(at pointer: CGPoint?) {
        lab.now += NotchLab<Model>.frameMS
        lab.pointer = pointer
        if isRunning || wakes(lab.frame, pointer, field) {
            frame()
        }
    }

    /// Time with the pointer still: frames only while they run.
    mutating func wait(_ ms: Double) {
        let end = lab.now + ms

        while lab.now < end {
            lab.now += NotchLab<Model>.frameMS
            if isRunning {
                frame()
            }
        }
    }

    private mutating func frame() {
        lab.step(at: lab.now)
        isRunning = lab.frame.wantsFrames(pointer: lab.pointer, field: field)
    }
}
