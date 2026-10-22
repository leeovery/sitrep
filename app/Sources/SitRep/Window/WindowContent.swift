import SitRepCore
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
    var askToFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var cancelFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var confirmFinish: @MainActor @Sendable (String) -> Void = { _ in }
    /// The pointer came over the board's list, or left it.
    var pointer: @MainActor @Sendable (Bool) -> Void = { _ in }
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
}

/// The right of the window, beside the sidebar: the session or the project picked, Settings, or why there is none, on
/// the panel's black, starting under the empty band beside the traffic lights. It draws what it is given, at the time
/// given, so it renders the same on the screen and off it, as the sidebar's `BoardColumn` does; Settings, by
/// `settings`, which reads what it shows for itself.
struct PageColumn<Settings: View>: View {
    let page: Page
    let now: Date
    @ViewBuilder let settings: () -> Settings

    var body: some View {
        pages
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        case .settings:
            Scrolling { settings().padding(.horizontal, WindowStyle.pageInset) }
                .id(Pick.settings)
        }
    }
}

extension PageColumn where Settings == EmptyView {
    /// The page with no Settings to draw.
    init(page: Page, now: Date) {
        self.init(page: page, now: now) { EmptyView() }
    }
}
