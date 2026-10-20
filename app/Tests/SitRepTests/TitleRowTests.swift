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
}
