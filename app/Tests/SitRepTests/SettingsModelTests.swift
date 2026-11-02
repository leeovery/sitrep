import AppKit
import Foundation
@testable import SitRep
import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepMenu
import SwiftUI
import Testing

struct DesktopCornerTests {
    private static let evening = Date(timeIntervalSince1970: 1_792_524_000)
    private static let london = TimeZone(identifier: "Europe/London")!

    /// The menu bar's own form, which DESIGN draws as "Tue 20 Oct 20:20".
    @Test(arguments: ["en_GB", "en_001@rg=gbzzzz"])
    func itsClockReadsAsTheMenuBarsWithNoCommaWhereTheLocaleWouldHaveOne(locale: String) {
        #expect(DesktopCorner.clock(Self.evening, locale: Locale(identifier: locale), timeZone: Self.london) == "Tue 20 Oct 20:20")
    }

    @Test func itsClockKeepsTheLocalesOrderAndTwelveHours() {
        #expect(DesktopCorner.clock(Self.evening, locale: Locale(identifier: "en_US"), timeZone: Self.london) == "Tue Oct 20 8:20\u{202F}PM")
    }
}

/// Settings as the window keeps it between visits, over a Mac of its own.
@MainActor
struct SettingsModelTests {
    /// What the Mac was asked, and the prompt held up until `answer` lets it go.
    @MainActor
    final class Mac {
        var logins = 0
        var displays = 0
        /// Reads of what macOS says, each asking first of notifications.
        var reads = 0
        var allows = 0
        var opened: [Leaves.Place] = []
        /// The sounds played, by name, none of them aloud.
        var played: [String] = []
        var answer: CheckedContinuation<GhosttyLeave, Never>?
        /// The notices helper slow to answer: each read of notifications held until `noticesAnswer` lets it go.
        var holdsNotices = false
        var noticesAnswer: CheckedContinuation<Void, Never>?

        func services() -> SettingsServices {
            SettingsServices(
                displays: { self.displays += 1; return [] }, hasGlass: true, jump: { _ in }, sendTest: {}, copy: { _ in },
                sounds: AlertSounds(names: ["Basso", "Glass", "Tink"]) { self.played.append($0) },
                noticeLeave: {
                    self.reads += 1
                    if self.holdsNotices {
                        await withCheckedContinuation { self.noticesAnswer = $0 }
                    }

                    return .allowed(.banners)
                },
                askForNotices: {},
                login: { self.logins += 1; return LoginItem(.enabled) }, chooseLogin: {}, ghostty: { .unasked },
                allowGhostty: {
                    self.allows += 1
                    return await withCheckedContinuation { self.answer = $0 }
                },
                open: { self.opened.append($0) }
            )
        }
    }

    private static func settings(_ mac: Mac, _ defaults: UserDefaults = MemoryDefaults()) -> SettingsModel {
        SettingsModel(preferences: Preferences(defaults), live: LiveBoard(), services: mac.services())
    }

    /// So Open at login never draws greyed for a frame before it is read.
    @Test func itKnowsWhetherSitRepOpensAtLoginBeforeAPaneFirstDraws() {
        let mac = Mac()
        let settings = Self.settings(mac)

        #expect(mac.logins == 1)
        #expect(settings.said.login == LoginItem(.enabled))
        #expect(settings.said.notices == nil)
    }

    @Test func itReadsTheDisplaysOnlyWhenAsked() {
        let mac = Mac()
        let settings = Self.settings(mac)

        #expect(mac.displays == 0)
        settings.readDisplays()
        #expect(mac.displays == 1)
    }

    @Test func whatMacOSSaidIsKeptForTheNextVisit() async {
        let settings = Self.settings(Mac())

        await settings.read()
        #expect(settings.said == MacSays(notices: .allowed(.banners), login: LoginItem(.enabled), ghostty: .unasked))
    }

    /// The notices helper may take up to its 2 seconds; Ghostty's row is read meanwhile.
    @Test func aSlowReadOfNotificationsHoldsUpNoOtherRow() async {
        let mac = Mac()
        let settings = Self.settings(mac)

        mac.holdsNotices = true

        let reading = Task { await settings.read() }

        for _ in 0 ..< 100 where settings.said.ghostty == nil {
            await Task.yield()
        }
        #expect(settings.said.ghostty == .unasked)
        #expect(settings.said.notices == nil)

        while mac.noticesAnswer == nil {
            await Task.yield()
        }
        mac.noticesAnswer?.resume()
        await reading.value
        #expect(settings.said.notices == .allowed(.banners))
    }

