/// A session on the panel: one of the prototype's sample sessions, for now.
public struct Session: Equatable, Sendable {
    /// Where it stands, in the order the panel lists them (the prototype's `ORDER`).
    public enum Kind: Int, Comparable, Sendable {
        case needs, turn, working, quiet, off

        public static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }

    public let id: String
    public let kind: Kind
    public let title: String
    /// Set in code type after the title, as in an ask to allow a command.
    public let code: String?
    public let sub: String
    /// How long ago it came to stand where it does, in ms.
    public let age: Double

    /// A click on it jumps to it, unless no window shows it.
    public var jumps: Bool { kind != .off }

    private static let minute = 60_000.0, hour = 60 * minute, day = 24 * hour

    /// The prototype's seven sample sessions, in the order it lists them.
    static let samples = [
        Session(id: "s1", kind: .needs, title: "Review Sessions & Runway, round 1", code: nil, sub: "Switchboard · Milestone 7 stages 4 to 14", age: 2 * hour),
        Session(id: "s2", kind: .needs, title: "Allow Bash: ", code: "gh release create v0.5.1", sub: "agntc · v0.5.1 follow-ups", age: 4 * minute),
        Session(id: "s3", kind: .turn, title: "Your turn", code: nil, sub: "Fumi · Management window discussion", age: 20 * minute),
        Session(id: "s4", kind: .working, title: "Drawing the side panel in Paper", code: nil, sub: "SitRep · Menu bar and jump to session", age: 12 * minute),
        Session(id: "s5", kind: .working, title: "Running the exception reporting tests", code: nil, sub: "DocMan · Fix inverted exception reporting", age: 3 * minute),
        Session(id: "s6", kind: .quiet, title: "Waiting for the next round of feedback", code: nil, sub: "Goosemates · Settle the older open questions", age: 3 * hour),
        Session(id: "s7", kind: .off, title: "The bootstrap", code: nil, sub: "Kit · no window shows it", age: 2 * day),
    ]
}

/// One item in the panel's list, below its head: a session's row, or the rule between what needs Lee and the rest.
public enum Item: Equatable, Sendable {
    case session(Session)
    case divider

    /// The prototype's sample sessions as its list shows them: by kind, needing Lee the oldest first, the divider
    /// after what needs Lee, and otherwise as given (its `cmpItems`).
    public static let samples: [Item] = {
        let sessions = Session.samples
        var items = sessions.map(Item.session)
        if sessions.contains(where: { $0.kind == .needs }), sessions.contains(where: { $0.kind != .needs }) {
            items.append(.divider)
        }
        return items.enumerated().sorted { a, b in
            if a.element.order != b.element.order {
                return a.element.order < b.element.order
            }
            if case let .session(x) = a.element, case let .session(y) = b.element, x.kind == .needs, y.kind == .needs, x.age != y.age {
                return x.age > y.age
            }
            return a.offset < b.offset
        }.map(\.element)
    }()

    /// Its place in `ORDER`: the divider sits between needs and turn.
    private var order: Double {
        switch self {
        case let .session(session): Double(session.kind.rawValue)
        case .divider: 0.5
        }
    }

    /// Its height as the prototype's CSS lays it out: a row (10 + 34 of text + 11) and the 4 below it, or the
    /// divider's 1 between 2 and 6.
    public var cssHeight: Double {
        switch self {
        case .session: 59
        case .divider: 9
        }
    }
}

/// The panel's content, as the view lays it out: the height of the head and of each item, in `Item.samples`'
/// order. The scroll's padding is the prototype's, above the head and below the last item.
public struct Content: Equatable, Sendable {
    public var headHeight: Double
    public var itemHeights: [Double]

    public init(headHeight: Double, itemHeights: [Double]) {
        self.headHeight = headHeight
        self.itemHeights = itemHeights
    }

    /// As the prototype's CSS lays it out: the head's 16 line and the 10 below it, and each item's `cssHeight`.
    public static let css = Content(headHeight: 26, itemHeights: Item.samples.map(\.cssHeight))

    static let paddingTop = 18.0, paddingBottom = 14.0

    /// The whole of it, padding and all, before the panel's height caps it.
    var height: Double { Self.paddingTop + headHeight + itemHeights.reduce(0, +) + Self.paddingBottom }
}
