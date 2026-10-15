import AppKit
import SitRepPanel
import SwiftUI

/// The window of Lee's dials, opened from the menu bar's menu. SitRep has no Dock icon, so showing it activates the
/// app, or it would open behind whatever Lee is in.
@MainActor
final class PanelSettingsWindow {
    private let window: NSWindow

    init(dials: PanelDials) {
        window = NSWindow(contentViewController: NSHostingController(rootView: PanelSettingsView(dials: dials)))
        window.title = "Panel settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

/// A slider for each of the prototype's dials, what they make beneath, and its Copy settings and Reset.
private struct PanelSettingsView: View {
    @Bindable var dials: PanelDials
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Grid(alignment: .leading, verticalSpacing: 6) {
                ForEach(Dial.allCases, id: \.self) { dial in
                    GridRow {
                        Text(dial.name)
                        Slider(value: value(of: dial), in: dial.range, step: dial.step)
                        Text(dial.show(dials.settings[dial]))
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                    }
                }
            }

            Text(dials.settings.derived)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(copied ? "Copied" : "Copy settings", action: copy)
                Button("Reset", action: dials.reset)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    /// A dial's value, put onto its step as it moves, so the JSON prints it as the prototype's slider would.
    private func value(of dial: Dial) -> Binding<Double> {
        Binding(
            get: { dials.settings[dial] },
            set: { dials.settings[dial] = dial.stepped($0) }
        )
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(dials.settings.copied, forType: .string)
        copied = true

        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            copied = false
        }
    }
}
