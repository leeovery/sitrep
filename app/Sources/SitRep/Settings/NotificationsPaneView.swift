import AppKit
import SitRepMenu
import SwiftUI

/// Notifications: the notification a new ask sends, drawn; the switch, off by default; a test; and macOS's own answer,
/// read again each time the window comes forward, as Lee may have changed it in System Settings.
struct NotificationsPaneView: View {
    @Bindable var preferences: Preferences
    let services: SettingsServices
    @State var leave: NoticeLeave?

    init(preferences: Preferences, services: SettingsServices, leave: NoticeLeave? = nil) {
        self.preferences = preferences
        self.services = services
        _leave = State(initialValue: leave)
    }

    var body: some View {
        Form {
            Section {
                NoticePreview()
            } footer: {
                Text("What a new ask sends when this is on, silent, and a click on it jumps")
            }
            Section {
                Toggle(isOn: notifies) {
                    Text("Notify me of a new ask")
                    Text(NotificationsPane.switchLine(isOn: preferences.app.notifiesNewAsks, show: preferences.edge.show))
                }
                SettingsRow(title: "A test notification") {
                    Button("Send", action: services.sendTest)
                }
            }
            Section {
                SettingsRow(title: "In System Settings", line: leave?.words) {
                    ChangeButton { services.open(.notifications) }
                }
            }
        }
        .formStyle(.grouped)
        .task { await read() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await read() }
        }
    }

    /// The switch: turned on, macOS is asked for leave, unless Lee answered already.
    private var notifies: Binding<Bool> {
        Binding(get: { preferences.app.notifiesNewAsks }, set: { isOn in
            preferences.app.notifiesNewAsks = isOn
            if isOn {
                Task {
                    await services.askForNotices()
                    await read()
                }
            }
        })
    }

    private func read() async {
        leave = await services.noticeLeave()
    }
}

/// The notification a new ask sends, drawn as macOS draws one: SitRep's icon, the ask's title, its project and session.
private struct NoticePreview: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("Choose how long the ledger keeps requests").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text("Switchboard · Usage").font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("now").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12), lineWidth: 0.5) }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
