import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import Testing

/// Steps 1 and 2's loops, on the notch and on the strip: the stage draws no pointer, so the only row its edge ever
/// lights is the ask's, never one an unseen pointer passes over on its way to it or away. Read off what the stage's own
/// surfaces were last told to draw, frame by frame, on the clock the test moves.
@MainActor
struct WelcomePointerTests {
    typealias Made = WelcomeWorld.Made
    typealias Clock = WelcomeWorld.Clock

    /// A shape as Lee may set it: the notch in either style, or the strip, on either edge, moving or reducing motion.
    struct Look: Sendable, CustomTestStringConvertible {
        let show: EdgeSettings.Show
        let style: NotchStyle
        let edge: EdgeSettings.Edge
        var reducesMotion = false

        static let all = EdgeSettings.Edge.allCases.flatMap { edge in
            NotchStyle.allCases.map { Look(show: .notch, style: $0, edge: edge) }
                + [Look(show: .strip, style: .meniscus, edge: edge)]
        }

        var testDescription: String {
            (show == .strip ? "strip, \(edge)" : "\(style) notch, \(edge)") + (reducesMotion ? ", reducing motion" : "")
        }

        func set(_ settings: inout EdgeSettings) {
            settings.show = show
            settings.style = style
            settings.edge = edge
            settings.reducesMotion = reducesMotion
        }
    }

    /// A change Lee makes while the loop plays, this far into it.
    struct Change: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let from: Look
        let at: @Sendable (WelcomeLoop) -> Double
        let make: @Sendable (inout EdgeSettings) -> Void

