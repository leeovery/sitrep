/// The card's own constants (card.html's, from `FIELD` to `SEATED`), each with its value unchanged and a name close
/// to its own; those it shares with Meniscus's prototype are `Tuning`'s.
enum CardTuning {
    // The approach: Meniscus's field at Pull 0.35. Within it, the notch eases out toward the pointer by up to Nudge,
    // pulled as 1/(gap + `nudgeD0`) as Meniscus's tongue is, so it grows sharply as the gap closes, and it is all the
    // way out as the pointer touches its hit area.

    /// The field's reach from the edge (140 × Pull 0.35), ...
    static let field = 49.0
    /// ... and along it, whole within this of the notch's centre, fading to nothing at `Tuning.fieldY`.
    static let fieldYFull = 90.0
    static let nudgeD0 = 10.0

    // Opening: the depth springs out of the notch to the panel's, and Lag into the slide (÷ Slide) the length starts
    // springing out to the panel's too, both ways from its centre, while the depth is still sliding.

    /// The rows land once the depth is within this of the panel's, ...
    static let depthLands = 12.0
    /// ... and the length within this of the panel's.
    static let lengthLands = 4.0

    // Closing mirrors it: the rows fade, the length starts shrinking back to the notch's, and Lag later (÷ Close) the
    // depth starts home on a critically damped spring, so it eases over its last few points and seats in the slot,
    // never past it.

    /// The card starts back this long into the rows' fade (÷ Close).
    static let closeAt = 50.0
    /// The light comes back as the depth comes within this of home.
    static let lightBack = 30.0
    /// Closer than this, it is home.
    static let seated = 0.3
}
