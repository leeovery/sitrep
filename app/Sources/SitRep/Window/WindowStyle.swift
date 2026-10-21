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

    /// Words of this tone on what is behind them: on a row selected in a list with focus, its selection the accent,
    /// white whatever their tone, as the system's own rows' words go; on anything else, their own grey.
    static func colour(_ tone: Tone, on prominence: BackgroundProminence = .standard) -> Color {
        guard prominence != .increased else {
            return .white
        }

        switch tone {
        case .text: return text
        case .soft: return soft
        case .faint: return faint
        }
    }

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
    /// Settings' right inset, less than a page's, so the three pictures fit beside one another as drawn.
    static let settingsInset: CGFloat = 36
    /// The band under the window's toolbar, beside the traffic lights, which the toolbar sets 26 points down: empty on
    /// the page, which starts under it.
    static let barHeight: CGFloat = 52
    /// The system's sidebar list, as it lays out its rows, measured offscreen on macOS 26: a row's height, its words in
    /// from the sidebar's edges, and the gap between two sections.
    static let rowHeight: CGFloat = 32
    /// What the list sets above and below a row's words, a lane's 18 points tall in a row of 32: a still sets it.
    static let rowPadding: CGFloat = (rowHeight - lane.height) / 2
    static let rowInset: CGFloat = 16
    static let sectionGap: CGFloat = 13
    /// The sidebar's foot, as spec 2.6 draws it: a hairline, then 8 above its row of 32 and 10 below it.
    static let footerTop: CGFloat = 8
    static let footerRow: CGFloat = 32
    static let footerBottom: CGFloat = 10
    /// The foot is a list of its one row, which the system's sidebar list sets 10 in from its top and from its bottom,
    /// as measured offscreen on macOS 26: its bottom inset is the drawing's 10, and its top is tucked under the hairline
    /// by what the drawing's 8 lacks of it.
    static let footerListInset: CGFloat = 10
    static let footerList = footerListInset + footerRow + footerListInset
    /// The hairline over the foot, in from the sidebar's sides as its rows are.
    static let footerLine = Color.white.opacity(Double(0x14) / 255)
    /// The system's selection in the sidebar, in from its edges and rounded, which a row's fills take: by eye, as
    /// nothing offscreen draws it.
    static let selectionInset: CGFloat = 10
    static let selectionRadius: CGFloat = 6
    /// A mark's lane, as the panel row's.
    static let lane = CGSize(width: 12, height: 18)
    /// Where a page line's words start, past its mark's lane.
    static let wordsEdge: CGFloat = 22
    /// How far a page line's highlight reaches past the column's edges, so its words keep their place beside the
    /// headings.
    static let reach: CGFloat = 8

    /// What a sidebar row draws behind its words: under the pointer, a quiet fill, never on the row picked, which
    /// keeps the system's selection; drawn as a still, which renders no list, a stand-in for that selection.
    static func sidebarFill(_ highlight: Highlight, isStill: Bool) -> Color? {
        switch highlight {
        case .hover: sidebarHover
        case .picked: isStill ? stillSelection : nil
        case .none: nil
        }
    }
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
