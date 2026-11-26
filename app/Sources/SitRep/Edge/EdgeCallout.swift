import AppKit
import SitRepMenu
import SwiftUI

/// The notch, as the callout beside it sees it: whether it shows, where it rests, and each frame it draws.
@MainActor
protocol CalloutShape: AnyObject {
    var isShown: Bool { get }
    /// The shape at rest, from the edge to its front, level with the notch's home, on the screen: from the targets it
    /// moves to, never a frame it moves through.
    var restingBand: CGRect { get }
    /// Each frame the shape draws, while set, with whether the pointer is over it.
    var onDrawn: ((_ isPointedAt: Bool) -> Void)? { get set }
}

/// The callout a welcome's Done leaves beside the real notch at rest (DESIGN, "The welcome window"): the stage's own,
/// "Your notch. Point at it.", beside the notch while it shows, while it is due. Due while the notch is hidden, at
/// Nothing or under a full-screen app, it waits for it to show. The first hover over the notch takes it away for good,
/// saved, so it shows once. The notch tells it of its frames only while it is due, so it follows the notch's front as
/// it lights and goes dark, which the notch takes in its next frame. Where it stands is told to `place`, a seam, as a
/// test never shows a window.
@MainActor
final class EdgeCallout {
    /// The shape it stands beside, from the edge to the shape's front on the screen, and whether that is the right
    /// edge.
    struct Beside: Equatable {
        var band: CGRect
        var isRight: Bool
    }

    private let preferences: Preferences
    private let shape: any CalloutShape
    private let isRight: () -> Bool
    private let place: (Beside?) -> Void
    private var placed: Beside?

    init(
        _ preferences: Preferences, shape: any CalloutShape, isRight: @escaping () -> Bool,
        place: @escaping (Beside?) -> Void
    ) {
        self.preferences = preferences
        self.shape = shape
        self.isRight = isRight
        self.place = place
        preferences.onCallout = { [weak self] _ in
            self?.listen()
            self?.refresh()
        }
        listen()
    }

    /// The notch as it now stands: the callout beside it while it shows and the callout is due, else nowhere. Told
    /// with each board and, while due, each frame: only a change is placed.
    func refresh() {
        let shows = preferences.callout.shows && shape.isShown
        let beside = shows ? Beside(band: shape.restingBand, isRight: isRight()) : nil

        guard beside != placed else {
            return
        }

        placed = beside
        place(beside)
    }

    /// The notch tells of its frames only while the callout is due: the first with the pointer over it takes it away
    /// for good; any other may have moved the notch's front.
    private func listen() {
        shape.onDrawn = preferences.callout.shows ? { [weak self] in self?.drawn(isPointedAt: $0) } : nil
    }

    private func drawn(isPointedAt: Bool) {
        if isPointedAt {
            preferences.callout.pointedAt()
        } else {
            refresh()
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
