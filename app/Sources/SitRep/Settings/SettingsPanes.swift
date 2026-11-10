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
/// how a window is opened for a session no window shows, the terminal and the open command.
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
                CardRow(label: "Terminal") {
                    PopUp(label: "Terminal", sections: [Driver.all], title: \.name, selection: terminal)
                }
                CardSeparator()
                CommandRow(command: openCommand)
            }
            CaptionRow(words: Text(CommandRow.caption))
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

    /// The command as typed, saved at each keystroke.
    private var openCommand: Binding<String> {
        Binding(get: { settings.preferences.app.openCommand }, set: { settings.preferences.app.openCommand = $0 })
    }
}

/// The open command's row: its label, and the command in a field against the card's right, in the label's size in the
/// monospaced face, kept as typed (`LiteralField`), the two on one line of text. The field gives way before the label
/// does, so the label keeps its one line, and the row its height, at the window's least width.
struct CommandRow: View {
    static let label = "Open command"
    static let caption = "Clicking a session that isn't showing in a terminal opens a new window and runs this "
        + "command. {session}, {socket} and {pane} are replaced with quoted values."
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
