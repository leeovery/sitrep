import Foundation
import Observation
import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel

/// What Lee sets, the one place it is kept: the edge's settings, which the menu's Show, Settings and a drag change, and
/// the rest beside them, each saved as one value as it changes. The edge follows every change Lee makes at once; a
/// drag's move it made itself. The pane the Settings window last showed is kept here too, on its own, so no follower
/// hears a turn to a pane, and whether a welcome has closed on this Mac.
@MainActor
@Observable
final class Preferences {
    private(set) var edge: EdgeSettings
    var app: AppSettings {
        didSet {
            if app != oldValue {
                savedApp.save(app)
                appFollowers.forEach { $0(app) }
            }
        }
    }

    /// The pane the Settings window opens on.
    var settingsPane: SettingsPane {
        didSet {
            if settingsPane != oldValue {
                savedSettingsWindow.save(SettingsWindowSettings(pane: settingsPane))
            }
        }
    }

    /// Whether a welcome has closed on this Mac, set as one closes: one opened after it changes nothing until pressed.
    var welcomed: Bool {
        didSet {
            if welcomed != oldValue {
                savedWelcome.save(WelcomeSettings(welcomed: welcomed))
            }
        }
    }

    /// The edge, told of each change Lee makes in the menu or Settings.
    @ObservationIgnored var onEdge: (EdgeSettings) -> Void = { _ in }
    /// The card and the SitRep window, each told of every change Lee makes to the rest, for the fold period.
    @ObservationIgnored private var appFollowers: [(AppSettings) -> Void] = []
    @ObservationIgnored private let savedEdge: SavedEdgeSettings
    @ObservationIgnored private let savedApp: SavedSettings<AppSettings>
    @ObservationIgnored private let savedSettingsWindow: SavedSettings<SettingsWindowSettings>
    @ObservationIgnored private let savedWelcome: SavedSettings<WelcomeSettings>

    init(_ defaults: UserDefaults = .standard) {
        savedEdge = SavedEdgeSettings(defaults)
        savedApp = SavedSettings(defaults)
        edge = savedEdge.read()
        app = savedApp.read()
        savedSettingsWindow = SavedSettings(defaults)
        settingsPane = savedSettingsWindow.read().pane
        savedWelcome = SavedSettings(defaults)
        welcomed = savedWelcome.read().welcomed
    }

    /// Told of each change Lee makes to the rest, from now on.
    func follow(app: @escaping (AppSettings) -> Void) {
        appFollowers.append(app)
    }

    /// A change Lee makes to the edge's settings: the edge takes it, and it is saved, unless it is one step of a drag
    /// that `save` ends.
    func edit(saving: Bool = true, _ change: (inout EdgeSettings) -> Void) {
        var edited = edge

        change(&edited)
        guard edited != edge else {
            return
        }

        edge = edited
        if saving {
            save()
        }
        onEdge(edited)
    }

    /// The edge's settings as they stand, saved: at the end of a drag whose steps were not.
    func save() {
        savedEdge.save(edge)
    }

    /// Where a drag left the notch or the strip, which has already placed itself there: saved, for Settings to show.
    func moved(_ settings: EdgeSettings) {
        edge = settings
        savedEdge.save(settings)
    }
}

/// The board as `watch` last printed it, and the plugin SitRep found, nil while it looks: for Settings to read as
/// they change.
@MainActor
@Observable
final class LiveBoard {
    var last = LastBoard()
    var plugin: PluginStanding?
}
