import AppKit
import SitRepWindow
import SwiftUI

/// The SitRep window's colours and type, from Paper's "The SitRep window" (surfaces round 3) and its tokens, in the
/// system's fonts: SF Pro where the drawing sets Inter, SF Mono where it sets Geist Mono.
enum WindowStyle {
    static let black = Color(hex: 0x000000)
    static let raise = Color(hex: 0x141416)
    static let line = Color(hex: 0x232327)
    static let text = Color(hex: 0xF5F5F7)
    static let soft = Color(hex: 0x98989F)
    static let faint = Color(hex: 0x5C5C63)
    static let orange = Color(hex: 0xE9643D)
    /// A white pill's words.
    static let ink = Color(hex: 0x111113)
    /// An outlined pill's ring.
    static let ring = Color(hex: 0x2C2C31)
    /// An option's fill and its ring.
    static let option = Color(hex: 0x1C1C1F)
    static let optionRing = Color(hex: 0x34343A)
    /// A pill under the pointer: its fill and its ring lifted.
    static let optionLift = Color(hex: 0x26262A)
    static let ringLift = Color(hex: 0x45454C)
    /// A page's row under the pointer, fainter than the picked one's raise.
    static let hover = Color(hex: 0x0D0D0F)
    /// A sidebar row under the pointer, behind its words, over the system's sidebar.
    static let sidebarHover = Color.white.opacity(0.06)
    /// The system's selection in the sidebar, drawn as a still, which renders no list.
    static let stillSelection = Color.white.opacity(0.12)
    /// An away session's dot.
    static let awayDot = Color(hex: 0x46464C)
    /// The working arc's track, and the arc.
    static let track = Color(hex: 0x2C2C31)
    static let arc = Color(hex: 0xC9C9CF)
    /// What is new, and a stop: washed orange in a ring of it.
    static let wash = orange.opacity(0.12)
    static let washRing = orange.opacity(0.28)

    /// A colour of words or of a mark on what is behind them: on the accent of a selection in the list that has the
    /// window's focus, `selected`, as the system brightens its own rows' words and icons; on anything else, its own.
    static func colour(_ own: Color, on prominence: BackgroundProminence, selected: Color = .white) -> Color {
        prominence == .increased ? selected : own
    }

