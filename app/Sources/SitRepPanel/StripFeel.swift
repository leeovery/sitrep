/// How the strip moves: its prototype's defaults, which Lee kept (18 October 2026). It ships fixed, with no dials, as
/// the notch's does; a test may vary it. Its shape and its tabs' ways are his choices, built in: the ends are the
/// board's S, at the top and mirrored at the bottom, never changing, a tab fitting into them; between marks a tab
/// glides; while marks slide it keeps with its mark.
struct StripFeel: Feel, Equatable, Sendable {
    var bounce = 0.50
    /// How long the pointer rests on a mark before the first tab pours out.
    var dwell = 120.0
    /// How far the strip's edge bows toward the pointer during the dwell.
    var reach = 3.0
    /// How fast a tab pours out, glides along the strip, and draws back: 2× is twice as quick.
    var pour = 1.00
    var glide = 1.00
    /// How long the words take to cross as a tab glides.
    var fade = 160.0
    var close = 1.00
    /// How much further the first mark sits under the top end's S, and the last over the bottom end's, every mark
    /// moving with it, so a tab's edge meets the S under its bump with room for its fillet.
    var room = 12.0
    /// How long a tab waits after the pointer leaves, down to a fifth of it on a fast leave.
    var grace = 300.0
    /// How long after the pointer leaves the strip the marks re-sort.
    var settle = 1000.0
    /// How fast the marks slide to their places.
    var slide = 1.00
    /// Length, Grows: how far the strip's ends lead the marks as it grows, and follow them as it shrinks; 1× moves
    /// them together.
    var lead = 1.25
    /// How many times a new mark's ring flashes.
    var swells = 2

    static let lees = StripFeel()

    /// A spring after Bounce, and as fast as its speed makes it (the prototype's `SP`).
    func sp(_ kind: StripSpring) -> SpringParams {
        let speed = switch kind {
        case .reach, .pour, .grow: pour
        case .glide, .width: glide
        case .draw: close
        case .slide, .arrive: slide
        case .press, .morph: 1.0
        }
        return kind.listed.after(bounce: bounceScale, speed: speed)
    }

    /// Length, Grows: the ends' spring, the marks' slide quicker by Lead as the strip grows, so the black is there
    /// before the marks, and slower by it otherwise, so as it shrinks the marks are in before the black follows.
    func ends(growing: Bool) -> SpringParams {
        let slide = sp(.slide)
        return SpringParams(response: slide.response * (growing ? 1 / lead : lead), damping: slide.damping)
    }
}

/// The strip prototype's springs (its `SPRINGS`), in its order.
enum StripSpring: CaseIterable, Sendable {
    case reach, pour, grow, glide, width, draw, slide, arrive, press, morph

    /// As listed, before Bounce and the speeds.
    var listed: SpringParams {
        switch self {
        // the edge bowing toward the pointer during the dwell
        case .reach: SpringParams(response: 0.20, damping: 0.70)
        // the tab's depth out of the strip, ...
        case .pour: SpringParams(response: 0.26, damping: 0.72)
        // ... and its body, from the mark's 24 to the row's 52
        case .grow: SpringParams(response: 0.22, damping: 0.80)
        // along the strip to the next mark, ...
        case .glide: SpringParams(response: 0.24, damping: 0.82)
        // ... its width and body after the next row
        case .width: SpringParams(response: 0.24, damping: 0.86)
        // back into the strip, a little past into a dent
        case .draw: SpringParams(response: 0.22, damping: 0.80)
        // the marks to their places
        case .slide: SpringParams(response: 0.36, damping: 0.80)
        // a new mark growing into its place
        case .arrive: SpringParams(response: 0.30, damping: 0.55)
        // a click pressing the tab, or the ring, in
        case .press: SpringParams(response: 0.10, damping: 0.70)
        // Grows: the column into the notch at rest, and back out
        case .morph: SpringParams(response: 0.42, damping: 0.86)
        }
    }
}
