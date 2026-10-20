import AppKit
import SwiftUI

/// SitRep's icon at 30, its name in the system's semibold and its version: the menu's header, and Settings'.
struct AppHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("SitRep").font(.system(size: 13, weight: .semibold))
                Text(Self.version).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    /// The version `app/build` stamps in the Info.plist, which the plugin shares.
    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).map { "Version \($0)" }
            ?? "Not built with app/build"
    }
}

enum MenuHeader {
    /// The header as a menu item's view, as wide as the menu.
    @MainActor
    static func view() -> NSView {
        let header = AppHeader()
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        let view = NSHostingView(rootView: header)

        view.frame.size = view.fittingSize
        view.autoresizingMask = .width

        return view
    }
}
