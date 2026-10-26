/// The front handed back to the app Lee was in, by hiding the helper. A click that starts the helper is told as it
/// launches, perhaps before macOS's activation lands, so hidden then it would be left in front: not yet active, it
/// hides as it next becomes active, within a second, so an activation that comes later, of its own, is never hidden.
@MainActor
final class Front {
    private let isActive: () -> Bool
    private let hide: () -> Void
    private let now: () -> ContinuousClock.Instant
    private let within: Duration
    /// Till when an activation is hidden, once the front was to be handed back before the helper was active.
    private var until: ContinuousClock.Instant?

    init(
        isActive: @escaping () -> Bool, hide: @escaping () -> Void,
        now: @escaping () -> ContinuousClock.Instant = { .now }, within: Duration = .seconds(1)
    ) {
        self.isActive = isActive
        self.hide = hide
        self.now = now
        self.within = within
    }

    func handBack() {
        if isActive() {
            hide()
        } else {
            until = now() + within
        }
    }

    /// The helper made the active app.
    func activated() {
        guard let until else {
            return
        }

        self.until = nil
        if now() <= until {
            hide()
        }
    }
}