    /// The working arc's track on the accent of a selection: dimmer than the arc, now white, so the arc still reads.
    static let selectedTrack = Color.white.opacity(Double(0x4D) / 255)

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    /// The window as drawn: its two columns and their insides.
    static let size = CGSize(width: 1100, height: 720)
    /// As small as the window goes.
    static let smallest = CGSize(width: 860, height: 520)
    static let boardWidth: CGFloat = 296
    static let pageInset: CGFloat = 44
    /// Settings' right inset, less than a page's: under a page of 704 + 44 + 36, its column narrows with the page.
    static let settingsInset: CGFloat = 36
    /// The band under the window's toolbar, beside the traffic lights, which the toolbar sets 26 points down: empty on
    /// the page, which starts under it.
    static let barHeight: CGFloat = 52
    /// The sidebar, as Paper's round 8 draws it (board C, "Option B, one list"). The accessory over the list: the
    /// Filter field, the system's at its large size, 28 tall, 9 under the titlebar's band and 10 over the list.
    static let accessoryTop: CGFloat = 9
    static let fieldHeight: CGFloat = 28
    static let accessoryBottom: CGFloat = 10
    static let accessory = accessoryTop + fieldHeight + accessoryBottom
    /// The system's sidebar list, as measured offscreen on macOS 26 in the window's split: it sets its rows 10 in from
    /// its top and its bottom, which no modifier changes, and a row's words 16 in from the sidebar's edges, 6 inside
    /// its selection, which is 10 in.
    static let listInset: CGFloat = 10
    static let selectionInset: CGFloat = 10
    static let rowInset: CGFloat = 16
    /// The list's last row, 12 over the foot's rule.
    static let listBottom: CGFloat = 12
    /// A session's row, the sidebar's medium row; a session's row under Needs you, the system's two-line row, its
    /// words 4 from its top; a heading's row, 10 under the rows before it, or 2 under the list's top when it is first.
    static let rowHeight: CGFloat = 32
    static let twoLineHeight: CGFloat = 39
    static let twoLineTop: CGFloat = 4
    static let headingHeight: CGFloat = 24
    static let headingGap: CGFloat = 10
    static let firstHeadingGap: CGFloat = 2
    /// A heading's words end 2 inside its selection, 4 past a row's.
    static let headingTrailing: CGFloat = 2
    /// A row's mark, in its slot, the gap after it to the words, and a heading's chevron in its slot.
    static let slot = CGSize(width: 26, height: 16)
    static let slotGap: CGFloat = 4
    static let chevronSlot = CGSize(width: 15, height: 24)
    /// The selection's corners: a row's, as drawn, and a heading's, which SitRep draws (`FoldHeading`).
    static let rowRadius: CGFloat = 9
    static let headingRadius: CGFloat = 8
    /// The sidebar's words: a title's, 13 with its tracking; a heading's, a row's project line and a count's, 11.
    static let titleSize: CGFloat = 13
    static let titleTracking: CGFloat = -0.01
    static let smallSize: CGFloat = 11
    static let ageSize: CGFloat = 12
    static let titleLine: CGFloat = 16
    static let smallLine: CGFloat = 14
    /// The sidebar's foot, as spec 2.5 draws it: a rule of 0.5, then 8 above its row of 32 and 10 below it.
    static let footerRule: CGFloat = 0.5
    static let footerTop: CGFloat = 8
    static let footerRow: CGFloat = 32
    static let footerBottom: CGFloat = 10
    /// A mark's lane, as the panel row's.
    static let lane = CGSize(width: 12, height: 18)
    /// Where a page line's words start, past its mark's lane.
    static let wordsEdge: CGFloat = 22
    /// How far a page line's highlight reaches past the column's edges, so its words keep their place beside the
    /// headings.
    static let reach: CGFloat = 8

    /// What a sidebar row draws behind its words: under the pointer, a quiet fill, never on the row picked, which
    /// keeps the system's selection; drawn as a still, which renders no list, a stand-in for that selection. A
    /// heading draws none.
    static func sidebarFill(_ highlight: Highlight, isStill: Bool) -> Color? {
        switch highlight {
        case .hover: sidebarHover
        case .picked: isStill ? stillSelection : nil
        case .none: nil
        }
    }

    /// The sidebar's words of a tone, in the system's label colours, which the list's emphasized selection turns white
    /// by itself.
    static func label(_ tone: Tone) -> HierarchicalShapeStyle {
        switch tone {
        case .text: .primary
        case .soft: .secondary
        case .faint: .tertiary
        }
    }

    /// The working mark's track in the sidebar, as drawn.
    static let sidebarTrack = Color.white.opacity(0.15)

    /// The system's selection, as SitRep draws it where no list does, on a heading, which the list will not select
    /// (`FoldHeading`), and on Settings at the foot (`SettingsFooter`): the accent's while it has the key window's
    /// focus, else the system's grey; drawn as a still, the stand-in.
    static func selection(isEmphasized: Bool, isStill: Bool) -> Color {
        if isStill {
            return stillSelection
        }

        let system: NSColor = isEmphasized ? .selectedContentBackgroundColor : .unemphasizedSelectedContentBackgroundColor

        return Color(nsColor: system)
    }

    /// The rule over the sidebar's foot.
    static let separator = Color(nsColor: .separatorColor)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// Letter-spacing as the drawing gives it, in ems of this size.
    func spacing(_ ems: CGFloat, of size: CGFloat) -> some View {
        tracking(ems * size)
    }
}
