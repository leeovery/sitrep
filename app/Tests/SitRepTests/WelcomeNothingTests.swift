import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

/// Nothing at the edge, from the welcome: step 3 at Nothing, and the stage with no edge from step 3 on, made, never
/// shown.
@MainActor
@Suite(.backstop)
struct WelcomeNothingTests {
    typealias Made = WelcomeWorld.Made
    typealias Clock = WelcomeWorld.Clock

    // MARK: Your edge

    /// The form's rows stay in their place, taking no presses, as Show nothing at the edge sets it.
    @Test func atNothingTheFormsRowsStayInTheirPlaceDisabled() async {
        let made = Made()

        made.at(.edge)

        let notch = await made.settled()
        let rows = Self.rows(in: notch)

        expectEvery(Self.segments(in: notch)) { $0.isEnabled }
        made.welcome.choose(.nothing)
        #expect(made.preferences.edge.show == .nothing)

        let nothing = await made.settled()

        #expect(Self.segments(in: nothing).count == 3)
        expectEvery(Self.segments(in: nothing)) { !$0.isEnabled }
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
        expectEvery(Self.segments(in: await made.settled())) { $0.isEnabled }
    }

    /// Done at Nothing leaves no callout waiting for a shape picked later; Done with a shape does.
    @Test(arguments: [(EdgeSettings.Show.nothing, CalloutSettings.Standing.unshown), (.notch, .due), (.strip, .due)])
    func doneArmsTheCalloutOnlyWithAShape(show: EdgeSettings.Show, standing: CalloutSettings.Standing) {
        let made = Made()

        made.preferences.edit { $0.show = show }
        made.at(.ready)
        made.welcome.goOn()
        #expect(made.preferences.callout.standing == standing)
    }

    // MARK: The stage

    /// Steps 1 and 2 teach what the notch does, so show it at Nothing too; from step 3, the stage shows no edge.
    @Test func atNothingTheStageShowsNoEdgeFromStepThree() async throws {
        let made = Made()
        let stage = try made.stage

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
        let stage = try made.stage

        made.at(.ready)
        _ = await made.settled()
        try #require(stage.callout.place != nil)
        made.preferences.edit { $0.show = .nothing }
        _ = await made.settled()
        #expect(stage.callout.place == nil)
    }

    /// Chosen at step 3, the stage's edge goes at once; a tile brings it back.
    @Test func choosingNothingTakesTheStagesEdgeAway() async throws {
        let made = Made()
        let stage = try made.stage

        made.at(.edge)
        _ = await made.settled()
        #expect(stage.surface is NotchSurface)
        made.welcome.choose(.nothing)
        stage.step(at: made.clock.now)
        #expect(!(stage.surface is NotchSurface))
        made.welcome.choose(.notch)
        stage.step(at: made.clock.now)
        #expect(stage.surface is NotchSurface)
    }

    // MARK: The stage's menu bar

    /// SitRep's item lit while the stage's board has its ask, whatever the shape: as the notch is lit from step 3, but
    /// at rest beside the callout; with no edge, at rest at the sound's step until a sound is chosen.
    @Test(arguments: [EdgeSettings.Show.notch, .strip, .nothing])
    func theMenuBarsItemIsLitWhileTheBoardHasItsAsk(show: EdgeSettings.Show) async throws {
        let made = Made()
        let scene = try made.stage.scene

        made.preferences.edit { $0.show = show }
        for step in [WelcomeStep.edge, .sound, .permissions, .ready] {
            made.at(step)
            _ = await made.settled()
            #expect(scene.isItemLit == (step != .ready && !(show == .nothing && step == .sound)), "\(step)")
        }
    }

    /// Step 1's loop: at rest until the ask lands, then lit.
    @Test func onStepOneTheItemLightsAsTheAskLands() async throws {
        let made = Made()
        let stage = try made.stage

        _ = await made.settled()
        #expect(!stage.scene.isItemLit)
        stage.standing = .inFront
        stage.step(at: made.clock.pass(WelcomeLoop.hello.lands + 100))
        _ = await made.settled()
        #expect(stage.scene.isItemLit)
    }

    /// With no notch to swell, each sound chosen lights the item for as long as the notch would swell, then it rests
    /// again, a frame woken as the light ends.
    @Test func atNothingEachSoundChosenLightsTheItemForAChimesLength() async throws {
        let made = Made()
        let stage = try made.stage

        made.preferences.edit { $0.show = .nothing }
        made.at(.sound)
        _ = await made.settled()
        #expect(!stage.scene.isItemLit)
        for sound in ["Pop", "Tink"] {
            let chimed = made.clock.now

            // the chime told the stage at once, as the view's update would tell it, so no wait comes between
            made.welcome.choose(sound: sound)
            stage.chime(made.welcome.chimes)

            let ends = try #require(stage.chimeEnds as? Clock.Wake)

            #expect(stage.toldItem, "\(sound)")
            #expect(ends.due == chimed + StageEdge.chimeLight)
            stage.step(at: made.clock.pass(StageEdge.chimeLight - 50))
            #expect(stage.toldItem, "\(sound)")
            made.clock.fire(ends)
            #expect(!stage.toldItem && stage.chimeEnds == nil, "\(sound)")
            _ = await made.settled()
            #expect(!stage.scene.isItemLit, "\(sound)")
        }
    }

    /// Show changed in Settings while the welcome is at the sound's step: the item follows the board at once.
    @Test func theItemFollowsAShapeChangedMidStep() async throws {
        let made = Made()
        let stage = try made.stage

        made.at(.sound)
        _ = await made.settled()
        #expect(stage.scene.isItemLit)
        made.preferences.edit { $0.show = .nothing }
        _ = await made.settled()
        #expect(!stage.scene.isItemLit)
        made.preferences.edit { $0.show = .strip }
        _ = await made.settled()
        #expect(stage.scene.isItemLit)
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
