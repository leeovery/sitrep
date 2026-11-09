import os

/// An app kept in front after a jump brought its window forward. With another app in front as the jump begins, and the
/// Space the jump goes to last showing that app in front, macOS hands the front back to it once its slide to the Space
/// ends: Ghostty in front about 0.2s after the jump, the other app again at about 0.5s, Ghostty's focused terminal by
/// then the one the jump chose. Bringing Ghostty forward again then keeps it there. With Ghostty in front as the jump
/// began, it never happened (all seen live, 14 October 2026).
///
/// The hand-back is heard, not polled: each app is heard as it comes to the front, from before the jump's first event,
/// so one coming between Ghostty's window activated and its terminal focused is heard too.
final class KeptInFront: Sendable {
    /// How long after the focus a hand-back is waited for: twice the half second at which it came, in all three logged
    /// (14 October 2026). No longer, since a jump that sees none keeps Lee waiting this long, and a switch he makes
    /// himself within it would be undone.
    static let watch = Duration.seconds(1)

    private let app: String
    private let workspace: any Workspace
    private let handBack: HandBack
    private let listening: any Listening

    /// Listening from now for the app, by its bundle id, where another app, `before`, was in front as the jump began;
    /// nil where the app itself was, or none was told.
    init?(_ app: String, after before: String?, on workspace: any Workspace) {
        guard let before, before != app else {
            return nil
        }

        let handBack = HandBack(of: app)

        self.app = app
        self.workspace = workspace
        self.handBack = handBack
        listening = workspace.listen(handBack.heard)
    }

    /// Once its window is forward, brings the app forward again, once, should another app take the front back from it
    /// within `watch`; nothing that fails here fails the jump.
    func keep(on clock: any JumpClock) async {
        guard await handBack.isHandedBack(within: Self.watch, on: clock),
              let running = await workspace.running([app])
        else {
            return
        }

        _ = await workspace.bringForward(running, on: clock)
    }

    func end() {
        listening.end()
    }
}

/// Whether the front was handed back from an app: another app heard coming to the front after it. The app never heard
/// in front is no hand-back: the focus may have shown nothing, the app hidden or its window minimised, and bringing it
/// forward could make it open a new window. An app heard with no bundle id changes nothing.
final class HandBack: Sendable {
    private let app: String
    private let isForward = OSAllocatedUnfairLock(initialState: false)
    private let handedBack = First<Bool>()

    init(of app: String) {
        self.app = app
    }

    func heard(_ front: String?) {
        let isHandedBack = isForward.withLock { isForward in
            defer { isForward = isForward || front == app }
            return isForward && front != nil && front != app
        }

        if isHandedBack {
            handedBack.answer(true)
        }
    }

    /// Whether it is handed back, once heard, or by the time given.
    func isHandedBack(within limit: Duration, on clock: any JumpClock) async -> Bool {
        let timer = Task {
            if (try? await clock.sleep(for: limit)) != nil {
                handedBack.answer(false)
            }
        }

        defer { timer.cancel() }
        return await handedBack.value(onCancel: false)
    }
}
