import AppKit
import SwiftUI

/// A top-right corner of a Mac's screen, drawn by SitRep, with the notification a new ask sends landing on it: the
/// wallpaper, the see-through menu bar with the glyph lit and its clock telling the time now, a Claude window behind,
/// and the banner as macOS 26 draws one, with SitRep's own icon. Its words are a sample. As wide as the column and 150
/// tall, nothing in it stretched or scaled: wider than its drawing, the wallpaper and the menu bar run on, the window
/// behind keeping its place at the left and the menu bar's items and the banner theirs at the right; narrower, it crops
/// at its left, keeping the clock and the banner. To VoiceOver, one image.
struct DesktopCorner: View {
    private static let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    /// As Paper draws it.
    private static let drawing = CGSize(width: 704, height: 150)

    var body: some View {
        CropsAtItsLeft(drawing: Self.drawing) {
            desktop
        }
        .clipShape(Self.shape)
        .overlay(Self.shape.strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A new ask's notification, as it lands on your desktop")
        .accessibilityAddTraits(.isImage)
    }

    private var desktop: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x4A5572), location: 0),
                    .init(color: Color(hex: 0x66718F), location: 0.48),
                    .init(color: Color(hex: 0x9A98AE), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            WindowBehind().offset(x: 28, y: 56)
            MenuBar()
            Banner()
                .fixedSize()
                .padding(.top, 32)
                .padding(.trailing, 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// The clock in the menu bar's own form, in the Mac's locale and its 12- or 24-hour choice: "Tue 20 Oct 20:20", the
    /// day in the locale's order with none of its commas.
    nonisolated static func clock(
        _ date: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        let day = DateFormatter.dateFormat(fromTemplate: "EEEdMMM", options: 0, locale: locale) ?? "EEE d MMM"
        let time = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: locale) ?? "HH:mm"

        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "\(day.replacingOccurrences(of: ",", with: "")) \(time)"
        return formatter.string(from: date)
    }
}

/// Its one view as wide as it is offered and the drawing's height, the view laid out at least the drawing's width
/// against its right edge: wider, the view runs on; narrower, what is past its left is cropped by whoever clips it.
private struct CropsAtItsLeft: Layout {
    let drawing: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width(or: drawing.width), height: drawing.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = max(bounds.width, drawing.width)

        for subview in subviews {
            subview.place(
                at: CGPoint(x: bounds.maxX - width, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: drawing.height)
            )
        }
    }
}

/// The menu bar across the top, right-aligned: Wi-Fi, SitRep's glyph lit, and the clock, a minute at a time, all in
/// the drawn bar's own ink, whatever the Mac's appearance.
private struct MenuBar: View {
    private static let ink = Color(hex: 0xF5F5F7)
    private static let glyph = MenuImages.glyph(.lit, ink: NSColor(ink))

    var body: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "wifi").font(.system(size: 16, weight: .semibold))
            Image(nsImage: Self.glyph).resizable().frame(width: 16, height: 16)
            TimelineView(.everyMinute) { moment in
                Text(DesktopCorner.clock(moment.date)).font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(.black.opacity(0.18))
    }
}

/// A Claude session in Ghostty, behind the banner, cut off by the picture's foot.
private struct WindowBehind: View {
    private static let grey = Color(hex: 0x8E8E95)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach([0xFF5F57, 0xFEBC2E, 0x28C840], id: \.self) { light in
                    Circle().fill(Color(hex: UInt32(light))).frame(width: 9, height: 9)
                }
                Text("switchboard · claude")
                    .font(.system(size: 11))
                    .foregroundStyle(Self.grey)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 40)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color(hex: 0x1F1F23))
            VStack(alignment: .leading, spacing: 4) {
                Text("✻ Claude Code").foregroundStyle(WindowStyle.orange)
                Text("● How long should the ledger keep requests?").foregroundStyle(Self.grey)
            }
            .font(WindowStyle.mono(11))
            .lineLimit(1)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            Spacer(minLength: 0)
        }
        .frame(width: 340, height: 140)
        .background(Color(hex: 0x17171A))
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 14)
    }
}

/// The banner a new ask sends: the app's icon, the ask as its title, "now", and its project and session.
private struct Banner: View {
    private static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    private static let words = Color(hex: 0xEBEBF5)

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: AppIcon.banner).resizable().frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text("Choose how long the ledger keeps requests")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF5F5F7))
                    Spacer(minLength: 0)
                    Text("now").font(.system(size: 12)).foregroundStyle(Self.words.opacity(0.55))
                }
                Text("Switchboard · Usage").font(.system(size: 13)).foregroundStyle(Self.words.opacity(0.7))
            }
            .lineLimit(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(hex: 0x3A3A40).opacity(0.85), in: Self.shape)
        .overlay(Self.shape.strokeBorder(.white.opacity(0.17), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
    }
}
