import SitRepCore

/// The one `sitrep watch` the app runs, its child: started here, and stopped as the app quits. Each board, as it
/// changes, goes to what shows it.
@MainActor
final class Feed {
    private var watching: Task<Void, Never>?
    private let child = RunningChild()

    func start(_ sitrep: SitRepCLI, onBoard: @escaping (LastBoard) -> Void) {
        watching = Task { [child] in
            for await last in SitRepWatch(cli: sitrep, watcher: watchProgram(holding: child)).boards() {
                onBoard(last)
            }
        }
    }

    /// Stops `watch` before returning, so it is sent SIGTERM even if the app is gone before the cancelled task
    /// next runs; cancelling keeps it from being started again.
    func stop() {
        watching?.cancel()
        child.terminate()
    }
}
