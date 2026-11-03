import AppKit
import SitRepMenu
import SwiftUI

/// The notch or the strip, as the callout beside it sees it: whether it shows, where it rests, and the pointer over it.
@MainActor
protocol CalloutShape: AnyObject {
    var isShown: Bool { get }
    /// The shape at rest, from the edge to its front, level with the notch's home, on the screen: from the targets it
    /// moves to, never a frame it moves through.
    var restingBand: CGRect { get }
    /// The pointer over the shape, told each frame it is.
    var onPointedAt: () -> Void { get set }
}

/// The callout a welcome's Done leaves beside the real notch, or the strip, at rest (DESIGN, "The welcome window"):
/// the stage's own, "Your notch. Point at it.", beside whichever shape shows, while it is due. Due while neither shows,
/// at Nothing or under a full-screen app, it waits for one to show. The first hover over the shape takes it away for
/// good, saved, so it shows once; from then on the shapes tell it nothing. Where it stands is told to `place`, a seam,
/// as a test never shows a window.
@MainActor
final class EdgeCallout {
    /// The shape it stands beside, from the edge to the shape's front on the screen, and whether that is the right
    /// edge.
    struct Beside: Equatable {
        var band: CGRect
        var isRight: Bool
    }

    private let preferences: Preferences
    private let shapes: [any CalloutShape]
    private let isRight: () -> Bool
    private let place: (Beside?) -> Void
    private var placed: Beside?

    /// `shapes` in the order they are looked at, the first showing the one it stands beside.
    init(
        _ preferences: Preferences, shapes: [any CalloutShape], isRight: @escaping () -> Bool,
        place: @escaping (Beside?) -> Void
    ) {
        self.preferences = preferences
        self.shapes = shapes
        self.isRight = isRight
        self.place = place
        preferences.onCallout = { [weak self] _ in self?.refresh() }
        listen()
    }

    /// The shapes as they now stand: the callout beside the one showing while it is due, else nowhere.
    func refresh() {
        let shape = shapes.first(where: \.isShown)
        let beside = preferences.callout.shows ? shape.map { Beside(band: $0.restingBand, isRight: isRight()) } : nil

        guard beside != placed else {
            return
        }

        placed = beside
        place(beside)
    }

    /// The pointer over the shape: the callout, while it shows, gone for good, and the shapes told to stop telling.
    private func pointedAt() {
        guard preferences.callout.shows else {
            return
        }

        preferences.callout.pointedAt()
        listen()
    }

    /// The shapes tell of the pointer only while the callout may yet show.
    private func listen() {
        let listens = preferences.callout.standing != .gone

        for shape in shapes {
            shape.onPointedAt = listens ? { [weak self] in self?.pointedAt() } : {}
        }
    }
}

/// The callout's window on the real screen: clear and borderless, on every Space and taking no clicks, as the edge's
/// own are, its near side 14 past the shape's front and its middle level with the notch's home.
@MainActor
final class CalloutWindow {
    /// Past the shape's front, as on the stage.
    static let gap = 14.0
    /// Round the callout, for its shadow.
    static let room = 24.0

    private let window: EdgeWindow
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
    /// shape's front to the right; against the right, past it to the left.
    static func frame(_ beside: EdgeCallout.Beside, size: CGSize) -> CGRect {
        let band = beside.band
        let x = beside.isRight ? band.minX - gap + room - size.width : band.maxX + gap - room

        return CGRect(x: x, y: band.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// The stage's callout, at its own size, the room round it.
    private struct Content: View {
        let isRight: Bool

        var body: some View {
            NotchCallout(isRight: isRight).fixedSize().padding(CalloutWindow.room)
        }
    }
}
