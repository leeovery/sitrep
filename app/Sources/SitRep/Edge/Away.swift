import SwiftUI

/// A session no window holds, on every surface alike. An ask of its waiting on Lee is marked as Slack and Teams mark
/// someone away: the needs dot's footprint hollow, a ring 7 across, its stroke 1.5 inside it, in the needs orange with
/// no glow. Orange says an ask waits on Lee; hollow, that no window holds it. Its row's title and the line under it dim
/// as one, each by the one factor, so its title stays brighter than its project and the two sit below the rows round
/// them: the black's away title, 45% of its white. Its time, in its own lane and already the row's quietest words,
/// stays as it is.
enum Away {
    static let ringSide: CGFloat = 7
    static let ringLine: CGFloat = 1.5
    static let dim = 0.45
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
