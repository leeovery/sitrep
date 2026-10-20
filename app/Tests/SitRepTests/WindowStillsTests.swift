import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// The SitRep window's key states, drawn offscreen over what the real CLI printed, as Paper's drawing has them: the
/// session, a permission prompt, an away session and its finish, a project, and the moments of an answer and of a
/// board changing under Lee. Each draws whole at the window's size. With `SITREP_WINDOW_STILLS` naming a folder, each
/// is kept there as a PNG, to read beside the drawing; nothing opens on the screen.
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
            content: WindowContent(listed: run.listed(at: now), page: run.page(at: now), pick: run.pick, now: now)
                .frame(width: WindowStyle.size.width, height: WindowStyle.size.height)
                .environment(\.isStill, true)
                .environment(\.isHoveredStill, still == .hovered)
        )

        renderer.scale = 2

        let image = try #require(renderer.cgImage)

        #expect(image.width == 2200)
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

        /// The window's run in the state, and the time it is drawn at.
        func run() -> (WindowRun, Date) {
            let now = printed
            let run = Self.opened()

            switch self {
            case .session:
                break
            case .permission:
                Self.pick(.session("sr-dash02"), in: run)
            case .away:
                Self.pick(.session("sr-gs7kq2"), in: run)
            case .finishing:
                Self.pick(.session("sr-gs7kq2"), in: run)
                run.askToFinish("sr-gs7kq2")
            case .project:
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
                [.status(0), .next, .note("sr-macapp:n2"), .parked("p1"), .resolved("k4"), .resolved("k5")].forEach(run.toggle)
            case .longOptions:
                Self.pick(.session("sr-macapp"), in: run, board: Self.withLongOptions)
            }
            return (run, now)
        }

        private static func opened() -> WindowRun {
            let run = WindowRun()

            _ = run.show(heard(Lines.watch[0]), at: printed, reducesMotion: false)
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
