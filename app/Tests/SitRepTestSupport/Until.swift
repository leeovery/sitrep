import Testing

/// Lets the tasks run, on the caller's actor, until the condition holds; one that still does not after so many turns
/// fails the test at the caller. Counted in turns, not time, where the actor is shared with every other test of the
/// suite, as the main actor is.
public func until(
    turns: Int, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ holds: () -> Bool
) async {
    for _ in 0 ..< turns where !holds() {
        await Task.yield()
    }
    if !holds() {
        neverHeld(at: sourceLocation)
    }
}

/// Lets the tasks run, on the caller's actor, until the condition holds; one that still does not once the time is up
/// fails the test at the caller, rather than let it go on to wait on what never came.
public func until(
    within limit: Duration, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ holds: () -> Bool
) async {
    let clock = ContinuousClock()
    let deadline = clock.now + limit

    while !holds() {
        guard clock.now < deadline else {
            return neverHeld(at: sourceLocation)
        }

        await Task.yield()
    }
}

private func neverHeld(at sourceLocation: SourceLocation) {
    Issue.record("The condition waited for never held.", sourceLocation: sourceLocation)
}
