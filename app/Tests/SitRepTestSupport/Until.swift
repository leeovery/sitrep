import Foundation
import Testing

/// Lets the tasks run, on the caller's actor, until the condition holds; one that still does not after so many turns
/// fails the test at the caller, saying why where a comment is given. Counted in turns, not time, where the actor is
/// shared with every other test of the suite, as the main actor is; turns cost no time, so a test goes on past one
/// that never held.
public func until(
    turns: Int, _ comment: Comment? = nil, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ holds: () -> Bool
) async {
    for _ in 0 ..< turns where !holds() {
        await Task.yield()
    }
    if !holds() {
        let why = comment.map { ": \($0.rawValue)" } ?? "."

        Issue.record("The condition waited for never held\(why)", sourceLocation: sourceLocation)
    }
}

/// Checks the condition, on the caller's actor, until it holds; one that still does not once the time is up ends the
/// test at the caller, rather than let it go on to wait on what never came. Between checks it sleeps rather than
/// yield: a spin of yields on the main actor keeps the main queue full, and the main run loop, whose timers and Core
/// Animation's completions a condition may wait on, rarely comes round to them on a loaded Mac.
public func until(
    within limit: Duration, _ comment: Comment? = nil, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ holds: () -> Bool
) async throws {
    let slept = await sleepOut(limit, until: holds)
    let heldInTime = slept.isDone

    try #require(heldInTime, slept.ranOut("for the condition to hold", comment), sourceLocation: sourceLocation)
}

/// How a time slept out ended, and how long it took on the clock.
struct Slept: Sendable {
    /// What ended it: what it waited on come; the time slept out; the clock's ceiling reached before it was, its actor
    /// too slow to come back; or its task cancelled.
    enum End: Sendable {
        case done
        case sleptOut
        case ceiling
        case cancelled
    }

    let limit: Duration
    let end: End
    let took: Duration

    var isDone: Bool { end == .done }

    /// The failure's words: what the wait was for, the caller's comment where given ("for the run to end"), what ended
    /// it, and its time on the clock.
    func ranOut(_ awaited: String, _ comment: Comment?) -> Comment {
        let wait = "The wait \(comment?.rawValue ?? awaited)"
        let (limit, took) = (Self.seconds(limit), Self.seconds(took))

        return switch end {
        case .done, .sleptOut: "\(wait) ran out of time: \(limit) slept out, \(took) on the clock."
        case .ceiling: "\(wait) reached its ceiling: \(took) on the clock, ten times its \(limit), not yet slept out."
        case .cancelled: "\(wait) was cancelled: \(took) on the clock."
        }
    }

    private static func seconds(_ duration: Duration) -> String {
        String(format: "%.1f s", Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
    }
}

/// Sleeps the time out on the caller's actor a tick at a time, until `done` holds. Each tick ends only as the actor
/// takes the caller back, so a busy actor holds the time back as it holds the work waited on: on a clock, the time ran
/// out with a test's work still queued on the main actor behind every other test's, which on a loaded Mac took minutes
/// to come round. A hot actor, never blocked but slow to come back, would hold it back without end, so it ends all the
/// same at its ceiling, ten times the limit on the clock. Unloaded, the time is the clock's, near enough.
func sleepOut(
    _ limit: Duration, tick: Duration = .milliseconds(5), isolation: isolated (any Actor)? = #isolation,
    until done: () -> Bool
) async -> Slept {
    let clock = ContinuousClock()
    let start = clock.now
    let ceiling = start + limit * 10
    var ticks = max(1, Int(limit / tick))

    func ended(_ end: Slept.End) -> Slept {
        Slept(limit: limit, end: end, took: clock.now - start)
    }

    while true {
        if done() {
            return ended(.done)
        }
        if Task.isCancelled {
            return ended(.cancelled)
        }
        if clock.now >= ceiling {
            return ended(.ceiling)
        }
        if ticks == 0 {
            return ended(.sleptOut)
        }

        ticks -= 1
        try? await Task.sleep(for: tick)
    }
}
