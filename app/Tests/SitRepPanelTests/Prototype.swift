@testable import SitRepPanel

// The panel as its prototypes, meniscus.html and card.html, laid it out when the notch's tests were recorded: their
// seven sample sessions and the CSS's heights.

extension Item {
    private static let minute = 60_000.0, hour = 60 * minute, day = 24 * hour

    /// The prototypes' seven sample sessions, in the order they list them, the hairline under the two that need Lee;
    /// their quiet one is Lee's turn, and the one no window shows an away ask. Their ages are as of the wall clock's 0.
    static let prototype: [Item] = [
        .session(Session(id: "s1", project: "Woodgrove", kind: .needs, title: "Review the report pages, round 1", sub: "Woodgrove · Phase 2 steps 3 to 9", since: -2 * hour)),
        .session(Session(id: "s2", project: "trey", kind: .needs, title: "Allow Bash: ", code: "gh release create v2.3.1", sub: "trey · v2.3.1 follow-ups", since: -4 * minute)),
        .divider,
        .session(Session(id: "s3", project: "Wingtip", kind: .turn, title: "Your turn", sub: "Wingtip · Admin page discussion", since: -20 * minute)),
        .session(Session(id: "s4", project: "Trey Research", kind: .working, title: "Drawing the settings page", sub: "Trey Research · Settings and search", since: -12 * minute)),
        .session(Session(id: "s5", project: "BlueYonder", kind: .working, title: "Running the error totals tests", sub: "BlueYonder · Fix the reversed error totals", since: -3 * minute)),
        .session(Session(id: "s6", project: "Lucerne", kind: .turn, title: "Waiting for the next round of comments", sub: "Lucerne · Close out the remaining questions", since: -3 * hour)),
        // last, past the hairline, where the recordings have it, not where the design's order puts an away ask
        .session(Session(id: "s7", project: "Litware", kind: .needs, away: true, title: "The installer", sub: "Litware · no window shows it", since: -2 * day)),
    ]
}

extension Content {
    /// The prototypes' list as their CSS lays it out: the head's 16 line and the 10 below it; a row, 10 + 34 of text +
    /// 11, and the 4 below it; the divider's 1 between 2 and 6.
    static let css = Content(
        headHeight: 26, entries: Item.prototype.map { Entry($0, height: $0.session == nil ? 9 : 59) }
    )
}
