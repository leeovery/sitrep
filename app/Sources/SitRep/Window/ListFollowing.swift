import AppKit
import Observation

/// The list beside the page as the window's model says, in the split's content list: folded away as the page fills
/// the window and shown as a place shows, with the change, as the model takes it, so no moment draws an empty column
/// beside the page; focus on it as a session opened from outside before any board lands on the board come; and focus
/// it held kept off it as it goes, folded away or emptied to its one line, given to the sidebar's list. Whether focus
/// was on the list is read as the model changes, before the views take the change, as a table gone takes focus with
/// it.
@MainActor
final class ListFollowing {
    private let model: WindowModel
    private let list: NSSplitViewItem
    private let focus: SideFocus

    init(model: WindowModel, list: NSSplitViewItem, focus: SideFocus) {
        self.model = model
        self.list = list
        self.focus = focus
        SitRepWindow.fold(list, isFullPage: model.isFullPage)
        model.arrange = { [weak self] isFullPage, landed in
            self?.arrange(isFullPage: isFullPage, landed: landed)
        }
        follow(wasOnTheList: false)
    }

    private func arrange(isFullPage: Bool, landed: Bool) {
        SitRepWindow.fold(list, isFullPage: isFullPage)
        if landed {
            focus.focusList()
        }
    }

    private func follow(wasOnTheList: Bool) {
        if wasOnTheList {
            focus.keepOffTheList()
        }
        withObservationTracking {
            _ = (model.isFullPage, model.showsRows)
        } onChange: { [weak self] in
            MainActor.assumeIsolated {
                let wasOnIt = self?.focus.isOnTheList ?? false

                Task { @MainActor in self?.follow(wasOnTheList: wasOnIt) }
            }
        }
    }
}
