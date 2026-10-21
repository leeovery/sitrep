import SitRepWindow
import SwiftUI

/// The board down the left, in the system's sidebar: the Filter field, then one list (`Sidebar`): Needs you, the
/// projects each under a heading that folds, and the quiet projects under theirs. The filter narrows it in place, the
/// words typed lit in the names that hold them; with nothing kept, one line says so, and an empty board says how the
/// board stands. Its rows are a list whose selection is the row picked, of a session's two while it has an ask, drawn
/// by the system, which the pointer and the arrow keys move alike, and which never empties; a quiet project's row opens
/// the project. A row under the pointer that is not the one picked shows a quiet fill behind it. The row picked is
/// scrolled into view whenever the pick or the order changes: a pick made elsewhere, by a jump, a notification or the
/// menu, or a resort. Settings sits at the sidebar's foot, which never scrolls; while it shows, nothing on the board
/// is picked.
struct BoardColumn: View {
    let sidebar: Sidebar
    let spot: Spot?
    let pick: Pick?
    let filter: Filter
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.reducesWindowMotion) private var reducesMotion
    @Environment(\.isStill) private var isStill
    @Environment(\.controlActiveState) private var activeState
    /// The row picked as the list holds it: the spot, put back whenever the list lets go of it, as a click in its
    /// blank space or on the row picked does, so its selection never empties while something on it is picked.
    @State private var selection: Spot?
    @FocusState private var isListFocused: Bool

    var body: some View {
        if isStill {
            standIn
        } else {
            VStack(alignment: .leading, spacing: 0) {
                accessory
                list
                    .overlay {
                        if let note {
                            ListNote(words: note).padding(.bottom, SettingsFooter.height)
                        }
                    }
                    .overlay(alignment: .bottom) { SettingsFooter(pick: pick, now: now) }
            }
            // A window on screen gives the sidebar a bottom safe area, which an offscreen one does not, and which a
            // list and a bar over it each take into their insets: the foot is set from the glass's bottom instead.
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

    /// The one line in the list's place where it lists nothing: that the filter keeps nothing, or how the board stands.
    private var note: String? {
        guard sidebar.isEmpty else {
            return nil
        }
        return filter.isEmpty ? sidebar.head.title : Words.noMatch(filter)
    }

    /// The list, running on under the foot, its last row 12 over the foot's rule. The system's list sets its first
    /// row 10 under its top, so it starts 10 higher, over the accessory's last 10, for its first heading to sit 2
    /// under the accessory as drawn. Scrolled, its rows pass under those 10, where the drawing clips them: a mask that
    /// would clip them there takes the list's own 10 away (measured offscreen).
    private var list: some View {
        ScrollViewReader { scroller in
            List(selection: $selection) { lines }
                .sidebarList()
                .focused($isListFocused)
                .padding(.top, -WindowStyle.listInset)
                .safeAreaPadding(.bottom, SettingsFooter.height + WindowStyle.listBottom - WindowStyle.listInset)
                .softFoot()
                .animation(reducesMotion ? nil : .easeInOut(duration: 0.25), value: order)
                .onHover { act.pointer($0) }
                .onChange(of: selection) { _, selected in
                    guard let selected else {
                        selection = spot
                        return
                    }
                    if selected != spot {
                        act.pickInList(selected)
                    }
                }
                .onChange(of: spot, initial: true) { _, spot in
                    selection = spot
                    reveal(spot, in: scroller)
                }
                .onChange(of: order) { reveal(spot, in: scroller) }
        }
    }

    private var lines: some View {
        ForEach(Array(sidebar.lines.enumerated()), id: \.element.id) { place, line in
            SidebarLine(
                line: line, isFirst: place == 0, spot: spot, isEmphasized: isListFocused && activeState == .key,
                filter: filter, now: now
            )
            .id(line.id)
        }
    }

    /// The lines in the order they show, which moves the row picked when the list resorts or folds.
    private var order: [Sidebar.Line.ID] {
        sidebar.lines.map(\.id)
    }

    /// The row picked scrolled into view, only as far as it needs.
    private func reveal(_ spot: Spot?, in scroller: ScrollViewProxy) {
        if let spot {
            scroller.scrollTo(Sidebar.Line.ID.spot(spot))
        }
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
                VStack(alignment: .leading, spacing: 0) { lines }
                Spacer(minLength: 0)
            }
            SettingsFooter(pick: pick, now: now)
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
        .frame(height: 28)
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
    /// On macOS 26, the list faded by the system's soft scroll edge where it runs on under the foot (spec 2.5's fade,
    /// the sidebar's glass where Paper drew a gradient); before it, no fade.
    @ViewBuilder func softFoot() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }
}

/// Settings at the sidebar's foot, under a rule, fixed as the list runs on under it: a list of its one row, so it
/// takes the system's own selection while Settings shows, as a picked session's row does, and is a stop of its own for
/// the keys. Drawn as a still, its row alone, as the board's rows are.
struct SettingsFooter: View {
    let pick: Pick?
    let now: Date

    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill
    /// The row as the list holds it, put back whenever the list lets go of it while Settings shows.
    @State private var selection: Pick?

    /// Its rule, and its row with the space above and below it (spec 2.5).
    static let height = WindowStyle.footerRule + WindowStyle.footerTop + WindowStyle.footerRow + WindowStyle.footerBottom

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(WindowStyle.separator)
                .frame(height: WindowStyle.footerRule)
                .padding(.horizontal, WindowStyle.selectionInset)
            if isStill {
                row.padding(.top, WindowStyle.footerTop).padding(.bottom, WindowStyle.footerBottom)
            } else {
                // The list sets its row 10 under its own top, so it starts 2 over the rule, which it draws nothing
                // over, to set its row 8 under it.
                List(selection: $selection) { row }
                    .sidebarList()
                    .scrollDisabled(true)
                    .frame(height: WindowStyle.footerList)
                    .padding(.top, WindowStyle.footerTop - WindowStyle.listInset)
                    .onChange(of: selection) { _, selected in
                        if selected == .settings, pick != .settings {
                            act.pick(.settings)
                        } else if selected == nil, pick == .settings {
                            selection = .settings
                        }
                    }
                    .onChange(of: pick, initial: true) { _, pick in
                        selection = pick == .settings ? .settings : nil
                    }
            }
        }
    }

    private var row: some View {
        SettingsFootRow().sidebarRow(Pick.settings, isPicked: pick == .settings, now: now)
    }
}

/// Settings' row: the gear, in the accent, white on the emphasized selection, and its word.
private struct SettingsFootRow: View {
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            Image(systemName: "gearshape")
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(WindowStyle.colour(Color.accentColor, on: prominence))
                .frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
                .accessibilityHidden(true)
            Text("Settings")
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .foregroundStyle(.primary)
        }
        .frame(height: WindowStyle.footerRow)
    }
}
