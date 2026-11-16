import Foundation

/// Defaults of a test's own, held in memory, so a test's settings are its alone and nothing is written to disk.
///
/// Proven by experiment on 26 October 2026: the typed getters read through `object(forKey:)` and the typed setters go
/// through `set(_:forKey:)`, so nothing reaches the suite's domain. `register(defaults:)`, the persistent and volatile
/// domain calls, `addSuite` and `synchronize` are not overridden and would reach the real suite or the registration
/// domain; nothing here calls them.
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

    /// Posts `didChangeNotification` from itself, as `UserDefaults` does on a change, and traps on a value that is no
    /// property list, as `UserDefaults` raises on one.
    override public func set(_ value: Any?, forKey key: String) {
        if let value {
            precondition(PropertyListSerialization.propertyList(value, isValidFor: .binary), "\(key) is no property list")
        }
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
