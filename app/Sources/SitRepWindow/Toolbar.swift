/// The window's toolbar as the run has it: Back and Forward, each with a step to go to or not; and on a place, over its
/// list, the place's title, and over the page where the pick stands in the list, "1 / 5", with up and down, each with a
/// row to step to or not. A project's page and a session's, which fill the window, have Back and Forward alone.
public struct Toolbar: Equatable, Sendable {
    /// What the toolbar has of a place's list.
    public struct Listing: Equatable, Sendable {
        public var title: String
        /// None while the list shows nothing picked: nothing picked yet, or a pick it no longer shows, as an ask
        /// answered, up and down then going on from where the pick stood.
        public var position: PlaceList.Position?
        public var canStepUp: Bool
        public var canStepDown: Bool

        public init(
            title: String, position: PlaceList.Position? = nil, canStepUp: Bool = false, canStepDown: Bool = false
        ) {
            self.title = title
            self.position = position
            self.canStepUp = canStepUp
            self.canStepDown = canStepDown
        }
    }

    public var canGoBack: Bool
    public var canGoForward: Bool
    /// None for a page that fills the window.
    public var listing: Listing?

    /// Before anything is heard: Needs you, nothing picked, nowhere to go.
    public init(
        canGoBack: Bool = false, canGoForward: Bool = false, listing: Listing? = Listing(title: Place.needsYou.title)
    ) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.listing = listing
    }
}

extension WindowRun {
    /// The toolbar as the window now stands: Back and Forward from its history; on a place, its list as it shows, held,
    /// filtered and folded, its position and up and down as ↑ and ↓ step it (`step(down:at:)`).
    public var toolbar: Toolbar {
        Toolbar(canGoBack: canGoBack, canGoForward: canGoForward, listing: location.place.map(listing(of:)))
    }

    private func listing(of place: Place) -> Toolbar.Listing {
        let list = arranged(place)
        let picked = location.picked

        return Toolbar.Listing(
            title: place.title, position: list.position(of: picked?.pick),
            canStepUp: list.step(from: picked, down: false) != nil,
            canStepDown: list.step(from: picked, down: true) != nil
        )
    }
}
