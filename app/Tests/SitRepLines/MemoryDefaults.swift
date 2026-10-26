import Foundation

/// Defaults of a test's own, held in memory, so a test's settings are its alone and nothing is written to disk.
///
/// Proven by experiment on 26 October 2026: `data`, `string`, `bool`, `integer` and `double` read through
/// `object(forKey:)`, and setting a `Data`, a `String`, an optional `String`, a `Bool`, an `Int` or a `Double` goes
/// through `set(_:forKey:)`, so nothing reaches the suite's domain. `register(defaults:)`, which no code here uses,
/// would still reach the process's registration domain.
public final class MemoryDefaults: UserDefaults, @unchecked Sendable {
    /// The domain it stands in for, which nothing is written to.
    public let suite = "com.leeovery.sitrep.tests.\(UUID().uuidString)"
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    public init() {
        super.init(suiteName: suite)!
    }

    override public func object(forKey key: String) -> Any? {
        lock.withLock { values[key] }
    }

    /// Posts `didChangeNotification` from itself, as `UserDefaults` does on a change.
    override public func set(_ value: Any?, forKey key: String) {
        lock.withLock { values[key] = value }
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: self)
    }

    override public func removeObject(forKey key: String) {
        set(nil, forKey: key)
    }

    override public func dictionaryRepresentation() -> [String: Any] {
        lock.withLock { values }
    }
}