    /// The window keyed as it opens reads once, however often it is told it is key.
    @Test func itReadsWhatMacOSSaysOnceAsTheWindowOpens() async {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.keys(true)
        await settings.reading?.value
        settings.keys(true)
        await settings.reading?.value
        #expect(mac.reads == 1)
    }

    /// Lee may have changed it in System Settings meanwhile.
    @Test func itReadsAgainEachTimeTheWindowComesForward() async {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.keys(true)
        await settings.reading?.value
        settings.keys(false)
        settings.keys(true)
        await settings.reading?.value
        #expect(mac.reads == 2)
    }

    /// A pane comes into sight as Lee turns to it, by the sidebar or by back and forward; the pane shown, picked again,
    /// stays in sight.
    @Test func itReadsAsLeeTurnsToAPaneWhileTheWindowIsKey() async {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.keys(true)
        await settings.reading?.value
        settings.turn(to: .notifications)
        await settings.reading?.value
        settings.goBack()
        await settings.reading?.value
        settings.goForward()
        await settings.reading?.value
        settings.turn(to: .notifications)
        await settings.reading?.value
        #expect(mac.reads == 4)
    }

    /// As where About SitRep or another app's window takes the keyboard.
    @Test func itReadsNothingWhileTheWindowIsNotKey() {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.keys(false)
        settings.turn(to: .general)
        settings.turn(to: .edge)
        settings.goBack()
        #expect(settings.reading == nil)
        #expect(mac.reads == 0)
    }

    @Test func itOpensOnGeneralTheFirstTime() {
        #expect(Self.settings(Mac()).pane == .general)
    }

    /// The pane turned to is saved, by the sidebar or by back and forward, and the window opens on it next.
    @Test func itOpensOnThePaneItLastShowed() {
        let defaults = MemoryDefaults()
        let settings = Self.settings(Mac(), defaults)

        settings.turn(to: .claudeCode)
        #expect(Self.settings(Mac(), defaults).pane == .claudeCode)
        settings.turn(to: .edge)
        settings.goBack()
        #expect(settings.pane == .claudeCode)
        settings.goForward()
        #expect(SavedSettings<AppSettings>(defaults).read().pane == .edge)
        #expect(Self.settings(Mac(), defaults).pane == .edge)
    }

    @Test func allowIsPressedOnceWhileMacOSsPromptIsUp() async {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.fix(.allowGhostty)
        settings.fix(.allowGhostty)
        while mac.answer == nil {
            await Task.yield()
        }
        #expect(settings.isAllowing)
        #expect(mac.allows == 1)
        mac.answer?.resume(returning: .allowed)
        while settings.isAllowing {
            await Task.yield()
        }
        #expect(settings.said.ghostty == .allowed)
    }

    /// As System Settings › Sound plays an alert sound chosen.
    @Test func aSoundChosenIsSavedAndPlayedOnce() {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.choose(sound: "Tink")
        #expect(settings.preferences.app.sound == "Tink")
        #expect(mac.played == ["Tink"])
    }

    /// Show on a window behind jumps to its session, as the menu's item for it does; Copy puts the command each
    /// needs on the pasteboard.
    @Test func showJumpsToTheWindowBehindAndCopyCopiesTheCommand() async throws {
        let asked = Hosted.Asked()
        let settings = await Hosted.settings(live: Hosted.live(needsReload: true), asked: asked)
        let reload = try #require(ClaudeCodePane(settings.live.last, plugin: settings.live.plugin).reloads.first)

        settings.show(reload)
        settings.copyReloadCommand()
        #expect(asked.jumps == ["sr-aw3bgs"])
        #expect(asked.copies == ["/reload-plugins"])
    }

    @Test func eachButtonOpensItsPlace() {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.fix(.notifications)
        settings.fix(.automation)
        settings.fix(.loginItems)
        #expect(mac.opened == [.notifications, .automation, .loginItems])
    }
}
