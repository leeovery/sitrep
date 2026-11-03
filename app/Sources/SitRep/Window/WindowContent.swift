import SitRepCore
import enum SitRepPanel.SnoozeChoice
import enum SitRepPanel.WakeTime
import SitRepWindow
import SwiftUI

/// What a press in the window asks for, each handed to the model.
struct WindowActions: Sendable {
    var pick: @MainActor @Sendable (Pick) -> Void = { _ in }
    /// A row of the board's list picked, by a click or an arrow key (`WindowRun.pickInList`).
    var pickInList: @MainActor @Sendable (Pick) -> Void = { _ in }
    var press: @MainActor @Sendable (Card.Button, AskAddress) -> Void = { _, _ in }
    /// A project's ask opened in place, or closed back.
    var toggle: @MainActor @Sendable (AskAddress) -> Void = { _ in }
    /// An item of Status, Notes, Parked or Resolved opened in place, or closed again.
    var toggleItem: @MainActor @Sendable (Item) -> Void = { _ in }
    /// To the session's window: "Open in Ghostty ↗", and a stop's "Answer in Claude ↗".
    var jump: @MainActor @Sendable (JumpPress) -> Void = { _ in }
    /// A card's ask snoozed until the time chosen on its Snooze, or woken by its Wake now.
    var snooze: @MainActor @Sendable (AskAddress, SnoozeChoice) -> Void = { _, _ in }
    var wake: @MainActor @Sendable (AskAddress) -> Void = { _ in }
    /// A sidebar row's asks, as it showed them, snoozed from its menu, or woken from a Snoozed row's.
    var snoozeRow: @MainActor @Sendable (Listed.Row, SnoozeChoice) -> Void = { _, _ in }
    var wakeRow: @MainActor @Sendable (Listed.Row) -> Void = { _ in }
    var askToFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var cancelFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var confirmFinish: @MainActor @Sendable (String) -> Void = { _ in }
    /// The pointer came over the board's list, or left it.
    var pointer: @MainActor @Sendable (Bool) -> Void = { _ in }
    /// A region of the page found the pointer over it, or not, saying so under its own identity (`PagePointer`).
    var pointerOverPage: @MainActor @Sendable (Bool, ObjectIdentifier) -> Void = { _, _ in }
    /// A heading of the sidebar clicked, which folds or unfolds what is under it, or "N earlier", which opens or folds.
    var fold: @MainActor @Sendable (Fold) -> Void = { _ in }
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

/// The right of the window, beside the sidebar: the session or the project picked, or why there is none, on the
/// panel's black, starting under the empty band beside the traffic lights. It draws what it is given, at the time
/// given, so it renders the same on the screen and off it, as the sidebar's `BoardColumn` does. On screen, the pointer
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
        case let .session(session):
            Scrolling { SessionPageView(page: session, now: now).padding(.horizontal, WindowStyle.pageInset) }
                .id(Pick.session(session.id))
        case let .project(project):
            Scrolling { ProjectPageView(page: project, now: now).padding(.horizontal, WindowStyle.pageInset) }
                .id(Pick.project(project.key))
        }
    }
}
