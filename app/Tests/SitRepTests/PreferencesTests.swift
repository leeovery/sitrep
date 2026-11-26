import Foundation
@testable import SitRep
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

/// What Lee sets, kept in one place: a change saves as it is made; Snooze's choices are written for the pane in Claude
/// Code as SitRep starts and as they change.
@MainActor
@Suite(.backstop)
struct PreferencesTests {
    @Test func aChangeIsSavedAndTheEdgeTakesIt() {
        let defaults = MemoryDefaults()
        let preferences = Preferences(defaults)
        var taken: [EdgeSettings.Show] = []

        preferences.onEdge = { taken.append($0.show) }
        preferences.edit { $0.show = .nothing }

        #expect(taken == [.nothing])
        #expect(SavedEdgeSettings(defaults).read().show == .nothing)
    }

    /// A file of a test's own, in a folder not there yet, gone with the folder once the test is done.
    private final class SnoozeFolder {
        let url = FileManager.default.temporaryDirectory.appending(path: "sitrep-preferences-\(UUID().uuidString)")
        var file: SnoozeFile { SnoozeFile(url: url.appending(path: "sitrep/\(SnoozeFile.name)")) }

        func read() throws -> SnoozeSettings {
            try JSONDecoder().decode(SnoozeSettings.self, from: Data(contentsOf: file.url))
        }

        deinit {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// As SitRep starts it writes the file what it keeps, so the file says what the app has whatever wrote it last: a
    /// file another build wrote is put right.
    @Test func snoozesChoicesAreWrittenForThePaneAsItStarts() throws {
        let defaults = MemoryDefaults(), folder = SnoozeFolder()
        var kept = SnoozeSettings()

        kept.thisWeekend.isOn = true
        SavedSettings(defaults).save(kept)
        try FileManager.default.createDirectory(
            at: folder.file.url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try SnoozeFile.text(SnoozeSettings()).write(to: folder.file.url)
        _ = Preferences(defaults, snoozeFile: folder.file)

        #expect(try folder.read() == kept)
    }

    /// A change is saved and written for the pane at once; one that changes nothing writes nothing.
    @Test func aChangeToSnoozesChoicesIsSavedAndWrittenForThePane() throws {
        let defaults = MemoryDefaults(), folder = SnoozeFolder()
        let preferences = Preferences(defaults, snoozeFile: folder.file)

        preferences.snooze.tonight.at = TimeOfDay(hour: 20)

        #expect(try folder.read().tonight.at == TimeOfDay(hour: 20))
        #expect(SavedSettings<SnoozeSettings>(defaults).read().tonight.at == TimeOfDay(hour: 20))

        try FileManager.default.removeItem(at: folder.file.url)
        preferences.snooze.tonight.at = TimeOfDay(hour: 20)

        #expect(!FileManager.default.fileExists(atPath: folder.file.url.path))
    }

    /// The SitRep window's keys go as it starts; the rest stay.
    @Test func whatTheWindowKeptIsTakenOutAtTheStart() {
        let defaults = MemoryDefaults()

        Preferences.retired.forEach { defaults.set(Data([1]), forKey: $0) }
        defaults.set(Data([1]), forKey: SavedEdgeSettings.key)
        _ = Preferences(defaults)

        expectEvery(Preferences.retired) { defaults.object(forKey: $0) == nil }
        #expect(defaults.object(forKey: SavedEdgeSettings.key) != nil)
    }
}
