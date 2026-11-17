import Foundation
import SitRepTestSupport
import Testing

/// A test's defaults of its own: read back as set, apart from every other test's, and never on disk.
@Suite(.backstop)
struct MemoryDefaultsTests {
    @Test func whatIsSetIsReadBackAndRemoved() {
        let defaults = MemoryDefaults()

        defaults.set(Data([1, 2]), forKey: "data")
        defaults.set("words", forKey: "string")
        defaults.set(true, forKey: "bool")
        defaults.set(7, forKey: "integer")

        #expect(defaults.data(forKey: "data") == Data([1, 2]))
        #expect(defaults.string(forKey: "string") == "words")
        #expect(defaults.bool(forKey: "bool"))
        #expect(defaults.integer(forKey: "integer") == 7)
        #expect(Set(defaults.dictionaryRepresentation().keys) == ["data", "string", "bool", "integer"])

        defaults.set(nil as String?, forKey: "string")
        defaults.removeObject(forKey: "data")

        #expect(defaults.string(forKey: "string") == nil)
        #expect(defaults.data(forKey: "data") == nil)
    }

    @Test func aPropertyListIsTaken() {
        let defaults = MemoryDefaults()
        let value: [String: Any] = ["words": "words", "number": 7, "data": Data([1]), "list": [true, 2.5]]

        defaults.set(value, forKey: "plist")

        #expect(defaults.dictionary(forKey: "plist") as NSDictionary? == value as NSDictionary)
    }

    @Test func eachIsItsOwn() {
        let one = MemoryDefaults()

        one.set("one", forKey: "key")

        #expect(MemoryDefaults().object(forKey: "key") == nil)
    }

    /// Registered defaults are read under what is set, and the persistent domain calls act on what is held: its own
    /// suite's domain is its values, any other domain its own.
    @Test func registeringAndDomainsAreHeldInMemory() {
        let defaults = MemoryDefaults()
        let elsewhere = defaults.suite + ".elsewhere"

        defaults.register(defaults: ["registered": 1, "string": "registered"])
        defaults.set("words", forKey: "string")

        #expect(defaults.integer(forKey: "registered") == 1)
        #expect(defaults.string(forKey: "string") == "words")

        defaults.setPersistentDomain(["kept": true], forName: defaults.suite)
        defaults.setPersistentDomain(["other": 2], forName: elsewhere)

        #expect(defaults.bool(forKey: "kept") && defaults.string(forKey: "string") == "registered")
        #expect(defaults.persistentDomain(forName: elsewhere)?["other"] as? Int == 2)

        defaults.removePersistentDomain(forName: defaults.suite)
        defaults.removePersistentDomain(forName: elsewhere)

        #expect(defaults.persistentDomain(forName: defaults.suite) == nil)
        #expect(defaults.persistentDomain(forName: elsewhere) == nil)
    }

    /// Nothing set, registered or given as a domain reaches the real suite's domain.
    @Test func nothingReachesTheSuitesDomain() throws {
        let defaults = MemoryDefaults()

        defaults.set("words", forKey: "string")
        defaults.register(defaults: ["registered": 1])
        defaults.setPersistentDomain(["kept": true], forName: defaults.suite)

        let domain = try #require(UserDefaults(suiteName: defaults.suite))

        #expect(domain.persistentDomain(forName: defaults.suite) == nil)
        #expect(domain.object(forKey: "string") == nil && domain.object(forKey: "registered") == nil)
        #expect(domain.object(forKey: "kept") == nil)
    }

    @Test func aChangeIsPostedFromTheDefaultsChanged() {
        let defaults = MemoryDefaults()
        nonisolated(unsafe) var posted = 0
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: nil
        ) { _ in posted += 1 }

        defer { NotificationCenter.default.removeObserver(observer) }
        defaults.set(true, forKey: "bool")
        defaults.removeObject(forKey: "bool")
        MemoryDefaults().set(true, forKey: "bool")

        #expect(posted == 2)
    }
}
