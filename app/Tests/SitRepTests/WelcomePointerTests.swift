import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import Testing

/// Steps 1 and 2's loops, on the notch and on the strip: the stage draws no pointer, so the only row its edge ever
/// lights is the ask's, never one an unseen pointer passes over on its way to it or away. Read off what the stage's own
/// surfaces were last told to draw, frame by frame, on a clock of the test's own.
@MainActor
struct WelcomePointerTests {
    typealias Made = WelcomeWindowTests.Made

    @Test(arguments: [WelcomeStep.hello, .ask], [EdgeSettings.Show.notch, .strip])
    func onlyTheAsksRowIsEverLit(_ step: WelcomeStep, _ show: EdgeSettings.Show) async throws {
        let stage = await Self.stage(at: step, show)
        let loop = try #require(stage.play.loop)
        var time = Displays.now, lit: Set<String> = []

        while stage.loopTime < loop.length - 20 {
            time += 1000 / 60
            stage.step(at: time)

            let now = Self.lit(stage)

            #expect(now.isSubset(of: [WelcomeBoard.asking]), "at \(Int(stage.loopTime)): \(now)")
            lit.formUnion(now)
        }
        #expect(lit == [WelcomeBoard.asking])
    }

    /// As the pointer leaves, the panel closes and the strip's tab drains, so nothing is lit or out as the loop ends.
    @Test(arguments: [WelcomeStep.hello, .ask], [EdgeSettings.Show.notch, .strip])
    func asThePointerLeavesWhatPouredGoesBackIn(_ step: WelcomeStep, _ show: EdgeSettings.Show) async throws {
        let stage = await Self.stage(at: step, show)
        let loop = try #require(stage.play.loop)
        var time = Displays.now, wasOut = false

        while stage.loopTime < loop.length - 20 {
            time += 1000 / 60
            stage.step(at: time)
            wasOut = wasOut || stage.isOut || !Self.tabs(stage).isEmpty
        }
        #expect(wasOut)
        #expect(!stage.isOut && Self.tabs(stage).isEmpty && Self.lit(stage).isEmpty)
    }

    /// The welcome at this step, its stage on this shape, its window in front.
    private static func stage(at step: WelcomeStep, _ show: EdgeSettings.Show) async -> StageEdge {
        let made = Made()

        made.preferences.edit { $0.show = show }
        made.at(step)
        _ = await made.settled()
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        return made.window.stage
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
