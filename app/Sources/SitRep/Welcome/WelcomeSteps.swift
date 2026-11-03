import AppKit
import SitRepMenu
import SitRepPanel
import SwiftUI

/// Step 1, Hello, from the edge: SitRep's icon over the step's words, in the column's middle, and the aside at its
/// foot.
struct HelloStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Image(nsImage: AppIcon.welcome)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                StepWords(step: .hello)
            }
            .padding(.bottom, 8)
            .frame(maxHeight: .infinity)
            Text("About a minute. Everything here is in Settings later.")
                .font(.system(size: 11))
                .foregroundStyle(WelcomeStyle.faint)
                .padding(.bottom, 4)
        }
    }
}

/// Step 2, An ask, from Claude to you: the step's words, then the loop's three moments, each lit as the stage plays
/// it. Nothing here is pressed: the stage shows it all.
struct AskStep: View {
    /// The moment the stage is at, if any.
    let lit: WelcomeLoop.Moment?

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepWords(step: .ask)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(WelcomeLoop.Moment.allCases, id: \.self) { moment in
                    MomentLine(words: moment.words, isLit: moment == lit)
                }
            }
        }
        .padding(.top, 40)
    }
}

/// One of step 2's moments: a dot and its words, in the accent and the label colour while the stage plays it, else
/// faint.
private struct MomentLine: View {
    let words: String
    let isLit: Bool

    var body: some View {
        let fade = Animation.easeInOut(duration: 0.3)

        HStack(spacing: 10) {
            Circle()
                .animation(fade) { $0.foregroundStyle(isLit ? Color.accentColor : .white.opacity(0x2E / 255)) }
                .frame(width: 6, height: 6)
            Text(words)
                .font(.system(size: 13, weight: .medium))
                .animation(fade) { $0.foregroundStyle(isLit ? WelcomeStyle.text : WelcomeStyle.faint) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isLit ? .isSelected : [])
    }
}

/// Step 3, Your edge: Notch or Strip as Settings' own pictures, the one chosen ringed in the accent, then a grouped
/// form: Style, or at Strip Length in its place, cross-fading so the form keeps its height; Material, from macOS 26;
/// and Edge. Each press sets the setting itself.
struct EdgeStep: View {
    let welcome: WelcomeModel

    /// A picture's size, at the window's: half the column, less the gap between the two.
    static let picture = CGSize(width: 130, height: 72)

    var body: some View {
        let edge = welcome.preferences.edge
        let rows = WelcomeEdgeForm.rows(edge, hasGlass: welcome.services.hasGlass)

        VStack(alignment: .leading, spacing: 22) {
            StepWords(step: .edge)
            HStack(spacing: 10) {
                ForEach([EdgeSettings.Show.notch, .strip], id: \.self) { show in
                    ShapeTile(show: show, isChosen: edge.show == show) { welcome.choose(show) }
                }
            }
            WelcomeCard {
                // one row for another in the one place, so the form keeps its height as they cross-fade
                ZStack {
                    FormRow(row: rows[0], preferences: welcome.preferences)
                        .id(rows[0])
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.2), value: rows[0])
                ForEach(rows.dropFirst(), id: \.self) { row in
                    Hairline()
                    FormRow(row: row, preferences: welcome.preferences)
                }
            }
        }
        .padding(.top, 40)
    }
}

