import AppKit
import SitRepEdge
import SitRepPanel

/// One frame as the strip draws it, in the stage's coordinates, x into the screen from its edge: `StripView` puts it
/// through the edge's mirror, and hangs it from the menu bar its window starts under. The asks panel and the tab's
/// arrow with it.
struct StripScene {
    let frame: StripFrame
    /// The count's row under the pointer, by its mark's key (`Session.markID`).
    let hoverRow: String?
    let note: StripNote
    /// The wall clock, ms, which the rows' times count on.
    let now: Double
    /// The stage into the window: mirrored on the right edge.
    let mirror: CGAffineTransform
    /// The menu bar's height: the stage starts this far above the window.
    let menu: Double
    /// Whether to reduce motion: a working tab's title is still, in ink, as the prototype's is, and the arrow turns at
    /// once.
    let reducesMotion: Bool
    /// The tab's arrow, where it shows, by its session's mark's key, lit or not (`StripRun.arrow`).
    var arrow: (row: String, isLit: Bool)?
    /// The asks panel, while it is open.
    var asks: AsksShown?

    /// The arrow on these words, where they are its tab's session's row: lit or not, pointing toward where the asks
    /// panel opens, away from the screen's edge, and turned while the asks panel is open beside the tab.
    func arrow(on words: StripFrame.Words) -> ArrowButton.Look? {
        guard let arrow, case let .row(session) = words.content, session.markID == arrow.row else {
            return nil
        }

        return ArrowButton.Look(
            isLit: arrow.isLit, pointsLeft: mirror.a < 0, isTurned: asks?.row == arrow.row, turnsAtOnce: reducesMotion
        )
    }

    /// A mark's centre, through the mirror.
    func centre(_ mark: StripFrame.Mark) -> CGPoint {
        mark.centre.applying(mirror)
    }

    /// A tab's words' box, through the mirror.
    func box(_ tab: StripFrame.Tab) -> CGRect {
        tab.box.applying(mirror)
    }

    /// The tab's clip in its box's frame, its front corners rounded.
    func clip(_ tab: StripFrame.Tab) -> CGPath {
        frontRounded(tab.clip, top: tab.radius, bottom: tab.radius, through: mirror, from: box(tab).origin)
    }

    /// Which side of a tab's words the strip is: 0 their left, on the left edge, 1 their right.
    var stripSide: Double { mirror.a < 0 ? 1 : 0 }

    /// One of a tab's words in its box, against the strip on either edge: mirrored, the box's far side is the strip's.
    func frame(_ words: StripFrame.Words, in tab: StripFrame.Tab) -> CGRect {
        tab.frame(of: words, mirrored: mirror.a < 0)
    }
}
