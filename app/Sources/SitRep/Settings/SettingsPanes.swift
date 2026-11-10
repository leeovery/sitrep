import SitRepMenu
import SitRepPanel
import SitRepScreen
import SwiftUI

/// The pane shown, in the Settings window beside its sidebar (DESIGN, "Settings"): its sections in a column 20 in
/// from the sidebar and from the window's right, with no cap. A pane longer than the window scrolls under the toolbar,
/// with the system's scroll edge; a short one leaves the rest of the window empty. Turned to another pane, it opens at
/// that pane's top.
struct SettingsPaneView: View {
    let settings: SettingsModel

    var body: some View {
        ScrollView {
            SettingsPaneContent(pane: settings.pane, settings: settings)
        }
        .id(settings.pane)
    }
}

/// A pane's sections, 26 apart, its first 13 under the toolbar, as Paper's boards draw them.
struct SettingsPaneContent: View {
    let pane: SettingsPane
    let settings: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsStyle.sectionGap) {
            switch pane {
            case .general: GeneralPane(settings: settings)
            case .edge: EdgePaneView(settings: settings)
            case .notifications: NotificationsPane(settings: settings)
            case .claudeCode: ClaudeCodePaneView(settings: settings)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SettingsStyle.paneInset)
        .padding(.top, 13)
        .padding(.bottom, SettingsStyle.paneInset)
    }
}

/// General: Startup, Open at login; Ghostty, the leave to bring a session's Ghostty window to the front; New windows,
/// the command typed into a window opened for a session no window shows, one for each multiplexer.
private struct GeneralPane: View {
    let settings: SettingsModel

    var body: some View {
        SettingsSection(name: "Startup") {
            SettingsCard {
                StatedRow(row: .login(settings.said.login), isOn: opensAtLogin, fix: settings.fix)
            }
        }
        SettingsSection(name: "Ghostty") {
            SettingsCard {
                StatedRow(row: .ghostty(settings.said.ghostty), isBusy: settings.isAllowing, fix: settings.fix)
            }
        }
        SettingsSection(name: "New windows") {
            SettingsCard {
                AttachRows(zmx: command(\.zmxAttach), tmux: command(\.tmuxAttach))
            }
            CaptionRow(words: Text(AttachRows.caption))
        }
    }

    private var opensAtLogin: Binding<Bool> {
        Binding(get: { settings.said.login?.isOn ?? false }, set: { _ in settings.chooseLogin() })
    }

    /// A command as typed, saved at each keystroke.
    private func command(_ setting: WritableKeyPath<AppSettings, String>) -> Binding<String> {
        Binding(
            get: { settings.preferences.app[keyPath: setting] },
            set: { settings.preferences.app[keyPath: setting] = $0 }
        )
    }
}

/// The attach commands, a row for each multiplexer, zmx's over tmux's: its name over the placeholders it fills, and the
/// command in a field against the card's right, in the label's size in the monospaced face, SitRep's own shown greyed
/// in it while Lee has given none, and under it, as he types, what is wrong with what he typed, the row growing. The
/// rows are a grid's, so the fields line up at every width, and the words of each stand centred on its field, never on
/// the field and its warning. The fields give way before the words do, so the words keep their one line, and each row
/// its height, at the window's least width.
struct AttachRows: View {
    static let caption = "Clicking a session that isn't showing in a terminal opens a new Ghostty window and runs the "
        + "matching command. Placeholders are replaced with quoted values. Leave a field empty to use the default."
    /// Wide enough for the tmux default whole in the monospaced face.
    static let fieldWidth: CGFloat = 300
    /// The least a field gives way to: still wide enough for zmx's default whole.
    static let leastFieldWidth: CGFloat = 200
    /// Between a field and its warning.
    private static let warningGap: CGFloat = 4

