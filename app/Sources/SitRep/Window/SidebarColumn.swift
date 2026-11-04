import SitRepWindow
import SwiftUI

/// The sidebar, in the system's sidebar, as A1 revised draws it: the Filter field, then its list (`SidebarList`), the
/// four places and every project. The list runs to the glass's foot, where its rows fade out, its last row 12 over it.
struct SidebarColumn: View {
    let places: Places
    /// What the sidebar shows picked: the place the window is on, or the project, a session pushed from it or not.
    let root: Root
    let filter: Filter

    @Environment(\.isStill) private var isStill

    var body: some View {
        if isStill {
            standIn
        } else {
            VStack(alignment: .leading, spacing: 0) {
                accessory
                list.fadingAtItsFoot()
            }
            // A window on screen gives the sidebar a bottom safe area, which an offscreen one does not: ignored, the
            // list runs to the glass's foot.
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

    private var list: SidebarList {
        SidebarList(places: places, root: root, filter: filter)
    }

    /// A stand-in for the sidebar, drawn as a still: an image renderer draws no list, nor the sidebar it sits in, nor
    /// AppKit's controls. Below the bar the traffic lights sit in, a stand-in for the field, then its rows laid out as
    /// the system's list sets them, the one picked on a stand-in for the selection, all on the panel's black with a
    /// hairline beside it.
    private var standIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            StillField(filter: filter)
            list
            Spacer(minLength: 0)
        }
        .background(WindowStyle.black)
        .overlay(alignment: .trailing) { Rectangle().fill(WindowStyle.line).frame(width: 1) }
    }
}

/// The sidebar's list, whose selection is where the window is, a place or a project, drawn by the system, which the
/// pointer and the arrow keys move alike, each a step Back returns from, and which never empties. A click on the row
/// already picked goes there too, as a session's page pushed from a project goes back to the project's page
/// (`Location.clicking(_:)`). The row showing scrolls into view whenever it changes, only as far as it needs. The
/// pointer over it holds the projects' order. Drawn as a still, its rows one under another, as the list sets them.
///
/// The system's list sets its first row 10 under its top, so it starts 10 higher, over the accessory's last 10, for its
/// first row to start at the accessory's foot (measured offscreen).
struct SidebarList: View {
    let places: Places
    let root: Root
    let filter: Filter

    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill
    /// The row picked as the list holds it, put back whenever the list lets go of it, as a click in its blank space
    /// does, so its selection never empties.
    @State private var selection: Root?

    var body: some View {
        if isStill {
            VStack(alignment: .leading, spacing: 0) { rows }
        } else {
            ScrollViewReader { scroller in
                List(selection: $selection) { rows }
                    .sidebarList()
                    .padding(.top, -WindowStyle.listInset)
                    // The list's own bottom inset, 10, and 2 more: its content margins it ignores (measured offscreen).
                    .safeAreaPadding(.bottom, WindowStyle.listBottom - WindowStyle.listInset)
                    .onHover { act.pointer(.projects, $0) }
                    .onChange(of: selection) { _, selected in
                        guard let selected else {
                            selection = root
                            return
                        }
                        if selected != root {
                            act.click(selected)
                        }
                    }
                    .onChange(of: root, initial: true) {
                        selection = root
                        scroller.scrollTo(root)
                    }
            }
        }
    }

    @ViewBuilder private var rows: some View {
        ForEach(Place.allCases, id: \.self) { place in
            PlaceRow(place: place, count: places.count(of: place))
                .spoken(Spoken.place(place, count: places.count(of: place)))
                .sidebarRow(.place(place), root: root)
                .id(Root.place(place))
        }
        ProjectsHeading()
        ForEach(places.projects) { project in
            ProjectRow(project: project, filter: filter)
                .spoken(Spoken.project(project))
                .sidebarRow(.project(project.id), root: root)
                .id(Root.project(project.id))
        }
    }
}

