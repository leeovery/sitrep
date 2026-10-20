import SitRepCore
import SitRepWindow
import SwiftUI

/// What a press in the window asks for, each handed to the model.
struct WindowActions: Sendable {
    var pick: @MainActor @Sendable (Pick) -> Void = { _ in }
    var press: @MainActor @Sendable (Card.Button, AskAddress) -> Void = { _, _ in }
    /// A project's ask opened in place, or closed back.
    var toggle: @MainActor @Sendable (AskAddress) -> Void = { _ in }
    /// To the session's window: "Open in Ghostty ↗", and a stop's "Answer in Claude ↗".
    var jump: @MainActor @Sendable (String) -> Void = { _ in }
    var askToFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var cancelFinish: @MainActor @Sendable (String) -> Void = { _ in }
    var confirmFinish: @MainActor @Sendable (String) -> Void = { _ in }
    /// The pointer came over the board's list, or left it.
    var pointer: @MainActor @Sendable (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    @Entry var windowActions = WindowActions()
    /// A jump runs: nothing jumps until it answers.
    @Entry var isJumping = false
}

/// The window's two columns, all of it the panel's black: the board down the left, and what Lee picked on the right.
/// It draws what it is given, at the time given, so it renders the same on the screen and off it.
struct WindowContent: View {
    let listed: Listed
    let page: Page
    let pick: Pick?
    let now: Date

    var body: some View {
        HStack(spacing: 0) {
            BoardColumn(listed: listed, pick: pick, now: now)
                .frame(width: WindowStyle.boardWidth)
            Rectangle().fill(WindowStyle.line).frame(width: 1)
            PageColumn(page: page, now: now)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(WindowStyle.black)
        .environment(\.colorScheme, .dark)
    }
}

/// The right of the window: the session or the project picked, or why there is neither.
struct PageColumn: View {
    let page: Page
    let now: Date

    var body: some View {
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
