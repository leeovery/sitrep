/// Where the window has been, for Back and Forward (⌘[ and ⌘]), from when it opens; not kept across launches. Going
/// somewhere pushes the location, letting go of what lay forward; a change of what the list has picked replaces it.
/// It keeps where the list's pick stands as the list shows, so ↑ and ↓ go on from there, and Back returns to it as it
/// was.
public struct History: Equatable, Sendable {
    /// How Lee went somewhere, each making a step Back returns from.
    public enum Way: CaseIterable, Sendable {
        /// A place's or a project's row in the sidebar.
        case sidebar
        /// A session's row on a project's page.
        case projectSession
        /// A link in a page's breadcrumb.
        case breadcrumb
        /// A session's "later N parked".
        case sessionParked
        /// A project's "N parked".
        case projectParked
        /// A parked item's "Back to its session".
        case backToSession
        /// "Open in SitRep" from the card or the menu.
        case outside
    }

    public private(set) var location: Location
    private var back: [Location] = []
    private var forward: [Location] = []
    /// It opened on a board: until then, where it opened was where it was left, and the first board heard opens it
    /// as the board says, unless Lee went somewhere first.
    private var isOpenedOnABoard: Bool

    /// At the location, on a board already heard.
    public init(_ location: Location) {
        self.location = location
        isOpenedOnABoard = true
    }

    /// The window opening on this board, where it was left as given (`Location.opening(on:remembered:)`); with no
    /// board heard yet, it opens as the first board says.
    public init(opening listed: Listed, remembered: Location?) {
        location = Location.opening(on: listed, remembered: remembered)
        isOpenedOnABoard = listed.hasBoard
    }

    public var canGoBack: Bool { !back.isEmpty }
    public var canGoForward: Bool { !forward.isEmpty }

    /// To the location, the way given: pushed, unless it is where the window already is.
    public mutating func go(to location: Location, by _: Way) {
        guard location != self.location else {
            return
        }

        back.append(self.location)
        forward = []
        self.location = location
    }

    /// Where an open of a session from outside lands, as Lee would go there himself: a session's page pushed over its
    /// project's is two steps, the project's page and then the session's, so Back goes to the project's page; but
    /// where the window is on that page, or on the session's already, no step is made for it, as going where the
    /// window is makes none. Whether it landed: a landing awaiting a board is tried again once one is heard.
    @discardableResult
    public mutating func land(_ landing: Landing) -> Bool {
        guard case let .location(location) = landing else {
            return false
        }

        if case let .session(_, root) = location, self.location != location {
            go(to: root.location, by: .outside)
        }
        go(to: location, by: .outside)
        return true
    }

    /// Where an open of a session from outside lands, the window opening afresh onto it: there, with no step back to
    /// where the window would have opened, which Lee never saw; but a session's page is pushed over its project's, as
    /// `land(_:)` pushes it, so Back goes to the project's page. Whether it landed.
    @discardableResult
    public mutating func open(onto landing: Landing) -> Bool {
        guard case let .location(location) = landing else {
            return false
        }

        back = []
        forward = []
        isOpenedOnABoard = true
        if case let .session(_, root) = location {
            self.location = root.location
            go(to: location, by: .outside)
        } else {
            self.location = location
        }
        return true
    }

    /// Another row picked within the list, or none, by a click, an arrow key or the toolbar's up or down: the step
    /// the window is on changes, and no step is made. A page with no list has nothing to pick.
    public mutating func pick(_ selection: Selection?) {
        if location.place != nil {
            replace(with: location.picking(selection))
        }
    }

    /// The list as it now shows, held and filtered: where it shows the pick, the pick stands there, the location
    /// otherwise as it is.
    public mutating func stand(in list: PlaceList) {
        if location.place == list.place {
            location = location.standing(in: list)
        }
    }

    /// The board changed, or a list's order with it: where the window is, and every step back and forward, as each
    /// stands on it (`Location.kept(on:)`). A step that no longer stands goes, as does one that comes to be the step
    /// beside it or where the window is. Where the window is no longer stands, it opens afresh, on Needs you's first
    /// row as it shows. The first board heard after an open with none opens the window as that board says, unless Lee
    /// went somewhere first. Then the pick stands where its list, as given for each place, shows it.
    public mutating func keep(on listed: Listed, arranged: (Place) -> PlaceList) {
        guard listed.hasBoard else {
            return
        }

        let needsYou = arranged(.needsYou)

        if !isOpenedOnABoard, back.isEmpty, forward.isEmpty {
            location = Location.opening(on: listed, remembered: location, needsYou: needsYou)
        }
        isOpenedOnABoard = true
        location = location.kept(on: listed) ?? Location.opening(on: listed, remembered: nil, needsYou: needsYou)
        if let place = location.place {
            stand(in: arranged(place))
        }
        back = Self.collapsed(back.compactMap { $0.kept(on: listed) }, toward: location)
        forward = Self.collapsed(forward.compactMap { $0.kept(on: listed) }, toward: location)
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

    /// Where the window is, changed with no step to go back from. Where that is the step before, or the step after,
    /// that step goes, so neither Back nor Forward stays where it is.
    private mutating func replace(with location: Location) {
        self.location = location
        back = Self.collapsed(back, toward: location)
        forward = Self.collapsed(forward, toward: location)
    }

    /// The steps of a stack, its nearest to where the window is last, with none the same as the one beside it, nor
    /// at its end the same as where the window is.
    private static func collapsed(_ steps: [Location], toward location: Location) -> [Location] {
        var collapsed = steps.reduce(into: [Location]()) { kept, step in
            if kept.last != step {
                kept.append(step)
            }
        }

        while collapsed.last == location {
            collapsed.removeLast()
        }
        return collapsed
    }
}
