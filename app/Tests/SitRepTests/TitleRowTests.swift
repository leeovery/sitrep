import AppKit
@testable import SitRep
import SwiftUI
import Testing

/// A session's name and its jump, laid out by measured width: side by side while the name wraps to no more lines
/// beside the jump than across the whole width, else the jump under it.
@MainActor
struct TitleRowTests {
    private static let title = "Build the Mac app"
    private static let button = CGSize(width: 120, height: 26)

    private static func words(_ title: String) -> some View {
        Text(title).font(WindowStyle.ui(28, .bold))
    }

    private static func height(of view: some View, in width: CGFloat) -> CGFloat {
        NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }

    private static func row(_ title: String, jumps: Bool = true, in width: CGFloat) -> CGFloat {
        height(of: TitleRow {
            words(title)
            if jumps {
                Color.clear.frame(width: button.width, height: button.height)
            }
        }, in: width)
    }

    /// The name on one line, its width.
    private static var line: CGSize {
        NSHostingController(rootView: words(title)).sizeThatFits(in: CGSize(width: 10_000, height: 10_000))
    }

    @Test func withRoomTheJumpSitsBesideTheNameOnItsFirstLine() {
        #expect(Self.row(Self.title, in: 1000) == Self.line.height)
    }

    @Test func aNameThatFitsOnlyAcrossTheWholeWidthPutsTheJumpUnderIt() {
        let width = Self.line.width + Self.button.width / 2

        #expect(Self.row(Self.title, in: width) == Self.line.height + 10 + Self.button.height)
    }

    @Test func aNameThatWrapsNoFurtherBesideTheJumpKeepsItBeside() {
        let long = Array(repeating: Self.title, count: 4).joined(separator: " ")
        let width = Self.line.width * 3
        let across = Self.height(of: Self.words(long), in: width)

        #expect(across > Self.line.height)
        #expect(Self.row(long, in: width) == across)
    }

    @Test func aNameAloneTakesTheWholeWidth() {
        #expect(Self.row(Self.title, jumps: false, in: Self.line.width + 1) == Self.line.height)
    }

    @Test func proposedAnInfiniteWidthTheJumpSitsBesideTheNameOnOneLine() {
        #expect(Self.row(Self.title, in: .infinity) == Self.line.height)
        #expect(TitleRow.finite(.infinity) == nil)
        #expect(TitleRow.finite(320) == 320)
    }
}

/// `TitleRow`'s places at each width it can be proposed, over a stand-in name 300 points on one line and 40 a line
/// tall, wrapping in whole lines, and a jump 120 by 26.
struct TitleRowFramesTests {
    private static let row = TitleRow()
    private static let button = CGSize(width: 120, height: 26)

    private static func name(_ width: CGFloat?) -> CGSize {
        guard let width, width < 300 else {
            return CGSize(width: 300, height: 40)
        }
        return CGSize(width: width, height: 40 * (300 / max(width, 1)).rounded(.up))
    }

    private static func frames(_ width: CGFloat?, button: CGSize = button) -> [CGRect] {
        row.frames(width, button: button, title: name)
    }

    @Test func withNoWidthItsIdealIsSideBySideTheNameOnOneLine() {
        let frames = Self.frames(nil)

        #expect(frames[0] == CGRect(x: 0, y: 0, width: 300, height: 40))
        #expect(frames[1] == CGRect(x: 300 + 16, y: 7, width: 120, height: 26))
    }

    @Test func besideTheJumpTrailsAtTheWidthsRightEdge() {
        let frames = Self.frames(800)

        #expect(frames[1].minX == CGFloat(800 - 120))
        #expect(frames[1].maxX == 800)
    }

    @Test func inAWidthTooNarrowForTheJumpItGoesUnderTheNameAtTheLeadingEdge() {
        for width in [0, 100, 120 + 15] as [CGFloat] {
            let frames = Self.frames(width)

            #expect(frames[1].minX == 0)
            #expect(frames[1].minY == frames[0].maxY + 10)
        }
    }

    @Test func aJumpTallerThanTheNamesLineLowersTheNameAndStaysInTheHeight() {
        let frames = Self.frames(800, button: CGSize(width: 120, height: 60))

        #expect(frames[1].minY == 0)
        #expect(frames[0].minY == 10)
        #expect(frames.map(\.maxY).max() == 60)
    }
}
