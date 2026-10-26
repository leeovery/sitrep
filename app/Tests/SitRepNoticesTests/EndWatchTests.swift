import AppKit
import SitRepRelay
import Testing

/// The watch on a real running app, the Dock, as SitRep and the helper get one, by its pid: a fresh instance, owned
/// by nothing but the watch once its autorelease pool drains. Under `swift test` this process is no app LaunchServices
/// knows, so it has none of its own. An app freed while observed crashed SitRep and the helper as they started (26
/// October 2026); here it crashes the test run. Only `isTerminated` is read: nothing is asked of the Dock.
@MainActor
struct EndWatchTests {
    /// A fresh instance of the Dock's app, which nothing else holds.
    private static func ownApp() throws -> NSRunningApplication {
        let listed = try #require(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first)
        let fresh = try #require(NSRunningApplication(processIdentifier: listed.processIdentifier))

        try #require(fresh !== listed)

        return fresh
    }

    @Test func itHoldsTheAppItWatchesOnceItsPoolDrains() throws {
        var watch: EndWatch?

        try autoreleasepool {
            watch = EndWatch(try Self.ownApp()) {}
        }

        #expect(watch != nil)
    }

    /// Dropped, it stops observing before it lets the app go.
    @Test func itIsDroppedSafely() throws {
        var watch: EndWatch?

        try autoreleasepool {
            watch = EndWatch(try Self.ownApp()) {}
        }
        autoreleasepool {
            watch = nil
        }

        #expect(watch == nil)
    }

    /// As SitRep's watch on its helper is replaced once a helper ends and another is started.
    @Test func itIsReplacedSafely() throws {
        var watch: EndWatch?

        try autoreleasepool {
            watch = EndWatch(try Self.ownApp()) {}
        }
        try autoreleasepool {
            watch = EndWatch(try Self.ownApp()) {}
        }

        #expect(watch != nil)
    }

    /// The process running, its end is not told.
    @Test func aRunningAppIsNotToldEnded() async throws {
        let told = Told()
        let watch = EndWatch(try Self.ownApp()) { told.isEnded = true }

        await Task.yield()

        #expect(!told.isEnded)
        withExtendedLifetime(watch) {}
    }

    @MainActor
    final class Told {
        var isEnded = false
    }
}
