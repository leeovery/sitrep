import SitRepMenu
import SitRepPanel
import SwiftUI

/// What stays on screen's first row, set as System Settings sets Appearance's on macOS 26: Show at its left, and at
/// its right the three pictures of the screen's edge, each named under it: the notch and its light, the strip and its
/// rings, or only the menu bar's glyph, lit. The one chosen is ringed in the accent; a click on another chooses it. It
/// is the menu's Show. With Nothing, the line under Show says what carries the board instead. Nothing in the pictures
/// moves, under the pointer or not.
struct ShowRow: View {
    @Binding var show: EdgeSettings.Show
    /// Whether the window is on screen; off it, no tile is under the pointer.
    let isOnScreen: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RowWords(label: "Show", line: show == .nothing ? StaysOnScreen.menuCarries : nil)
            HStack(spacing: TileFace.apart) {
                ForEach(EdgeSettings.Show.allCases, id: \.self) { choice in
                    ShowTile(choice: choice, isChosen: choice == show, isOnScreen: isOnScreen) { show = choice }
                }
            }
            .padding(.vertical, SettingsStyle.inset)
        }
        .padding(.horizontal, SettingsStyle.inset)
    }
}

/// A picture and its name, as one button (`TileFace`); not chosen, its hairline and its name brighten while the
/// pointer is over it.
private struct ShowTile: View {
    let choice: EdgeSettings.Show
    let isChosen: Bool
    let isOnScreen: Bool
    let choose: () -> Void

    @State private var isOver = false

    var body: some View {
        Button(action: choose) {
            TileFace(choice: choice, isChosen: isChosen, isOver: isOver)
        }
        .buttonStyle(.plain)
        .onHover { isOver = $0 }
        .onChange(of: isOnScreen) {
            // the pointer's leaving may never be heard as the window leaves the screen
            if !isOnScreen {
                isOver = false
            }
        }
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A tile as it draws, at Appearance's thumbnail sizes: its picture, 67 × 44, with room round it for the ring, over
/// its name, 11. Chosen, a gap of the card's raise, 0.5, and a ring in the accent, 3, round the picture, its name
/// semibold in the label colour; else a hairline inside it, white at 15%, its name regular in the secondary colour.
/// While the pointer is over a tile not chosen, its hairline lifts to 40% and its name to the label colour, at once:
/// all the pointer changes.
struct TileFace: View {
    let choice: EdgeSettings.Show
    let isChosen: Bool
    let isOver: Bool

    static let picture = CGSize(width: 67, height: 44)
    static let radius: CGFloat = 5
    static let gap: CGFloat = 0.5
    static let ring: CGFloat = 3
    /// Between two tiles' rooms for their rings: their pictures 15 apart.
    static let apart: CGFloat = 8
    private static let hairline = Color.white.opacity(0.15)
    private static let hairlineLifted = Color.white.opacity(0.4)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        let ringMiddle = Self.gap + Self.ring / 2

        // the name's line 1 under the ring's room, 4.5 under the picture: its capitals 7 under it, as Appearance's
        VStack(spacing: 1) {
            EdgePicture(show: choice)
                .frame(width: Self.picture.width, height: Self.picture.height)
                .clipShape(shape)
                .overlay {
                    if isChosen {
                        RoundedRectangle(cornerRadius: Self.radius + ringMiddle, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: Self.ring)
                            .padding(-ringMiddle)
                    } else {
                        shape.strokeBorder(isOver ? Self.hairlineLifted : Self.hairline, lineWidth: 0.5)
                    }
                }
                .padding(Self.gap + Self.ring)
            Text(choice.title)
                .font(.subheadline.weight(isChosen ? .semibold : .regular))
                .foregroundStyle(isChosen || isOver ? SettingsStyle.label : SettingsStyle.secondary)
        }
        .contentShape(Rectangle())
    }
}
