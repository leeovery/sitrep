import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
import SitRepMenu
@testable import SitRepWindow
import SwiftUI
import Testing

/// What moves in the SitRep window moves as the panel's does, by Core Animation in the render server: a working mark's
/// arc turning once a second, and a working line's lead shimmering, in Working's list and on a page alike; nothing
/// that draws them again stops them; under Reduce motion both hold still. The sidebar's Working mark is a place's, and
/// holds still. Both are decoration: a click on either lands on the row under it. Made, never shown.
@MainActor
struct WindowMotionTests {
    /// The board `watch` printed by session, SitRep working among it, open on Working.
    private static func opened() -> WindowRun {
        let run = HostedSidebar.opened(Lines.bySession[0])

        run.click(.place(.working))
        return run
    }

    /// The working rows of the board, as Working lists them.
    private static func working(in run: WindowRun) -> Int {
        run.list(at: HostedSidebar.printed)?.rows.filter { $0.row.mark == .working }.count ?? 0
    }

    @Test func workingsRowsTurnAndShimmer() throws {
        let run = Self.opened()
        let side = try HostedSidebar(run, column: .list)
        let count = Self.working(in: run)

        try #require(count > 0)
        #expect(Self.turning(in: side.view) == count)
        #expect(Self.sweeping(in: side.view) == count)
    }

    /// A board coming in draws the list again: its working rows turn and shimmer on.
    @Test func aBoardDrawingTheListAgainLeavesThemTurning() throws {
        let run = Self.opened()
        let side = try HostedSidebar(run, column: .list)
        let count = Self.working(in: run)

        side.show(run, at: HostedSidebar.printed)
        side.show(run, at: HostedSidebar.printed.addingTimeInterval(60))
        #expect(Self.turning(in: side.view) == count)
        #expect(Self.sweeping(in: side.view) == count)
    }

    @Test func underReduceMotionTheListHoldsStill() throws {
        let side = try HostedSidebar(Self.opened(), column: .list, reducesMotion: true)

        #expect(!HostedSidebar.views(SpinnerView.self, in: side.view).isEmpty)
        #expect(Self.turning(in: side.view) == 0)
        #expect(Self.sweeping(in: side.view) == 0)
    }

    /// Working's place holds its arc still, whatever is working: the place is where Lee goes, not what moves.
    @Test func theSidebarsWorkingMarkHoldsStill() throws {
        let side = try HostedSidebar(Self.opened())

        #expect(!HostedSidebar.views(SpinnerView.self, in: side.view).isEmpty)
        #expect(Self.turning(in: side.view) == 0)
        #expect(Self.sweeping(in: side.view) == 0)
    }

    /// A page's working mark and lead, as the list's.
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

    // MARK: A click

    /// A click on a working row's arc or its lit lead lands on the list's row under it, in the row's own cell, never on
    /// either, so the list takes it as a click on the row. (No click made offscreen reaches a list or a button, its
    /// window never key: where it lands is what can be read.)
    @Test func aClickOnAListRowsArcOrLeadLandsOnTheRow() throws {
        let side = try HostedSidebar(Self.opened(), column: .list)
        let decoration = Self.decoration(in: side.view)

        try #require(!decoration.isEmpty)
        for view in decoration {
            let point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
            let row = side.board.row(at: side.board.convert(point, from: nil))
            let hit = try #require(Self.hit(point, in: side.window))

            try #require(row >= 0)
            #expect(!Self.isDecoration(hit))
            #expect(Self.row(of: hit) === side.board.rowView(atRow: row, makeIfNecessary: false))
        }
    }

    /// On a project's page, a click on a working session's arc or its lit lead lands on the page itself, whose button
    /// the session's row is, never on either.
    @Test func aClickOnAProjectPagesArcOrLeadLandsOnThePage() throws {
        let window = Self.hosted(
            ProjectPageView(page: Self.project, now: Date(timeIntervalSince1970: 60)),
            size: CGSize(width: 600, height: 300)
        )
        let page = try #require(window.contentView)
        let decoration = Self.decoration(in: page)

        try #require(decoration.count == 3)
        for view in decoration {
            let point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)

            #expect(Self.hit(point, in: window) === page)
        }
    }

    /// A project of one session, working: its row's arc and lead, and its card's arc in Now.
    private static let project = ProjectPage(
        key: "project", name: Sample.project,
        sessions: [ProjectPage.Session(
            id: "sr-work01", name: "Session", mark: .working, isAway: false, isOffScreen: false,
            standing: .doing(
                .working, Board.Row.Words(lead: Sample.writing.title, mono: Sample.writing.code, more: nil)
            ),
            since: Date(timeIntervalSince1970: 0), now: [], next: nil, updated: Date(timeIntervalSince1970: 0), log: []
        )],
        waiting: [], parked: 0
    )

    /// The arcs and lit leads in a view.
    private static func decoration(in view: NSView) -> [NSView] {
        HostedSidebar.views(SpinnerView.self, in: view) + HostedSidebar.views(SweepView.self, in: view)
    }

    private static func isDecoration(_ view: NSView) -> Bool {
        sequence(first: view, next: \.superview).contains { $0 is SpinnerView || $0 is SweepView }
    }

    /// The view a click at this point in the window lands on.
    private static func hit(_ point: CGPoint, in window: NSWindow) -> NSView? {
        guard let content = window.contentView, let frame = content.superview else {
            return nil
        }

        return content.hitTest(frame.convert(point, from: nil))
    }

    /// The list's row a view is in.
    private static func row(of view: NSView) -> NSTableRowView? {
        sequence(first: view, next: \.superview).first { $0 is NSTableRowView } as? NSTableRowView
    }

    /// A view in a window of its own, laid out, never shown: the window, which holds it.
    private static func hosted(
        _ content: some View, reducesMotion: Bool = false, size: CGSize = CGSize(width: 300, height: 60)
    ) -> NSWindow {
        let host = NSHostingView(rootView: content.environment(\.reducesWindowMotion, reducesMotion))
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: true
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
