import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepWindow
import Testing

extension WindowModel {
    /// A model over a plugin that runs nothing, its defaults a suite of their own unless given, with where it was left
    /// as given, its run's wall clock the Mac's unless given.
    static func made(
        remembered: Location? = nil, defaults given: UserDefaults? = nil, wall: @escaping () -> Date = Date.init
    ) throws -> WindowModel {
        let defaults = try given ?? #require(UserDefaults(suiteName: "sitrep.WindowModel.\(UUID().uuidString)"))
        let plugin = Plugin()
        let banners = Banners(pid: 1, send: { _ in }, helperApp: NoHelper())

        if let remembered {
            WhereLeft.save(remembered, in: defaults)
        }
        return WindowModel(
            plugin: plugin, works: Works(banners: banners, plugin: plugin),
            snoozes: Snoozes(plugin: plugin, banners: banners), following: Following(), defaults: defaults, wall: wall
        )
    }
}

/// A helper app that never starts.
private final class NoHelper: HelperStarting {
    var watched: Int32? { nil }

    func open() {}

    func isRunning(_: Int32) -> Bool { false }
}
