import CoreGraphics
import SwiftUI

/// A session no window holds, on every surface alike. An ask of its waiting on Lee is marked as Slack and Teams mark
/// someone away: the needs dot's footprint hollow, a ring 7 across, its stroke 1.5 inside it, in the needs orange with
/// no glow. Orange says an ask waits on Lee; hollow, that no window holds it. Its row's words dim as one, each by the
/// one factor, so its title stays brighter than its second line and the two sit below the rows round them. The factor
/// is the least that keeps the black card's second line, its ink2 dimmed, as readable as the faint ink, 0x5C, about
/// 3:1 on the black. Its time is never brighter than its title: where it would be, it dims with the row.
enum Away {
    static let ringSide: CGFloat = 7
    static let ringLine: CGFloat = 1.5
    static let dim = 0.61

    /// How much of its words' ink a row shows: dimmed while no window holds it, else all.
    static func dimming(_ isAway: Bool) -> Double {
        isAway ? dim : 1
    }

    /// A colour of a row's words, dimmed while no window holds it, over the black.
    static func dimmed(_ colour: CGColor, _ isAway: Bool) -> CGColor {
        isAway ? colour.copy(alpha: colour.alpha * dim) ?? colour : colour
    }
}

/// An away ask's ring as a view, stroked in a style.
struct AwayRing<Ink: ShapeStyle>: View {
    let ink: Ink

    var body: some View {
        Circle()
            .strokeBorder(ink, lineWidth: Away.ringLine)
            .frame(width: Away.ringSide, height: Away.ringSide)
    }
}
