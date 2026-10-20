import SitRepCore

/// The one `sitrep watch` the app runs, its child: started here, started again on another plugin's CLI as SitRep
/// settles on one, and stopped as the app quits. Each board, as it changes, goes to what shows it.
@MainActor
final class Feed {
    private var watching: Task<Void, Never>?
    /// A child once stopped stays so, so each start holds its own.
    private var child: RunningChild?

    /// `watch` on the CLI given, in place of any running.
    func start(_ sitrep: SitRepCLI, onBoard: @escaping (LastBoard) -> Void) {
        stop()

        let child = RunningChild()

        self.child = child
        watching = Task {
            for await last in SitRepWatch(cli: sitrep, watcher: watchProgram(holding: child)).boards() where !Task.isCancelled {
                onBoard(last)
            }
        }
    }

    /// Stops `watch` before returning, so it is sent SIGTERM even if the app is gone before the cancelled task
    /// next runs; cancelling keeps it from being started again.
    func stop() {
        watching?.cancel()
        child?.terminate()
    }
}
