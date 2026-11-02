import SitRepMenu
import SitRepPanel
import SwiftUI

/// Edge's first row, on a card of its own, as System Settings sets Appearance's on macOS 26: Show at its left, and at
/// its right the three pictures of the screen's edge, each named under it: the notch and its light, the strip and its
/// rings, or only the menu bar's glyph, lit. The one chosen is ringed in the accent; a click on another chooses it. It
/// is the menu's Show. With Nothing, the line under Show says what carries the board instead. Nothing in the row
/// answers the pointer, as nothing in Appearance's does: a picture changes only as it is chosen.
struct ShowRow: View {
    @Binding var show: EdgeSettings.Show

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RowWords(label: "Show", line: show == .nothing ? EdgePane.menuCarries : nil)
            HStack(spacing: TileFace.apart) {
                ForEach(EdgeSettings.Show.allCases, id: \.self) { choice in
                    Button { show = choice } label: {
                        TileFace(choice: choice, isChosen: choice == show)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(choice == show ? .isSelected : [])
                }
            }
            .fixedSize()
            .padding(.vertical, SettingsStyle.rowMargin)
        }
        .padding(.horizontal, SettingsStyle.inset)
    }
}

/// A tile as it draws, at Appearance's thumbnail sizes: its picture, 67 × 44, with room round it for the ring, over
/// its name, 11. Chosen, a gap of the card's raise, 0.5, and a ring in the accent, 3, round the picture, its name
/// semibold in the label colour; else its picture stands on Appearance's soft shadow, black at 30% blurred 2 all
/// round, its name regular in the secondary colour.
struct TileFace: View {
    let choice: EdgeSettings.Show
    let isChosen: Bool

    static let picture = CGSize(width: 67, height: 44)
    static let radius: CGFloat = 5
    static let gap: CGFloat = 0.5
    static let ring: CGFloat = 3
    /// Between two tiles' rooms for their rings: their pictures 15 apart.
    static let apart: CGFloat = 8

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        let ringMiddle = Self.gap + Self.ring / 2

        // the name's line 1 under the ring's room, 4.5 under the picture: its capitals 7 under it, as Appearance's
        VStack(spacing: 1) {
            EdgePicture(show: choice)
                .frame(width: Self.picture.width, height: Self.picture.height)
                .clipShape(shape)
                .shadow(color: .black.opacity(isChosen ? 0 : 0.3), radius: 2)
                .overlay {
                    if isChosen {
                        RoundedRectangle(cornerRadius: Self.radius + ringMiddle, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: Self.ring)
                            .padding(-ringMiddle)
                    }
                }
                .padding(Self.gap + Self.ring)
            Text(choice.title)
                .font(.subheadline.weight(isChosen ? .semibold : .regular))
                .foregroundStyle(isChosen ? SettingsStyle.label : SettingsStyle.secondary)
        }
        .contentShape(Rectangle())
    }
}
