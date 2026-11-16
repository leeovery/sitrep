import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// A folder of its own for a test, gone once the test is done with it.
final class Scratch {
    let folder = FileManager.default.temporaryDirectory.appending(path: "sitrep-tests-\(UUID().uuidString)")

    /// The bundle's copy, `Contents/Resources/Plugin`, and SitRep's own, `Application Support/sitrep`.
    var carried: URL { folder.appending(path: "SitRep.app/Contents/Resources/Plugin") }
    var own: URL { folder.appending(path: "Application Support/sitrep") }
    var copies: PluginCopies { PluginCopies(carried: carried, own: own) }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    /// A plugin of the version given at the folder, its CLI saying which it is.
    func plugin(_ version: String, at plugin: URL, cli: String? = nil) throws {
        try write(#"{"name": "sitrep", "version": "\#(version)"}"#, to: plugin.appending(path: ".claude-plugin/plugin.json"))
        try write(cli ?? "sitrep \(version)", to: plugin.appending(path: "bin/sitrep"))
    }

    func write(_ text: String, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
    }

    func read(_ file: URL) -> String? {
        try? String(contentsOf: file, encoding: .utf8)
    }
}

struct PluginCopiesTests {
    @Test func eachCopysVersionIsAsItsManifestSaysAndItsBuildAsItsStamp() throws {
        let scratch = Scratch()

        try scratch.plugin("0.3.0", at: scratch.carried)
        try scratch.write("4f2a9c\n", to: scratch.carried.appending(path: ".sitrep-build"))
        try scratch.plugin("0.2.0", at: scratch.own)

        #expect(scratch.copies.standing == OwnPlugin(
            folder: scratch.own.path, carried: OwnPlugin.Copy(version: "0.3.0", build: "4f2a9c"), copied: OwnPlugin.Copy(version: "0.2.0")
        ))
        #expect(scratch.copies.ownIfThere == scratch.own.path)
    }

    @Test func aCopyNotThereOrWithNoManifestToReadHasNoVersion() throws {
        let scratch = Scratch()

        try scratch.write("{", to: scratch.carried.appending(path: ".claude-plugin/plugin.json"))

        #expect(scratch.copies.standing == OwnPlugin(folder: scratch.own.path, carried: nil, copied: nil))
        #expect(scratch.copies.ownIfThere == nil)
        #expect(PluginCopies(carried: nil, own: scratch.own).standing.carried == nil)
    }

    @Test func theFirstCopyMakesTheFolderItGoesIn() throws {
        let scratch = Scratch()

        try scratch.plugin("0.2.0", at: scratch.carried)
        try scratch.copies.replace()

        #expect(scratch.read(scratch.own.appending(path: "bin/sitrep")) == "sitrep 0.2.0")
        #expect(PluginCopies.version(scratch.own) == "0.2.0")
    }

    @Test func aCopyReplacesTheOldWholeLeavingNoneOfItNorAnythingBeside() throws {
        let scratch = Scratch()

        try scratch.plugin("0.3.0", at: scratch.carried)
        try scratch.plugin("0.2.0", at: scratch.own)
        try scratch.write("gone in 0.3.0", to: scratch.own.appending(path: "hooks/old.ts"))
        try scratch.copies.replace()

        #expect(scratch.read(scratch.own.appending(path: "bin/sitrep")) == "sitrep 0.3.0")
        #expect(!FileManager.default.fileExists(atPath: scratch.own.appending(path: "hooks/old.ts").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: scratch.own.deletingLastPathComponent().path) == ["sitrep"])
    }

    @Test func theCLIStaysExecutable() throws {
        let scratch = Scratch()
        let cli = scratch.carried.appending(path: "bin/sitrep")

        try scratch.plugin("0.2.0", at: scratch.carried)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        try scratch.copies.replace()

        #expect(FileManager.default.isExecutableFile(atPath: scratch.own.appending(path: "bin/sitrep").path))
    }

    @Test func aCopyFromADownloadIsNoLongerQuarantinedButKeepsItsOtherAttributes() throws {
        let scratch = Scratch()
        let other = "com.leeovery.sitrep.test"

        try scratch.plugin("0.2.0", at: scratch.carried)
        let files = [scratch.carried, scratch.carried.appending(path: "bin"), scratch.carried.appending(path: "bin/sitrep")]
        for file in files {
            try Self.mark(file, PluginCopies.quarantine, "0081;6a0f5c2b;Safari;")
            try Self.mark(file, other, "kept")
        }
        try scratch.copies.replace()

        for file in [scratch.own, scratch.own.appending(path: "bin"), scratch.own.appending(path: "bin/sitrep")] {
            #expect(!Self.marked(file, PluginCopies.quarantine))
            #expect(Self.marked(file, other))
        }
    }

    private static func mark(_ file: URL, _ name: String, _ value: String) throws {
        let set = value.withCString { setxattr(file.path, name, $0, strlen($0), 0, XATTR_NOFOLLOW) }

        if set != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private static func marked(_ file: URL, _ name: String) -> Bool {
        getxattr(file.path, name, nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }

    @Test func twoStartsCopyingAtOnceBothLeaveOneWholeCopy() async throws {
        let scratch = Scratch()
        let copies = scratch.copies

        try scratch.plugin("0.3.0", at: scratch.carried)
        try scratch.plugin("0.2.0", at: scratch.own)

        async let first: Void = Task.detached { try copies.replace() }.value
        async let second: Void = Task.detached { try copies.replace() }.value

        try await first
        try await second
        #expect(scratch.read(scratch.own.appending(path: "bin/sitrep")) == "sitrep 0.3.0")
        #expect(try FileManager.default.contentsOfDirectory(atPath: scratch.own.deletingLastPathComponent().path) == ["sitrep"])
    }

    @Test func withNothingCarriedThereIsNothingToCopy() {
        let scratch = Scratch()

        #expect(throws: PluginTrouble.uncarried) { try PluginCopies(carried: nil, own: scratch.own).replace() }
    }

    @Test func aCopyThatFailsSaysWhere() throws {
        let scratch = Scratch()

        #expect {
            try scratch.copies.replace()
        } throws: { error in
            guard case let .failed(why) = error as? PluginTrouble else {
                return false
            }

            return why.hasPrefix("Copying it to \(scratch.own.path) failed: ")
        }
    }
}

