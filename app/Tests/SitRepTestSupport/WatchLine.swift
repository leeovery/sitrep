import Foundation

/// A line of `sitrep watch`, typed, as cli/output.ts's `watchLine` prints it: every field always there, a list empty
/// and any other value null where there is none (DESIGN.md, "One engine, two front ends"). Written from the CLI, apart
/// from the app's own reading of it, so a test cannot pass by a mistake the two share. Each part defaults to a
/// placeholder, so a test states only what it is about.
public struct WatchLine: Encodable, Sendable {
    /// How many lines need Lee, away ones among them, and how many sessions the rows hold.
    public struct Head: Encodable, Sendable {
        public var needYou: Int
        public var sessions: Int

        public init(needYou: Int, sessions: Int) {
            self.needYou = needYou
            self.sessions = sessions
        }
    }

    public var at: Int
    /// The CLI's own version.
    @OrNull public var version: String?
    /// Counted from the rows where not given, as core counts it.
    public var head: Head?
    public var rows: [Row]
    public var snoozed: [SnoozedRow]
    public var projects: [Project]
    public var windows: [Window]
    public var new: [String]

    public init(
        at: Int = 1_792_445_574_706, version: String? = "0.1.0", head: Head? = nil, rows: [Row] = [],
        snoozed: [SnoozedRow] = [], projects: [Project] = [], windows: [Window] = [], new: [String] = []
    ) {
        self.at = at
        self.version = version
        self.head = head
        self.rows = rows
        self.snoozed = snoozed
        self.projects = projects
        self.windows = windows
        self.new = new
    }

    /// The line on one line, its keys sorted so the same line is always the same text.
    public var text: String {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try! encoder.encode(self), as: UTF8.self)
    }

    /// The boards of the sessions followed, which no surface of the app reads: always none.
    public func encode(to encoder: any Encoder) throws {
        var line = encoder.container(keyedBy: Key.self)
        let counted = Head(
            needYou: rows.filter { $0.printedSection == .needsYou }.map(\.lines.count).reduce(0, +),
            sessions: rows.count
        )

        try line.encode(3, forKey: .v)
        try line.encode(at, forKey: .at)
        try line.encode(_version, forKey: .version)
        try line.encode(head ?? counted, forKey: .head)
        try line.encode(rows, forKey: .rows)
        try line.encode(snoozed, forKey: .snoozed)
        try line.encode(projects, forKey: .projects)
        try line.encode(windows, forKey: .windows)
        try line.encode(new, forKey: .new)
        try line.encode([String: String](), forKey: .boards)
    }

    private enum Key: String, CodingKey {
        case v, at, version, head, rows, snoozed, projects, windows, new, boards
    }
}

/// A value the CLI prints as null where there is none, never leaving its key out.
@propertyWrapper
public struct OrNull<Value: Encodable & Sendable>: Encodable, Sendable {
    public var wrappedValue: Value?

    public init(wrappedValue: Value?) {
        self.wrappedValue = wrappedValue
    }

    public func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()

        if let wrappedValue {
            try value.encode(wrappedValue)
        } else {
            try value.encodeNil()
        }
    }
}
