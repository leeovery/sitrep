import Foundation

extension Words {
    /// When an item was parked, in whole words, under its title: "Parked just now", "Parked 3 hours ago".
    public static func parkedAgo(_ at: Date, at now: Date) -> String {
        "Parked \(Spoken.ago(at, at: now))"
    }

    /// The headings of a parked item's page.
    public static let parkedFrom = "Parked from"
    public static let sinceParked = "Since it was parked"
    /// Under the lines since an item was parked where its session's board carries no line from before it.
    public static let sinceCut = "Only its newest lines show."
    /// A parked item's way to the page of the session it was parked from.
    public static let backToSession = "Back to its session"
}

extension Spoken {
    /// A row of Parked's list, one element: its title, its project, its session and how long ago it was parked, as
    /// "Retry failed uploads, Northwind, Ledger export, 3 hours".
    static func parked(_ item: Listed.Parked, at now: Date) -> String {
        [item.item.title, item.projectName, item.sessionName, age(item.item.at, at: now)].joined(separator: ", ")
    }

    /// A project's heading in Parked's list: its name and how many of its items show, as "Northwind, 2 items".
    public static func heading(_ heading: PlaceList.Heading) -> String {
        "\(heading.name), \(Words.count(heading.count, "item"))"
    }

    /// The session a parked item was parked from, as its card under "Parked from" says it: its name, what its mark
    /// means, its now line and its asks waiting, as "Ledger export, away, Mapping the ledger columns, 2 asks".
    public static func parkedFrom(_ from: ParkedPage.From) -> String {
        ([from.name, mark(from.mark)] + from.parts).joined(separator: ", ")
    }
}
