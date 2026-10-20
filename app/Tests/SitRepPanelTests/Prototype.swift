@testable import SitRepPanel

// The panel as its prototypes, meniscus.html and card.html, laid it out when the notch's tests were recorded: their
// seven sample sessions and the CSS's heights.

extension Item {
    private static let minute = 60_000.0, hour = 60 * minute, day = 24 * hour

    /// The prototypes' seven sample sessions, in the order they list them, the hairline under the two that need Lee;
    /// their quiet one is Lee's turn, and the one no window shows an away ask. Their ages are as of the wall clock's 0.
    static let prototype: [Item] = [
        .session(Session(id: "s1", project: "Switchboard", kind: .needs, title: "Review Sessions & Runway, round 1", sub: "Switchboard · Milestone 7 stages 4 to 14", since: -2 * hour)),
        .session(Session(id: "s2", project: "agntc", kind: .needs, title: "Allow Bash: ", code: "gh release create v0.5.1", sub: "agntc · v0.5.1 follow-ups", since: -4 * minute)),
        .divider,
        .session(Session(id: "s3", project: "Fumi", kind: .turn, title: "Your turn", sub: "Fumi · Management window discussion", since: -20 * minute)),
        .session(Session(id: "s4", project: "SitRep", kind: .working, title: "Drawing the side panel in Paper", sub: "SitRep · Menu bar and jump to session", since: -12 * minute)),
        .session(Session(id: "s5", project: "DocMan", kind: .working, title: "Running the exception reporting tests", sub: "DocMan · Fix inverted exception reporting", since: -3 * minute)),
        .session(Session(id: "s6", project: "Goosemates", kind: .turn, title: "Waiting for the next round of feedback", sub: "Goosemates · Settle the older open questions", since: -3 * hour)),
        // last, past the hairline, where the recordings have it, not where the design's order puts an away ask
        .session(Session(id: "s7", project: "Kit", kind: .needs, away: true, title: "The bootstrap", sub: "Kit · no window shows it", since: -2 * day)),
    ]
}

extension Content {
    /// The prototypes' list as their CSS lays it out: the head's 16 line and the 10 below it; a row, 10 + 34 of text +
    /// 11, and the 4 below it; the divider's 1 between 2 and 6.
    static let css = Content(
        headHeight: 26, entries: Item.prototype.map { Entry($0, height: $0.session == nil ? 9 : 59) }
    )
}
