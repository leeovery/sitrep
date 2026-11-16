import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
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

    /// A made-up `watch` line: Fabrikam's session, an ask waiting in Needs you and two asleep in Snoozed.
    private static let line: String = {
        let asleep: [WatchLine.SnoozedRow.Line] = [
            .init(
                "ask:sr-qx81zt:k1", ask: "k1", first: "Review the plan", since: 1_792_740_927_000,
                wakesAt: 1_792_741_532_000
            ),
            .init(
                "ask:sr-qx81zt:k2", ask: "k2", first: "Pick the second region", since: 1_792_741_027_000,
                wakesAt: 1_792_745_127_000
            ),
        ]
        let waiting = WatchLine.Row.Line(
            "ask:sr-qx81zt:k3", .ask, ask: "k3", first: "Give the go", since: 1_792_741_127_000
        )

        return WatchLine(
            at: 1_792_741_527_619, version: "0.2.0",
            rows: [.init(session: "sr-qx81zt", name: "Region rollout", projectName: "Fabrikam", lines: [waiting])],
            snoozed: [.init(session: "sr-qx81zt", name: "Region rollout", projectName: "Fabrikam", lines: asleep)]
        ).text
    }()

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
        _ = last.hear(.line(Self.line), at: .now)
        let board = PanelBoard(last), asleep = try #require(board.snoozed.first)
        strip.onJump = { id, _ in heard.said.append("jump \(id)") }
        strip.onSnooze = { id, asks, _ in heard.said.append("snooze \(id) \(asks)") }
        strip.onWake = { heard.said.append("wake \($0)") }
        strip.show(board)

        let actions = strip.rowActions(for: asleep)
        actions.snooze(asleep.asks, .untilItMoves)
        actions.wake()
        actions.jump()

        #expect(heard.said == ["snooze sr-qx81zt [\"k1\", \"k2\"]", "wake sr-qx81zt", "jump sr-qx81zt"])
    }
}
