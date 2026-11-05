import AppKit
import SitRepMenu
import SitRepPanel
import SwiftUI

/// The stage: a small desktop, drawn as in Paper, its menu bar holding Ghostty's menus, SitRep's item and the time
/// now; a Ghostty window with Claude Code's ask in it, on the side away from the edge; and SitRep's own edge
/// (`StageEdge`) down the edge Lee chose, or none at Nothing. At step 2 the Ghostty window waits behind until the loop's
/// click brings it forward, and the answer comes into it. At the sound's step, while SitRep opens at login, macOS's
/// "Background Items Added" shows as it will come; at the step asking for notifications, a new ask's banner; at the
/// last, the callout stands beside the notch, where there is one.
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
            StageMenuBar(isLit: edge.scene.isItemLit)
            GhosttyWindow(session: session)
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

    /// The session's window as step 2's loop has it, behind until the click takes Lee to it; at every other step, in
    /// front with the ask waiting.
    private var session: WelcomeLoop.Scene {
        welcome.step == .ask ? edge.scene.now : WelcomeLoop.Scene(isInSession: true)
    }

    /// macOS's notice while this visit's registration is the one it tells of; a new ask's banner as it will come, at
    /// the step that asks for them; the callout where the stage places it.
    @ViewBuilder private var overlays: some View {
        if welcome.step == .sound, welcome.login.isOn, welcome.announcesNotice {
            Self.corner(StageNotice.backgroundItems)
        } else if welcome.step == .permissions {
            Self.corner(StageNotice.newAsk)
        } else if welcome.step == .ready, let place = edge.callout.place {
            // as tall as twice its middle, so centred there
            NotchCallout(isRight: place.isRight)
                .fixedSize()
                .padding(place.isRight ? .trailing : .leading, place.inset)
                .frame(maxWidth: .infinity, alignment: place.isRight ? .trailing : .leading)
                .frame(height: place.middle * 2)
        }
    }

    /// A notice where macOS puts one, under the menu bar at the desktop's right.
    private static func corner(_ notice: StageNotice) -> some View {
        notice
            .padding(.top, 28)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .trailing)
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

/// The menu bar across the stage's top: Ghostty's menus, then SitRep's item, lit or at rest, and the time now, a minute
/// at a time.
private struct StageMenuBar: View {
    private static let ink = Color(hex: 0x1D1D1F)
    private static let lit = MenuImages.glyph(.lit, ink: NSColor(ink))
    private static let rest = MenuImages.glyph(.rest)

    let isLit: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("Ghostty").fontWeight(.bold)
            ForEach(["Shell", "Edit", "View"], id: \.self) { Text($0) }
            Spacer(minLength: 0)
            Image(nsImage: isLit ? Self.lit : Self.rest)
                .resizable()
                .foregroundStyle(Self.ink)
                .frame(width: 12, height: 12)
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

/// A Claude Code session in Ghostty, asking, in placeholder words (`Sample`): behind, dimmed with its traffic lights
/// grey, as macOS draws a window not in front, until a click on its row brings it forward; then, once answered, the
/// answer under the ask. Each change cross-fades, and only its colours and fades move, never its place.
private struct GhosttyWindow: View {
    static let size = CGSize(width: 292, height: 318)
    private static let lights: [UInt32] = [0xFF5F57, 0xFEBC2E, 0x28C840]
    private static let fade = Animation.easeInOut(duration: 0.35)

    let session: WelcomeLoop.Scene

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ForEach(Self.lights, id: \.self) { light in
                    Circle()
                        .animation(Self.fade) { $0.foregroundStyle(Color(hex: session.isInSession ? light : 0x4A4A4E)) }
                        .frame(width: 7, height: 7)
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
                Text("✻ Claude Code").foregroundStyle(PictureStyle.orange)
                Text(Sample.terminalAsk).foregroundStyle(Color(hex: 0xC8C8CC))
                Text(Sample.terminalTool).foregroundStyle(WelcomeStyle.faint)
                Text(Sample.terminalAnswer)
                    .foregroundStyle(WelcomeStyle.text)
                    .padding(.top, 4)
                    .animation(Self.fade) { $0.opacity(session.isAnswered ? 1 : 0) }
            }
            .font(PictureStyle.mono(9))
            .lineLimit(1)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .animation(Self.fade) { $0.opacity(session.isInSession ? 1 : 0.55) }
            Spacer(minLength: 0)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(hex: 0x19191C))
        .clipShape(.rect(cornerRadius: 8))
        .animation(Self.fade) { $0.shadow(color: .black.opacity(session.isInSession ? 0.3 : 0.15), radius: 15, y: 12) }
    }
}

/// A notice on the stage's desktop as it will come, SitRep's icon beside it: macOS's as SitRep registers to open at
/// login (Paper's board D), or a new ask's banner (board E).
private struct StageNotice: View {
    let title: String
    let line: String

    /// macOS's notice as SitRep registers to open at login.
    static let backgroundItems = StageNotice(
        title: "Background Items Added",
        line: "“SitRep” can run in the background. You can manage this in Login Items Settings."
    )
    /// A new ask's banner, in placeholder words.
    static let newAsk = StageNotice(title: Sample.ask, line: Sample.place)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(nsImage: AppIcon.notice).resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WelcomeStyle.text)
                Text(line)
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
