import Foundation
import os
import SitRepCore
import SitRepPanel

/// A value Lee sets, kept whole under a key of its own in the app's defaults, and read leniently: its type's decoding
/// keeps what it can of a value another version saved, so only something that is not JSON at all is the defaults.
public protocol SavedValue: Codable, Equatable, Sendable {
    /// Its key in the app's defaults.
    static var key: String { get }
    /// The defaults.
    init()
}

/// One saved value: JSON, under its type's key.
public struct SavedSettings<Value: SavedValue> {
    public static var key: String { Value.key }

    private let defaults: UserDefaults
    private let logger = Logger(sitrep: "settings")

    public init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func read() -> Value {
        guard let saved = defaults.data(forKey: Self.key) else {
            return Value()
        }

        do {
            return try JSONDecoder().decode(Value.self, from: saved)
        } catch {
            logger.error("The \(Self.key, privacy: .public) settings are not JSON, so the defaults stand: \(error, privacy: .public)")

            return Value()
        }
    }

    public func save(_ value: Value) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: Self.key)
        } catch {
            logger.error("The \(Self.key, privacy: .public) settings were not saved: \(error, privacy: .public)")
        }
    }
}

/// What Lee sets for the edge (`EdgeSettings`), as one value.
public typealias SavedEdgeSettings = SavedSettings<EdgeSettings>

extension EdgeSettings: SavedValue {
    public static let key = "edge"
}

/// The card's sections Lee folded, kept across opens and launches as one value of its own under the key "card". "N
/// earlier" open is not kept: it is folded each time the card comes out.
public struct CardSettings: SavedValue {
    public static let key = "card"

    public var folded: Set<BoardSection> = []

    public init() {}

    public init(folded: Set<BoardSection>) {
        self.folded = folded
    }

    public init(from decoder: any Decoder) {
        let defaults = CardSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        folded = given.value(.folded, or: defaults.folded)
    }
}
