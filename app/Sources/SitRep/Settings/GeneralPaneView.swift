import AppKit
import SitRepCore
import SitRepMenu
import SwiftUI

/// General: the Claude plugin SitRep runs, its version and the windows running it, Show listing those that need
/// `/reload-plugins`, a click jumping to each; Open at login; and what macOS lets it do. What macOS says is read again
/// each time the window comes forward.
struct GeneralPaneView: View {
    let live: LiveBoard
    let services: SettingsServices
    @State var login: LoginItem?
    @State var ghostty: GhosttyLeave?
    @State private var isListing = false

    /// What macOS says is read as the pane appears; given here, it shows at once, as the stills draw it.
    init(live: LiveBoard, services: SettingsServices, login: LoginItem? = nil, ghostty: GhosttyLeave? = nil) {
        self.live = live
        self.services = services
        _login = State(initialValue: login)
        _ghostty = State(initialValue: ghostty)
    }

    var body: some View {
        let card = PluginCard(live.last, plugin: live.plugin)

        Form {
            Section {
                plugin(card)
                if isListing {
                    ForEach(card.reloads) { reload in
                        Button {
                            services.jump(reload.session)
                        } label: {
                            Label(reload.label, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            Section {
                Toggle(isOn: opensAtLogin) {
                    Text("Open at login")
                    if let line = login?.line {
                        Text(line)
                    }
                }
                .disabled(login == nil)
            }
            Section("What macOS lets it do") {
                SettingsRow(title: "Jump to a session's window", line: ghostty?.words) {
                    ChangeButton { services.open(.automation) }
                }
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.2), value: isListing)
        .task { await read() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await read() }
        }
        .onChange(of: card.reloads.isEmpty) { _, isEmpty in
            if isEmpty {
                isListing = false
            }
        }
    }

    private func plugin(_ card: PluginCard) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "apple.terminal")
                .font(.system(size: 18))
                .frame(width: 34, height: 34)
                .background(.quaternary, in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(card.line).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if !card.reloads.isEmpty {
                Button(isListing ? "Hide" : "Show") { isListing.toggle() }
            } else if card.isCurrent {
                Label {
                    Text("Current").foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
    }

    /// Open at login, from the login item's real status, read again once Lee flips it.
    private var opensAtLogin: Binding<Bool> {
        Binding(get: { login?.isOn ?? false }, set: { _ in
            services.chooseLogin()
            login = services.login()
        })
    }

    private func read() async {
        login = services.login()
        ghostty = await services.ghostty()
    }
}
