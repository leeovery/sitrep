import AppKit
import Dispatch

/// A signal to stop, as `app/quit`'s `pkill` sends SIGTERM, quits SitRep as Quit SitRep does, so what quitting does is
/// done: `watch` stopped, and a welcome showing closed as its close button would. Left to its default, SIGTERM ends
/// SitRep with none of it. Heard off the main thread, so a SitRep whose main thread is stuck still stops: the signal's
/// default is back at once, so a second one ends it, and one still running `grace` after the first is ended then.
/// `quit`, `end` and `after`, which ends it once the grace has passed, are seams, as a test never quits, nor waits.
@MainActor
final class QuitOnSignal {
    private let number: Int32
    private let source: any DispatchSourceSignal

    init(
        _ number: Int32 = SIGTERM, grace: Duration = .seconds(3),
        quit: @escaping @MainActor @Sendable () -> Void = { NSApp.terminate(nil) },
        end: @escaping @Sendable (Int32) -> Void = { raise($0) },
        after: @escaping @Sendable (Duration, @escaping @Sendable () -> Void) -> Void = QuitOnSignal.onAGlobalQueue
    ) {
        self.number = number
        signal(number, SIG_IGN)
        source = DispatchSource.makeSignalSource(signal: number, queue: .global())
        source.setEventHandler(handler: Self.heard(number, grace: grace, quit: quit, end: end, after: after))
        source.resume()
    }

    /// The signal heard, off the main thread: made outside the main actor, as a closure made on it would trap there.
    nonisolated private static func heard(
        _ number: Int32, grace: Duration, quit: @escaping @MainActor @Sendable () -> Void,
        end: @escaping @Sendable (Int32) -> Void,
        after: @escaping @Sendable (Duration, @escaping @Sendable () -> Void) -> Void
    ) -> @Sendable () -> Void {
        {
            signal(number, SIG_DFL)
            Task { @MainActor in quit() }
            after(grace) { end(number) }
        }
    }

    /// The work run on a global queue once the grace has passed on the uptime clock, whatever the main thread or the
    /// tasks' threads are stuck on.
    nonisolated static func onAGlobalQueue(after grace: Duration, _ work: @escaping @Sendable () -> Void) {
        let (seconds, attoseconds) = grace.components
        let wait = Double(seconds) + Double(attoseconds) / 1e18

        DispatchQueue.global().asyncAfter(deadline: .now() + wait, execute: work)
    }

    /// No longer heard, and the signal's default back.
    func stop() {
        source.cancel()
        signal(number, SIG_DFL)
    }
}