        static let all = [
            Change(
                testDescription: "the notch for the strip, as the pointer arrives",
                from: Look(show: .notch, style: .meniscus, edge: .left), at: { $0.arrive + 100 }
            ) { $0.show = .strip },
            Change(
                testDescription: "the strip's length, its tab out",
                from: Look(show: .strip, style: .meniscus, edge: .left), at: { $0.onRow + 100 }
            ) { $0.length = $0.length == .grows ? .full : .grows },
            Change(
                testDescription: "the notch's style, on the row",
                from: Look(show: .notch, style: .meniscus, edge: .left), at: { $0.onRow + 100 }
            ) { $0.style = .card },
        ]
    }

    @Test(arguments: [WelcomeStep.hello, .ask], Look.all)
    func onlyTheAsksRowIsEverLit(_ step: WelcomeStep, _ look: Look) async throws {
        let made = await Self.made(at: step, look)
        let stage = try made.stage, loop = try #require(stage.play.loop)
        var lit: Set<String> = []

        while stage.loopTime < loop.length - 20 {
            stage.step(at: made.clock.pass(1000 / 60))
            lit.formUnion(Self.litOnlyByTheAsk(stage))
        }
        #expect(lit == [WelcomeBoard.asking])
    }

    /// A change mid-loop moves the rows or the marks, or makes the shape anew: the pointer never lands on another's.
    @Test(arguments: [WelcomeStep.hello, .ask], Change.all)
    func aChangeMidLoopLightsOnlyTheAsksRow(_ step: WelcomeStep, _ change: Change) async throws {
        let made = await Self.made(at: step, change.from)
        let stage = try made.stage, loop = try #require(stage.play.loop)
        var lit: Set<String> = [], changed = false

        while stage.loopTime < loop.length - 20 {
            if !changed, stage.loopTime >= change.at(loop) {
                made.preferences.edit(change.make)
                changed = true
            }
            stage.step(at: made.clock.pass(1000 / 60))
            lit.formUnion(Self.litOnlyByTheAsk(stage))
        }
        #expect(changed && lit == [WelcomeBoard.asking])
    }

    /// Paced as the stage paces itself, frames only while something moves and asleep until the loop's next beat, the
    /// ask's row lights as the pointer steps onto it: the step is a beat of its own. Reducing motion, the panel has
    /// poured and frames sleep before it, so only that beat wakes them for it.
    @Test(arguments: [WelcomeStep.hello, .ask], [EdgeSettings.Show.notch, .strip].flatMap { show in
        [false, true].map { Look(show: show, style: .meniscus, edge: .left, reducesMotion: $0) }
    })
    func pacedAsItPacesItselfTheRowLightsAsThePointerStepsOntoIt(_ step: WelcomeStep, _ look: Look) async throws {
        let made = await Self.made(at: step, look)
        let stage = try made.stage, loop = try #require(stage.play.loop)
        var firstLit: Double?

        while stage.loopTime < loop.length - 20 {
            try Self.paced(stage, on: made.clock)
            if firstLit == nil, !Self.litOnlyByTheAsk(stage).isEmpty {
                firstLit = stage.loopTime
            }
        }
        #expect(try #require(firstLit) <= loop.onRow + 20)
    }

    /// As the pointer leaves, the panel closes and the strip's tab drains, so nothing is lit or out as the loop ends.
    @Test(arguments: [WelcomeStep.hello, .ask], Look.all)
    func asThePointerLeavesWhatPouredGoesBackIn(_ step: WelcomeStep, _ look: Look) async throws {
        let made = await Self.made(at: step, look)
        let stage = try made.stage, loop = try #require(stage.play.loop)
        var wasOut = false

        while stage.loopTime < loop.length - 20 {
            stage.step(at: made.clock.pass(1000 / 60))
            wasOut = wasOut || stage.isOut || !Self.tabs(stage).isEmpty
        }
        #expect(wasOut)
        #expect(!stage.isOut && Self.tabs(stage).isEmpty && Self.lit(stage).isEmpty)
    }

    // MARK: Helpers

    /// The welcome at this step, its stage on this shape, its window in front.
    private static func made(at step: WelcomeStep, _ look: Look) async -> Made {
        let made = Made()

        made.preferences.edit(look.set)
        made.at(step)
        _ = await made.settled()
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: made.recorded))
        return made
    }

    /// The stage's next frame as its own pacing brings it, on the test's clock: the link's next refresh while frames
    /// run, at the light's slower rate while only the light moves, or the loop's next beat, whichever comes first.
    private static func paced(_ stage: StageEdge, on clock: Clock) throws {
        let rate = stage.lastPace == .light ? 30.0 : 60
        let refresh = stage.isDrawing ? clock.now + 1000 / rate : nil
        let beat = stage.beat as? Clock.Wake
        let due = [refresh, beat?.due].compactMap(\.self).min()
        let next = try #require(due, "the stage sleeps with no beat to wake it")

        if let beat, beat.due == next {
            clock.fire(beat)
        } else {
            clock.now = next
            stage.frame(at: next)
        }
    }

    /// What the stage's edge last drew lit, expected to be the ask's row alone, if anything.
    private static func litOnlyByTheAsk(_ stage: StageEdge) -> Set<String> {
        let lit = lit(stage)

        #expect(lit.isSubset(of: [WelcomeBoard.asking]), "at \(Int(stage.loopTime)): \(lit)")
        return lit
    }

    /// The sessions whose rows the stage's edge last drew lit, by their ids: on the notch, the row under the pointer
    /// and the row pressed in; on the strip, each mark lifted, each tab out, and a count's row under the pointer.
    /// Anything lit that is no session's row is named for what it is.
    private static func lit(_ stage: StageEdge) -> Set<String> {
        if let notch = stage.surface as? NotchSurface, let scene = notch.scene, let list = notch.list {
            let hovered = scene.hover.map { list.item($0)?.session?.id ?? "item \($0)" }
            let pressed = scene.frame.panel?.pressed.map { key in
                list.content.items.first { $0.key == key }?.session?.id ?? key
            }

            return Set([hovered, pressed].compactMap(\.self))
        }
        if let strip = stage.surface as? StripSurface, let scene = strip.scene {
            let lifted = scene.frame.marks.filter { $0.isLifted || $0.lift > 0 }.map { id($0.key) }

            return Set(lifted + tabs(stage) + [scene.hoverRow].compactMap(\.self))
        }
        return []
    }

    /// The strip's tabs out, by whose they are.
    private static func tabs(_ stage: StageEdge) -> [String] {
        (stage.surface as? StripSurface)?.scene?.frame.tabs.map { id($0.key) } ?? []
    }

    private static func id(_ key: MarkKey) -> String {
        if case let .session(id) = key {
            return id
        }
        return "\(key)"
    }
}
