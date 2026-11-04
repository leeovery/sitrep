import SitRepPanel
import SwiftUI

/// A section's eyebrow on glass, laid out as the black's, in the glass's label colours: its name in the secondary, its
/// count in the tertiary, Needs you's in Claude's orange, and its chevron in the tertiary.
struct GlassEyebrow: View {
    let eyebrow: Eyebrow
    let size: CGSize

    var body: some View {
        let font = Font.system(size: 11, weight: .semibold)
        ZStack(alignment: .topLeading) {
            HStack(spacing: EyebrowLayout.gap) {
                Text(eyebrow.section.title).font(font).foregroundStyle(.secondary)
                Text("\(eyebrow.count)").font(font.monospacedDigit())
                    .foregroundStyle(eyebrow.section == .needsYou ? AnyShapeStyle(GlassInk.orange) : AnyShapeStyle(.tertiary))
            }
            .placed(in: EyebrowLayout.label(in: size))
            GlassChevron(isOpen: !eyebrow.isFolded, box: EyebrowLayout.chevron(in: size))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
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

/// A row's button that opens its session in the SitRep window, on glass as in black: white at 10%, its corners 7, its
/// glyph in white at 80% (`EdgeStyle.opener`, `openerGlyph`).
struct GlassOpener: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Opener.radius).fill(Color(cgColor: EdgeStyle.opener))
            Outline(path: Path(OpenerGlyph.path))
                .stroke(Color(cgColor: EdgeStyle.openerGlyph), lineWidth: OpenerGlyph.stroke)
                .frame(width: OpenerGlyph.size.width, height: OpenerGlyph.size.height)
        }
        .frame(width: Opener.side, height: Opener.side)
    }
}
