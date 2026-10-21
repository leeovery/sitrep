@testable import SitRep
import SitRepWindow
import SwiftUI

/// The SitRep window as a still draws it, its run at this time: the sidebar's stand-in at its width beside the page,
/// and Settings drawn by `settings` where the page is Settings.
@MainActor
func stillWindow<Settings: View>(
    _ run: WindowRun, at now: Date, @ViewBuilder settings: @escaping () -> Settings
) -> some View {
    HStack(spacing: 0) {
        BoardColumn(sidebar: run.sidebar(at: now), spot: run.spot, pick: run.pick, filter: run.filter, now: now)
            .frame(width: WindowStyle.boardWidth)
        PageColumn(page: run.page(at: now), now: now, settings: settings)
    }
    .environment(\.isStill, true)
}

/// The SitRep window as a still draws it, on a page that is not Settings.
@MainActor
func stillWindow(_ run: WindowRun, at now: Date) -> some View {
    stillWindow(run, at: now) { EmptyView() }
}
