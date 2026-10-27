import Foundation

/// The plugin's two copies SitRep keeps: the one its bundle carries, `Contents/Resources/Plugin`, put there by
/// `app/bundle`, and its own outside the bundle, `~/Library/Application Support/sitrep`, which it installs, since
/// anything written into a signed app breaks its signature.
public struct PluginCopies: Sendable {
    /// The file `app/bundle` stamps the carried copy's build in, a digest of its files.
    static let buildFile = ".sitrep-build"

    /// The bundle's copy; nil for a SitRep that carries none.
    let carried: URL?
    let own: URL

    public init(carried: URL?, own: URL) {
        self.carried = carried
        self.own = own
    }

    /// This SitRep's: its bundle's copy, where `app/bundle` put one, and its own in Application Support.
    public static var app: PluginCopies {
        let carried = Bundle.main.resourceURL?.appending(path: "Plugin")

        return PluginCopies(
            carried: carried.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil },
            own: .applicationSupportDirectory.appending(path: "sitrep")
        )
    }

    /// The two copies, as their manifests and stamps say.
    public var standing: OwnPlugin {
        OwnPlugin(folder: own.path, carried: carried.flatMap(Self.copy), copied: Self.copy(own))
    }

    /// SitRep's own copy's folder, when it has one.
    public var ownIfThere: String? {
        FileManager.default.fileExists(atPath: own.path) ? own.path : nil
    }

    /// The bundle's copy put in place of SitRep's own whole: copied beside it, under a name of this start's own, so
    /// two starts at once never share one, then swapped in, so Claude Code never loads half of one.
    public func replace() throws(PluginTrouble) {
        guard let carried else {
            throw .uncarried
        }

        let files = FileManager.default
        let incoming = own.deletingLastPathComponent().appending(path: "\(own.lastPathComponent).incoming-\(UUID().uuidString)")

        do {
            try files.createDirectory(at: own.deletingLastPathComponent(), withIntermediateDirectories: true)
            try files.copyItem(at: carried, to: incoming)
            try Self.unquarantine(incoming)
            if files.fileExists(atPath: own.path) || (try? files.moveItem(at: incoming, to: own)) == nil {
                _ = try files.replaceItemAt(own, withItemAt: incoming)
            }
        } catch {
            try? files.removeItem(at: incoming)
            throw .failed("Copying it to \(own.path) failed: \(error.localizedDescription)")
        }
    }

    /// The mark macOS puts on every file of a download, and checks a program by as it first runs.
    static let quarantine = "com.apple.quarantine"

    /// Takes the mark off every file of a copy: copying keeps extended attributes, so a copy from a downloaded SitRep
    /// carries it. The copy is SitRep's own sealed payload, approved with SitRep, but its CLI runs from outside the
    /// bundle, where macOS judges a quarantined program with no ticket stapled to it on its own, by a lookup online
    /// that could refuse it offline.
    static func unquarantine(_ folder: URL) throws {
        let inside = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.allObjects.compactMap { $0 as? URL }

        for file in [folder] + (inside ?? []) {
            if removexattr(file.path, quarantine, XATTR_NOFOLLOW) != 0, errno != ENOATTR {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
    }

    /// A copy's version, as its manifest says, and its build, as its stamp says; nil with no manifest to read.
    static func copy(_ folder: URL) -> OwnPlugin.Copy? {
        version(folder).map { version in
            let build = try? String(contentsOf: folder.appending(path: buildFile), encoding: .utf8)

            return OwnPlugin.Copy(version: version, build: build?.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// The version a copy's manifest says; nil when there is none to read.
    static func version(_ folder: URL) -> String? {
        struct Manifest: Decodable {
            let version: String
        }

        let manifest = folder.appending(path: ".claude-plugin/plugin.json")

        return (try? Data(contentsOf: manifest)).flatMap { try? JSONDecoder().decode(Manifest.self, from: $0) }?.version
    }
}
