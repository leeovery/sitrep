import AppKit
import Foundation
@testable import SitRep
import SitRepCore
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
        var answer: CheckedContinuation<GhosttyLeave, Never>?
        /// The notices helper slow to answer: each read of notifications held until `noticesAnswer` lets it go.
        var holdsNotices = false
        var noticesAnswer: CheckedContinuation<Void, Never>?

        func services() -> SettingsServices {
            SettingsServices(
                displays: { self.displays += 1; return [] }, hasGlass: true, jump: { _ in }, sendTest: {},
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

    private static func settings(_ mac: Mac) -> SettingsModel {
        SettingsModel(
            preferences: Preferences(MemoryDefaults()),
            live: LiveBoard(), services: mac.services()
        )
    }

    /// So Open at login never draws greyed for a frame before it is read.
    @Test func itKnowsWhetherSitRepOpensAtLoginBeforeThePageFirstDraws() {
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

    @Test(arguments: [true, false])
    func itReadsWhatMacOSSaysOnceAsTheWindowOpensOnThePage(showsFirst: Bool) async {
        let mac = Mac()
        let settings = Self.settings(mac)

        if showsFirst {
            settings.shows(true)
            settings.keys(true)
        } else {
            settings.keys(true)
            settings.shows(true)
        }
        await settings.reading?.value
        #expect(mac.reads == 1)
    }

    @Test func itReadsAgainEachTimeTheWindowComesForwardOnThePage() async {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.shows(true)
        settings.keys(true)
        await settings.reading?.value
        settings.keys(false)
        settings.keys(true)
        await settings.reading?.value
        #expect(mac.reads == 2)
    }

    /// As where About SitRep or another app's window takes the keyboard, or the window shows another page.
    @Test func itReadsNothingWhileThePageIsAwayOrItsWindowIsNotKey() {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.keys(true)
        settings.keys(false)
        settings.shows(true)
        settings.shows(false)
        settings.keys(true)
        #expect(settings.reading == nil)
        #expect(mac.reads == 0)
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

    @Test func eachButtonOpensItsPlace() {
        let mac = Mac()
        let settings = Self.settings(mac)

        settings.fix(.notifications)
        settings.fix(.automation)
        settings.fix(.loginItems)
        #expect(mac.opened == [.notifications, .automation, .loginItems])
    }
}