struct MarketplaceEntryTests {
    private static func entry(_ json: String) throws -> MarketplaceEntry? {
        let scratch = Scratch()

        try scratch.write(json, to: scratch.folder.appending(path: ".claude-plugin/marketplace.json"))

        return MarketplaceEntry.sitrep(in: scratch.folder.path)
    }

    @Test func sitrepsOwnMarketplaceHasItAtItsRoot() throws {
        #expect(MarketplaceEntry.sitrep(in: Repository.root.path) == .within("./"))
    }

    @Test func aPathIsWhereItIsWithinTheFolder() throws {
        #expect(try Self.entry(#"{"plugins": [{"name": "litware"}, {"name": "sitrep", "source": "./sitrep"}]}"#) == .within("./sitrep"))
    }

    @Test func aSourceClaudeFetchesIsFetched() throws {
        #expect(try Self.entry(#"{"plugins": [{"name": "sitrep", "source": {"source": "github", "repo": "leeovery/sitrep"}}]}"#) == .fetched)
    }

    @Test func noSitrepNoFileOrOneThatDoesNotReadIsNone() throws {
        #expect(try Self.entry(#"{"plugins": [{"name": "litware", "source": "./litware"}]}"#) == nil)
        #expect(try Self.entry("{") == nil)
        #expect(MarketplaceEntry.sitrep(in: Scratch().folder.path) == nil)
    }
}