    @Binding var zmx: String
    @Binding var tmux: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
            row(.zmx, $zmx)
            Rectangle().fill(SettingsStyle.separator).frame(height: 0.5).gridCellUnsizedAxes(.horizontal)
            row(.tmux, $tmux)
        }
        .padding(.horizontal, SettingsStyle.inset)
    }

    private func row(_ kind: MultiplexerKind, _ command: Binding<String>) -> some View {
        GridRow(alignment: .fieldCentre) {
            RowWords(label: kind.rawValue, line: "Placeholders: \(kind.placeholderList)")
                .fixedSize(horizontal: true, vertical: false)
                .alignmentGuide(.fieldCentre) { $0[VerticalAlignment.center] }
            VStack(alignment: .leading, spacing: Self.warningGap) {
                TextField(kind.rawValue, text: command, prompt: Text(AttachCommands.default(for: kind)))
                    .font(.system(size: NSFont.systemFontSize).monospaced())
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .alignmentGuide(.fieldCentre) { $0[VerticalAlignment.center] }
                if let warning = AttachCommands.warning(about: command.wrappedValue, for: kind) {
                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, SettingsStyle.rowMargin)
                }
            }
            .frame(minWidth: Self.leastFieldWidth, maxWidth: Self.fieldWidth)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

extension VerticalAlignment {
    /// A row's words and its field, centre to centre, whatever shows under the field.
    private enum FieldCentre: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let fieldCentre = VerticalAlignment(FieldCentre.self)
}

/// Notifications: the desktop corner a new ask's notification lands on, its caption and Send Test; Banners, the switch
/// and macOS's own answer; Sound, what a new ask plays, which banners, silent, leave alone: its switch, and the sound,
/// greyed while the switch is off.
private struct NotificationsPane: View {
    let settings: SettingsModel

    var body: some View {
        let said = settings.said

        VStack(alignment: .leading, spacing: 0) {
            DesktopCorner()
            CaptionRow(
                words: Text("A new ask, as it lands on your desktop"), button: "Send Test",
                action: settings.services.sendTest
            )
        }
        SettingsSection(name: "Banners") {
            SettingsCard {
                StatedRow(row: .notify(said.notices, show: settings.preferences.edge.show), isOn: notifies, fix: settings.fix)
                CardSeparator()
                StatedRow(row: .allowed(said.notices), fix: settings.fix)
            }
        }
        SettingsSection(name: "Sound") {
            SettingsCard {
                CardRow(label: "Play a sound for a new ask", line: "Once, whichever session it lands in") {
                    MiniSwitch(label: "Play a sound for a new ask", isOn: playsSound)
                }
                CardSeparator()
                CardRow(label: "Sound") {
                    PopUp(label: "Sound", sections: [settings.services.sounds.names], title: \.self, selection: sound)
                }
                .disabled(!settings.preferences.app.playsSound)
            }
        }
    }

    private var notifies: Binding<Bool> {
        Binding(get: { settings.preferences.app.notifiesNewAsks }, set: settings.notify)
    }

    private var playsSound: Binding<Bool> {
        Binding(get: { settings.preferences.app.playsSound }, set: { settings.preferences.app.playsSound = $0 })
    }

    private var sound: Binding<String> {
        Binding(
            get: { settings.services.sounds.chosen(settings.preferences.app.sound) }, set: settings.choose(sound:)
        )
    }
}

/// Claude Code: Plugin, the plugin's row; and while some windows run an older plugin, Needs /reload-plugins, each a
/// row with Show, which jumps to it as the menu's item for it does, then how to reload them, with Copy. It reads the
/// board, which `watch` brings each time it prints.
private struct ClaudeCodePaneView: View {
    let settings: SettingsModel

    var body: some View {
        let pane = ClaudeCodePane(settings.live.last, plugin: settings.live.plugin)

        SettingsSection(name: "Plugin") {
            SettingsCard {
                StatedRow(row: pane.plugin, fix: settings.fix)
            }
        }
        if !pane.reloads.isEmpty {
            SettingsSection(name: ClaudeCodePane.reloadTitle) {
                SettingsCard {
                    ForEach(Array(pane.reloads.enumerated()), id: \.element.id) { place, reload in
                        if place > 0 {
                            CardSeparator()
                        }
                        ReloadRow(reload: reload) { settings.show(reload) }
                    }
                }
                CaptionRow(
                    words: Text("Type \(Text(ClaudeCodePane.command).monospaced()) in each; a new window needs nothing"),
                    button: "Copy", action: settings.copyReloadCommand
                )
            }
        }
    }
}

/// A window on an older plugin: its session over its project and version, and Show, to VoiceOver with the session's
/// name.
private struct ReloadRow: View {
    let reload: ClaudeCodePane.Reload
    let show: () -> Void

    var body: some View {
        CardRow(label: reload.name, line: reload.line) {
            Button("Show", action: show)
                .buttonStyle(.bordered)
                .accessibilityLabel("Show \(reload.name)")
        }
    }
}
