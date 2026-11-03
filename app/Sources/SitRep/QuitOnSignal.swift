import AppKit
import Dispatch

/// A signal to stop, as `app/quit`'s `pkill` sends SIGTERM, quits SitRep as Quit SitRep does, so what quitting does is
/// done: `watch` stopped, and a welcome showing closed as its close button would. Left to its default, SIGTERM ends
/// SitRep with none of it. `quit` is a seam, as a test never quits.
@MainActor
final class QuitOnSignal {
    private let source: any DispatchSourceSignal

    init(_ number: Int32 = SIGTERM, quit: @escaping @MainActor () -> Void = { NSApp.terminate(nil) }) {
        signal(number, SIG_IGN)
        source = DispatchSource.makeSignalSource(signal: number, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { quit() }
        }
        source.resume()
    }

    /// No longer heard.
    func stop() {
        source.cancel()
    }
}
