import CoreGraphics
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The strip over the boards `watch` prints, as `PanelBoard` says them: a mark flashes for what a line's `new` says,
/// and never again for a board gone stale.
struct StripFeedTests {
    private static let stage = StripStage(width: 1512, height: 982, menu: 37)
    private static var measure: StripMeasure { .uniform(200) }

    /// A strip at Full, frames every 1/60s from this time on.
    private struct Run {
        let strip: Strip
        var time = 0.0

        init() {
            strip = Strip(
                length: .full, maxLength: .full, along: 0.42, sessions: [], measure: StripFeedTests.measure,
                StripInput(time: 0, pointer: nil, stage: StripFeedTests.stage)
            )
        }

        /// Frames for this long: the brightest any mark's ring flashed meanwhile.
        mutating func play(_ ms: Double) -> Double {
            var flash = 0.0

            for _ in 0 ..< Int(ms / (1000 / 60)) {
                time += 1000 / 60
                flash = max(flash, strip.frame(StripInput(time: time, pointer: nil, stage: StripFeedTests.stage))
                    .marks.map(\.flash).max() ?? 0)
            }

            return flash
        }
    }

    private static func heard(_ said: Heard...) -> PanelBoard {
        var last = LastBoard()

        for heard in said {
            _ = last.hear(heard, at: .now)
        }

        return PanelBoard(last)
    }

    @Test func aRowNewOnTheLineFlashes() {
        var run = Run()
        let board = Self.heard(.line(realLine), .line(watchLine))

        run.strip.show(Self.heard(.line(realLine)).sessions, new: [])
        _ = run.play(3000)
        run.strip.show(board.sessions, new: board.new)

        #expect(run.play(1500) > 0.9)
    }

    /// Gone stale, the last line's new rows are not new again: a strip that never showed that line takes its rows
    /// unflashed.
    @Test func aBoardGoneStaleFlashesNothing() {
        var run = Run()
        let stale = Self.heard(.line(realLine), .line(watchLine), .exited(.status(1), stderr: ""))

        run.strip.show(Self.heard(.line(realLine)).sessions, new: [])
        _ = run.play(3000)
        run.strip.show(stale.sessions, new: stale.new)

        #expect(stale.new.isEmpty)
        #expect(run.play(3000) == 0)
    }
}
