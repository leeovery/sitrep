import AppKit
@testable import SitRep
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// What moves in the SitRep window moves as the panel's does, by Core Animation in the render server: a working mark's
/// arc turning once a second, and a working line's lead shimmering, in the sidebar's list and on a page alike; nothing
/// that draws them again stops them; under Reduce motion both hold still. Made, never shown.
@MainActor
struct WindowMotionTests {
    /// The board `watch` printed by session, SitRep working among it, open.
    private static func opened() -> WindowRun {
        HostedSidebar.opened(Lines.bySession[0])
    }

    /// The working rows of the board, as the sidebar lists it.
    private static func working(in run: WindowRun) -> Int {
        run.sidebar(at: HostedSidebar.printed).lines.filter { line in
            if case let .session(row) = line { row.mark == .working } else { false }
        }.count
    }

    @Test func theSidebarsWorkingRowsTurnAndShimmer() throws {
        let run = Self.opened()
        let side = try HostedSidebar(run, listAlone: true)
        let count = Self.working(in: run)

        try #require(count > 0)
        #expect(Self.turning(in: side.view) == count)
        #expect(Self.sweeping(in: side.view) == count)
    }

    /// A board coming in draws the list again: its working rows turn and shimmer on.
    @Test func aBoardDrawingTheListAgainLeavesThemTurning() throws {
        let run = Self.opened()
        let side = try HostedSidebar(run, listAlone: true)
        let count = Self.working(in: run)

        side.show(run.listed(at: HostedSidebar.printed), folds: run.folds)
        side.show(run.listed(at: HostedSidebar.printed.addingTimeInterval(60)), folds: run.folds)
        #expect(Self.turning(in: side.view) == count)
        #expect(Self.sweeping(in: side.view) == count)
    }

    @Test func underReduceMotionTheSidebarHoldsStill() throws {
        let side = try HostedSidebar(Self.opened(), listAlone: true, reducesMotion: true)

        #expect(!HostedSidebar.views(SpinnerView.self, in: side.view).isEmpty)
        #expect(Self.turning(in: side.view) == 0)
        #expect(Self.sweeping(in: side.view) == 0)
    }

    /// A page's working mark and lead, as the sidebar's.
    @Test(arguments: [false, true])
    func aPagesWorkingMarkAndLeadMoveButUnderReduceMotion(reducesMotion: Bool) throws {
        let window = Self.hosted(HStack {
            MarkView(mark: .working)
            ShimmeringLead { isLit in Text("Writing").foregroundStyle(isLit ? WindowStyle.text : WindowStyle.soft) }
        }, reducesMotion: reducesMotion)
        let view = try #require(window.contentView)

        #expect(Self.turning(in: view) == (reducesMotion ? 0 : 1))
        #expect(Self.sweeping(in: view) == (reducesMotion ? 0 : 1))
    }

    /// Taken out of its window and put back, as a list's row is as it scrolls away and back, its arc turns again.
    @Test func backInAWindowItTurnsAgain() throws {
        let window = Self.hosted(MarkView(mark: .working))
        let view = try #require(window.contentView)
        let spinner = try #require(HostedSidebar.views(SpinnerView.self, in: view).first)
        let parent = try #require(spinner.superview)

        spinner.removeFromSuperview()
        spinner.layer?.sublayers?.forEach { $0.removeAllAnimations() }
        #expect(!spinner.isTurning)
        parent.addSubview(spinner)
        #expect(spinner.window === window)
        #expect(spinner.isTurning)
    }

    /// Drawn as a still, which renders no AppKit view, in SwiftUI alone.
    @Test func drawnAsAStillNothingTurns() throws {
        let window = Self.hosted(MarkView(mark: .working).environment(\.isStill, true))
        let view = try #require(window.contentView)

        #expect(HostedSidebar.views(SpinnerView.self, in: view).isEmpty)
    }

    /// A view in a window of its own, laid out, never shown: the window, which holds it.
    private static func hosted(_ content: some View, reducesMotion: Bool = false) -> NSWindow {
        let host = NSHostingView(rootView: content.environment(\.reducesWindowMotion, reducesMotion))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 60), styleMask: [.borderless], backing: .buffered,
            defer: true
        )

        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return window
    }

    private static func turning(in view: NSView) -> Int {
        HostedSidebar.views(SpinnerView.self, in: view).filter(\.isTurning).count
    }

    private static func sweeping(in view: NSView) -> Int {
        HostedSidebar.views(SweepView.self, in: view).filter(\.isSweeping).count
    }
}
