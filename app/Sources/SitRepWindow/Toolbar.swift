import SitRepCore

/// The window's toolbar as the run has it: the window's title, Back and Forward, each with a step to go to or not; and
/// on a place, over the page, where the pick stands in the list, "1 / 5", with up and down, each with a row to step to
/// or not. On a place the title is the place's, shown over its list; on a project's page and a session's, which fill
/// the window and have Back and Forward alone, it is the page's, not shown, but naming the window to Mission Control,
/// App Exposé and VoiceOver, as Finder's folder does.
public struct Toolbar: Equatable, Sendable {
    /// What the toolbar has of a place's list.
    public struct Listing: Equatable, Sendable {
        /// None while the list shows nothing picked: nothing picked yet, or a pick it no longer shows, as an ask
        /// answered, up and down then going on from where the pick stood.
        public var position: PlaceList.Position?
        public var canStepUp: Bool
        public var canStepDown: Bool

        public init(position: PlaceList.Position? = nil, canStepUp: Bool = false, canStepDown: Bool = false) {
            self.position = position
            self.canStepUp = canStepUp
            self.canStepDown = canStepDown
        }
    }

    public var title: String
    public var canGoBack: Bool
    public var canGoForward: Bool
    /// None for a page that fills the window.
    public var listing: Listing?

    /// The title shows only over a place's list.
    public var showsTitle: Bool { listing != nil }

    /// Before anything is heard: Needs you, nothing picked, nowhere to go.
    public init(
        title: String = Place.needsYou.title, canGoBack: Bool = false, canGoForward: Bool = false,
        listing: Listing? = Listing()
    ) {
        self.title = title
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.listing = listing
    }

    /// The window's own name, where a page it fills is not on the board.
    static let untitled = "SitRep"
}

extension WindowRun {
    /// The toolbar as the window now stands: Back and Forward from its history; on a place, its list as it shows, held,
    /// filtered and folded, its position and up and down as ↑ and ↓ step it (`step(down:at:)`).
    public var toolbar: Toolbar {
        Toolbar(
            title: title, canGoBack: canGoBack, canGoForward: canGoForward, listing: location.place.map(listing(of:))
        )
    }

    /// The place's name; a project's page its project's; a session's page its session's.
    private var title: String {
        switch location {
        case let .place(place, _, _): place.title
        case let .project(key): last.board?.projects.first { $0.key == key }?.name ?? Toolbar.untitled
        case let .session(id, _): last.board?.session(id)?.session.name ?? Toolbar.untitled
        }
    }

    private func listing(of place: Place) -> Toolbar.Listing {
        let list = arranged(place)
        let picked = location.picked

        return Toolbar.Listing(
            position: list.position(of: picked?.pick), canStepUp: list.step(from: picked, down: false) != nil,
            canStepDown: list.step(from: picked, down: true) != nil
        )
    }
}
