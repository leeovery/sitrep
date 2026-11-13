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

/// General: Startup, Open at login; Terminal, the terminal a window is opened in for a session this Mac doesn't show,
/// and beneath it the leave to bring a session's Ghostty window to the front; Resume command, what that window types,
/// with Restore Default.
private struct GeneralPane: View {
    let settings: SettingsModel

    var body: some View {
        SettingsSection(name: "Startup") {
            SettingsCard {
                StatedRow(row: .login(settings.said.login), isOn: opensAtLogin, fix: settings.fix)
            }
        }
        SettingsSection(name: "Terminal") {
            SettingsCard {
                CardRow(label: "Terminal") {
                    PopUp(label: "Terminal", sections: [Driver.all], title: \.name, selection: terminal)
                }
                CardSeparator()
                StatedRow(row: .ghostty(settings.said.ghostty), isBusy: settings.isAllowing, fix: settings.fix)
            }
        }
        SettingsSection(name: "Resume command") {
            SettingsCard {
                CommandRow(command: resumeCommand)
            }
            CaptionRow(
                words: Text(CommandRow.caption), button: "Restore Default",
                isEnabled: !settings.preferences.app.resumesByDefault,
                action: { settings.preferences.app.restoreResumeCommand() }
            )
        }
    }

    private var opensAtLogin: Binding<Bool> {
        Binding(get: { settings.said.login?.isOn ?? false }, set: { _ in settings.chooseLogin() })
    }

    private var terminal: Binding<Driver> {
        Binding(
            get: { settings.preferences.app.openSettings.terminal },
            set: { settings.preferences.app.terminal = $0.program }
        )
    }

    /// The command as typed, saved at each keystroke; the default until Lee gives one.
    private var resumeCommand: Binding<String> {
        Binding(
            get: { settings.preferences.app.openSettings.resumeCommand },
            set: { settings.preferences.app.resumeCommand = $0 }
        )
    }
}

extension AppSettings {
    /// Whether the resume command reads as the default, given or not, so Restore Default has nothing to put back.
    var resumesByDefault: Bool {
        openSettings.resumeCommand == OpenSettings.defaultResumeCommand
    }

    /// The resume command put back to the default: unset, as one never given.
    mutating func restoreResumeCommand() {
        resumeCommand = nil
    }
}

/// The resume command's row: its label, and the command in a field against the card's right, in the label's size in
/// the monospaced face, kept as typed (`LiteralField`), the two on one line of text. The field gives way before the
/// label does, so the label keeps its one line, and the row its height, at the window's least width.
struct CommandRow: View {
    static let label = "Command"
    /// What the command is for, and its placeholders.
    static let caption = "Clicking a session this Mac doesn't show opens a new window and types this command into "
        + "your login shell. {claude} is its Claude Code session id, {dir} the folder it ran in, and {tty} the "
        + "terminal that Claude still runs on, empty unless it does. Each is replaced with a quoted value."
    /// The field's width where the column has room.
    static let fieldWidth: CGFloat = 360
    /// The command's face: monospaced, at the label's size.
    static let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    @Binding var command: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            RowWords(label: Self.label)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)
            LiteralField(label: Self.label, font: Self.font, text: $command)
                .frame(maxWidth: Self.fieldWidth)
                .layoutPriority(1)
        }
        .padding(.horizontal, SettingsStyle.inset)
        .frame(minHeight: SettingsStyle.oneLineRow)
    }
}

/// Notifications: the desktop corner a new ask's notification lands on, its caption and Send Test; then what a new
/// ask and Lee's turn each do, set apart (13 November 2026): Banners, a switch for each and macOS's own answer; Sound,
/// what each plays, which banners, silent, leave alone, its switch and the sound, greyed while the switch is off; and
/// Notch, whether each pulses the notch.
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
                StatedRow(row: notify(.ask), isOn: notifies(.ask), fix: settings.fix)
                CardSeparator()
                StatedRow(row: notify(.turn), isOn: notifies(.turn), fix: settings.fix)
                CardSeparator()
                StatedRow(row: .allowed(said.notices), fix: settings.fix)
            }
        }
        SettingsSection(name: "Sound") {
            SettingsCard {
                SoundRows(
                    label: "Play a sound for a new ask", line: "Once, whichever session it lands in",
                    isOn: binding(\.playsSound), sound: sound(.ask), sounds: settings.services.sounds.names
                )
                CardSeparator()
                SoundRows(
                    label: "Play a sound when it's my turn", line: "Once, as a session's turn ends",
                    isOn: binding(\.playsTurnSound), sound: sound(.turn), sounds: settings.services.sounds.names
                )
            }
        }
        SettingsSection(name: "Notch") {
            SettingsCard {
                CardRow(label: "Pulse for a new ask", line: "It swells and its light flashes") {
                    MiniSwitch(label: "Pulse for a new ask", isOn: binding(\.pulsesNewAsks))
                }
                CardSeparator()
                CardRow(label: "Pulse when it's my turn", line: "It swells as a session's turn ends") {
                    MiniSwitch(label: "Pulse when it's my turn", isOn: binding(\.pulsesTurns))
                }
            }
        }
    }

    private func notify(_ need: Need) -> SettingsRow {
        let preferences = settings.preferences

        return .notify(
            settings.said.notices, show: preferences.edge.show, for: need, pulses: preferences.app.pulses.contains(need)
        )
    }

    private func notifies(_ need: Need) -> Binding<Bool> {
        Binding(
            get: { settings.preferences.app.notifies(need) }, set: { settings.notify($0, for: need) }
        )
    }

    private func binding(_ setting: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.preferences.app[keyPath: setting] },
            set: { settings.preferences.app[keyPath: setting] = $0 }
        )
    }

    private func sound(_ need: Need) -> Binding<String> {
        Binding(
            get: { settings.services.sounds.chosen(settings.preferences.app.sound(for: need)) },
            set: { settings.choose(sound: $0, for: need) }
        )
    }
}

/// A sound's two rows: its switch, and the sound, a pop-up of macOS's alert sounds, greyed while the switch is off.
private struct SoundRows: View {
    let label: String
    let line: String
    @Binding var isOn: Bool
    @Binding var sound: String
    let sounds: [String]

    var body: some View {
        CardRow(label: label, line: line) {
            MiniSwitch(label: label, isOn: $isOn)
        }
        CardSeparator()
        CardRow(label: "Sound") {
            PopUp(label: "Sound", sections: [sounds], title: \.self, selection: $sound)
        }
        .disabled(!isOn)
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
