@testable import SitRep
import SitRepWindow
import SwiftUI

/// The SitRep window as a still draws it, its run at this time: the sidebar's stand-in at its width, the list's beside
/// it where the window is on a place, then the page.
@MainActor
func stillWindow(_ run: WindowRun, at now: Date) -> some View {
    HStack(spacing: 0) {
        SidebarColumn(places: run.places, root: run.location.root, filter: run.filter)
            .frame(width: WindowStyle.boardWidth)
        if let list = run.list(at: now) {
            ListColumn(list: list, picked: run.location.picked?.pick, head: run.head, filter: run.filter, now: now)
                .frame(width: WindowStyle.listWidth)
                .overlay(alignment: .trailing) { Rectangle().fill(WindowStyle.line).frame(width: 1) }
        }
        PageColumn(page: run.page(at: now), now: now)
    }
    .environment(\.isStill, true)
}
