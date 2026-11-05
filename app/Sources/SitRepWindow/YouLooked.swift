import Foundation
import SitRepEdge
import SitRepPanel

/// When Lee last looked at each session, by its id: the time its page, beside a place's list or filling the window,
/// last stopped showing, kept across launches as one value of its own under "windowLooked", and only for the sessions
/// on the board. Written only as the page stops showing, so it holds still while he reads it, and what comes meanwhile
/// stands newer than it.
public struct LastLooked: SavedValue {
    public static let key = "windowLooked"

    /// When each session's page last stopped showing.
    public private(set) var sessions: [String: Date] = [:]

    public init() {}

    public init(_ sessions: [String: Date]) {
        self.sessions = sessions
    }

    /// Read leniently: a value another version saved that is not a map of times is none looked at.
    public init(from decoder: any Decoder) {
        sessions = (try? decoder.container(keyedBy: CodingKeys.self))?.value(.sessions, or: [:]) ?? [:]
    }

    /// As these defaults keep it.
    public static func read(_ defaults: UserDefaults) -> LastLooked {
        SavedSettings<LastLooked>(defaults).read()
    }

    /// Saved in these defaults.
    public func save(in defaults: UserDefaults) {
        SavedSettings<LastLooked>(defaults).save(self)
    }

    /// When Lee last looked at the session; none where he never has.
    public subscript(session: String) -> Date? {
        sessions[session]
    }

    /// The session's page stopped showing at this time.
    mutating func stopped(showing session: String, at time: Date) {
        sessions[session] = time
    }

    /// Only these sessions kept: those on the board.
    mutating func keep(only kept: Set<String>) {
        sessions = sessions.filter { kept.contains($0.key) }
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
    }
}

/// Where Lee last looked at a session, on a thread of its entries, the newest first, as What happened and Since it was
/// parked draw it: above the newest entry from at or before the look, the entries from there on drawn dimmer. Only
/// with entries on both sides of it: with none newer nothing came since, and with none from before nothing he saw
/// shows, so neither draws it nor dims anything.
public struct YouLooked: Equatable, Sendable {
    /// When he looked.
    public let at: Date
    /// How many entries stand above it, newer than the look.
    public let newer: Int

    /// On a thread of entries at these times, the newest first, a look at this time, where there was one.
    init?(_ looked: Date?, over times: [Date]) {
        guard let looked, let first = times.firstIndex(where: { $0 <= looked }), first > 0 else {
            return nil
        }

        at = looked
        newer = first
    }

    /// The entry at this place on the thread is from at or before the look: drawn dimmer.
    public func isOlder(_ place: Int) -> Bool {
        place >= newer
    }
}

extension Words {
    /// The divider where Lee last looked: "You looked 2h ago", "You looked just now".
    public static func youLooked(_ at: Date, at now: Date) -> String {
        "You looked \(ago(at, at: now))"
    }
}

extension Spoken {
    /// The divider where Lee last looked, in whole words: "You looked 2 hours ago".
    public static func youLooked(_ at: Date, at now: Date) -> String {
        "You looked \(ago(at, at: now))"
    }
}
