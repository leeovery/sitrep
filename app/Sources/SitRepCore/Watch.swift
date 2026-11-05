import Foundation
import os

/// How a program ended: exited with its status, or stopped by a signal.
public enum Exit: Sendable, Equatable {
    case status(Int32)
    case signal(Int32)
}

/// What a run of `sitrep watch` says: each line it prints, then how it ended.
public enum Heard: Sendable, Equatable {
    case line(String)
    case exited(Exit, stderr: String)
    case unstartable(String)
}

/// Starts a program meant to run for the app's life and gives what it says,
/// as it says it. Ending the iteration of what it says stops it.
public typealias Watcher = @Sendable (Program) -> AsyncStream<Heard>

/// How the app hears the board: one `sitrep watch`, its child, started again
/// after a back-off whenever it ends, or at once, the board not stale, when
/// it made way for a new version.
public struct SitRepWatch<C: Clock>: Sendable where C.Duration == Duration {
    let cli: SitRepCLI
    let watcher: Watcher
    let clock: C
    /// The time of day, for when the board went stale.
    let now: @Sendable () -> Date

    public init(
        cli: SitRepCLI, watcher: @escaping Watcher = watchProgram, clock: C,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.cli = cli
        self.watcher = watcher
        self.clock = clock
        self.now = now
    }

    /// The board as it changes, from a `watch` of its own: each call starts
    /// one, so the app calls it once. Every board is kept for a reader that
    /// falls behind, since each line's `new` is told once. Ending the
    /// iteration, or cancelling its task, stops `watch`: the app does so as
    /// it quits.
    public func boards() -> AsyncStream<LastBoard> {
        AsyncStream { boards in
            let watching = Task { await watch(into: boards) }

            boards.onTermination = { _ in watching.cancel() }
        }
    }

    private func watch(into boards: AsyncStream<LastBoard>.Continuation) async {
        var last = LastBoard()
        var backoff = Backoff()
        var renewed: C.Instant?

        while !Task.isCancelled {
            let program = await cli.program(["watch"], limit: .infinity)

            // Stopped while Lee's PATH was asked for: it begins nothing, so only the run started in its place runs.
            guard !Task.isCancelled else {
                break
            }

            let run = watcher(program)
            let started = clock.now
            var isRenewal = false
            var isReaderGone = false

            last.begin()

            for await heard in run {
                if renews(heard, started: started, renewed: renewed) {
                    isRenewal = true
                    renewed = clock.now
                } else if last.hear(heard, at: now()), case .terminated = boards.yield(last) {
                    isReaderGone = true
                    break
                }
            }

            guard !isReaderGone, !Task.isCancelled else {
                break
            }

            if isRenewal {
                backoff.renew()
                Logger.watch.notice("sitrep watch made way for a new version: starting it again")

                continue
            }

            let wait = backoff.wait(after: started.duration(to: clock.now))
            let why = last.stale?.description ?? "saying nothing"

            Logger.watch.notice("sitrep watch ended, \(why, privacy: .public): starting it again in \(wait, privacy: .public)")

            try? await clock.sleep(for: wait)
        }

        boards.finish()
    }

    /// Whether what was heard is the run's end making way for a new version.
    private func renews(_ heard: Heard, started: C.Instant, renewed: C.Instant?) -> Bool {
        guard case let .exited(exit, _) = heard else {
            return false
        }

        let ended = clock.now

        return Backoff.renews(exit, lived: started.duration(to: ended), sinceRenewal: renewed?.duration(to: ended))
    }
}

extension SitRepWatch where C == ContinuousClock {
    public init(cli: SitRepCLI, watcher: @escaping Watcher = watchProgram) {
        self.init(cli: cli, watcher: watcher, clock: ContinuousClock())
    }
}
