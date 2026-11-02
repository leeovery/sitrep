import AppKit
import SitRepMenu
import SwiftUI

/// Settings set as System Settings sets its grouped form, measured on macOS 26 (spec round 8, 4), in Xcode 27's frame:
/// its words in the system's own roles and text styles, its rows at the form's heights, its cards the system's fill.
enum SettingsStyle {
    static let label = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)
    /// A card, on the window's own background, at Xcode's radius.
    static let card = Color(nsColor: .tertiarySystemFill)
    static let cardRadius: CGFloat = 12
    /// A row's words and its control, in from the card's edges; a section header and the line where a card would
    /// be, in as far.
    static let inset: CGFloat = 10
    /// Over and under what a row holds, its words or the Show row's pictures: the drawing's 52 less a row's two lines,
    /// 16 and 14, and the 2 between, which is what a wrapped line grows the row by.
    static let rowMargin: CGFloat = 10
    /// Between a section's header and what it heads.
    static let headerGap: CGFloat = 10
    /// Between a section and the next.
    static let sectionGap: CGFloat = 26
    /// The panes' column, in from the sidebar and from the window's right.
    static let paneInset: CGFloat = 20
    /// A row at least as tall as the form's: with a line under its label, or without.
    static let twoLineRow: CGFloat = 52
    static let oneLineRow: CGFloat = 38
}

/// A section of Settings: its header, in sentence case as the form heads its sections, 10 over what it heads.
struct SettingsSection<Content: View>: View {
    let name: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsStyle.headerGap) {
            Text(name)
                .font(.body.weight(.semibold))
                .spacing(-0.01, of: 13)
                .foregroundStyle(SettingsStyle.label)
                .padding(.horizontal, SettingsStyle.inset)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) { content }
        }
    }
}

/// Settings' rows on a card, one box deep: rows of SitRep's own at the form's metrics, not SwiftUI's grouped Form,
/// whose sections draw their own fill and insets, scroll on their own and draw nothing as a still.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(SettingsStyle.card, in: .rect(cornerRadius: SettingsStyle.cardRadius, style: .continuous))
    }
}

/// Words under what a section shows, in its line's style, with a push button against the column's right: the desktop
/// corner's caption and Send Test, and Needs /reload-plugins' note and Copy.
struct CaptionRow: View {
    let words: Text
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            words.font(.subheadline).foregroundStyle(SettingsStyle.secondary)
            Spacer(minLength: 0)
            Button(button, action: action).buttonStyle(.bordered).fixedSize()
        }
        .padding(.top, 8)
        .padding(.horizontal, SettingsStyle.inset)
    }
}

/// The hairline between two rows of a card, in from both its ends.
struct CardSeparator: View {
    var body: some View {
        Rectangle().fill(SettingsStyle.separator).frame(height: 0.5).padding(.horizontal, SettingsStyle.inset)
    }
}

/// A row of a card: its label, the line under it, and its control at the system's own size against the card's right.
/// The words take what the control leaves, wrapping onto more lines, so the row grows, before the control would give
/// up any of its width. Disabled, its words dim as the system dims a disabled row's.
struct CardRow<Control: View>: View {
    let label: String
    var line: String?
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 16) {
            RowWords(label: label, line: line)
            control().fixedSize()
        }
        .padding(.horizontal, SettingsStyle.inset)
        .frame(minHeight: line == nil ? SettingsStyle.oneLineRow : SettingsStyle.twoLineRow)
    }
}

/// A row's words: its label, 13, and the line under it, 11 in the secondary colour, taking the width the row leaves
/// them and wrapping onto more lines. Disabled, they dim as the system dims a disabled row's.
struct RowWords: View {
    let label: String
    var line: String?

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.body)
                .spacing(-0.01, of: 13)
                .foregroundStyle(SettingsStyle.label)
                .opacity(isEnabled ? 1 : 0.5)
            if let line {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(SettingsStyle.secondary)
                    .opacity(isEnabled ? 1 : 0.6)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, SettingsStyle.rowMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The switch as the HIG sets one in a grouped form: the mini switch.
struct MiniSwitch: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn).toggleStyle(.switch).controlSize(.mini).labelsHidden()
    }
}

/// A row from what it says of itself (`SettingsRow`): its state where its control goes. A green dot and a word when
/// it's fine; a push button, its ellipsis saying it opens somewhere else, when the fix is Lee's, greyed while `isBusy`
/// says the fix is under way; or the switch, bound to `isOn`.
struct StatedRow: View {
    let row: SettingsRow
    var isOn: Binding<Bool> = .constant(false)
    var isBusy = false
    let fix: (SettingsRow.Fix) -> Void

    var body: some View {
        CardRow(label: row.label, line: row.line) { side }
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
            MiniSwitch(label: row.label, isOn: isOn)
        }
    }
}

/// All well: a green dot, then its word; to VoiceOver, the word.
struct StatusDot: View {
    let word: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(nsColor: .systemGreen)).frame(width: 7, height: 7)
            Text(word).font(.body).foregroundStyle(SettingsStyle.secondary)
        }
        .spoken(word)
    }
}
