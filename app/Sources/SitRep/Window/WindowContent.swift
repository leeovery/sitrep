import SitRepCore
import enum SitRepPanel.SnoozeChoice
import enum SitRepPanel.WakeTime
import SitRepWindow
import SwiftUI

/// What a press in the window asks for, each handed to the model: every way the window goes somewhere, declared here
/// whether or not a view offers it yet, so the toolbar and the pages wire them without the run changing.
struct WindowActions: Sendable {
    /// A row of the sidebar clicked, a place or a project (`WindowRun.click(_:)`).
    var click: @MainActor @Sendable (Root) -> Void = { _ in }
    /// A row of the list beside the page picked, by a click (`WindowRun.pickInList(_:at:)`). Whether it was: a row a
    /// board has just dropped picks nothing.
    var pickInList: @MainActor @Sendable (ListPick) -> Bool = { _ in false }
    /// ↓, true, or ↑, false, in the list, or the toolbar's down or up (`WindowRun.step(down:at:)`).
    var step: @MainActor @Sendable (Bool) -> Void = { _ in }
    /// The fold at a place's list's foot clicked, "N snoozed" or "N earlier", which opens or folds.
    var toggleFold: @MainActor @Sendable (Place) -> Void = { _ in }
    /// Back and Forward, ⌘[ and ⌘].
    var back: @MainActor @Sendable () -> Void = {}
    var forward: @MainActor @Sendable () -> Void = {}
    /// A session's row on a project's page: its page, pushed from the project.
    var openSession: @MainActor @Sendable (String) -> Void = { _ in }
    /// A session page's project, in its breadcrumb: the project's page.
    var openProject: @MainActor @Sendable (String) -> Void = { _ in }
    /// A session's "later N parked" or a project's "N parked": Parked, narrowed to it.
    var openParked: @MainActor @Sendable (ParkedScope) -> Void = { _ in }
    /// A parked item's "Back to its session": the session's page, pushed from Parked.
    var backToSession: @MainActor @Sendable (String) -> Void = { _ in }
    var press: @MainActor @Sendable (Card.Button, AskAddress) -> Void = { _, _ in }
    /// An item opened in place, or closed again (`Item`).
    var toggleItem: @MainActor @Sendable (Item) -> Void = { _ in }
    /// To the session's window: "Open in Ghostty ↗", and a stop's "Answer in Claude ↗".
    var jump: @MainActor @Sendable (JumpPress) -> Void = { _ in }
    /// A card's ask snoozed until the time chosen on its Snooze, or woken by its Wake now.
    var snooze: @MainActor @Sendable (AskAddress, SnoozeChoice) -> Void = { _, _ in }
    var wake: @MainActor @Sendable (AskAddress) -> Void = { _ in }
    /// A line's one ask snoozed from its row's menu, or woken from an ask asleep's.
    var snoozeLine: @MainActor @Sendable (PlaceList.LineRow, SnoozeChoice) -> Void = { _, _ in }
    var wakeLine: @MainActor @Sendable (PlaceList.LineRow) -> Void = { _ in }
    var askToFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var cancelFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var confirmFinish: @MainActor @Sendable (String) -> Void = { _ in }
    /// The pointer came over a column, the list or the projects, or left it.
    var pointer: @MainActor @Sendable (HeldLists.Column, Bool) -> Void = { _, _ in }
    /// A region of the page found the pointer over it, or not, saying so under its own identity (`PagePointer`).
    var pointerOverPage: @MainActor @Sendable (Bool, ObjectIdentifier) -> Void = { _, _ in }
    /// What the Filter field holds, as Lee types or clears it.
    var filter: @MainActor @Sendable (String) -> Void = { _ in }
    /// Return in the Filter field.
    var openFirstMatch: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    @Entry var windowActions = WindowActions()
    /// The button whose jump runs, which alone shows it; nil with none of the window's.
    @Entry var pressedJump: JumpPress?
    /// The calendar wake times are worded and snoozes worked out on, the window's run's.
    @Entry var wakeCalendar = WakeTime.calendar
}

/// The page: beside the list, the session its row picked; filling the window, a project's page or a session's; or why
/// there is none, on the panel's black, starting under the toolbar's band. It draws what it is given, at the time
/// given, so it renders the same on the screen and off it, as the columns beside it do. On screen, the pointer
/// anywhere over it holds the page (`PagePointer`).
struct PageColumn: View {
    let page: Page
    let now: Date

    @Environment(\.isStill) private var isStill

    var body: some View {
        pages
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                if !isStill {
                    PagePointer()
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .background(WindowStyle.black.ignoresSafeArea())
    }

    @ViewBuilder private var pages: some View {
        switch page {
        case let .empty(words):
            Text(words)
                .font(WindowStyle.ui(14))
                .foregroundStyle(WindowStyle.faint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .detail(session):
            Scrolling { SessionPageView(page: session, now: now).padding(.horizontal, WindowStyle.detailInset) }
                .id(Pick.session(session.id))
        case let .session(session):
            Scrolling { SessionPageView(page: session, now: now).padding(.horizontal, WindowStyle.pageInset) }
                .id(Pick.session(session.id))
        case let .project(project):
            Scrolling { ProjectPageView(page: project, now: now).padding(.horizontal, WindowStyle.pageInset) }
                .id(Pick.project(project.key))
        }
    }
}
