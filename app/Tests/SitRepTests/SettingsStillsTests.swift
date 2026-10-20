import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SwiftUI
import Testing

/// Settings' panes and the menu's images drawn offscreen into PNGs, to read beside Paper's drawings: only when
/// `SITREP_STILLS` names a folder for them, so a run of the tests writes nothing.
@MainActor
@Suite(.enabled(if: stills != nil))
struct SettingsStillsTests {

    private static let services = SettingsServices(
        displays: { [DisplayChoice.Connected(id: "A", name: "Built-in Retina Display", isMain: true)] },
        hasGlass: true, jump: { _ in }, sendTest: {},
        noticeLeave: { .allowed(.banners) }, askForNotices: {}, login: { LoginItem(.enabled) }, chooseLogin: {},
        ghostty: { .allowed }, open: { _ in }
    )

    private static func preferences(_ change: (inout EdgeSettings) -> Void = { _ in }) -> Preferences {
        let preferences = Preferences(UserDefaults(suiteName: "com.leeovery.sitrep.stills.\(UUID().uuidString)")!)

        preferences.edit(change)

        return preferences
    }

    private static func live(windows: [String] = []) -> LiveBoard {
        let live = LiveBoard()
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(stillsLine(windows: windows)), at: Date())
        live.last = last
        live.plugin = .running(.folder("~/Code/sitrep"), folder: "/Users/lee/Code/sitrep")

        return live
    }

    private static func render(_ view: some View, _ name: String, size: CGSize = CGSize(width: 500, height: 560)) throws {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height).preferredColorScheme(.dark))

        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))

        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: try #require(stills).appending(path: "\(name).png"))
    }

    @Test func atTheEdge() throws {
        try Self.render(EdgePaneView(preferences: Self.preferences(), services: Self.services), "settings-edge-notch")
        try Self.render(EdgePaneView(preferences: Self.preferences { $0.show = .strip }, services: Self.services), "settings-edge-strip")
        try Self.render(EdgePaneView(preferences: Self.preferences { $0.show = .nothing }, services: Self.services), "settings-edge-nothing")
    }

    @Test func notifications() throws {
        try Self.render(
            NotificationsPaneView(preferences: Self.preferences(), services: Self.services, leave: .allowed(.banners)),
            "settings-notifications"
        )
    }

    @Test func general() throws {
        let old = Watched.window("w1", needsReload: true)
        let current = Watched.window("w2", needsReload: false)

        try Self.render(GeneralPaneView(live: Self.live(windows: [current, current]), services: Self.services, login: LoginItem(.enabled), ghostty: .allowed), "settings-general")
        try Self.render(GeneralPaneView(live: Self.live(windows: [old, current]), services: Self.services, login: LoginItem(.enabled), ghostty: .unasked), "settings-general-reload")
    }

    @Test func theWholeWindow() throws {
        let view = SettingsView(preferences: Self.preferences(), live: Self.live(), services: Self.services)

        try Self.render(view, "settings-window", size: CGSize(width: 700, height: 540))
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
