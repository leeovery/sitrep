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

/// "N earlier" on glass, laid out as the black's: its ring and its projects in the tertiary, "8 earlier" in the
/// secondary, and its chevron; lifting under the pointer as a row does.
struct GlassEarlier: View {
    let earlier: Earlier
    let size: CGSize
    let lit: Bool

    var body: some View {
        let words = EarlierLayout.words(in: size)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: SessionRowLayout.turnRadius).fill(.primary.opacity(lit ? 0.08 : 0))
            Circle().strokeBorder(.tertiary, lineWidth: 1.5).frame(width: 9, height: 9)
                .position(EarlierLayout.mark(in: size))
            HStack(alignment: .firstTextBaseline, spacing: EarlierLayout.gap) {
                Text(earlier.title).font(.system(size: 13)).kerning(-0.13).foregroundStyle(.secondary).fixedSize()
                Text(earlier.projects.joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            .placed(in: words)
            GlassChevron(isOpen: earlier.isOpen, box: EarlierLayout.chevron(in: size))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.11), value: lit)
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

/// A row's button that opens its session in the SitRep window, on glass as in black: the primary at 10%, its corners
/// 7, its glyph in the primary at 80%.
struct GlassOpener: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Opener.radius).fill(.primary.opacity(0x1A / 255))
            Outline(path: Path(OpenerGlyph.path))
                .stroke(.primary.opacity(0.8), lineWidth: OpenerGlyph.stroke)
                .frame(width: OpenerGlyph.size.width, height: OpenerGlyph.size.height)
        }
        .frame(width: Opener.side, height: Opener.side)
    }
}
