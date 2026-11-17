import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// Settings' panes, About SitRep and the menu's images drawn offscreen into PNGs, to read beside Paper's drawings: only
/// when `SITREP_STILLS` names a folder for them, so a run of the tests writes nothing.
@MainActor
@Suite(.backstop, .enabled(if: stills != nil))
struct SettingsStillsTests {

    private static let fine = MacSays(notices: .allowed(.banners), login: LoginItem(.enabled), ghostty: .allowed)

    /// Settings over a Mac that says this, read as the window reads it as a pane comes into sight.
    private static func settings(_ preferences: Preferences, windows: [WatchLine.Window], said: MacSays = fine) async -> SettingsModel {
        let settings = SettingsModel(
            preferences: preferences, live: live(windows: windows), services: Hosted.services(said: said)
        )

        settings.readDisplays()
        await settings.read()
        return settings
    }

    private static func preferences(_ change: (inout EdgeSettings) -> Void = { _ in }) -> Preferences {
        let preferences = Preferences(MemoryDefaults())

        preferences.edit(change)
        preferences.app.notifiesNewAsks = true

        return preferences
    }

    /// A window on Trey Research's The desktop app, on an older plugin or not.
    private static func window(_ writer: String, needsReload: Bool) -> WatchLine.Window {
        WatchLine.Window(
            writer: writer, session: "sr-a8n2xc", name: "The desktop app", project: "Trey Research",
            version: needsReload ? "0.1.0" : "0.2.0", needsReload: needsReload
        )
    }

    /// A board for the stills: the menu drawing's sessions.
    private static func live(windows: [WatchLine.Window]) -> LiveBoard {
        let live = LiveBoard()
        var last = LastBoard()
        let line = WatchLine(version: "0.2.0", head: .init(needYou: 1, sessions: 1), windows: windows)

        last.begin()
        _ = last.hear(.line(line.text), at: Date())
        live.last = last
        live.plugin = .running(.folder("~/Code/sitrep"), folder: "/Users/me/Code/sitrep")

        return live
    }

    private static func render(
        _ view: some View, _ name: String, size: CGSize, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height).environment(\.colorScheme, .dark))

        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        let bitmap = try #require(
            hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds), sourceLocation: sourceLocation
        )

        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:]), sourceLocation: sourceLocation)
            .write(to: try #require(stills, sourceLocation: sourceLocation).appending(path: "\(name).png"))
    }

    /// A pane as the window shows it beside the sidebar, unscrolled, on the window's background, at the window's first
    /// size unless `width` says.
    private static func pane(
        _ pane: SettingsPane, _ settings: SettingsModel, _ name: String,
        width: CGFloat = SettingsWindow.size.width - 188
    ) throws {
        let view = SettingsPaneContent(pane: pane, settings: settings)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor))

        try render(view, "settings-\(name)", size: CGSize(width: width, height: SettingsWindow.size.height))
    }

    private static let current = [window("w2", needsReload: false)]

    @Test(arguments: SettingsPane.allCases)
    func eachPane(pane: SettingsPane) async throws {
        try Self.pane(pane, await Self.settings(Self.preferences(), windows: Self.current), pane.rawValue)
    }

    /// Resume command with a command of Lee's given, so Restore Default is enabled.
    @Test func generalWithACommandGiven() async throws {
        let preferences = Self.preferences()

        preferences.app.resumeCommand = "portal open --claude {claude} -p {dir}"
        try Self.pane(.general, await Self.settings(preferences, windows: Self.current), "general-command")
    }

    @Test(arguments: [EdgeSettings.Show.strip, .nothing])
    func edgeAtEachChoice(show: EdgeSettings.Show) async throws {
        let settings = await Self.settings(Self.preferences { $0.show = show }, windows: Self.current)

        try Self.pane(.edge, settings, "edge-\(show.title.lowercased())")
    }

    /// A dot when it's fine, a button when it's Lee's: Ghostty not asked, opening at login waiting, banners off, and
    /// windows on an older plugin.
    @Test(arguments: [SettingsPane.general, .notifications, .claudeCode])
    func whenARowNeedsSomething(pane: SettingsPane) async throws {
        let old = [Self.window("w1", needsReload: true), Self.window("w3", needsReload: true)]
        let said = MacSays(notices: .denied, login: LoginItem(.requiresApproval), ghostty: .unasked)
        let settings = await Self.settings(Self.preferences(), windows: old, said: said)

        try Self.pane(pane, settings, "\(pane.rawValue)-needs-lee")
    }

    /// At the window's least width.
    @Test(arguments: SettingsPane.allCases)
    func eachPaneAtItsNarrowest(pane: SettingsPane) async throws {
        let settings = await Self.settings(Self.preferences(), windows: Self.current)

        try Self.pane(pane, settings, "\(pane.rawValue)-narrowest", width: SettingsWindow.smallest.width - 188)
    }

    @Test func aboutSitRep() throws {
        try Self.render(AboutView().background(Color(nsColor: .windowBackgroundColor)), "about", size: CGSize(width: 308, height: 313))
    }

    @Test func theMenusImages() throws {
        let images: [(String, NSImage)] = [
            ("glyph-rest", MenuImages.glyph(.rest)), ("glyph-lit", MenuImages.glyph(.lit)),
            ("mark-needs", MenuImages.mark(Session(id: "", project: "", kind: .needs, title: "", sub: "", since: 0))),
            ("mark-turn", MenuImages.mark(Session(id: "", project: "", kind: .turn, title: "", sub: "", since: 0))),
            ("mark-working", MenuImages.mark(Session(id: "", project: "", kind: .working, title: "", sub: "", since: 0))),
        ]

        for (name, image) in images {
            let size = NSSize(width: image.size.width * 4, height: image.size.height * 4)
            let bitmap = try #require(NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ))

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            NSColor(white: 0.12, alpha: 1).setFill()
            NSRect(origin: .zero, size: size).fill()
            NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
                Self.inked(image).draw(in: NSRect(origin: .zero, size: size))
            }
            NSGraphicsContext.restoreGraphicsState()
            try #require(bitmap.representation(using: .png, properties: [:]))
                .write(to: try #require(stills).appending(path: "menu-\(name).png"))
        }
    }
}

extension SettingsStillsTests {
    /// A template image as a dark menu draws it, in white; any other as it is.
    fileprivate static func inked(_ image: NSImage) -> NSImage {
        guard image.isTemplate else {
            return image
        }

        return NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor.white.setFill()
            rect.fill(using: .sourceIn)
            return true
        }
    }
}

/// Where the stills go.
private let stills = ProcessInfo.processInfo.environment["SITREP_STILLS"].map(URL.init(fileURLWithPath:))
