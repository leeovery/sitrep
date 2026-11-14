import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepPanel
import Testing

/// The strip's menu on a Snoozed mark, as the controller wires it: Jump to the window, Snooze and Wake now each reach
/// the jump and the CLI with the session's own id, never its mark's key in Snoozed. The display is far off every
/// screen, so nothing shows.
@MainActor
struct StripControllerMenuTests {
    private static let display = Display(
        id: "A", frame: CGRect(x: -20000, y: -20000, width: 1512, height: 982),
        visible: CGRect(x: -20000, y: -20000, width: 1512, height: 958)
    )

    /// What each reached, in the order chosen.
    private final class Heard {
        var said: [String] = []
    }

    @Test func aSnoozedMarksMenuReachesTheJumpAndTheCliWithTheSessionsOwnId() throws {
        let folding = Folding()
        folding.set(.snoozed, folded: false)
        let strip = StripController(EdgeSettings(), on: Self.display, folding: folding), heard = Heard()
        var last = LastBoard()

        defer { strip.window.close() }
        _ = last.hear(.line(Lines.snoozed[0]), at: .now)
        let board = PanelBoard(last), asleep = try #require(board.snoozed.first)
        strip.onJump = { id, _ in heard.said.append("jump \(id)") }
        strip.onSnooze = { id, asks, _ in heard.said.append("snooze \(id) \(asks)") }
        strip.onWake = { heard.said.append("wake \($0)") }
        strip.show(board)

        let actions = strip.rowActions(for: asleep)
        actions.snooze(asleep.asks, .untilItMoves)
        actions.wake()
        actions.jump()

        #expect(heard.said == ["snooze sr-4g01a7 [\"k1\", \"k2\"]", "wake sr-4g01a7", "jump sr-4g01a7"])
    }
}
