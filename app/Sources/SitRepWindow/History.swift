/// Where the window has been, for Back and Forward (⌘[ and ⌘]), from when it opens; not kept across launches. Going
/// somewhere pushes the location, letting go of what lay forward; a change of what the list has picked replaces it.
public struct History: Equatable, Sendable {
    /// How Lee went somewhere.
    public enum Way: CaseIterable, Sendable {
        /// A place's or a project's row in the sidebar.
        case sidebar
        /// A session's row on a project's page.
        case projectSession
        /// A link in a page's breadcrumb.
        case breadcrumb
        /// A session's "later · N parked".
        case sessionParked
        /// A project's "N parked".
        case projectParked
        /// A parked item's "Back to its session".
        case backToSession
        /// "Open in SitRep" from the card or the menu.
        case outside
        /// Another row picked within the middle list, by a click, an arrow key or the toolbar's up or down.
        case list

        /// It makes a step Back returns from, rather than changing the step the window is on.
        public var pushes: Bool { self != .list }
    }

    public private(set) var location: Location
    private var back: [Location] = []
    private var forward: [Location] = []

    public init(_ location: Location) {
        self.location = location
    }

    public var canGoBack: Bool { !back.isEmpty }
    public var canGoForward: Bool { !forward.isEmpty }

    /// To the location, the way given: pushed, unless it is where the window already is; or replacing where it is.
    public mutating func go(to location: Location, by way: Way) {
        guard way.pushes else {
            replace(with: location)
            return
        }
        guard location != self.location else {
            return
        }

        back.append(self.location)
        forward = []
        self.location = location
    }

    /// Where the window is, changed with no step to go back from: as the list picks another row, or as the board
    /// leaves the window somewhere else (`Location.kept(on:)`). Where that is the step before, the step goes, so
    /// Back never stays where it is.
    public mutating func replace(with location: Location) {
        if back.last == location {
            back.removeLast()
        }
        self.location = location
    }

    /// Back a step, where there is one.
    public mutating func goBack() {
        if let last = back.popLast() {
            forward.append(location)
            location = last
        }
    }

    /// Forward a step, where Back left one.
    public mutating func goForward() {
        if let next = forward.popLast() {
            back.append(location)
            location = next
        }
    }
}
