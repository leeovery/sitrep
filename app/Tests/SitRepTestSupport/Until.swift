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
    /// What ended it: what it waited on come, the time slept out, or its task cancelled.
    enum End: Sendable {
        case done
        case sleptOut
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
        let took = Self.seconds(took)

        return switch end {
        case .done, .sleptOut: "\(wait) ran out of time: \(Self.seconds(limit)) slept out, \(took) on the clock."
        case .cancelled: "\(wait) was cancelled: \(took) on the clock."
        }
    }

    private static func seconds(_ duration: Duration) -> String {
        String(format: "%.1f s", Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
    }
}

/// The longest nap of a wait: a wait answered at once costs a few short naps, and a long one ten turns a second.
let longestNap = Duration.milliseconds(100)

/// Sleeps the time out on the caller's actor a nap at a time, until `done` holds: naps of a millisecond at first, each
/// twice the last, to `longestNap`. A nap ends only as the actor takes the caller back, so a busy actor holds the time
/// back as it holds the work waited on. With 20 burners on a Mac already at a load of 190 (16 November 2026), the main
/// queue of SitRepTests ran 76 to 122 seconds behind for minutes at a time: any bound on the clock under that ran out
/// with the work it waited on still queued, as a ceiling of ten times the limit did. So there is none: an actor that
/// never takes the caller back stops every test on it, and the run with them, which the backstop ends.
func sleepOut(
    _ limit: Duration, isolation: isolated (any Actor)? = #isolation, until done: () -> Bool
) async -> Slept {
    let clock = ContinuousClock()
    let start = clock.now
    var slept = Duration.zero
    var nap = Duration.milliseconds(1)

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
        if slept >= limit {
            return ended(.sleptOut)
        }

        let next = min(nap, limit - slept)

        try? await Task.sleep(for: next)
        slept += next
        nap = min(nap * 2, longestNap)
    }
}
