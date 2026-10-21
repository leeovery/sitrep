import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel
@testable import SitRepWindow
import SwiftUI
import Testing

/// Settings' page, About SitRep and the menu's images drawn offscreen into PNGs, to read beside Paper's drawings: only
/// when `SITREP_STILLS` names a folder for them, so a run of the tests writes nothing.
@MainActor
@Suite(.enabled(if: stills != nil))
struct SettingsStillsTests {

    private static let fine = MacSays(notices: .allowed(.banners), login: LoginItem(.enabled), ghostty: .allowed)

    /// The page over a Mac that says this, as the page reads it again as it appears.
    private static func page(_ preferences: Preferences, windows: [String], said: MacSays = fine) -> SettingsPage {
        let services = SettingsServices(
            displays: { [DisplayChoice.Connected(id: "A", name: "Built-in Retina Display", isMain: true)] },
            hasGlass: true, jump: { _ in }, sendTest: {},
            noticeLeave: { said.notices ?? .unasked }, askForNotices: {}, login: { said.login ?? LoginItem(.notFound) },
            chooseLogin: {}, ghostty: { said.ghostty ?? .unknown }, allowGhostty: { .allowed }, open: { _ in }
        )

        return SettingsPage(preferences: preferences, live: live(windows: windows), services: services, said: said)
    }

    private static func preferences(_ change: (inout EdgeSettings) -> Void = { _ in }) -> Preferences {
        let preferences = Preferences(UserDefaults(suiteName: "com.leeovery.sitrep.stills.\(UUID().uuidString)")!)

        preferences.edit(change)
        preferences.app.notifiesNewAsks = true

        return preferences
    }

    private static func live(windows: [String]) -> LiveBoard {
        let live = LiveBoard()
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(stillsLine(windows: windows)), at: Date())
        live.last = last
        live.plugin = .running(.folder("~/Code/sitrep"), folder: "/Users/lee/Code/sitrep")

        return live
    }

    private static func render(_ view: some View, _ name: String, size: CGSize) throws {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height).environment(\.colorScheme, .dark))

        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))

        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: try #require(stills).appending(path: "\(name).png"))
    }

    /// The window on Settings, the sidebar's stand-in with Settings picked at its foot, as tall as `height`.
    private static func window(_ page: SettingsPage, _ name: String, height: CGFloat = WindowStyle.size.height) throws {
        let view = HStack(spacing: 0) {
            BoardColumn(listed: Listed(), pick: .settings, now: Date()).frame(width: WindowStyle.boardWidth)
            PageColumn(page: .settings, now: Date()) { page }
        }
        .environment(\.isStill, true)

        try render(view, name, size: CGSize(width: WindowStyle.size.width, height: height))
    }

    @Test(arguments: EdgeSettings.Show.allCases)
    func theWindowOnSettings(show: EdgeSettings.Show) throws {
        let page = Self.page(Self.preferences { $0.show = show }, windows: [Watched.window("w2", needsReload: false)])

        try Self.window(page, "settings-\(show.title.lowercased())")
    }

    @Test func theWholePage() throws {
        let page = Self.page(Self.preferences(), windows: [Watched.window("w2", needsReload: false)])

        try Self.window(page, "settings-whole", height: 1500)
    }

    /// A dot when it's fine, a button when it's Lee's: windows on an older plugin, Ghostty not asked, banners off.
    @Test func whenARowNeedsSomething() throws {
        let old = Watched.window("w1", needsReload: true)
        let said = MacSays(notices: .denied, login: LoginItem(.requiresApproval), ghostty: .unasked)
        let page = Self.page(Self.preferences(), windows: [old, old], said: said)

        try Self.window(page, "settings-needs-lee", height: 1500)
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

/// A board for the stills: the menu drawing's sessions.
private func stillsLine(windows: [String]) -> String {
    """
    {"v":1,"at":1792445574706,"version":"0.2.0","head":{"needYou":1,"sessions":1},"rows":[],"projects":[],\
    "windows":[\(windows.joined(separator: ","))],"new":[],"changed":[]}
    """
}

private enum Watched {
    static func window(_ writer: String, needsReload: Bool) -> String {
        """
        {"writer":"\(writer)","session":"sr-aw3bgs","name":"The Mac app","project":"SitRep",\
        "version":"\(needsReload ? "0.1.0" : "0.2.0")","needsReload":\(needsReload),"where":null,"state":null,\
        "attachedAt":1792440000000}
        """
    }
}
