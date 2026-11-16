import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepMenu
import SitRepTestSupport
import SwiftUI
import Testing

/// The sounds a new ask can play: macOS's own alert sounds, by name.
@MainActor
@Suite(.backstop)
struct AlertSoundsTests {
    /// Read from this Mac's macOS, in order, and holding every name the tests use in their place: a macOS that adds a
    /// sound passes, one that drops or renames one the tests use fails.
    @Test(.tags(.thisMac))
    func theyAreMacOSsAlertSoundsByNameInOrder() {
        let names = AlertSounds.live.names

        #expect(Set(AlertSounds.macOSNames).isSubset(of: names))
        #expect(names == names.sorted())
    }

    @Test func aFolderListsItsSoundFilesAlone() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "sounds-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for file in ["Tink.aiff", "Pop.caf", "Basso.aiff", "notes.txt", ".hidden.aiff"] {
            try Data().write(to: folder.appending(path: file))
        }

        #expect(AlertSounds.names(in: folder) == ["Basso", "Pop", "Tink"])
    }

    /// A name edited by hand, saved on another Mac or dropped by a later macOS.
    @Test func aSavedNameMacOSLacksPlaysGlass() {
        var played: [String] = []
        let sounds = AlertSounds(names: ["Basso", "Glass", "Tink"]) { played.append($0) }

        sounds.play("Gone")
        sounds.play("Tink")
        #expect(played == ["Glass", "Tink"])
    }
}

/// Settings' "Play a sound for a new ask" and "Sound", in Notifications' Sound, after Banners.
@MainActor
@Suite(.backstop)
struct SoundRowsTests {
    /// What the page played, none of it aloud.
    @MainActor
    final class Played {
        var names: [String] = []

        var sounds: AlertSounds {
            AlertSounds(names: ["Basso", "Glass", "Tink"]) { self.names.append($0) }
        }
    }

    private static func page(_ defaults: UserDefaults, _ played: Played) async -> (Hosted, SettingsModel) {
        let settings = await Hosted.settings(defaults: defaults, sounds: played.sounds)

        return (Hosted(Hosted.content(.notifications, settings), size: CGSize(width: 744, height: 620)), settings)
    }

    private static func popUp(_ hosted: Hosted) throws -> NSPopUpButton {
        try #require(hosted.all(NSPopUpButton.self).first { $0.accessibilityLabel() == "Sound" })
    }

    /// The switch in the row over Sound's.
    private static func soundSwitch(_ hosted: Hosted) throws -> NSSwitch {
        let sound = try hosted.frame(of: popUp(hosted))
        let over = hosted.all(NSSwitch.self).filter { hosted.frame(of: $0).maxY <= sound.minY }

        return try #require(over.max { hosted.frame(of: $0).minY < hosted.frame(of: $1).minY })
    }

    /// The switch on and Glass chosen, as Lee has set nothing, and nothing played as the page draws.
    @Test func itOffersMacOSsSoundsGlassChosenTheSwitchOn() async throws {
        let played = Played()
        let (hosted, _) = await Self.page(MemoryDefaults(), played)
        let button = try Self.popUp(hosted)

        #expect(button.itemTitles == ["Basso", "Glass", "Tink"])
        #expect(button.titleOfSelectedItem == "Glass")
        #expect(button.isEnabled)
        #expect(try Self.soundSwitch(hosted).state == .on)
        #expect(played.names.isEmpty)
    }

    @Test func aSoundChosenIsSavedAndPlayedOnce() async throws {
        let defaults = MemoryDefaults()
        let played = Played()
        let (hosted, _) = await Self.page(defaults, played)
        let button = try Self.popUp(hosted)

        button.selectItem(withTitle: "Tink")
        _ = button.sendAction(button.action, to: button.target)

        #expect(SavedSettings<AppSettings>(defaults).read().sound == "Tink")
        #expect(played.names == ["Tink"])
    }

    @Test func aSavedNameMacOSLacksShowsAsGlass() async throws {
        let defaults = MemoryDefaults()
        var gone = AppSettings()

        gone.sound = "Gone"
        SavedSettings(defaults).save(gone)

        let (hosted, _) = await Self.page(defaults, Played())

        #expect(try Self.popUp(hosted).titleOfSelectedItem == "Glass")
    }

    /// The pop-up follows the switch as Lee flips it, off then on.
    @Test func theSoundGreysAndComesBackAsTheSwitchFlips() async throws {
        let (hosted, settings) = await Self.page(MemoryDefaults(), Played())
        let flipped = { (isOn: Bool) in
            let control = try Self.soundSwitch(hosted)

            control.state = isOn ? .on : .off
            _ = control.sendAction(control.action, to: control.target)
            #expect(settings.preferences.app.playsSound == isOn)
            hosted.hosting.layoutSubtreeIfNeeded()
            return try Self.popUp(hosted).isEnabled
        }

        #expect(try !flipped(false))
        #expect(try flipped(true))
    }

    @Test func theSoundIsGreyedWhileTheSwitchIsOff() async throws {
        let defaults = MemoryDefaults()
        var off = AppSettings()

        off.playsSound = false
        SavedSettings(defaults).save(off)

        let (hosted, _) = await Self.page(defaults, Played())

        #expect(try !Self.popUp(hosted).isEnabled)
        #expect(try Self.soundSwitch(hosted).state == .off)
    }
}