/// A place's row, 32 tall, as A1 revised draws it: its mark in the mark's slot, Needs you's orange dot, Your turn's
/// ring, Working's arc, still, and Parked's diamond; its name, 13 in white at 85%; and its count in a lane of 26 at its
/// end, 12 in tabular figures, orange and semibold for Needs you, the one orange count, white at 35% for the others,
/// none at nought.
struct PlaceRow: View {
    let place: Place
    let count: Int

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            PlaceMark(place: place)
            Name(place.title, litBy: Filter(), tone: .text, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(count > 0 ? "\(count)" : "")
                .font(WindowStyle.ui(WindowStyle.ageSize, place == .needsYou ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(countInk)
                .frame(width: WindowStyle.countLane, alignment: .trailing)
        }
        .frame(height: WindowStyle.placeHeight)
    }

    private var onPick: Bool { prominence == .increased }

    private var countInk: Color {
        if place == .needsYou {
            return WindowStyle.orange
        }
        return onPick ? WindowStyle.picked(.dim) : WindowStyle.dim
    }
}

/// A place's mark, in the mark's slot: Needs you's orange dot, Your turn's ring, Working's arc on its track, held
/// still, and Parked's diamond, stroked.
private struct PlaceMark: View {
    let place: Place

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        Group {
            switch place {
            case .needsYou: Circle().fill(WindowStyle.orange).frame(width: 7, height: 7)
            case .yourTurn: Circle().stroke(.secondary, lineWidth: 1.5).frame(width: 7.5, height: 7.5)
            case .working:
                TurningArc(
                    radius: 4.25,
                    track: WindowStyle.colour(WindowStyle.sidebarTrack, on: prominence, selected: WindowStyle.selectedTrack),
                    arc: WindowStyle.colour(WindowStyle.sidebarArc, on: prominence)
                )
                .environment(\.reducesWindowMotion, true)
            case .parked: Diamond().stroke(.secondary, lineWidth: 1.5).frame(width: 9, height: 9)
            }
        }
        .frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
        .accessibilityHidden(true)
    }
}

/// A diamond, its points at the middles of its edges: Parked's mark.
struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addLines([
                CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY),
            ])
            path.closeSubpath()
        }
    }
}

/// The heading over the projects, 11 semibold in white at 55%, 16 under the places, with no count and no chevron, as
/// nothing folds; the list never selects it.
private struct ProjectsHeading: View {
    var body: some View {
        Text(Words.projects)
            .font(WindowStyle.ui(WindowStyle.smallSize, .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: WindowStyle.headingHeight, alignment: .leading)
            .padding(.top, WindowStyle.projectsGap)
            .accessibilityAddTraits(.isHeader)
            .selectionDisabled()
            .listCell()
    }
}

/// A project's row, 32 tall, which opens its page, as A1 revised draws it: its mark, the orange dot while a line of a
/// session a window holds waits on Lee, the away ring while only lines of sessions none holds do, else a quiet grey
/// dot; its name, 13 in white at 85%, at 55% where it is quiet; and its sessions, a grey count in the count's lane,
/// none where it is quiet.
struct ProjectRow: View {
    let project: Places.Project
    let filter: Filter

    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: WindowStyle.slotGap) {
            mark.frame(width: WindowStyle.slot.width, height: WindowStyle.slot.height)
            Name(project.name, litBy: filter, tone: project.isQuiet ? .soft : .text, onPick: onPick)
                .font(WindowStyle.ui(WindowStyle.titleSize))
                .spacing(WindowStyle.titleTracking, of: WindowStyle.titleSize)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(project.count.map { "\($0)" } ?? "")
                .font(WindowStyle.ui(WindowStyle.ageSize).monospacedDigit())
                .foregroundStyle(onPick ? WindowStyle.picked(.dim) : WindowStyle.dim)
                .frame(width: WindowStyle.countLane, alignment: .trailing)
        }
        .frame(height: WindowStyle.placeHeight)
    }

    private var onPick: Bool { prominence == .increased }

    @ViewBuilder private var mark: some View {
        switch project.mark {
        case .needs: Circle().fill(WindowStyle.orange).frame(width: 7, height: 7)
        case .awayAsk: AwayRing(ink: WindowStyle.orange)
        case .nothingWaiting: Circle().fill(.tertiary).frame(width: 5, height: 5)
        }
    }
}

/// One line, centred in a list's place, soft.
struct ListNote: View {
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
    /// A list in the sidebar's style, its rows as low as a heading's 24 allows, each row's height its own: the
    /// sidebar's, and the list beside the page, whose rows are the sidebar's at the list's width.
    func sidebarList() -> some View {
        listStyle(.sidebar).environment(\.sidebarRowSize, .small)
    }

    /// A list whose rows fade out at its bottom edge, the glass's foot: on macOS 26 by the system's soft scroll edge
    /// (spec 2.5's fade, the sidebar's glass where Paper drew a gradient); before it, with no fade.
    @ViewBuilder func fadingAtItsFoot() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }
}

private extension View {
    /// A row of the sidebar, tagged with where it goes, picked while the window is there, and a click on it, picked
    /// already, going there too, which the list's selection, unchanged, never tells.
    func sidebarRow(_ root: Root, root picked: Root) -> some View {
        modifier(Reclicked(root: root)).listRow(root, isPicked: root == picked, now: .distantPast)
    }
}

/// A click on a sidebar row the list has selected already, heard beside the list's own, which changes no selection.
private struct Reclicked: ViewModifier {
    let root: Root

    @Environment(\.windowActions) private var act
    @Environment(\.isStill) private var isStill

    func body(content: Content) -> some View {
        if isStill {
            content
        } else {
            content.simultaneousGesture(TapGesture().onEnded { act.click(root) })
        }
    }
}
