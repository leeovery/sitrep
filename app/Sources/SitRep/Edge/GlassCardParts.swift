import SitRepPanel
import SwiftUI

/// A section's eyebrow on glass, laid out as the black's, in the glass's label colours: its name in the secondary, its
/// counts in the tertiary, Needs you's asks in Claude's orange and its stopped in blue, and its chevron in the tertiary.
struct GlassEyebrow: View {
    let eyebrow: Eyebrow
    let size: CGSize

    var body: some View {
        let font = Font.system(size: 11, weight: .semibold)
        ZStack(alignment: .topLeading) {
            HStack(spacing: EyebrowLayout.gap) {
                Text(eyebrow.section.title).font(font).foregroundStyle(.secondary)
                ForEach(Array(eyebrow.counts.enumerated()), id: \.offset) { _, count in
                    Text("\(count.value)").font(font.monospacedDigit()).foregroundStyle(ink(of: count))
                }
            }
            .placed(in: EyebrowLayout.label(in: size))
            GlassChevron(isOpen: !eyebrow.isFolded, box: EyebrowLayout.chevron(in: size))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func ink(of count: Eyebrow.Count) -> AnyShapeStyle {
        count.need.map { AnyShapeStyle(GlassInk.colour(of: $0)) } ?? AnyShapeStyle(.tertiary)
    }
}

/// The black's chevron in its box, in the tertiary label colour.
private struct GlassChevron: View {
    let isOpen: Bool
    let box: CGRect

    var body: some View {
        Outline(path: Path(CardChevron.path(isOpen: isOpen)))
            .stroke(.tertiary, style: StrokeStyle(lineWidth: CardChevron.stroke, lineCap: .round, lineJoin: .round))
            .frame(width: box.width, height: box.height)
            .offset(x: box.minX, y: box.minY)
    }
}
