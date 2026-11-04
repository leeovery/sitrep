import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// The list beside the page following the window's model, in the window's split over a real `WindowModel`, made,
/// never shown: folded away with the change that fills the window, focus kept off a list going, and focus on the list
/// as a session opened from outside before any board lands on the board come.
@MainActor
struct ListFollowingTests {
    /// A project opened with focus on the list: the list folds away at once, with the change, and focus goes to the
    /// sidebar's list.
    @Test func aProjectOpenedWithFocusOnTheListFoldsItAwayGivingFocusToTheSidebar() async throws {
        let window = try Followed()

        window.model.show(HostedSidebar.heard(Lines.watch[0]))
        window.model.opened()
        window.focus.focusList()
        try #require(window.isOnTheList)
        window.model.actions.click(.project("switchboard"))
        #expect(window.list.isCollapsed)
        await window.settled()
        #expect(window.isOnTheSidebar)
    }

    /// The list holding focus empties to its one line, its last line gone from the board: focus goes to the sidebar's
    /// list.
    @Test func theListEmptyingUnderFocusGivesItToTheSidebar() async throws {
        let window = try Followed()

        window.model.show(HostedSidebar.heard(Lines.watch[0]))
        window.model.opened()
        window.focus.focusList()
        try #require(window.isOnTheList)
        window.model.show(HostedSidebar.heard(Self.nothingWaiting))
        await window.settled()
        #expect(window.isOnTheSidebar)
    }

    /// Left on a project's page and opened from outside before any board: focus on the sidebar, the list folded away;
    /// the board come, the landing lands on Needs you, the list shows, and focus goes to it.
    @Test func aLandingWaitingOnTheBoardPutsFocusOnTheListAsItLands() async throws {
        let window = try Followed(remembered: .project("switchboard"))

        window.model.opened(landing: "sr-gs7kq2")
        window.focus.focusList()
        #expect(window.list.isCollapsed)
        #expect(window.isOnTheSidebar)
        window.model.show(HostedSidebar.heard(Lines.watch[0]))
        #expect(!window.list.isCollapsed)
        await window.settled()
        #expect(window.isOnTheList)
    }

    /// `watch`'s first line with nothing waiting on Lee.
    private static let nothingWaiting = {
        var board = try! JSONSerialization.jsonObject(with: Data(Lines.watch[0].utf8)) as! [String: Any]

        board["rows"] = (board["rows"] as! [[String: Any]]).filter { $0["section"] as? String != "needsYou" }
        return String(decoding: try! JSONSerialization.data(withJSONObject: board), as: UTF8.self)
    }()
}

/// The window's split over a model of its own, its defaults a suite of their own, with where it was left as given.
@MainActor
private struct Followed {
    let model: WindowModel
    let window: NSWindow
    let focus: SideFocus
    let list: NSSplitViewItem
    private let following: ListFollowing
    private let sidebar: NSView
    private let listed: NSView

    init(remembered: Location? = nil) throws {
        let defaults = try #require(UserDefaults(suiteName: "sitrep.ListFollowingTests.\(UUID().uuidString)"))
        let plugin = Plugin()
        let banners = Banners(pid: 1, send: { _ in }, helperApp: NoHelper())

        if let remembered {
            WhereLeft.save(remembered, in: defaults)
        }
        model = WindowModel(
            plugin: plugin, works: Works(banners: banners, plugin: plugin),
            snoozes: Snoozes(plugin: plugin, banners: banners), following: Following(), period: .hour,
            defaults: defaults
        )

        let columns = SitRepWindow.columns(over: model)
        let split = SitRepWindow.split(sidebar: columns.sidebar, list: columns.list, page: columns.page)

        window = SitRepWindow.window(split)
        window.contentView?.layoutSubtreeIfNeeded()
        focus = SideFocus(
            window: window, sidebar: columns.sidebar.view, list: columns.list.view, page: columns.page.view
        )
        list = split.splitViewItems[1]
        following = ListFollowing(model: model, list: list, focus: focus)
        sidebar = columns.sidebar.view
        listed = columns.list.view
    }

    /// What the change left to run after it, run, the window laid out.
    func settled() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        window.contentView?.layoutSubtreeIfNeeded()
    }

    var isOnTheList: Bool { isFocused(in: listed) }
    var isOnTheSidebar: Bool { isFocused(in: sidebar) }

    /// Focus on the column's list.
    private func isFocused(in column: NSView) -> Bool {
        HostedSidebar.views(NSTableView.self, in: column).first.map { window.firstResponder === $0 } ?? false
    }
}

/// A helper app that never starts.
private final class NoHelper: HelperStarting {
    var watched: Int32? { nil }

    func open() {}

    func isRunning(_: Int32) -> Bool { false }
}
