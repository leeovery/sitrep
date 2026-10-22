import Foundation
import Observation
import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel

/// What Lee sets, the one place it is kept: the edge's settings, which the menu's Show, Settings and a drag change, and
/// the rest beside them, each saved as one value as it changes. The edge follows every change Lee makes at once; a
/// drag's move it made itself.
@MainActor
@Observable
final class Preferences {
    private(set) var edge: EdgeSettings
    var app: AppSettings {
        didSet {
            if app != oldValue {
                savedApp.save(app)
                onApp(app)
            }
        }
    }

    /// The edge, told of each change Lee makes in the menu or Settings.
    @ObservationIgnored var onEdge: (EdgeSettings) -> Void = { _ in }
    /// The edge, told of each change Lee makes to the rest, for the card's fold period.
    @ObservationIgnored var onApp: (AppSettings) -> Void = { _ in }
    @ObservationIgnored private let savedEdge: SavedEdgeSettings
    @ObservationIgnored private let savedApp: SavedSettings<AppSettings>

    init(_ defaults: UserDefaults = .standard) {
        savedEdge = SavedEdgeSettings(defaults)
        savedApp = SavedSettings(defaults)
        edge = savedEdge.read()
        app = savedApp.read()
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
