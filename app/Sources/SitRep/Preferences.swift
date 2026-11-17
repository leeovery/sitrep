import Foundation
import Observation
import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel

/// What Lee sets, the one place it is kept: the edge's settings, which the menu's Show, Settings and a drag change, and
/// the rest beside them, each saved as one value as it changes. The edge follows every change Lee makes at once; a
/// drag's move it made itself. The pane the Settings window last showed is kept here too, on its own, so no follower
/// hears a turn to a pane, whether a welcome has closed on this Mac, and the callout its Done leaves.
@MainActor
@Observable
final class Preferences {
    private(set) var edge: EdgeSettings
    var app: AppSettings {
        didSet {
            if app != oldValue {
                savedApp.save(app)
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

    /// The callout beside the real edge, due once a welcome's Done closes it and gone once Lee points at the edge.
    var callout: CalloutSettings {
        didSet {
            if callout != oldValue {
                savedCallout.save(callout)
                onCallout(callout)
            }
        }
    }

    /// The edge, told as the callout beside it comes or goes.
    @ObservationIgnored var onCallout: (CalloutSettings) -> Void = { _ in }
    /// The edge, told of each change Lee makes in the menu or Settings.
    @ObservationIgnored var onEdge: (EdgeSettings) -> Void = { _ in }
    @ObservationIgnored private let savedEdge: SavedEdgeSettings
    @ObservationIgnored private let savedApp: SavedSettings<AppSettings>
    @ObservationIgnored private let savedSettingsWindow: SavedSettings<SettingsWindowSettings>
    @ObservationIgnored private let savedWelcome: SavedSettings<WelcomeSettings>
    @ObservationIgnored private let savedCallout: SavedSettings<CalloutSettings>
    /// Where the card's folded sections are kept, in the same defaults.
    @ObservationIgnored let savedCard: SavedSettings<CardSettings>

    /// What the SitRep window kept, until it went on 5 November 2026: where it was left, where Lee last looked at each
    /// session, and its frame.
    static let retired = ["windowLocation", "windowLastSession", "windowLooked", "NSWindow Frame SitRepWindow"]

    /// What it reads, and the window's keys taken out, quietly, at each start, which finds them gone after the first.
    init(_ defaults: UserDefaults) {
        Self.retired.filter { defaults.object(forKey: $0) != nil }.forEach(defaults.removeObject(forKey:))
        savedEdge = SavedEdgeSettings(defaults)
        savedApp = SavedSettings(defaults)
        edge = savedEdge.read()
        app = savedApp.read()
        savedSettingsWindow = SavedSettings(defaults)
        settingsPane = savedSettingsWindow.read().pane
        savedWelcome = SavedSettings(defaults)
        welcomed = savedWelcome.read().welcomed
        savedCallout = SavedSettings(defaults)
        callout = savedCallout.read()
        savedCard = SavedSettings(defaults)
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
