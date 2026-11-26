import AppKit
@testable import SitRep
import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// Edge as a choice changes: its sections, their rows and the pane's height change at once, with no motion, in the
/// frame the Show row's tiles change in (Lee, 22 October 2026: "the animation on the panel when switching the notch
/// mode is a bit jarring"). On the real pane in a window at 2×, drawn as soon as the choice changes.
@MainActor
@Suite(.backstop)
struct EdgePaneChangeTests {
    /// A change to Edge's choices, from where it starts.
    enum Change: CaseIterable, Sendable {
        case notchToNothing, nothingToNotch

        func start(_ edge: inout EdgeSettings) {
            edge.show = self == .notchToNothing ? .notch : .nothing
        }

        func change(_ edge: inout EdgeSettings) {
            edge.show = self == .notchToNothing ? .nothing : .notch
        }

        /// The cards once changed: the Show row's 86, then the notch's section, its header's 16 and 10 over its card,
        /// and Motion's, 26 apart, the notch's three rows with their hairlines; at Nothing, the Show row's card alone.
        var cards: [ClosedRange<CGFloat>] {
            switch self {
            case .notchToNothing: [13 ... 99]
            case .nothingToNotch: [13 ... 99, 151 ... 294, 346 ... 398]
            }
        }

        /// The last card's foot before the change, past which what the pane held is read for what is left of it.
        var footBefore: CGFloat {
            self == .notchToNothing ? 398 : 99
        }
    }

    private static let size = CGSize(width: 744, height: 620)

    /// Down the column, clear of the Show row's pictures.
    private static let column: CGFloat = 252

    /// Edge in a window, its settings started by `settings`.
    private static func hosted(_ settings: (inout EdgeSettings) -> Void) async -> (settings: SettingsModel, hosted: Hosted) {
        let model = await Hosted.settings(settings)

        return (model, Hosted(Hosted.content(.edge, model), size: size))
    }

    /// Edge drawn straight after `change`.
    private static func changed(_ change: Change) async throws -> Drawn {
        let (settings, hosted) = await hosted(change.start)

        settings.preferences.edit(change.change)
        hosted.hosting.layoutSubtreeIfNeeded()

        return try Drawn(hosted.hosting).atTwice()
    }

    /// Edge drawn with `change` made before it appeared.
    private static func settled(_ change: Change) async throws -> Drawn {
        try await Drawn(hosted { change.start(&$0); change.change(&$0) }.hosted.hosting).atTwice()
    }

    /// The cards stand at their new heights as soon as the choice changes.
    @Test(arguments: Change.allCases)
    func theCardsTakeTheirNewHeightsAtOnce(change: Change) async throws {
        let drawn = try await Self.changed(change)
        let cards = drawn.litSpans(atX: Self.column)

        #expect(cards.count == change.cards.count)
        for (card, expected) in zip(cards, change.cards) {
            #expect(expected.isWithinAPixel(of: card, at: drawn.scale))
        }
    }

    /// How far past the taller pane's foot is read, so a hairline or an edge left just under it is read too.
    private static let pastTheFoot: CGFloat = 10

    /// As soon as the choice changes, the pane to the foot of the taller of the old and the new is drawn to the pixel
    /// as the pane drawn with the choice already made: the new sections whole, in their places, at full opacity, and
    /// nothing left of the old ones. Across the column's left half, where every row's words and hairlines are.
    @Test(arguments: Change.allCases)
    func theSectionsChangeAtOnce(change: Change) async throws {
        let changed = try await Self.changed(change)
        let settled = try await Self.settled(change)
        let top = change.cards[0].lowerBound
        let foot = max(change.footBefore, change.cards.last?.upperBound ?? 0) + Self.pastTheFoot
        let rows = CGRect(x: 0, y: top, width: Self.size.width / 2, height: foot - top)

        #expect(changed.pixels(in: rows) == settled.pixels(in: rows))
    }
}
