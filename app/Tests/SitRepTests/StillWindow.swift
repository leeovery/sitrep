@testable import SitRep
import SitRepWindow
import SwiftUI

/// The SitRep window as a still draws it, its run at this time: the sidebar's stand-in at its width beside the page.
@MainActor
func stillWindow(_ run: WindowRun, at now: Date) -> some View {
    HStack(spacing: 0) {
        BoardColumn(sidebar: run.sidebar(at: now), pick: run.pick, filter: run.filter, now: now)
            .frame(width: WindowStyle.boardWidth)
        PageColumn(page: run.page(at: now), now: now)
    }
    .environment(\.isStill, true)
}
