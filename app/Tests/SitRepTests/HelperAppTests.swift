import Foundation
@testable import SitRep
import Testing

/// The notices helper as an app, over a macOS of its own: nothing is started or watched for real.
@MainActor
struct HelperAppTests {
    private struct Refused: Error {}

    /// What macOS was asked: each open held until the test answers it, and each watch's end, told by the test.
    @MainActor
    final class Mac {
        var running: Int32?
        var opens = 0
        var opening: CheckedContinuation<Int32, Error>?
        var ends: [Int32: @MainActor () -> Void] = [:]

        func helperMac() -> HelperMac {
            HelperMac(
                running: { self.running },
                open: {
                    self.opens += 1

                    return try await withCheckedThrowingContinuation { self.opening = $0 }
                },
                watch: { pid, ended in
                    self.ends[pid] = ended

                    return NSObject()
                },
                isRunning: { _ in true }
            )
        }

        /// The open under way answered with this helper.
        func opened(_ pid: Int32) async {
            while opening == nil {
                await Task.yield()
            }
            opening?.resume(returning: pid)
            opening = nil
        }
    }

    @MainActor
    final class Ends {
        var told: [HelperApp.End] = []
    }

    private let mac = Mac()
    private let ends = Ends()

    private func helperApp() -> HelperApp {
        let app = HelperApp(mac.helperMac())

        app.ended = { [ends] in ends.told.append($0) }

        return app
    }

    private func watching(_ app: HelperApp, _ pid: Int32) async {
        app.open()
        await mac.opened(pid)
        while app.watched != pid {
            await Task.yield()
        }
    }

    private static func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    @Test func itOpensOnceWhileAnOpenIsUnderWay() async {
        let app = helperApp()

        app.open()
        app.open()
        await Self.settle()

        #expect(mac.opens == 1)
    }

    @Test func itOpensNothingWhileOneIsWatched() async {
        let app = helperApp()

        await watching(app, 5150)
        app.open()
        await Self.settle()

        #expect(mac.opens == 1)
    }

    @Test func anOpenThatFailsLetsTheNextOpen() async {
        let app = helperApp()

        app.open()
        await Self.settle()
        mac.opening?.resume(throwing: Refused())
        mac.opening = nil
        await Self.settle()
        app.open()
        await Self.settle()

        #expect(mac.opens == 2)
        #expect(app.watched == nil)
    }

    @Test func theEndOfTheOneWatchedIsToldAndTheNextMayOpen() async {
        let app = helperApp()

        await watching(app, 5150)
        mac.ends[5150]?()

        #expect(ends.told == [HelperApp.End(pid: 5150, wasRunning: false)])
        #expect(app.watched == nil)

        app.open()
        await Self.settle()

        #expect(mac.opens == 2)
    }

    /// An end told late, of a helper watched before, says nothing of the one watched now.
    @Test func aStaleEndAfterAnotherIsWatchedIsPassedOver() async {
        let app = helperApp()

        await watching(app, 5150)
        mac.ends[5150]?()
        await watching(app, 5151)
        mac.ends[5150]?()

        #expect(ends.told == [HelperApp.End(pid: 5150, wasRunning: false)])
        #expect(app.watched == 5151)
    }

    /// One running before SitRep opened it, as one left from the SitRep before, is told so as it ends.
    @Test func aHelperAlreadyRunningIsToldSoAsItEnds() async {
        let app = helperApp()

        mac.running = 977
        await watching(app, 977)
        mac.ends[977]?()

        #expect(ends.told == [HelperApp.End(pid: 977, wasRunning: true)])
    }
}
