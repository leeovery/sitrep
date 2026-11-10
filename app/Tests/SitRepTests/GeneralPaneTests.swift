import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepScreen
import SwiftUI
import Testing

/// Settings' General: Startup, Ghostty and New windows, and no longer "Your turn folds after", retired with "N earlier"
/// on 4 November 2026, as the card shows every your-turn row (board J).
@MainActor
struct GeneralPaneTests {
    @Test func itOffersNoFoldPeriod() async throws {
        let settings = await Hosted.settings(defaults: MemoryDefaults())
        let hosted = Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))

        #expect(hosted.all(NSPopUpButton.self).isEmpty)
        #expect(hosted.all(NSSwitch.self).count == 1)
    }

    /// New windows: zmx's command over tmux's, SitRep's own greyed in each while Lee has given none.
    @Test func newWindowsHoldsZmxsCommandThenTmuxsEachShowingSitRepsOwnUntilOneIsGiven() async throws {
        let settings = await Hosted.settings(defaults: MemoryDefaults())
        let hosted = Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))
        let fields = hosted.all(NSTextField.self)

        #expect(fields.map(\.placeholderString) == ["zmx attach {session}", "tmux -S {socket} attach -t {pane}"])
        #expect(fields.map(\.stringValue) == ["", ""])
    }

    @Test func eachFieldShowsTheCommandLeeGave() async throws {
        let defaults = MemoryDefaults()
        var app = AppSettings()

        app.zmxAttach = "portal open -s {session}"
        SavedSettings(defaults).save(app)

        let settings = await Hosted.settings(defaults: defaults)
        let hosted = Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))

        #expect(hosted.all(NSTextField.self).map(\.stringValue) == ["portal open -s {session}", ""])
    }

    /// A row as the card holds it, its command given, laid out in a column of the width given.
    private static func row(_ kind: MultiplexerKind, _ command: String = "", column: CGFloat)
        -> (height: CGFloat, field: CGRect)
    {
        let row = AttachRow(kind: kind, command: .constant(command))
        let hosted = Hosted(row.fixedSize(horizontal: false, vertical: true), size: CGSize(width: column, height: 400))
        let field = hosted.all(NSTextField.self).first.map(hosted.frame(of:)) ?? .zero
        let height = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: column, height: 400)).height

        return (height, field)
    }

    /// The field takes its 300 where the column has room, and gives way before the row's words do, so each row keeps
    /// its line, and its 52, at the window's least width, 476.
    @Test(arguments: [MultiplexerKind.zmx, .tmux])
    func theFieldGivesWayBeforeTheWordsSoTheRowKeepsItsHeightAtTheLeastWidth(kind: MultiplexerKind) {
        let wide = Self.row(kind, column: 704)
        let narrowest = Self.row(kind, column: Self.leastColumn)

        #expect(wide.height == SettingsStyle.twoLineRow)
        #expect(wide.field.width == AttachRow.fieldWidth)
        #expect(narrowest.height == SettingsStyle.twoLineRow)
        #expect(narrowest.field.width < AttachRow.fieldWidth)
        #expect(narrowest.field.width >= AttachRow.leastFieldWidth)
    }

    /// zmx's words are the shorter, yet its field stands where tmux's does, so the two line up at every width.
    @Test(arguments: [704, leastColumn])
    func theFieldsLineUp(column: CGFloat) {
        let zmx = Self.row(.zmx, column: column).field
        let tmux = Self.row(.tmux, column: column).field

        #expect(zmx.minX == tmux.minX)
        #expect(zmx.width == tmux.width)
    }

    /// The card's column at the window's least width.
    nonisolated private static let leastColumn = SettingsWindow.smallest.width - 188 - 40

    /// What is wrong with a command shows under its field as Lee types it, growing the row; nothing for one fit to
    /// type.
    @Test(arguments: ["zmx attach {pane}", #"zmx attach "{session}""#])
    func aCommandSitRepCannotTypeIsWarnedOfUnderItsField(command: String) {
        #expect(Self.row(.zmx, command, column: 704).height > SettingsStyle.twoLineRow)
        #expect(Self.row(.zmx, "portal open -s {session}", column: 704).height == SettingsStyle.twoLineRow)
    }
}
