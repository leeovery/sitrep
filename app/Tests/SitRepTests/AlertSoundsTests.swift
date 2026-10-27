import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepLines
import SitRepMenu
import SwiftUI
import Testing

extension AlertSounds {
    /// macOS's sounds by name, none of them ever played.
    static var silent: AlertSounds {
        AlertSounds(names: live.names, play: { _ in })
    }
}

/// The sounds a new ask can play: macOS's own alert sounds, by name.
@MainActor
struct AlertSoundsTests {
    @Test func theyAreMacOSsAlertSoundsByNameInOrder() {
        let names = AlertSounds.live.names

        #expect(names.first == "Basso")
        #expect(names.last == "Tink")
        #expect(names.contains("Glass"))
        #expect(names == names.sorted())
    }
}

/// Settings' "Play a sound for a new ask" and "Sound", in Notifications after macOS's answer.
@MainActor
struct SoundRowsTests {
    /// What the page played, none of it aloud.
    @MainActor
    final class Played {
        var names: [String] = []

        var sounds: AlertSounds {
            AlertSounds(names: ["Basso", "Glass", "Tink"]) { self.names.append($0) }
        }
    }

    private static func page(_ defaults: UserDefaults, _ played: Played) async -> (Hosted, SettingsPage) {
        let page = await Hosted.pageView(defaults: defaults, sounds: played.sounds)

        return (Hosted(PageColumn(page: .settings, now: Date()) { page }, size: CGSize(width: 956, height: 1400)), page)
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
