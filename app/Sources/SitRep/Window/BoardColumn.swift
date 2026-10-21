import SitRepWindow
import SwiftUI

/// The board down the left, in the system's sidebar: the Filter field, then one list (`BoardList`): Needs you, the
/// projects each under a heading that folds, and the quiet projects under theirs. The filter narrows it in place, the
/// words typed lit in the names that hold them; with nothing kept, one line says so, and an empty board says how the
/// board stands. A quiet project's row opens the project. A row under the pointer that is not the one picked shows a
/// quiet fill behind it. Settings sits at the sidebar's foot, which never scrolls, the list running on under it, its
/// last row 12 over the foot's rule; while Settings shows, nothing on the board is picked.
struct BoardColumn: View {
    let sidebar: Sidebar
    let spot: Spot?
    let pick: Pick?
    let filter: Filter
    let now: Date

    @Environment(\.isStill) private var isStill

    var body: some View {
        if isStill {
            standIn
        } else {
            VStack(alignment: .leading, spacing: 0) {
                accessory
                list.underFoot().overlay {
                    if let note {
                        ListNote(words: note).padding(.bottom, SettingsFooter.height)
                    }
                }
            }
            // Over the list and its scroll edge, on the glass's bottom: a window on screen gives the sidebar a bottom
            // safe area, which an offscreen one does not, and by which a foot in the list's bar rose.
            .overlay(alignment: .bottom) { SettingsFooter(pick: pick) }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    /// The Filter field alone, at its large size, which SwiftUI sets on the field.
    private var accessory: some View {
        FilterField(text: filter.text)
            .controlSize(.large)
            .padding(.horizontal, WindowStyle.selectionInset)
            .padding(.top, WindowStyle.accessoryTop)
            .padding(.bottom, WindowStyle.accessoryBottom)
    }

    private var list: BoardList {
        BoardList(sidebar: sidebar, spot: spot, filter: filter, now: now)
    }

    /// The one line in the list's place where it lists nothing: that the filter keeps nothing, or how the board stands.
    private var note: String? {
        guard sidebar.isEmpty else {
            return nil
        }
        return filter.isEmpty ? sidebar.head.title : Words.noMatch(filter)
    }

    /// A stand-in for the sidebar, drawn as a still: an image renderer draws no list, nor the sidebar it sits in, nor
    /// AppKit's controls. Below the bar the traffic lights sit in, a stand-in for the field, then its lines laid out as
    /// the system's list sets them, its picked row on a stand-in for the selection, all on the panel's black with a
    /// hairline beside it.
    private var standIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            StillField(filter: filter)
            if let note {
                ListNote(words: note)
            } else {
                list
                Spacer(minLength: 0)
            }
            SettingsFooter(pick: pick)
        }
        .background(WindowStyle.black)
        .overlay(alignment: .trailing) { Rectangle().fill(WindowStyle.line).frame(width: 1) }
    }
}

/// One line, centred in the list's place, soft.
private struct ListNote: View {
    let words: String

    var body: some View {
        Text(words)
            .font(WindowStyle.ui(WindowStyle.titleSize))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, WindowStyle.rowInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

/// The Filter field as a still draws it, which renders no AppKit control: at its size, its words or its placeholder.
private struct StillField: View {
    let filter: Filter

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Text(filter.text.isEmpty ? Words.filter : filter.text)
                .foregroundStyle(filter.text.isEmpty ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .font(WindowStyle.ui(WindowStyle.titleSize))
        .padding(.leading, 9)
        .frame(height: WindowStyle.fieldHeight)
        .background(Capsule().fill(Color.white.opacity(Double(0x17) / 255)))
        .padding(.horizontal, WindowStyle.selectionInset)
        .padding(.top, WindowStyle.accessoryTop)
        .padding(.bottom, WindowStyle.accessoryBottom)
    }
}

extension View {
    /// A list in the sidebar's style, its rows as low as a heading's 24 allows, each row's height its own.
    func sidebarList() -> some View {
        listStyle(.sidebar).environment(\.sidebarRowSize, .small)
    }
}

private extension View {
    /// Room at the list's foot for Settings, drawn over it, the list running on under it: on macOS 26 the system's own
    /// bar, holding nothing, whose soft scroll edge fades the list where it passes beneath (spec 2.5's fade, the
    /// sidebar's glass where Paper drew a gradient); before it, the list's inset, with no fade.
    @ViewBuilder func underFoot() -> some View {
        let room = Color.clear.frame(height: SettingsFooter.height)

        if #available(macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .bottom).safeAreaBar(edge: .bottom, spacing: 0) { room }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) { room }
        }
    }
}