/// Notch or Strip: Settings' own picture, named under it, ringed in the accent while chosen.
private struct ShapeTile: View {
    let show: EdgeSettings.Show
    let isChosen: Bool
    let choose: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        Button(action: choose) {
            VStack(spacing: 6) {
                EdgePicture(show: show)
                    .frame(width: EdgeStep.picture.width, height: EdgeStep.picture.height)
                    .clipShape(shape)
                    .overlay {
                        let ring: CGFloat = isChosen ? 2 : 1

                        RoundedRectangle(cornerRadius: 8 + ring, style: .continuous)
                            .strokeBorder(isChosen ? Color.accentColor : .white.opacity(0x29 / 255), lineWidth: ring)
                            .padding(-ring)
                    }
                Text(show.title)
                    .font(.system(size: 12, weight: isChosen ? .semibold : .medium))
                    .foregroundStyle(isChosen ? WelcomeStyle.text : WelcomeStyle.soft)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(show.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A row of step 3's form: its label, and the system's segmented control against the card's right.
private struct FormRow: View {
    let row: WelcomeEdgeForm.Row
    let preferences: Preferences

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(WelcomeStyle.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            control.fixedSize()
        }
        .frame(height: 38)
    }

    private var label: String {
        switch row {
        case .style: "Style"
        case .length: "Length"
        case .material: "Material"
        case .edge: "Edge"
        }
    }

    @ViewBuilder private var control: some View {
        switch row {
        case .style: segments(\.style, NotchStyle.allCases, \.title)
        case .length: segments(\.length, StripLength.allCases, \.title)
        case .material: segments(\.material, EdgeSettings.Material.allCases, \.title)
        case .edge: segments(\.edge, EdgeSettings.Edge.allCases, \.title)
        }
    }

    private func segments<Value: Hashable>(
        _ setting: WritableKeyPath<EdgeSettings, Value>, _ values: [Value], _ title: @escaping (Value) -> String
    ) -> some View {
        Segments(label: label, value: preferences.binding(setting), values: values, title: title)
    }
}

/// Step 4, Its sound, and its start: macOS's alert sounds, four showing and the rest a scroll away, No sound after a
/// hairline; then Open SitRep at login, the real login item.
struct SoundStep: View {
    let welcome: WelcomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepWords(step: .sound)
            SoundList(welcome: welcome)
            LoginCard(welcome: welcome)
        }
        .padding(.top, 36)
    }
}

/// The sounds, each row choosing its sound and playing it once; the chosen one tinted in the accent, its speaker on
/// the left and a tick on the right.
private struct SoundList: View {
    let welcome: WelcomeModel

    private static let row: CGFloat = 28

    var body: some View {
        let sounds = welcome.sounds, chosen = welcome.sound

        VStack(spacing: 0) {
            ScrollViewReader { list in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(sounds.names.enumerated()), id: \.element) { place, name in
                            SoundRow(name: name, aside: sounds.aside(at: place), isChosen: name == chosen) {
                                welcome.choose(sound: name)
                            }
                        }
                    }
                }
                .onAppear {
                    if let shown = chosen.flatMap(sounds.scrolledTo) {
                        list.scrollTo(shown, anchor: .bottom)
                    }
                }
            }
            .frame(height: Self.row * CGFloat(WelcomeSounds.shown))
            Hairline()
            SoundRow(name: "No sound", aside: nil, isChosen: chosen == nil, isQuiet: true) {
                welcome.choose(sound: nil)
            }
        }
        .padding(4)
        .background(WelcomeStyle.card, in: .rect(cornerRadius: WelcomeStyle.cardRadius))
    }
}

