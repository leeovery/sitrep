import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// The SitRep window's key states, drawn offscreen over what the real CLI printed, as Paper's drawing has them: the
/// session, a permission prompt, an away session and its finish, a project, and the moments of an answer and of a
/// board changing under Lee; a session's long name, and the window as narrow as it goes; the sidebar's Needs you view,
/// each view filtered, and a filter that keeps nothing. Each draws whole at the window's size, or at its narrowest.
/// With `SITREP_WINDOW_STILLS` naming a folder, each is kept there as a PNG, to read beside the drawing; nothing opens
/// on the screen.
/// When the real `watch` printed its first line.
private let printed = try! Board.read(Lines.watch[0]).at
private let boards = [
    "sr-macapp": Lines.board, "sr-dash02": Lines.dashboard, "sr-rq7dgr": Lines.ledger, "sr-gs7kq2": Lines.away,
]

@MainActor
struct WindowStillsTests {

    @Test(arguments: Still.allCases)
    func eachStateDrawsWholeAtTheWindowsSize(still: Still) throws {
        let (run, now) = still.run()
        let renderer = ImageRenderer(
            content: stillWindow(run, at: now)
                .frame(width: still.width, height: WindowStyle.size.height)
                .environment(\.colorScheme, .dark)
                .environment(\.isHoveredStill, still == .hovered)
        )

        renderer.scale = 2

        let image = try #require(renderer.cgImage)

        #expect(image.width == Int(still.width * 2))
        #expect(image.height == 1440)
        try keep(image, as: still.rawValue)
    }

