import AppKit
import SwiftUI

/// About SitRep (DESIGN, "About SitRep"): a small window of SitRep's own, made as it first opens, which the menu's
/// header opens. Opening it again brings it forward. Its close button or ⌘W shuts it; it neither minimises nor
/// zooms, and has nothing to change.
@MainActor
final class AboutWindow {
    private lazy var window = Self.window(NSHostingController(rootView: AboutView()))

    func show() {
        window.comeForward()
    }

    /// The window: titled, so it has the system's frame and close button, but showing no title; closable alone, so the
    /// main menu's ⌘W reaches it (`AppMenu`); sized by what it shows; on the Space Lee is on whenever it opens, and
    /// otherwise on its own (`ForwardWindow`).
    static func window(_ content: NSViewController) -> ForwardWindow {
        let window = ForwardWindow(contentViewController: content)

        window.title = "About SitRep"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setContentSize(content.view.fittingSize)
        window.center()
        return window
    }
}

/// What About SitRep shows, centred down a column 308 wide under the traffic lights: the icon at 112, the name and
/// the version, then what SitRep is and who made it.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: AppIcon.about)
                .frame(width: 112, height: 112)
                .padding(.vertical, 18)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("SitRep").font(.system(size: 20, weight: .bold)).spacing(-0.01, of: 20)
                Text(AppHeader.version).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                Text("The board for your Claude Code sessions").font(.system(size: 13))
                Text("Made by Lee Overy").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 18)
        }
        .padding(.top, Self.lights)
        .padding(.bottom, 30)
        .padding(.horizontal, 14)
        .frame(width: 308)
        .ignoresSafeArea()
    }

    /// The traffic lights' row, 16 tall, 14 down from the window's top: the column starts under it.
    private static let lights: CGFloat = 14 + 16
}
