import AppKit
@testable import SitRep
import SitRepPanel
import SwiftUI
import Testing

/// What stays on screen's card as a choice changes: its rows and its height change at once, with no motion, in the
/// frame the Show row's tiles change in (Lee, 22 October 2026: "the animation on the panel when switching the notch
/// mode is a bit jarring"). On the real page in a window at 2×, drawn as soon as the choice changes.
@MainActor
struct StaysOnScreenCardTests {
    /// A change to the card's choices, from where it starts.
    enum Change: CaseIterable, Sendable {
        case notchToStrip, stripToNothing, growsToFull

        func start(_ edge: inout EdgeSettings) {
            switch self {
            case .notchToStrip: edge.show = .notch
            case .stripToNothing, .growsToFull: edge.show = .strip
            }
        }

        func change(_ edge: inout EdgeSettings) {
            switch self {
            case .notchToStrip: edge.show = .strip
            case .stripToNothing: edge.show = .nothing
            case .growsToFull: edge.length = .full
            }
        }

        /// The card's top and foot once changed: the Show row's 86, then each row under it with its hairline: the
        /// strip's six; at Full, five, Max gone; at Nothing, none.
        var card: ClosedRange<CGFloat> {
            switch self {
            case .notchToStrip: 146 ... 533
            case .stripToNothing: 146 ... 232
            case .growsToFull: 146 ... 480.5
            }
        }

        /// The card's foot before the change, past which what it held is read for what is left of it.
        var footBefore: CGFloat {
            self == .notchToStrip ? 480.5 : 533
        }
    }

    private static let size = CGSize(width: 956, height: 1069)

    /// Down the column, clear of the Show row's pictures.
    private static let column: CGFloat = 276

    /// The page drawn straight after `change`, and the page drawn with it made before the page appeared.
    private static func drawn(_ change: Change) async throws -> (changed: Drawn, settled: Drawn) {
        let page = await Hosted.pageView(change.start)
        let hosted = Hosted(PageColumn(page: .settings, now: Date()) { page }, size: size)
        let settledPage = await Hosted.pageView { change.start(&$0); change.change(&$0) }
        let settled = Hosted(PageColumn(page: .settings, now: Date()) { settledPage }, size: size)

        page.settings.preferences.edit(change.change)
        await Task.yield()
        hosted.hosting.layoutSubtreeIfNeeded()

        return try (atTwice(Drawn(hosted.hosting)), atTwice(Drawn(settled.hosting)))
    }

    /// Read at 2×, as `ShowRowTests` reads the page.
    private static func atTwice(_ drawn: Drawn) throws -> Drawn {
        try #require(drawn.scale == 2, "Laid out at the screen's \(drawn.scale)×; these tests read it at 2×")
        return drawn
    }

    /// The card's height is the new one as soon as the choice changes.
    @Test(arguments: Change.allCases)
    func theCardTakesItsNewHeightAtOnce(change: Change) async throws {
        let drawn = try await Self.drawn(change).changed
        let card = try #require(drawn.litSpans(atX: Self.column).first)

        #expect(change.card.isWithinAPixel(of: card, at: drawn.scale))
    }

    /// As soon as the choice changes, the card and what follows it to where the old card ended are drawn to the pixel
    /// as the page drawn with the choice already made: the new rows whole, in their places, at full opacity, and
    /// nothing left of the old ones. Across the column's left half, where every row's words and hairlines are, clear of
    /// the desktop corner's clock.
    @Test(arguments: Change.allCases)
    func theRowsChangeAtOnce(change: Change) async throws {
        let (changed, settled) = try await Self.drawn(change)
        let rows = CGRect(x: 0, y: 146, width: Self.size.width / 2, height: change.footBefore + 10 - 146)

        #expect(changed.pixels(in: rows) == settled.pixels(in: rows))
    }
}