    private func keep(_ image: CGImage, as name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["SITREP_WINDOW_STILLS"] else {
            return
        }

        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))

        try png.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
    }

    enum Still: String, CaseIterable {
        case session = "a-the-mac-app"
        case permission = "b1-a-permission-prompt"
        case away = "b2-an-away-session"
        case finishing = "b2-finishing"
        case project = "b3-a-project"
        case pressed = "c1-pressed"
        case onItsWay = "c2-on-its-way"
        case claudeHasIt = "c3-claude-has-it"
        case closedWhileRead = "c4-closed-while-read"
        case newAsk = "c5-a-new-ask"
        case allClear = "c6-all-clear"
        case hovered = "d1-every-row-and-button-hovered"
        case quietProject = "d2-a-quiet-project-picked"
        case openedItems = "d3-items-opened"
        case longOptions = "d4-long-options-as-rows"
        case projectItemOpened = "d5-a-project-its-note-opened"
        case projectOfOne = "d6-a-project-of-one-session"
        case longTitle = "e1-a-long-title"
        case longTitleNarrow = "e2-a-long-title-narrow"
        case narrow = "e3-the-mac-app-narrow"
        case projectNarrow = "e4-a-project-narrow"
        case needsYou = "f1-needs-you"
        case filtered = "f2-projects-filtered"
        case needsYouFiltered = "f3-needs-you-filtered"
        case noMatch = "f4-no-match"

        /// The window's width: as drawn, or as narrow as it goes.
        var width: CGFloat {
            switch self {
            case .longTitleNarrow, .narrow, .projectNarrow: WindowStyle.smallest.width
            default: WindowStyle.size.width
            }
        }

        /// The window's run in the state, and the time it is drawn at.
        func run() -> (WindowRun, Date) {
            let now = printed
            let run = Self.opened(self == .longTitle || self == .longTitleNarrow ? Self.longName : Lines.watch[0])

            switch self {
            case .session, .longTitle, .longTitleNarrow, .narrow:
                break
            case .permission:
                Self.pick(.session("sr-dash02"), in: run)
            case .away:
                Self.pick(.session("sr-gs7kq2"), in: run)
            case .finishing:
                Self.pick(.session("sr-gs7kq2"), in: run)
                run.askToFinish("sr-gs7kq2")
            case .project, .projectNarrow:
                Self.pick(.project("switchboard"), in: run)
                run.toggle(AskAddress(session: "sr-dash02", ask: "k1"))
            case .pressed:
                _ = run.press(.yes("Approve"), on: AskAddress(session: "sr-macapp", ask: "k1"), at: now)
                return (run, now.addingTimeInterval(0.76))
            case .onItsWay:
                Self.heard(Lines.watch[1], in: run, board: Lines.onItsWay)
            case .claudeHasIt:
                Self.heard(Lines.watch[2], in: run, board: Lines.delivered)
            case .closedWhileRead:
                Self.pick(.session("sr-macapp"), in: run, board: Self.resolvedByClaude)
            case .newAsk:
                _ = run.show(Self.heard(Lines.watch[0], Self.withNew), at: now, reducesMotion: false)
                return (run, now.addingTimeInterval(0.3))
            case .allClear:
                _ = run.show(Self.heard(Self.nothingNeedingLee), at: now, reducesMotion: false)
                Self.pick(.session("sr-rq7dgr"), in: run)
            case .hovered:
                break
            case .quietProject:
                Self.pick(.project("kit"), in: run)
            case .openedItems:
                Self.pick(.session("sr-macapp"), in: run, board: Self.withLongItems)
                [.note("sr-macapp:n2"), .parked("p1"), .resolved("k4"), .resolved("k5")].forEach(run.toggle)
            case .longOptions:
                Self.pick(.session("sr-macapp"), in: run, board: Self.withLongOptions)
            case .projectItemOpened:
                for read in run.pick(.project("switchboard")) {
                    Self.answer([read], in: run, board: read.session == "sr-rq7dgr" ? Self.longLedger : nil)
                }
                if case let .project(page) = run.page(at: now), let note = page.notes.first {
                    run.toggle(.note(note.id))
                }
            case .projectOfOne:
                Self.pick(.project("sitrep"), in: run)
                run.toggle(.note("sr-macapp:n2"))
            case .needsYou:
                run.sidebar = .needsYou
            case .filtered:
                run.filter = Filter("ledg")
            case .needsYouFiltered:
                run.sidebar = .needsYou
                run.filter = Filter("switchboard")
            case .noMatch:
                run.filter = Filter("ledgr")
            }
            return (run, now)
        }

        private static func opened(_ line: String) -> WindowRun {
            let run = WindowRun()

            _ = run.show(heard(line), at: printed, reducesMotion: false)
            answer(run.open(), in: run)
            return run
        }

        private static func pick(_ pick: Pick, in run: WindowRun, board: String? = nil) {
            answer(run.pick(pick), in: run, board: board)
        }

        /// `watch`'s first line, then this one, the session it says changed read as `board` has it.
        private static func heard(_ line: String, in run: WindowRun, board: String) {
            answer(run.show(heard(Lines.watch[0], line), at: printed, reducesMotion: false), in: run, board: board)
        }

        private static func answer(_ reads: [Read], in run: WindowRun, board: String? = nil) {
            for read in reads {
                if let text = board ?? boards[read.session] {
                    run.read(read, gave: .board(try! SessionBoard.read(text)), at: printed, reducesMotion: false)
                }
            }
        }

        private static func heard(_ lines: String...) -> LastBoard {
            var last = LastBoard()

            last.begin()
            for line in lines {
                _ = last.hear(.line(line), at: printed)
            }
            return last
        }

        /// The Mac app's choice resolved by Claude, a choice of another id still open in its place.
        private static let resolvedByClaude = Lines.board
            .replacingOccurrences(of: #""id": "k5""#, with: #""id": "k2""#)
            .replacingOccurrences(of: #""id": "k2",\#n      "wants": "choice""#, with: #""id": "k9",\#n      "wants": "choice""#)

        /// The Mac app's choice with options as long as Claude often gives them.
        private static let withLongOptions = Lines.board
            .replacingOccurrences(of: #""Left, the notch's edge""#, with: #""Inside the Claude Code step's script, with its clean-up as a nightly job beside it (recommended)""#)
            .replacingOccurrences(of: #""Right""#, with: #""A Scratch step of its own, after Claude Code's, with its clean-up as a nightly job""#)

        /// The Mac app once its yes was delivered, its note and parked item as long as they often run, the parked item
        /// saying where it was parked from.
        private static let withLongItems = Lines.delivered
            .replacingOccurrences(of: #""text": "The strip written into DESIGN.md""#, with: #""text": "The strip written into DESIGN.md, with its rings, its two lengths and how it carries the board while the notch hides""#)
            .replacingOccurrences(of: #""title": "Try a shy notch",\#n      "where": null"#, with: #""title": "Try a shy notch that hides until the pointer comes near the top of the screen",\#n      "where": "Under \"The notch\", in DESIGN.md""#)

        /// Request ledger's status as long as it often runs.
        private static let longLedger = Lines.ledger
            .replacingOccurrences(of: #""text": "Status: now drawing the ledger schema""#, with: #""text": "Status: now drawing the ledger schema, its entries keyed by request and its totals rolled up by the hour""#)

        /// The first board, the Mac app named as long as a session's name runs.
        private static let longName = Lines.watch[0]
            .replacingOccurrences(of: #""name":"The Mac app""#, with: #""name":"Build the Mac app's window, its sidebar on the system's own glass, and its two pages""#)

        /// The first board, Goosemates' ask new on it.
        private static let withNew = Lines.watch[0]
            .replacingOccurrences(of: #""new":[]"#, with: #""new":["ask:sr-gs7kq2:k1"]"#)

        /// The first board with no ask waiting and no window stopped.
        private static let nothingNeedingLee = Lines.watch[0]
            .replacingOccurrences(of: #""is":"ask""#, with: #""is":"yourTurn""#)
            .replacingOccurrences(of: #""is":"permission""#, with: #""is":"yourTurn""#)
            .replacingOccurrences(of: #""needYou":6"#, with: #""needYou":0"#)
            .replacingOccurrences(of: #""state":"needsYou""#, with: #""state":"yourTurn""#)
    }
}
