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

/// Which form shows, which notch, and the dials of the one shown.
private struct PanelSettingsView: View {
    @Bindable var dials: PanelDials

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Show", selection: $dials.show) {
                ForEach(PanelForm.allCases, id: \.self) { form in
                    Text(form.name).tag(form)
                }
            }
            .pickerStyle(.segmented)

            switch dials.show {
            case .notch:
                Picker("Style", selection: $dials.style) {
                    ForEach(NotchStyle.allCases, id: \.self) { style in
                        Text(style.name).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                switch dials.style {
                case .meniscus:
                    DialsView(settings: $dials.settings, reset: dials.reset)
                case .card:
                    DialsView(settings: $dials.card, reset: dials.reset)
                }
            case .strip:
                DialsView(settings: $dials.strip, reset: dials.reset)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

/// A slider for each of a prototype's dials, what they make beneath, and its Copy settings and Reset.
private struct DialsView<Tuned: PanelSettings>: View {
    @Binding var settings: Tuned
    let reset: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Grid(alignment: .leading, verticalSpacing: 6) {
                ForEach(Tuned.Dial.allCases, id: \.self) { dial in
                    GridRow {
                        Text(dial.name)
                        Slider(value: value(of: dial), in: dial.range, step: dial.step)
                        Text(dial.show(settings[dial]))
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                    }
                }
            }

            Text(settings.derived)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(copied ? "Copied" : "Copy settings", action: copy)
                Button("Reset", action: reset)
            }
        }
    }

    /// A dial's value, put onto its step as it moves, so the JSON prints it as the prototype's slider would.
    private func value(of dial: Tuned.Dial) -> Binding<Double> {
        Binding(
            get: { settings[dial] },
            set: { settings[dial] = dial.stepped($0) }
        )
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(settings.copied, forType: .string)
        copied = true

        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            copied = false
        }
    }
}
