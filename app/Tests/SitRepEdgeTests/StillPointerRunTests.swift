import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// Only Lee opens the notch (DESIGN, "Keys"): its hit area growing, coming back or moving by itself under a pointer
/// that has not moved opens nothing, in either style: a new ask's swell, the notch shown again, another style, a new
/// home along the edge. The pointer's own move there opens it as ever. The Meniscus's tongue reaching a pointer in its
/// field opens it by design, so its cases run under reduced motion, which has no tongue.
@Suite(.backstop)
struct StillPointerRunTests {
    private static let frameMS = 1000.0 / 60
    private static let away = CGPoint(x: 1300, y: 300)
    /// Beside the calm notch along the edge, past its hit area, inside the one a swell grows.
    private static let besideTheCalmNotch = CGPoint(x: 3, y: 491 + 55)

    /// The styles with no reach toward a still pointer: the Card, with motion or without, and the Meniscus without.
    private static let looks: [(NotchStyle, Bool)] = [(.card, false), (.card, true), (.meniscus, true)]

    private static func setting(_ look: (NotchStyle, Bool), notchY: Double = 491) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: notchY), mirror: .identity,
            style: look.0, reducesMotion: look.1, takesKeys: true
        )
    }

    private static func at(_ run: NotchRun, _ pointer: CGPoint?, _ setting: NotchRun.Setting) -> NotchRun.Moment {
        NotchRun.Moment(time: run.time + frameMS, pointer: pointer, setting: setting)
    }

    private static func frames(
        _ run: NotchRun, for ms: Double, _ pointer: CGPoint?, _ setting: NotchRun.Setting,
        until done: () -> Bool = { false }
    ) {
        let end = run.time + ms

        while run.time < end, !done() {
            run.step(at(run, pointer, setting))
        }
    }

    /// Nothing needing Lee: one session working.
    private static func calm() -> PanelBoard {
        var last = LastBoard()

        _ = last.hear(.line(allClearLine), at: Date())
        return PanelBoard(last)
    }

    /// A run over `board`, at rest closed with the pointer come to rest here.
    private static func resting(
        at pointer: CGPoint, _ setting: NotchRun.Setting, board: PanelBoard = calm()
    ) throws -> NotchRun {
        let run = NotchRun(at: 1000, in: setting, folding: Folding())

        _ = run.show(board, at(run, Self.away, setting))
        frames(run, for: 500, Self.away, setting)
        frames(run, for: 2000, pointer, setting)
        try #require(run.phase == .closed)
        return run
    }

    @Test(arguments: looks)
    func aSwellUnderAStillPointerOpensNothing(look: (NotchStyle, Bool)) throws {
        let setting = Self.setting(look), run = try Self.resting(at: Self.besideTheCalmNotch, setting)

        _ = run.show(AsksBoard.board(), Self.at(run, Self.besideTheCalmNotch, setting))
        Self.frames(run, for: 3000, Self.besideTheCalmNotch, setting)
        try #require(run.frame.hits(Self.besideTheCalmNotch), "the swell grew over the pointer")
        #expect(run.phase == .closed)

        Self.frames(run, for: 2000, CGPoint(x: 2, y: Self.besideTheCalmNotch.y), setting)
        #expect(run.phase == .open)
    }

    @Test(arguments: [(NotchStyle.meniscus, false), (.meniscus, true), (.card, false), (.card, true)])
    func shownAgainUnderARestingPointerOpensNothing(look: (NotchStyle, Bool)) throws {
        let setting = Self.setting(look), run = try Self.resting(at: Self.away, setting)
        let onTheNotch = CGPoint(x: 3, y: 491)

        run.catchUp(NotchRun.Moment(time: run.time + 5000, pointer: onTheNotch, setting: setting))
        Self.frames(run, for: 2000, onTheNotch, setting)
        #expect(run.phase == .closed)

        Self.frames(run, for: 2000, CGPoint(x: 2, y: 492), setting)
        #expect(run.phase == .open)
    }

    /// Closed by `esc` under the pointer, which stays closed until the pointer leaves, then restyled: the new style's
    /// notch opens nothing under the pointer either.
    @Test(arguments: [(NotchStyle.meniscus, NotchStyle.card), (.card, .meniscus)])
    func anotherStyleUnderARestingPointerOpensNothing(from: NotchStyle, to: NotchStyle) throws {
        let was = Self.setting((from, false)), now = Self.setting((to, false))
        let onTheNotch = CGPoint(x: 3, y: 491)
        let run = NotchRun(at: 1000, in: was, folding: Folding())

        _ = run.show(AsksBoard.board(), Self.at(run, nil, was))
        Self.frames(run, for: 3000, onTheNotch, was) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)
        _ = run.key(.escape, Self.at(run, onTheNotch, was))
        Self.frames(run, for: 2000, onTheNotch, was) { run.phase == .closed && !run.frame.isMoving }
        try #require(run.phase == .closed)

        Self.frames(run, for: 2000, onTheNotch, now)
        #expect(run.phase == .closed)
    }

    @Test(arguments: looks)
    func aNewHomeUnderAStillPointerOpensNothing(look: (NotchStyle, Bool)) throws {
        let there = CGPoint(x: 3, y: 700), run = try Self.resting(at: there, Self.setting(look))
        let moved = Self.setting(look, notchY: there.y)

        Self.frames(run, for: 2000, there, moved)
        try #require(run.frame.hits(there), "the notch moved under the pointer")
        #expect(run.phase == .closed)
    }
}
