import AppKit

/// A window of SitRep's own, Settings, the welcome or About SitRep, which goes to the Space Lee is on only as SitRep
/// brings it forward (`comeForward()`). Otherwise it stays on its own Space, however SitRep is activated: a window
/// always moving to the active Space went to Lee's with a notification's click, ahead of the jump, when SitRep posted
/// them itself.
@MainActor
class ForwardWindow: NSWindow {
    /// Brought forward on the Space Lee is on, out of the Dock where minimised, and keyed: the window moves to that
    /// Space as it orders front, which `.moveToActiveSpace` asks for, before SitRep activates, so the activation finds
    /// a window of SitRep's where Lee is and takes him to no other Space. Activated first, macOS went to the Space the
    /// window was last on. It holds `.moveToActiveSpace` until Lee next changes Space: cleared as the activation keyed
    /// it, macOS took him to the window's last Space all the same (24 October 2026); and while he stays, the window is
    /// on his Space already, so a notification's click moves it nowhere.
    func comeForward() {
        collectionBehavior.insert(.moveToActiveSpace)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
        if isMiniaturized {
            deminiaturize(nil)
        }
        makeKeyAndOrderFront(nil)
        activateApp()
    }

    /// SitRep made the active app: a seam, as a test never activates.
    func activateApp() {
        NSApp.activate()
    }

    @objc private func spaceChanged(_ notification: Notification) {
        collectionBehavior.remove(.moveToActiveSpace)
        NSWorkspace.shared.notificationCenter.removeObserver(
            self, name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
    }
}
