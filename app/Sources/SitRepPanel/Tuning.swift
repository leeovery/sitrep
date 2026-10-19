/// The prototype's constants (meniscus.html's, from `MARGIN` to `ROWS_AT`), each with its value unchanged and a
/// name close to its own, so the port can be read beside it. Lengths are points (the prototype's px), times ms,
/// speeds points per ms. `BEZEL` has no counterpart: the model works from the screen's edge itself.
enum Tuning {
    /// The notch's home on the edge, this share of the way down the screen (meniscus.html's and card.html's), where
    /// the strip centres at Grows too.
    static let notchAt = 0.42
    /// The panel keeps this far inside the screen's visible frame, top and bottom.
    static let margin = 40.0
    static let panelDepth = 372.0, panelR = 24.0, panelF = 18.0
    /// The cubic quarter-circle constant.
    static let k = 0.5523

    // The meniscus. Approaching, the notch is attracted to the cursor: a tongue reaches out of its crest, aimed at
    // the pointer, and snaps to it once the gap is small enough. Leaving, the open panel's edge holds the cursor,
    // wherever it leaves (the front, a corner, the top or the bottom): a tongue stretches after it with its tip on
    // the pointer, until it breaks.

    /// The attraction's reach from the screen's edge, × Pull.
    static let fieldR = 140.0
    /// The attraction's reach along the edge from the notch's centre.
    static let fieldY = 220.0
    /// The tongue reaches out of the notch by up to this, × Pull.
    static let attractCap = 22.0
    /// The tongue is pulled as 1/(distance + this): sharply harder as the gap closes.
    static let attractD0 = 10.0
    /// The tongue's tip follows the pointer along the edge, up to this far from home; the notch's base never moves.
    static let attractY = 40.0
    /// The tongue snaps only once it has caught up with the pull, this share of the way, ...
    static let `catch` = 0.8
    /// ... and with the pointer moving along the edge slower than this past its tip: a pointer passing by is not
    /// caught.
    static let captureV = 0.15
    /// Toward the edge over the last 50ms, this fast: touching the notch opens it at once.
    static let fast = 1.2
    /// ... else after this long on it.
    static let dwell = 150.0
    /// The hit area reaches this far past the notch's front.
    static let hitPad = 4.0
    /// The open front edge bows toward a pointer this close to it, ...
    static let clingNear = 40.0
    /// ... by up to this, × Pull.
    static let clingA = 6.0
    /// Leaving, the tongue's tip runs this far past the pointer: it is held on the black.
    static let grip = 3.0
    /// The pointer this far ahead of the tip has outrun the tongue: it breaks.
    static let outrun = 6.0
    /// ... beside the tip, past this much: the tip is about as wide as this.
    static let outrunSide = 8.0
    /// Stretched to Hold, the tongue hangs this long before it breaks.
    static let hang = 60.0
    /// The tongue's tip narrows from the wide to the tip value as it stretches, on flanks from the wide to the tip
    /// length: concave, a liquid pulled thin.
    static let sigmaWide = 48.0, sigmaTip = 18.0
    static let flankWide = 48.0, flankTip = 24.0
    /// A leave this fast drains quickest, and its grace is shortest.
    static let fastLeave = 1.5
    /// The tongue fades out over this much of the edge before each flare into the bezel.
    static let taper = 20.0
    /// The outline's normals, blurred along it this much, so a tongue crossing from a straight run into a corner
    /// moves smoothly.
    static let normalBlur = 8.0
    /// Released, the bulge travels back to its line on the return spring; this is its response for a tongue that
    /// never stretched (a full Hold's is the return spring's own).
    static let returnFast = 0.15
    /// From the dent's deepest the ring takes it back out, quicker, and rings on through the collapse: this is its
    /// response for a tongue that never stretched.
    static let ringFast = 0.105
    /// The dent goes as deep as a ring of this response would take it, after a full Hold and after a flick.
    static let dentRef = 0.21, dentRefFast = 0.13
    /// A fast leave still pulls: the pointer throws the edge out after it, by up to this × Pull (14 at 0.35), as
    /// tanh(speed away / `flingV`): about 6.5 at 0.6 per ms, 12 at 1.5, 13 at 2, 14 at 3; never past Hold.
    static let fling = 40.0
    static let flingV = 1.2
    /// ... flying out on a spring of this response, so it peaks about 40ms on, and returns from there, ...
    static let flingOut = 0.21
    /// ... and carrying its place along the edge with this share of the pointer's speed along it.
    static let flingAlong = 0.25
    /// Whatever the speed, the edge goes out at least this far before it returns.
    static let ringMin = 4.0
    /// From the line to the dent's deepest, after a full Hold and after a flick: the dent goes as deep as the ring
    /// would take it, braking hard, so it is seen forming.
    static let dentIn = 85.0, dentInFast = 50.0
    /// The ring's dents are this narrow, until the deepest spreads them as the ripple.
    static let ringSigma = 30.0
    /// The collapse starts once the bulge has pushed through its line into the dent, Push of the time from the line
    /// to the deepest (0 at the line, 100% at the deepest), kicked by the bulge's speed through its line, this much
    /// per point per ms of it, ...
    static let kickCross = 0.75
    /// ... plus this much per point per ms of the pointer's speed away; from there the drain eases in, so the ring
    /// plays out on the panel's edge while the panel goes.
    static let kickV = 0.1
    /// The collapse lands as far above the notch's depth as it travels in `landLead` ms, from `landMin` to `landAt`:
    /// the width comes the rest of the way without passing the notch's depth, and the landing's wobble takes over.
    static let landAt = 16.0, landMin = 3.0, landLead = 24.0
    /// The landing dips this far under the notch's depth (× Land), swings back out, dips a little again, and settles
    /// in about 350ms, on the land spring, ...
    static let landDip = 2.75
    /// ... and the notch lengthens this much per point it dips, and shortens as it swings out.
    static let squash = 2.2
    /// The dent spreads along the front edge to this width, ...
    static let rippleSigma = 140.0
    /// ... over this long.
    static let rippleMS = 120.0
    /// Collapsing home, the end nearer the exit leads: its response this share shorter, ...
    static let endLead = 0.10
    /// ... kicked toward home this fast, ...
    static let endKick = 0.45
    /// ... and the far end starts this much later, all at an exit at the panel's end.
    static let endDelay = 36.0
    /// Each end eases into home over its last this many points.
    static let endLand = 16.0
    /// The notch arrives past home, away from the exit, by up to this, swings back a little, and settles; an exit at
    /// the run's end, a corner, the top or the bottom gives all of it, one dead centre none.
    static let rebound = 12.0
    /// The drain's response at `fastLeave` (its slow one is the drain spring's); both ÷ Close.
    static let drainFast = 0.37
    /// The drain aims this far past the notch's depth, so it comes into the landing moving.
    static let drainPast = 20.0
    /// The notch's two ends collapse home on this × the drain's response ...
    static let endsShare = 1.25
    /// ... and this damping (× Bounce), so they arrive with the width.
    static let endsDamping = 0.90
    /// Leaving back over the flare into the bezel: the grace, slow and fast.
    static let grace = 300.0, graceFast = 60.0
    /// The front edge meets resistance past the panel's width ...
    static let frontGive = 6.0
    /// ... and the notch below its own depth.
    static let notchGive = 4.0
    /// The head lands this long into the pour, then a row every 25ms.
    static let rowsAt = 160.0
    /// A new ask's swells come this far apart (ms): about one swing of the ask spring, so each starts as the last
    /// comes back up through NEEDS.
    static let swellGap = 450.0
    /// A clicked row presses in and spins until its jump answers, for this long at most, and then the panel drains.
    static let jumpFor = 450.0
}
