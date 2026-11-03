import AppKit
import SitRepMenu
import SwiftUI

/// The callout a welcome's Done leaves beside the real notch, or the strip, at rest (DESIGN, "The welcome window"):
/// the stage's own, "Your notch. Point at it.", while it is due and the shape shows, following the shape as Lee moves
/// it. The first hover over the shape takes it away for good, saved, so it shows once. Where it stands is told to
/// `place`, a seam, as a test never shows a window.
@MainActor
final class EdgeCallout {
    /// The shape it stands beside, on the screen, and whether that is against the right edge.
    struct Beside: Equatable {
        var resting: CGRect
        var isRight: Bool
    }

    private let preferences: Preferences
    private let place: (Beside?) -> Void
    /// The shape showing at the edge, as last told; nil while neither shows.
    private var shape: Beside?
    private var placed: Beside?

    init(_ preferences: Preferences, place: @escaping (Beside?) -> Void) {
        self.preferences = preferences
        self.place = place
        preferences.onCallout = { [weak self] _ in self?.replace() }
    }

    /// The shape at the edge as it now stands, nil while neither shows: the callout beside it while it is due.
    func beside(_ shape: Beside?) {
        self.shape = shape
        replace()
    }

    /// The pointer over the shape: the callout, if it shows, gone for good.
    func pointedAt() {
        preferences.callout.pointedAt()
    }

    /// Told `place` only as where it stands changes.
    private func replace() {
        let beside = preferences.callout.shows ? shape : nil

        guard beside != placed else {
            return
        }

        placed = beside
        place(beside)
    }
}

/// The callout's window on the real screen: clear and borderless, on every Space and taking no clicks, as the edge's
/// own are, its near side 14 past the shape's front and its middle level with the shape's.
@MainActor
final class CalloutWindow {
    /// Past the shape's front, as on the stage.
    static let gap = 14.0
    /// Round the callout, for its shadow.
    static let room = 24.0

    /// Its window: internal only for the tests, which read that it shows nothing until placed.
    let window: EdgeWindow
    private let host = NSHostingView(rootView: Content(isRight: false))

    init() {
        host.sizingOptions = []
        window = EdgeWindow.onScreen(frame: .zero, view: host)
    }

    /// Shown beside the shape, or hidden.
    func place(_ beside: EdgeCallout.Beside?) {
        guard let beside else {
            window.isShown = false
            return
        }

        host.rootView = Content(isRight: beside.isRight)
        window.setFrame(Self.frame(beside, size: host.fittingSize), display: true)
        window.isShown = true
    }

    /// Its window's frame on the screen, room for its shadow round it: against the left edge, its near side past the
    /// shape's right; against the right, past the shape's left.
    static func frame(_ beside: EdgeCallout.Beside, size: CGSize) -> CGRect {
        let shape = beside.resting
        let x = beside.isRight ? shape.minX - gap + room - size.width : shape.maxX + gap - room

        return CGRect(x: x, y: shape.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// The stage's callout, at its own size, the room round it.
    private struct Content: View {
        let isRight: Bool

        var body: some View {
            NotchCallout(isRight: isRight).fixedSize().padding(CalloutWindow.room)
        }
    }
}
