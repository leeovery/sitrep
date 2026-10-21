import AppKit
import SitRepMenu
import SwiftUI

/// Settings' rows as a project's page sets its asks: on the ask cards' raise, at their radius, split by the page's
/// hairline, one box deep. Rows of SitRep's own at the drawing's metrics, not SwiftUI's grouped Form, whose sections
/// draw their own fill and insets, scroll on their own and draw nothing as a still.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(WindowStyle.raise, in: .rect(cornerRadius: 14, style: .continuous))
    }
}

extension WindowStyle {
    /// The column on the right of Settings' rows that every control shares.
    static let controls: CGFloat = 176
}

/// The hairline between two rows of a card, in from its left.
struct CardSeparator: View {
    var body: some View {
        Rectangle().fill(WindowStyle.line).frame(height: 1).padding(.leading, 18)
    }
}

/// A row of a card: its label, the line under it, and its control at the system's own size, set to the right of the
/// one column every row's control shares, so the eye runs straight down them; with an icon, its tile leading.
/// Disabled, its words dim as the system dims a disabled row's.
struct CardRow<Control: View>: View {
    let label: String
    var line: String?
    /// An SF Symbol, in a tile before the words.
    var icon: String?
    @ViewBuilder let control: () -> Control

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 14) {
                if let icon {
                    IconTile(symbol: icon)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15))
                        .foregroundStyle(WindowStyle.text)
                        .opacity(isEnabled ? 1 : 0.5)
                    if let line {
                        Text(line)
                            .font(.system(size: 13))
                            .foregroundStyle(WindowStyle.soft)
                            .opacity(isEnabled ? 1 : 0.6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
                .fixedSize()
                .frame(width: WindowStyle.controls, alignment: .trailing)
        }
        .padding(.vertical, icon == nil ? 12 : 14)
        .padding(.horizontal, 18)
        .frame(minHeight: icon == nil ? 64 : 72)
    }
}

/// The tile an icon sits in at a row's head: a dark rounded square under a hairline.
private struct IconTile: View {
    let symbol: String

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 9, style: .continuous)

        Image(systemName: symbol)
            .font(.system(size: 15))
            .foregroundStyle(WindowStyle.text)
            .frame(width: 36, height: 36)
            .background(tile.fill(LinearGradient(
                colors: [Color(hex: 0x3C3C42), Color(hex: 0x1B1B1E)], startPoint: .topLeading, endPoint: .bottomTrailing
            )))
            .overlay(tile.strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

/// A row from what it says of itself (`SettingsRow`): its state where its control goes. A green dot and a word when
/// it's fine; a push button, its ellipsis saying it opens somewhere else, when the fix is Lee's, greyed while `isBusy`
/// says the fix is under way; the switch, bound to `isOn`; or Show Windows, a click on a window jumping to it.
struct StatedRow: View {
    let row: SettingsRow
    var icon: String?
    var isOn: Binding<Bool> = .constant(false)
    var isBusy = false
    let fix: (SettingsRow.Fix) -> Void
    var jump: (String) -> Void = { _ in }

    var body: some View {
        CardRow(label: row.label, line: row.line, icon: icon) { side }
            .disabled(row.side == .toggle(isEnabled: false))
    }

    @ViewBuilder private var side: some View {
        switch row.side {
        case .none:
            EmptyView()
        case let .fine(word):
            StatusDot(word: word)
        case let .button(title, fix):
            Button(title) { self.fix(fix) }.buttonStyle(.bordered).disabled(isBusy)
        case .toggle:
            Toggle(row.label, isOn: isOn).toggleStyle(.switch).labelsHidden()
        case let .windows(windows):
            Menu("Show Windows") {
                ForEach(windows) { window in
                    Button(window.label) { jump(window.session) }
                }
            }
            .menuStyle(.button)
        }
    }
}

/// All well: a green dot, then its word; to VoiceOver, the word.
struct StatusDot: View {
    let word: String

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(Color(nsColor: .systemGreen)).frame(width: 8, height: 8)
            Text(word).font(.system(size: 13)).foregroundStyle(WindowStyle.soft)
        }
        .spoken(word)
    }
}
