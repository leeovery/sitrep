import AppKit
import os
import ServiceManagement
import SitRepCore

/// The menu bar item and its plain menu: the works on screen, read afresh
/// each time the menu opens, then the test banner, starting at login, and
/// quitting.
///
/// An NSStatusItem rather than SwiftUI's MenuBarExtra: a menu-style
/// MenuBarExtra tells nothing as its menu opens, and NSMenuDelegate does.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private static let looking = "Looking for works on screen…"
    private static let noneOnScreen = "No work is on screen"

    private let works: Works
    private let banners: Banners
    private let loginLog = Logger(sitrep: "login")
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let loginItem = NSMenuItem(title: "", action: #selector(toggleLogin), keyEquivalent: "")
    /// The menu items of the works section, which every opening replaces.
    private var shown: [NSMenuItem] = []
    /// Which opening a listing answers, so one landing late never overwrites a newer one.
    private var opening = 0

    init(works: Works, banners: Banners) {
        self.works = works
        self.banners = banners
        super.init()

        item.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "SitRep")
        menu.autoenablesItems = false
        menu.delegate = self
        loginItem.target = self
        menu.items = [
            .separator(),
            action("Send a test banner", #selector(sendTestBanner)),
            loginItem,
            .separator(),
            action("Quit SitRep", #selector(quit)),
        ]
        item.menu = menu
    }

    /// The works are listed off the main thread, so the menu opens at once
    /// and takes them in, as it stays open, once they come.
    func menuWillOpen(_ menu: NSMenu) {
        opening += 1
        let answering = opening

        showWorks([line(Self.looking)])
        showLoginItem()
        Task {
            let listed = await works.list()

            if answering == opening {
                showWorks(items(for: listed))
            }
        }
    }

    private func items(for listed: ListAnswer) -> [NSMenuItem] {
        switch listed {
        case let .failed(why):
            return [line(why)]
        case let .works(onScreen) where onScreen.isEmpty:
            return [line(Self.noneOnScreen)]
        case let .works(onScreen):
            return onScreen.map(jumpItem)
        }
    }

    private func jumpItem(_ work: OnScreen) -> NSMenuItem {
        let jump = action(work.label, #selector(jump(_:)))

        jump.representedObject = work.id
        jump.isEnabled = !works.isJumping

        return jump
    }

    private func showWorks(_ items: [NSMenuItem]) {
        shown.forEach(menu.removeItem)
        items.reversed().forEach { menu.insertItem($0, at: 0) }
        shown = items
    }

    private func showLoginItem() {
        let status = SMAppService.mainApp.status
        let login = LoginItem(status)

        loginLog.info("Login item: \(status.words, privacy: .public)")
        loginItem.title = login.title
        loginItem.state = login.isOn ? .on : login.needsApproval ? .mixed : .off
    }

    @objc private func jump(_ sender: NSMenuItem) {
        if let work = sender.representedObject as? String {
            works.jump(to: work)
        }
    }

    @objc private func sendTestBanner() {
        works.sendTestBanner()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp

        do {
            switch LoginItem(service.status).choice {
            case .register:
                try service.register()
            case .unregister:
                try service.unregister()
            case .openSettings:
                break
            }
        } catch {
            loginLog.error("Login item unchanged: \(error.localizedDescription, privacy: .public)")
            Task { await banners.post(.refused("SitRep could not change starting at login", error.localizedDescription)) }
        }

        loginLog.info("Login item now: \(service.status.words, privacy: .public)")

        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")

        item.target = self

        return item
    }

    private func line(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")

        item.isEnabled = false

        return item
    }
}
