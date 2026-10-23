import AppKit

/// A window of SitRep's own, the SitRep window or About SitRep, which goes to the Space Lee is on only as SitRep
/// brings it forward (`comeForward()`). Otherwise it stays on its own Space: clicking a macOS notification activates
/// SitRep, and a window always moving to the active Space went to Lee's with it, before the jump took him away.
@MainActor
class ForwardWindow: NSWindow {
    private var isOrderingFront = false

    /// Brought forward on the Space Lee is on, out of the Dock where minimised, and keyed: the window moves to that
    /// Space as it orders front, which `.moveToActiveSpace` asks for, before SitRep activates, so the activation finds
    /// a window of SitRep's where Lee is and takes him to no other Space. Activated first, macOS went to the Space the
    /// window was last on. It keeps to its Space again once keyed: at once where SitRep is active, or else as the
    /// activation lands.
    func comeForward() {
        collectionBehavior.insert(.moveToActiveSpace)
        if isMiniaturized {
            deminiaturize(nil)
        }
        isOrderingFront = true
        makeKeyAndOrderFront(nil)
        isOrderingFront = false
        activateApp()
        if isKeyWindow {
            keepToItsSpace()
        }
    }

    /// Keyed while it orders front, as AppKit may key it first, it is not yet on Lee's Space, so it keeps
    /// `.moveToActiveSpace` until the order is done.
    override func becomeKey() {
        super.becomeKey()
        if !isOrderingFront {
            keepToItsSpace()
        }
    }

    /// SitRep made the active app: a seam, as a test never activates.
    func activateApp() {
        NSApp.activate()
    }

    private func keepToItsSpace() {
        collectionBehavior.remove(.moveToActiveSpace)
    }
}
