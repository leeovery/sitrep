import Foundation

/// Where the plugin SitRep runs comes from, as Claude Code's marketplaces say.
public enum PluginSource: Equatable, Sendable {
    /// SitRep's own copy, which it installed and keeps up to date.
    case own
    /// A folder of Lee's, as he would write it: `~/Code/sitrep`, as a checkout under `app/plugin here` is.
    case folder(String)
    /// A repository on GitHub: `leeovery/sitrep`.
    case github(String)
    /// Anywhere else, as Claude Code lists it: a git or https URL, or the marketplace's name where it lists no more.
    case other(String)
}

/// Why SitRep could not see to the plugin it installs. It then runs the plugin it last ran, or its own copy.
public enum PluginTrouble: Error, Equatable, Sendable {
    /// No `claude` where its installers put it, nor on Lee's PATH.
    case noClaude
    /// No `sitrep` marketplace nor plugin, and this SitRep carries no plugin to install: one not built by
    /// `app/bundle`.
    case uncarried
    /// Claude Code has sitrep from the place given, and SitRep cannot find its plugin there to run.
    case unfound(PluginSource)
    /// A step failed, in `claude`'s own words or the file system's.
    case failed(String)
}

/// The plugin SitRep runs once it has looked: where it comes from, and the folder whose `bin/sitrep` it runs; or
/// the trouble, and the folder it runs meanwhile, where it has one.
public enum PluginStanding: Equatable, Sendable {
    case running(PluginSource, folder: String)
    case trouble(PluginTrouble, folder: String?)

    /// The plugin whose CLI SitRep runs; nil with none to run.
    public var folder: String? {
        switch self {
        case let .running(_, folder): folder
        case let .trouble(_, folder): folder
        }
    }

    /// The trouble SitRep met; nil with none.
    public var trouble: PluginTrouble? {
        if case let .trouble(trouble, _) = self {
            trouble
        } else {
            nil
        }
    }
}

/// What SitRep has of its own plugin: the folder of its own copy, outside the bundle, the copy the bundle carries,
/// nil when it carries none, and its own copy, nil when there is none.
public struct OwnPlugin: Equatable, Sendable {
    /// A copy: its manifest's version, and the build `app/bundle` stamped it with, nil for one made before stamps.
    /// Two copies differ by either, so a rebuild at the same version is a new copy.
    public struct Copy: Equatable, Sendable {
        public let version: String
        public let build: String?

        public init(version: String, build: String? = nil) {
            self.version = version
            self.build = build
        }
    }

    public let folder: String
    public let carried: Copy?
    public let copied: Copy?

    public init(folder: String, carried: Copy?, copied: Copy?) {
        self.folder = folder
        self.carried = carried
        self.copied = copied
    }
}

