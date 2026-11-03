import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import Testing

/// Nothing at the edge, from the welcome: step 3 at Nothing, and the stage with no edge from step 3 on, made, never
/// shown.
@MainActor
struct WelcomeNothingTests {
    typealias Made = WelcomeWindowTests.Made

    // MARK: Your edge

    /// The form's rows stay in their place, taking no presses, as Show nothing at the edge sets it.
    @Test func atNothingTheFormsRowsStayInTheirPlaceDisabled() async {
        let made = Made()

        made.at(.edge)

        let notch = await made.settled()
        let rows = Self.rows(in: notch)

        #expect(Self.segments(in: notch).allSatisfy { $0.isEnabled })
        made.welcome.choose(.nothing)
        #expect(made.preferences.edge.show == .nothing)

        let nothing = await made.settled()

        #expect(Self.segments(in: nothing).count == 3)
        #expect(Self.segments(in: nothing).allSatisfy { !$0.isEnabled })
        #expect(Self.rows(in: nothing) == rows)
    }

    @Test(arguments: [EdgeSettings.Show.notch, .strip])
    func aTileBringsItsShapeBack(show: EdgeSettings.Show) async {
        let made = Made()

        made.preferences.edit { $0.show = .nothing }
        made.at(.edge)
        _ = await made.settled()
        made.welcome.choose(show)
        #expect(made.preferences.edge.show == show)
        #expect(Self.segments(in: await made.settled()).allSatisfy { $0.isEnabled })
    }

    // MARK: The stage

    /// Steps 1 and 2 teach what the notch does, so show it at Nothing too; from step 3, the stage shows no edge.
    @Test func atNothingTheStageShowsNoEdgeFromStepThree() async {
        let made = Made()
        let stage = made.window.stage

        made.preferences.edit { $0.show = .nothing }
        for step in WelcomeSteps.all {
            made.at(step)
            _ = await made.settled()
            #expect((stage.surface is NotchSurface) == [.hello, .ask].contains(step), "\(step)")
            #expect(!(stage.surface is StripSurface), "\(step)")
        }
    }

    /// At the last step, no callout, with nothing for it to point at.
    @Test func atNothingTheLastStepShowsNoCallout() async throws {
        let made = Made()
        let stage = made.window.stage

        made.at(.ready)
        _ = await made.settled()
        try #require(stage.callout.place != nil)
        made.preferences.edit { $0.show = .nothing }
        _ = await made.settled()
        #expect(stage.callout.place == nil)
    }

    /// Chosen at step 3, the stage's edge goes at once; a tile brings it back.
    @Test func choosingNothingTakesTheStagesEdgeAway() async {
        let made = Made()
        let stage = made.window.stage

        made.at(.edge)
        _ = await made.settled()
        #expect(stage.surface is NotchSurface)
        made.welcome.choose(.nothing)
        stage.step(at: Displays.now)
        #expect(!(stage.surface is NotchSurface))
        made.welcome.choose(.notch)
        stage.step(at: Displays.now)
        #expect(stage.surface is NotchSurface)
    }

    /// With no notch to swell, a sound chosen lights SitRep's item in the stage's menu bar, at rest until then.
    @Test func atNothingASoundChosenLightsTheMenuBarsItem() async {
        let made = Made()
        let scene = made.window.stage.scene

        made.preferences.edit { $0.show = .nothing }
        made.at(.sound)
        _ = await made.settled()
        #expect(!scene.isItemLit)
        made.welcome.choose(sound: "Pop")
        _ = await made.settled()
        #expect(scene.isItemLit)
        made.at(.ready)
        _ = await made.settled()
        made.welcome.goBack()
        made.welcome.goBack()
        _ = await made.settled()
        #expect(made.welcome.step == .sound && !scene.isItemLit)
    }

    /// With the notch, the item stays lit throughout, as for needs you.
    @Test func withTheNotchTheMenuBarsItemIsLit() async {
        let made = Made()

        made.at(.sound)
        _ = await made.settled()
        #expect(made.window.stage.scene.isItemLit)
    }

    // MARK: Helpers

    private static func segments(in view: NSView) -> [NSSegmentedControl] {
        view.subviews.flatMap { ($0 as? NSSegmentedControl).map { [$0] } ?? segments(in: $0) }
    }

    /// The form's rows' heights in the window, from the bottom.
    private static func rows(in view: NSView) -> [CGFloat] {
        segments(in: view).map { $0.convert($0.bounds, to: nil).midY }.sorted()
    }
}