private struct SoundRow: View {
    let name: String
    let aside: String?
    let isChosen: Bool
    var isQuiet = false
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .frame(width: 14)
                    .opacity(isChosen ? 1 : 0)
                Text(name)
                    .font(.system(size: 13, weight: isChosen ? .medium : .regular))
                    .foregroundStyle(isQuiet && !isChosen ? WelcomeStyle.soft : WelcomeStyle.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let aside {
                    Text(aside).font(.system(size: 11)).foregroundStyle(WelcomeStyle.faint)
                }
                if isChosen {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .foregroundStyle(WelcomeStyle.text)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(isChosen ? Color.accentColor.opacity(0x38 / 255) : .clear, in: .rect(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// Open SitRep at login: the switch, as General's, its line warning of macOS's notice while the notice is this visit's,
/// else General's line; while macOS waits on Lee's approval, General's words and the way to it.
private struct LoginCard: View {
    let welcome: WelcomeModel

    var body: some View {
        let row = welcome.loginRow
        let warns = row.side == .toggle(isEnabled: true) && welcome.announcesNotice

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Open SitRep at login").font(.system(size: 13)).foregroundStyle(WelcomeStyle.text)
                Text(warns ? "macOS confirms it with a notice" : row.line ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(WelcomeStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if case let .button(title, _) = row.side {
                Button(title) { welcome.fix(.loginItems) }.buttonStyle(.bordered)
            } else {
                MiniSwitch(label: "Open SitRep at login", isOn: opensAtLogin)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(WelcomeStyle.card, in: .rect(cornerRadius: WelcomeStyle.cardRadius))
    }

    private var opensAtLogin: Binding<Bool> {
        Binding(get: { welcome.login.isOn }, set: welcome.setLogin)
    }
}

/// Step 5, What it asks of macOS: Notifications and Control Ghostty, each with its reason and its state, then the aside
/// on Allow… and the way back from a refusal. Neither holds Continue back.
struct PermissionsStep: View {
    let welcome: WelcomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepWords(step: .permissions)
            WelcomeCard(inset: 12) {
                ForEach(Array(WelcomePermission.allCases.enumerated()), id: \.offset) { place, permission in
                    if place > 0 {
                        Hairline()
                    }
                    PermissionRow(
                        permission: permission, leave: welcome.leave(permission), hitch: welcome.hitch(permission)
                    ) {
                        welcome.press(permission)
                    }
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(WelcomeStyle.faint)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                Text(
                    "Allow… opens Ghostty if it isn't running: macOS only asks while it is. Refused? A button here "
                        + "opens the right page of System Settings."
                )
                .font(.system(size: 11))
                .lineSpacing(2)
                .foregroundStyle(WelcomeStyle.soft)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)
        }
        .padding(.top, 36)
    }
}

/// A leave's row: its icon, its name over its reason, and where it stands. To ask, a button named for what it does,
/// and what went wrong with the last ask under the reason; asking, a spinner, then where macOS put its prompt; on, a
/// green check; refused, Open System Settings… under the reason, as the column has no room for it beside the words;
/// with no Ghostty to open, the reason why and nothing to press.
private struct PermissionRow: View {
    let permission: WelcomePermission
    let leave: WelcomeLeave
    let hitch: WelcomeHitch?
    let press: () -> Void

    /// The line under the reason, if the row has one.
    private var note: String? {
        switch leave {
        case .asking(waitedLong: true): permission.whereAsked
        case .toAsk: hitch?.words
        case .unavailable: WelcomeHitch.notInstalled.words
        case .asking, .on, .refused: nil
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PermissionIcon(permission: permission)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WelcomeStyle.text)
                Text(permission.reason)
                    .font(.system(size: 11))
                    .foregroundStyle(WelcomeStyle.soft)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(WelcomeStyle.text)
                        .padding(.top, 2)
                }
                if leave == .refused {
                    PermissionButton(title: "Open System Settings…", action: press).padding(.top, 6)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            side
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var side: some View {
        switch leave {
        case .toAsk:
            PermissionButton(title: permission.ask, action: press)
        case .asking:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Waiting on macOS")
        case .on:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white, Color(hex: 0x30D158))
                    .accessibilityHidden(true)
                Text("On").font(.system(size: 12)).foregroundStyle(WelcomeStyle.text)
            }
        case .refused, .unavailable:
            EmptyView()
        }
    }
}

/// A row's button, as Paper draws it: SitRep's own, never macOS's dialog's.
private struct PermissionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WelcomeStyle.text)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(.white.opacity(0x24 / 255), in: .rect(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

/// Notifications' red tile and its bell; Ghostty's dark one and its prompt.
private struct PermissionIcon: View {
    let permission: WelcomePermission

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        Group {
            switch permission {
            case .notifications:
                Image(systemName: "bell.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(hex: 0xFF3B30), in: shape)
            case .ghostty:
                Prompt()
                    .stroke(WelcomeStyle.text, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 14, height: 12)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x2B2D33), Color(hex: 0x121316)], startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: shape
                    )
                    .overlay(shape.strokeBorder(.white.opacity(0x1F / 255), lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }

    /// A shell's prompt, `>_`, as Paper draws it in a box of 14 by 12.
    private struct Prompt: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let x = rect.width / 14, y = rect.height / 12

            path.move(to: CGPoint(x: 2 * x, y: 2.5 * y))
            path.addLine(to: CGPoint(x: 5.5 * x, y: 6 * y))
            path.addLine(to: CGPoint(x: 2 * x, y: 9.5 * y))
            path.move(to: CGPoint(x: 7.5 * x, y: 9.5 * y))
            path.addLine(to: CGPoint(x: 12 * x, y: 9.5 * y))
            return path
        }
    }
}

/// Step 6, Ready, and what's left: `/reload-plugins` with Copy, or where the plugin's first install failed, what
/// failed; then Lee's choices played back.
struct ReadyStep: View {
    let welcome: WelcomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepWords(step: .ready)
            switch welcome.reload {
            case let .command(command):
                CommandBox(command: command, copy: welcome.copyReloadCommand)
            case let .trouble(row):
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.label).font(.system(size: 13)).foregroundStyle(WelcomeStyle.text)
                    Text(row.line ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(WelcomeStyle.soft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .background(WelcomeStyle.card, in: .rect(cornerRadius: WelcomeStyle.cardRadius))
            }
            Playback(rows: welcome.playback, fix: welcome.fix)
        }
        .padding(.top, 36)
    }
}

/// The command in the monospaced face, and Copy.
private struct CommandBox: View {
    let command: String
    let copy: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WelcomeStyle.cardRadius)

        HStack(spacing: 10) {
            Text(command)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(WelcomeStyle.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: copy) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc").font(.system(size: 11))
                    Text("Copy").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(WelcomeStyle.text)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.white.opacity(0x1F / 255), in: .rect(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(command)")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 40)
        .background(WelcomeStyle.card, in: shape)
        .overlay(shape.strokeBorder(.white.opacity(0x14 / 255), lineWidth: 1))
    }
}

/// Lee's choices in four rows, each with its fix in place where something was left off.
private struct Playback: View {
    let rows: [WelcomePlayback.Row]
    let fix: (WelcomePlayback.Fix) -> Void

    var body: some View {
        WelcomeCard(inset: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { place, row in
                if place > 0 {
                    Hairline()
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Text(row.label).foregroundStyle(WelcomeStyle.soft).frame(width: 76, alignment: .leading)
                        Text(row.words)
                            .foregroundStyle(WelcomeStyle.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        side(row)
                    }
                    .lineLimit(1)
                    .frame(height: 30)
                    if let line = row.line {
                        Text(line)
                            .font(.system(size: 11))
                            .foregroundStyle(WelcomeStyle.soft)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 86)
                            .padding(.bottom, 8)
                    }
                }
                .font(.system(size: 12))
            }
        }
    }

    /// The row's fix, or while its ask is under way, a spinner in its place.
    @ViewBuilder private func side(_ row: WelcomePlayback.Row) -> some View {
        if row.isAsking {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Waiting on macOS")
        } else if let fix = row.fix {
            Button(fix.title) { self.fix(fix) }
                .buttonStyle(.plain)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentColor)
        }
    }
}

/// A card in the column, its rows set in from its sides.
private struct WelcomeCard<Content: View>: View {
    var inset: CGFloat = 10
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, inset)
            .background(WelcomeStyle.card, in: .rect(cornerRadius: WelcomeStyle.cardRadius))
    }
}

/// The hairline between two rows.
private struct Hairline: View {
    var body: some View {
        Rectangle().fill(WelcomeStyle.hairline).frame(height: 1)
    }
}