/// What SitRep does about the plugin as it starts (DESIGN, "Installing and updating"), from both of Claude Code's
/// lists:
/// - with neither listing anything of sitrep, no `sitrep` marketplace and no plugin named `sitrep`, it installs its
///   own copy: copied out of the bundle, that folder added as the marketplace, and `sitrep@sitrep` installed;
/// - with the marketplace its own copy, it replaces the copy when the bundle carries another build, and updates the
///   marketplace and the plugin while Claude's record of it is at another version than the copy, so a refresh cut
///   short is finished at the next start; with all the same, nothing. It installs the plugin should it be gone;
/// - with a `sitrep` marketplace anywhere else, or any plugin named `sitrep` not from its own copy (`sitrep@kit`),
///   it changes nothing, and runs that plugin's CLI from where Claude loads it: SitRep never removes, replaces or
///   re-points a marketplace or plugin it did not install, nor installs a second sitrep beside one.
public struct PluginPlan: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        /// The plugin the bundle carries put in place of SitRep's own copy.
        case copy
        /// `claude plugin marketplace add` of SitRep's own copy.
        case addMarketplace
        /// `claude plugin marketplace update sitrep`.
        case updateMarketplace
        /// `claude plugin install sitrep@sitrep`.
        case install
        /// `claude plugin update sitrep@sitrep`.
        case update
    }

    /// The plugin's own name, whatever marketplace it is from.
    public static let name = "sitrep"
    public static let marketplace = "sitrep"
    public static let plugin = "sitrep@sitrep"

    public let steps: [Step]
    /// The plugin SitRep runs once the steps are done; a trouble's folder is the setup's to fill.
    public let standing: PluginStanding

    /// `home` is Lee's, for writing a folder of his as he would; `entry` reads what a folder marketplace's own
    /// `marketplace.json` says of `sitrep`.
    public init(
        marketplaces: [Marketplace], plugins: [InstalledPlugin], own: OwnPlugin, home: String,
        entry: (String) -> MarketplaceEntry?
    ) {
        let marketplace = marketplaces.first { $0.name == Self.marketplace }
        let isOwnMarketplace = marketplace?.isFolder(own.folder) == true
        let ownFolder = Marketplace.standardized(own.folder)
        let isOwn = { (plugin: InstalledPlugin) in
            plugin.id == Self.plugin && (isOwnMarketplace || plugin.readFromFolder.map(Marketplace.standardized) == ownFolder)
        }
        let sitreps = plugins.filter { $0.name == Self.name }
        let foreign = sitreps.filter { !isOwn($0) }

        if (marketplace != nil && !isOwnMarketplace) || !foreign.isEmpty {
            let plugin = foreign.first { $0.id == Self.plugin } ?? foreign.first
            let named = plugin.map { plugin in marketplaces.first { $0.name == plugin.marketplace } } ?? marketplace

            steps = []
            standing = Self.foreign(plugin, of: named, named: plugin.map { String($0.marketplace) }, home: home, entry: entry)
        } else if marketplace == nil, sitreps.isEmpty {
            steps = own.carried == nil ? [] : [.copy, .addMarketplace, .install]
            standing = own.carried == nil ? .trouble(.uncarried, folder: nil) : .running(.own, folder: own.folder)
        } else {
            // Its own plugin, under its own marketplace, or one Claude lists the plugin of and not the marketplace,
            // which there is then no updating.
            steps = marketplace == nil ? [] : Self.refresh(own, installed: sitreps.first)
            standing = .running(.own, folder: own.folder)
        }
    }

    private static func refresh(_ own: OwnPlugin, installed: InstalledPlugin?) -> [Step] {
        let isMoved = own.carried.map { $0 != own.copied } ?? false
        let copy = isMoved ? own.carried : own.copied
        let copying: [Step] = isMoved ? [.copy] : []

        guard let installed else {
            return copying + (isMoved ? [.updateMarketplace] : []) + [.install]
        }

        let isBehind = copy.map { copy in installed.version.map { $0 != copy.version } ?? false } ?? false

        return copying + (isBehind ? [.updateMarketplace, .update] : [])
    }

    /// A plugin SitRep did not install, run from where Claude loads it: a folder marketplace's own folder and the
    /// plugin's place in it, else Claude's own copy of one it fetched. Claude's copy of one from a folder is never
    /// run: Claude loads that from the folder, and its copy is as stale as the install. With a marketplace it no
    /// longer lists, the folder it says it loads the plugin from; with none of these to read, the trouble.
    private static func foreign(
        _ plugin: InstalledPlugin?, of marketplace: Marketplace?, named: String?, home: String,
        entry: (String) -> MarketplaceEntry?
    ) -> PluginStanding {
        guard let marketplace else {
            return plugin?.readFromFolder.map { .running(.folder(Marketplace.written($0, home: home)), folder: $0) }
                ?? .trouble(.unfound(.other(named ?? Self.marketplace)), folder: nil)
        }

        let source = marketplace.origin(home: home)
        let fetched = plugin?.installPath.map { PluginStanding.running(source, folder: $0) }
            ?? .trouble(.unfound(source), folder: nil)

        guard marketplace.source == "directory", let path = marketplace.path else {
            return fetched
        }

        return switch entry(path) {
        case let .within(within)?: .running(source, folder: Marketplace.standardized("\(path)/\(within)"))
        case .fetched?: fetched
        case nil: .trouble(.unfound(source), folder: nil)
        }
    }
}

private extension Marketplace {
    /// A `directory` marketplace of the folder given.
    func isFolder(_ folder: String) -> Bool {
        source == "directory" && path.map(Self.standardized) == Self.standardized(folder)
    }

    func origin(home: String) -> PluginSource {
        switch (source, path, repo) {
        case let ("directory", path?, _): .folder(Self.written(path, home: home))
        case let ("github", _, repo?): .github(repo)
        default: .other(url ?? repo ?? path.map { Self.written($0, home: home) } ?? source)
        }
    }

    static func standardized(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    /// The path as Lee would write it, his home as `~`.
    static func written(_ path: String, home: String) -> String {
        path == home ? "~" : path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
