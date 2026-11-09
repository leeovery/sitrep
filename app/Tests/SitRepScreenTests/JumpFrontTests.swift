import SitRepCore
@testable import SitRepScreen
import Testing

/// The front kept: with another app in front as the jump began, Ghostty brought forward again, once, should another
/// app take the front back from it within the second after the focus, heard as each app comes to the front.
struct JumpFrontTests {
    /// A jump to a terminal in its window's selected tab, from Finder unless given, the apps coming to the front as the
    /// focus lands as given.
    private static func fromFront(
        _ front: String? = finder, focused: [String?], forward: Bool? = true
    ) async -> (Jumping, JumpAnswer) {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table, workspace: FakeWorkspace(front: front, forward: forward, focused: focused))

        return (jumping, await jumping.run([inTmux()]))
    }

    private static let ghosttyForward = bundled(ghosttyBundle).absoluteString

    /// Finder in front as the jump begins, and handed the front back after Ghostty, were Ghostty focused.
    private static var handingBack: FakeWorkspace {
        FakeWorkspace(front: finder, focused: [ghosttyBundle, finder])
    }

    @Test func withGhosttyInFrontAsTheJumpBeginsNothingWatchesTheFrontAfterIt() async {
        let (jumping, answer) = await Self.fromFront(ghosttyBundle, focused: [ghosttyBundle, finder])

        #expect(answer == .jumped)
        #expect(jumping.workspace.fronts == 1)
        #expect(jumping.workspace.listened == 0)
        #expect(jumping.clock.sleeps.isEmpty)
        #expect(jumping.workspace.brought.isEmpty)
    }

    @Test func anotherAppTakingTheFrontBackAfterGhosttyCameForwardBringsGhosttyForwardOnceFoundRunningWithinTwoSeconds() async {
        let (jumping, answer) = await Self.fromFront(focused: [finder, ghosttyBundle, ghosttyBundle, finder])

        #expect(answer == .jumped)
        #expect(jumping.workspace.runningAsked == [[ghosttyBundle]])
        #expect(jumping.workspace.brought == [Self.ghosttyForward])
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
        #expect(jumping.workspace.listening == 0, "the listening ends with the jump")
    }

    @Test func theWatchLastsASecondTwiceTheHalfSecondAtWhichTheHandBackCame() {
        #expect(KeptInFront.watch == .seconds(1))
    }

    @Test func ghosttyNeverComingForwardIsNeverBroughtForwardTheWatchRunsItsWholeSecondAsBringingItForwardCouldMakeAWindow() async {
        let (jumping, answer) = await Self.fromFront(focused: [finder])

        #expect(answer == .jumped)
        #expect(jumping.clock.sleeps == [KeptInFront.watch])
        #expect(jumping.workspace.brought.isEmpty)
    }

    @Test func ghosttyComingForwardAndKeepingTheFrontNeedsNothingMore() async {
        let (jumping, _) = await Self.fromFront(focused: [finder, ghosttyBundle])

        #expect(jumping.clock.sleeps == [KeptInFront.watch])
        #expect(jumping.workspace.brought.isEmpty)
    }

    @Test func ghosttyIsBroughtForwardNeverMoreThanOnceHoweverOftenTheFrontIsTakenBack() async {
        let (jumping, _) = await Self.fromFront(focused: [ghosttyBundle, finder, ghosttyBundle, finder, ghosttyBundle, finder])

        #expect(jumping.workspace.brought == [Self.ghosttyForward])
    }

    @Test func anAppComingToTheFrontWithNoBundleIdIsNoHandBack() async {
        let (handedBack, _) = await Self.fromFront(focused: [ghosttyBundle, nil, nil, finder])
        let notHanded = await Self.fromFront(focused: [ghosttyBundle, nil]).0

        #expect(handedBack.workspace.brought == [Self.ghosttyForward])
        #expect(notHanded.workspace.brought.isEmpty)
    }

    @Test func theFrontNotToldOrBringingForwardFailingOrNotAnsweringNeverFailsTheJump() async {
        let (untold, untoldAnswer) = await Self.fromFront(nil, focused: [ghosttyBundle, finder])

        #expect(untoldAnswer == .jumped)
        #expect(untold.workspace.listened == 0, "nothing watches when the front is not told")
        #expect(untold.workspace.brought.isEmpty)

        let (_, failed) = await Self.fromFront(focused: [ghosttyBundle, finder], forward: false)

        #expect(failed == .jumped)

        let (tmux, table) = shown()
        let hanging = Jumping(tmux, table, workspace: FakeWorkspace(front: finder, forward: nil, focused: [ghosttyBundle, finder]))
        let jumped = Task { await hanging.run([inTmux()]) }

        await until { hanging.clock.sleeps.contains(.seconds(2)) }
        hanging.clock.pass(.seconds(2))
        #expect(await jumped.value == .jumped)
        #expect(hanging.workspace.brought == [Self.ghosttyForward])
    }

    @Test func aJumpThatBringsNoWindowForwardWatchesNothing() async {
        var mac = Mac(), other = Mac()
        let detached = server([mac.ghosttyClient(kitTerminal.device, showing: kit)])
        let elsewhere = server([other.ghosttyClient("/dev/ttys099", showing: claudes)])
        let offScreen = Jumping(detached, FakeTable(mac.tree), workspace: Self.handingBack)
        let unanswered = Jumping(elsewhere, FakeTable(other.tree), workspace: Self.handingBack)

        #expect(await offScreen.run([inTmux()]) != .jumped)
        #expect(await unanswered.run([inTmux()]) != .jumped)

        for jumping in [offScreen, unanswered] {
            #expect(jumping.clock.sleeps.isEmpty)
            #expect(jumping.workspace.brought.isEmpty)
            #expect(jumping.workspace.listening == 0)
        }
    }

    /// For a tab not selected the slide begins as its window is activated, half a second before the focus, so the
    /// hand-back may come before the focus: heard from before the first event, it is caught all the same.
    @Test func aHandBackComingBetweenTheWindowActivatedAndTheFocusIsHeard() async {
        let (tmux, table) = shown()
        let tabbed = [FakeWindow(id: "TABBED-WINDOW", tabs: [[kitTerminal], [switchboardTerminal]], selected: 0)]
        let jumping = Jumping(tmux, table, terminals: tabbed, workspace: FakeWorkspace(front: finder, activated: [ghosttyBundle, finder]))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.told == ["activate window TABBED-WINDOW", "focus SWITCHBOARD-TERMINAL"])
        #expect(jumping.workspace.brought == [Self.ghosttyForward])
    }
}
