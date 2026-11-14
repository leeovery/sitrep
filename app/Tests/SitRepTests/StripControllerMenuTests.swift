import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
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

    /// A made-up `watch` line: Fabrikam's session, an ask waiting in Needs you and two asleep in Snoozed.
    private static let line = #"""
        {"v":3,"at":1792741527619,"version":"0.2.0","head":{"needYou":1,"sessions":1},"rows":[{"session":"sr-qx81zt",\#
        "section":"needsYou","isAway":false,"project":"fabrikam","name":"Region rollout","projectName":"Fabrikam",\#
        "letters":"Fa","lines":[{"key":"ask:sr-qx81zt:k3","is":"ask","ask":"k3","writer":null,\#
        "first":{"lead":"Give the go","mono":null,"more":null},"since":1792741127000}],\#
        "second":"Fabrikam · Region rollout","since":1792741127000}],"snoozed":[{"session":"sr-qx81zt",\#
        "isAway":false,"project":"fabrikam","name":"Region rollout","projectName":"Fabrikam","letters":"Fa",\#
        "lines":[{"key":"ask:sr-qx81zt:k1","ask":"k1","first":{"lead":"Review the plan","mono":null,"more":null},\#
        "since":1792740927000,"wakesAt":1792741532000},{"key":"ask:sr-qx81zt:k2","ask":"k2",\#
        "first":{"lead":"Pick the second region","mono":null,"more":null},"since":1792741027000,\#
        "wakesAt":1792745127000}],"second":"Fabrikam · Region rollout","wakesAt":1792741532000}],"projects":[],\#
        "windows":[],"new":[],"boards":{}}
        """#

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
