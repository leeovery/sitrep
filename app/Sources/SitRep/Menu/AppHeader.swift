import AppKit
import SwiftUI

/// SitRep's icon at 30, its name in the system's semibold and its version: the menu's header, and Settings'.
struct AppHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: Self.icon).frame(width: Self.iconSize, height: Self.iconSize)
            VStack(alignment: .leading, spacing: 1) {
                Text("SitRep").font(.system(size: 13, weight: .semibold))
                Text(Self.version).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    static let iconSize: CGFloat = 30

    /// The app's icon as macOS renders it for the bundle, masked and drawn at the header's size, not the Info.plist's
    /// largest picture scaled down, whose edge showed a dark fringe at 30.
    @MainActor
    static let icon: NSImage = {
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

        icon.size = NSSize(width: iconSize, height: iconSize)
        return icon
    }()

    /// The version `app/build` stamps in the Info.plist, which the plugin shares.
    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).map { "Version \($0)" }
            ?? "Not built with app/build"
    }
}

enum MenuHeader {
    /// The header as a menu item's view, at its own width. A view that stretches to the menu keeps the width it was
    /// stretched to, and the menu is never narrower than its views, so a stretched header held the menu as wide as
    /// its widest row ever was.
    @MainActor
    static func view() -> NSView {
        let header = AppHeader()
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        let view = NSHostingView(rootView: header)

        view.frame.size = view.fittingSize
        return view
    }
}
