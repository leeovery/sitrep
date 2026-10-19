/// What every one of the panel's models shares, as their prototypes share it: the sim clock and its timers, and the
/// pointer's trail.
protocol SimModel: AnyObject {
    associatedtype TimerName: RawRepresentable & Equatable where TimerName.RawValue == String

    /// The sim clock, ms.
    var t: Double { get }
    /// The view's clock at the latest frame, ms: the pointer's trail runs on it.
    var now: Double { get }
    var timers: SimTimers<Self, TimerName> { get set }
    /// The pointer this frame.
    var sp: Vec? { get }
    var trail: Trail { get }
}

extension SimModel {
    func later(_ name: TimerName, _ ms: Double, _ fn: @escaping (Self) -> Void) {
        timers.set(name, at: t + ms, fn)
    }

    func cancel(_ names: TimerName...) {
        timers.cancel(names)
    }

    func cancelPrefix(_ prefix: String) {
        timers.cancel(prefix: prefix)
    }

    /// Runs the timers due, soonest first: one an earlier one cancelled or set again doesn't run.
    func runTimers() {
        for timer in timers.due(by: t) where timers.take(timer) {
            timer.fn(self)
        }
    }

    /// The pointer has moved in the last 60ms: its trail still gives it a speed.
    var trailIsFresh: Bool { trail.isFresh(at: now) }

    func trailVelocity() -> Vec { trail.velocity(at: now) }

    /// The pointer's speed in any direction.
    func pointerSpeed() -> Double { trailVelocity().length }
}

/// A model's timers on its sim clock, by the prototype's names for them: one set again under its name replaces it.
struct SimTimers<Owner: AnyObject, Name: RawRepresentable & Equatable> where Name.RawValue == String {
    struct Timer {
        let name: Name
        let at: Double
        let serial: Int
        let fn: (Owner) -> Void
    }

    private var timers: [Timer] = []
    private var serial = 0

    var isEmpty: Bool { timers.isEmpty }

    func has(_ name: Name) -> Bool {
        timers.contains { $0.name == name }
    }

    mutating func set(_ name: Name, at: Double, _ fn: @escaping (Owner) -> Void) {
        serial += 1
        let timer = Timer(name: name, at: at, serial: serial, fn: fn)
        if let i = timers.firstIndex(where: { $0.name == name }) {
            timers[i] = timer
        } else {
            timers.append(timer)
        }
    }

    mutating func cancel(_ names: [Name]) {
        timers.removeAll { names.contains($0.name) }
    }

    mutating func cancel(prefix: String) {
        timers.removeAll { $0.name.rawValue.hasPrefix(prefix) }
    }

    /// Those due by t, soonest first, as they stand now.
    func due(by t: Double) -> [Timer] {
        timers.enumerated()
            .filter { $0.element.at <= t }
            .sorted { ($0.element.at, $0.offset) < ($1.element.at, $1.offset) }
            .map(\.element)
    }

    /// Takes one of those due off, to run it, unless an earlier one cancelled it or set it again: whether it was
    /// still set.
    mutating func take(_ timer: Timer) -> Bool {
        guard let i = timers.firstIndex(where: { $0.serial == timer.serial }) else {
            return false
        }

        timers.remove(at: i)
        return true
    }
}
