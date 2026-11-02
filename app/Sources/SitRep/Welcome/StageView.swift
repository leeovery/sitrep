import AppKit
import SitRepMenu
import SitRepPanel
import SwiftUI

/// The stage: a small desktop, drawn as in Paper, its menu bar holding Ghostty's menus, SitRep's item lit and the time
/// now; a Ghostty window with Claude Code's ask in it, on the side away from the edge; and SitRep's own edge
/// (`StageEdge`) down the edge Lee chose. At the sound's step, while SitRep opens at login, macOS's "Background Items
/// Added" shows as it will come; at the last, the callout stands beside the notch.
struct StageView: View {
    let welcome: WelcomeModel
    let edge: StageEdge

    private static let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        let isRight = welcome.preferences.edge.edge == .right

        ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0xA9B3C6), location: 0),
                    .init(color: Color(hex: 0xC7CCD6), location: 0.55),
                    .init(color: Color(hex: 0xD9D6D0), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            StageMenuBar()
            GhosttyWindow()
                .offset(x: isRight ? WelcomeStyle.stage.width - 178 - GhosttyWindow.size.width : 178, y: 58)
            EdgeHost(edge: edge, play: welcome.step.stage, chimes: welcome.chimes)
            overlays
        }
        .frame(width: WelcomeStyle.stage.width, height: WelcomeStyle.stage.height)
        .clipShape(Self.shape)
        .overlay(Self.shape.strokeBorder(.white.opacity(0x29 / 255), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SitRep's edge, on a desktop")
        .accessibilityAddTraits(.isImage)
    }

    /// macOS's notice while this visit's registration is the one it tells of; the callout where the stage places it.
    @ViewBuilder private var overlays: some View {
        if welcome.step == .sound, welcome.login.isOn, welcome.announcesNotice {
            BackgroundItemsNotice()
                .padding(.top, 28)
                .padding(.trailing, 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if welcome.step == .ready {
            let place = edge.callout.place

            // as tall as twice its middle, so centred there
            NotchCallout(isRight: place.isRight)
                .fixedSize()
                .padding(place.isRight ? .trailing : .leading, place.inset)
                .frame(maxWidth: .infinity, alignment: place.isRight ? .trailing : .leading)
                .frame(height: place.middle * 2)
        }
    }
}

/// The stage's edge, in the SwiftUI desktop: told what the step plays, and each sound chosen.
private struct EdgeHost: NSViewRepresentable {
    let edge: StageEdge
    let play: WelcomeStage
    let chimes: Int

    func makeNSView(context: Context) -> StageEdge {
        edge
    }

    func updateNSView(_ edge: StageEdge, context: Context) {
        edge.play = play
        edge.chime(chimes)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView edge: StageEdge, context: Context) -> CGSize? {
        edge.frame.size
    }
}

/// The menu bar across the stage's top: Ghostty's menus, then SitRep's item lit, and the time now, a minute at a time.
private struct StageMenuBar: View {
    private static let ink = Color(hex: 0x1D1D1F)
    private static let glyph = MenuImages.glyph(.lit, ink: NSColor(ink))

    var body: some View {
        HStack(spacing: 12) {
            Text("Ghostty").fontWeight(.bold)
            ForEach(["Shell", "Edit", "View"], id: \.self) { Text($0) }
            Spacer(minLength: 0)
            Image(nsImage: Self.glyph).resizable().frame(width: 12, height: 12)
            TimelineView(.everyMinute) { Text(DesktopCorner.clock($0.date)) }
        }
        .font(.system(size: 9.5))
        .foregroundStyle(Self.ink)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(height: WelcomeStyle.stageMenuBar)
        .background(.white.opacity(0x73 / 255))
    }
}

/// A Claude Code session in Ghostty, asking, in placeholder words (`Sample`).
private struct GhosttyWindow: View {
    static let size = CGSize(width: 292, height: 318)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ForEach([0xFF5F57, 0xFEBC2E, 0x28C840], id: \.self) { light in
                    Circle().fill(Color(hex: UInt32(light))).frame(width: 7, height: 7)
                }
                Text(Sample.terminal)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: 0x8A8A90))
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 26)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color(hex: 0x222226))
            VStack(alignment: .leading, spacing: 6) {
                Text("✻ Claude Code").foregroundStyle(WindowStyle.orange)
                Text(Sample.terminalAsk).foregroundStyle(Color(hex: 0xC8C8CC))
                Text("⎿ sitrep · ask").foregroundStyle(WelcomeStyle.faint)
            }
            .font(WindowStyle.mono(9))
            .lineLimit(1)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            Spacer(minLength: 0)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(hex: 0x19191C))
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 15, y: 12)
    }
}

/// macOS's notice as SitRep registers to open at login, as it will come (Paper's board D).
private struct BackgroundItemsNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(nsImage: AppIcon.notice).resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Background Items Added")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WelcomeStyle.text)
                Text("“SitRep” can run in the background. You can manage this in Login Items Settings.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color(hex: 0xB8B8BE))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .frame(width: 236, alignment: .leading)
        .background(Color(hex: 0x242428).opacity(0xF0 / 255), in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    }
}

/// The callout beside the notch at rest, pointing at it.
struct NotchCallout: View {
    /// Whether the notch is on the right edge, so to its right.
    let isRight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Your notch. Point at it.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0x111113))
            Text("It lights up when a session needs you")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: 0x55555C))
        }
        .lineLimit(1)
        .padding(.vertical, 7)
        .padding(.leading, 9)
        .padding(.trailing, 11)
        .background(Color(hex: 0xF5F5F7), in: .rect(cornerRadius: 9))
        .overlay(alignment: isRight ? .trailing : .leading) {
            Arrow()
                .fill(Color(hex: 0xF5F5F7))
                .frame(width: 7, height: 12)
                .scaleEffect(x: isRight ? -1 : 1)
                .offset(x: isRight ? 6 : -6)
        }
        .shadow(color: .black.opacity(0.22), radius: 9, y: 6)
    }

    /// Its point, toward the notch, drawn for the left edge.
    private struct Arrow: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()

            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + 0.8, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}
