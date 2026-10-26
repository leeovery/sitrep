import Foundation
import SitRepLines
import Testing

/// A test's defaults of its own: read back as set, apart from every other test's, and never on disk.
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

    @Test func eachIsItsOwn() {
        let one = MemoryDefaults()

        one.set("one", forKey: "key")

        #expect(MemoryDefaults().object(forKey: "key") == nil)
    }

    @Test func nothingReachesTheSuitesDomain() throws {
        let defaults = MemoryDefaults()

        defaults.set("words", forKey: "string")

        let domain = try #require(UserDefaults(suiteName: defaults.suite))

        #expect(domain.persistentDomain(forName: defaults.suite) == nil)
        #expect(domain.object(forKey: "string") == nil)
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
