import Foundation
@testable import SitRepNotices
import Testing

/// The helper serves the SitRep it sits in, not merely one with SitRep's bundle id: over folders of its own, standing in
/// for two copies of SitRep.app, with nothing launched.
@MainActor
struct OwnSitRepTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "own-sitrep-\(UUID().uuidString)")

    private func made(_ name: String) throws -> URL {
        let made = folder.appending(path: name)

        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)

        return made
    }

    @Test func ofTwoCopiesRunningItTakesTheOneItSitsIn() throws {
        let installed = try made("Applications/SitRep")
        let other = try made("Build/SitRep")
        defer { try? FileManager.default.removeItem(at: folder) }

        let apps: [(bundle: URL?, pid: Int32)] = [(other, 977), (installed, 4012)]

        #expect(OwnSitRep.pid(of: installed, among: apps) == 4012)
        #expect(OwnSitRep.pid(of: other, among: apps) == 977)
    }

    /// As the helper's bundle three folders up reads, against the path LaunchServices gives.
    @Test func itsBundleMatchesHoweverThePathIsWritten() throws {
        let installed = try made("Applications/SitRep")
        let link = folder.appending(path: "Link")
        defer { try? FileManager.default.removeItem(at: folder) }

        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: installed)

        let roundabout = installed.appending(path: "Contents/Helpers/..").appending(path: "../")

        #expect(OwnSitRep.pid(of: link, among: [(installed, 4012)]) == 4012)
        #expect(OwnSitRep.pid(of: installed, among: [(roundabout, 4012)]) == 4012)
    }

    @Test func withNoneRunningFromItItHasNone() throws {
        let installed = try made("Applications/SitRep")
        let other = try made("Build/SitRep")
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(OwnSitRep.pid(of: installed, among: [(other, 977), (nil, 12)]) == nil)
    }
}
