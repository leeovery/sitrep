import AppKit
import SitRepEdge
import SitRepPanel

/// One way of drawing the strip, in black or in glass: a frame at a time.
@MainActor
protocol StripDrawing: NSView {
    func show(_ scene: StripScene)
}

/// One frame as a drawing draws it, in the stage's coordinates, x into the screen from its edge: the drawing puts it
/// through the edge's mirror, and hangs it from the menu bar its window starts under.
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
    /// Whether to reduce motion: a working tab's title is still, in ink, as the prototype's is.
    let reducesMotion: Bool

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
        var frame = words.frame

        if mirror.a < 0 {
            frame.origin.x = tab.box.width - frame.maxX
        }

        return frame
    }
}
