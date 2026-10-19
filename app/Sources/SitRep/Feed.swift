import SitRepCore

/// The one `sitrep watch` the app runs, its child: started here, and stopped as the app quits. Each board, as it
/// changes, goes to what shows it.
@MainActor
final class Feed {
    private var watching: Task<Void, Never>?

    func start(_ sitrep: SitRepCLI, onBoard: @escaping (LastBoard) -> Void) {
        watching = Task {
            for await last in SitRepWatch(cli: sitrep).boards() {
                onBoard(last)
            }
        }
    }

    func stop() {
        watching?.cancel()
    }
}
