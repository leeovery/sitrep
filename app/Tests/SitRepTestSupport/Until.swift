import Testing

/// Lets the tasks run, on the caller's actor, until the condition holds; one that still does not after so many turns
/// fails the test at the caller, saying why where a comment is given. Counted in turns, not time, where the actor is
/// shared with every other test of the suite, as the main actor is.
public func until(
    turns: Int, _ comment: Comment? = nil, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ holds: () -> Bool
) async {
    for _ in 0 ..< turns where !holds() {
        await Task.yield()
    }
    if !holds() {
        neverHeld(comment, at: sourceLocation)
    }
}

/// Checks the condition, on the caller's actor, until it holds; one that still does not once the time is up fails the
/// test at the caller, rather than let it go on to wait on what never came. Between checks it sleeps rather than
/// yield: a spin of yields on the main actor keeps the main queue full, and the main run loop, whose timers and Core
/// Animation's completions a condition may wait on, rarely comes round to them on a loaded Mac.
public func until(
    within limit: Duration, _ comment: Comment? = nil, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ holds: () -> Bool
) async {
    if await !sleepOut(limit, until: holds) {
        neverHeld(comment, at: sourceLocation)
    }
}

/// Whether `done` came to hold, checked on the caller's actor as the time is slept out there a tick at a time. Each
/// tick ends only as the actor takes the caller back, so a busy actor holds the time back as it holds the work waited
/// on: on a clock, the time ran out with a test's work still queued on the main actor behind every other test's, which
/// on a loaded Mac took minutes to come round. Unloaded, the time is the clock's, near enough.
func sleepOut(
    _ limit: Duration, isolation: isolated (any Actor)? = #isolation, until done: () -> Bool
) async -> Bool {
    let tick = Duration.milliseconds(5)

    for _ in 0 ..< max(1, Int(limit / tick)) {
        guard !done(), !Task.isCancelled else {
            break
        }

        try? await Task.sleep(for: tick)
    }

    return done()
}

private func neverHeld(_ comment: Comment?, at sourceLocation: SourceLocation) {
    let why = comment.map { ": \($0.rawValue)" } ?? "."

    Issue.record("The condition waited for never held\(why)", sourceLocation: sourceLocation)
}
