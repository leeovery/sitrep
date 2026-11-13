import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepScreen
import SwiftUI
import Testing

/// Settings' General: Startup, Terminal and Resume command, as stage 8's rethink regrouped it (13 November 2026), and no
/// longer "Your turn folds after", retired with "N earlier" on 4 November 2026, as the card shows every your-turn row
/// (board J).
@MainActor
struct GeneralPaneTests {
    /// The card's column at the window's least width, and at the drawings' 704.
    nonisolated private static let leastColumn = SettingsWindow.smallest.width - 188 - 40
    nonisolated private static let column: CGFloat = 704

    private static func general(_ defaults: UserDefaults = MemoryDefaults()) async -> Hosted {
        let settings = await Hosted.settings(defaults: defaults)

        return Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))
    }

    /// No pop-up for a fold period: its one pop-up is the terminal, and its one switch Open at login.
    @Test func itsOnlyPopUpIsTheTerminalAndItsOnlySwitchOpenAtLogin() async throws {
        let hosted = await Self.general()

        #expect(hosted.all(NSPopUpButton.self).map(\.itemTitles) == [["Ghostty"]])
        #expect(hosted.all(NSSwitch.self).count == 1)
    }

    /// The terminals SitRep has a driver for, Ghostty alone, chosen by default.
    @Test func theTerminalIsAMenuOfTheTerminalsWithADriverGhosttyChosen() async throws {
        let popUp = try #require(await Self.general().all(NSPopUpButton.self).first)

        #expect(popUp.itemTitles == Driver.all.map(\.name))
        #expect(popUp.titleOfSelectedItem == "Ghostty")
    }

    /// One field, pre-filled with the default so Lee sees it; his own once given, and empty where he cleared it.
    @Test(arguments: [
        (String?.none, OpenSettings.defaultResumeCommand), ("portal open --claude {claude}", "portal open --claude {claude}"),
        ("", ""),
    ])
    func theResumeCommandIsPrefilledWithTheDefaultAndShowsLeesOnceGiven(given: String?, shown: String) async throws {
        let defaults = MemoryDefaults()
        var app = AppSettings()

        app.resumeCommand = given
        SavedSettings(defaults).save(app)

        let fields = await Self.general(defaults).all(NSTextField.self)

        #expect(fields.map(\.stringValue) == [shown])
    }

    /// Restore Default is enabled only while the field differs from the default, a command saved the same as it among
    /// those that do not; it puts the command back to one never given, the default.
    @Test func restoreDefaultHasSomethingToPutBackOnlyWhileTheFieldDiffersFromTheDefault() {
        var app = AppSettings()

        #expect(app.resumesByDefault)
        app.resumeCommand = OpenSettings.defaultResumeCommand
        #expect(app.resumesByDefault)
        for differing in ["", "portal open --claude {claude}", OpenSettings.defaultResumeCommand + " "] {
            app.resumeCommand = differing
            #expect(!app.resumesByDefault, "\(differing.debugDescription)")
        }

        app.restoreResumeCommand()
        #expect(app.resumeCommand == nil)
        #expect(app.openSettings.resumeCommand == OpenSettings.defaultResumeCommand)
    }

    /// Every character as wide as the next, at the label's 13.
    @Test func theCommandIsInTheLabelsSizeInTheMonospacedFace() async throws {
        let font = try #require(await Self.general().all(NSTextField.self).first?.font)
        let width = { (text: String) in (text as NSString).size(withAttributes: [.font: font]).width }

        #expect(font.pointSize == NSFont.systemFontSize)
        #expect(width("iiii") == width("mmmm"))
    }

    /// What Lee types is what is kept, for a shell: macOS's smart quotes, smart dashes, text replacement and spelling
    /// correction are off in the field's editor, and a `--` and a `'` typed, then checked as macOS checks typing, are
    /// saved as typed.
    @Test func theCommandIsKeptExactlyAsTyped() throws {
        let typed = "portal open -s {session} -- 'x' \"y\""
        var saved = ""
        let row = CommandRow(command: Binding(get: { saved }, set: { saved = $0 }))
        let hosted = Hosted(row, size: CGSize(width: Self.column, height: SettingsStyle.oneLineRow))
        let field = try #require(hosted.all(NSTextField.self).first)

        #expect(field.window?.makeFirstResponder(field) == true)

        let editor = try #require(field.currentEditor() as? NSTextView)

        #expect(!editor.isAutomaticQuoteSubstitutionEnabled)
        #expect(!editor.isAutomaticDashSubstitutionEnabled)
        #expect(!editor.isAutomaticTextReplacementEnabled)
        #expect(!editor.isAutomaticSpellingCorrectionEnabled)

        editor.insertText(typed, replacementRange: NSRange(location: NSNotFound, length: 0))
        editor.checkTextInDocument(nil)
        #expect(saved == typed)
    }

    /// The row, holding the command given, in a column of the width given: its height, its field, the field's first
    /// baseline from the row's top, and the row drawn.
    private static func row(_ command: String = "", column: CGFloat) throws
        -> (height: CGFloat, field: CGRect, baseline: CGFloat, drawn: Drawn)
    {
        let row = CommandRow(command: .constant(command)).background(.black)
        let hosted = Hosted(row, size: CGSize(width: column, height: SettingsStyle.oneLineRow))
        let field = try #require(hosted.all(NSTextField.self).first)
        let frame = hosted.frame(of: field)
        let height = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: column, height: 400)).height

        return (height, frame, frame.minY + field.firstBaselineOffsetFromTop, try Drawn(hosted.hosting))
    }

    /// The field takes its width where the column has room, the window's least width among them now its label is
    /// Command, and gives way before the label does where it has not, so the label keeps its one line, and the row its
    /// height.
    @Test func theFieldGivesWayBeforeTheLabelAndTheRowKeepsItsHeight() throws {
        let narrow = CommandRow.fieldWidth

        for column in [Self.column, Self.leastColumn] {
            let row = try Self.row(column: column)

            #expect(row.height == SettingsStyle.oneLineRow)
            #expect(row.field.width == CommandRow.fieldWidth)
            #expect(abs(row.field.maxX - (column - SettingsStyle.inset)) < 0.5)
        }

        let squeezed = try Self.row(column: narrow)

        #expect(squeezed.height == SettingsStyle.oneLineRow)
        #expect(squeezed.field.width < CommandRow.fieldWidth)
        #expect(abs(squeezed.field.maxX - (narrow - SettingsStyle.inset)) < 0.5)
    }

    /// The label and the command stand on one line of text: the foot of the label's O, which hangs below no line, on
    /// the field's first baseline, within a point.
    @Test(arguments: [column, leastColumn])
    func theLabelAndTheCommandStandOnOneLineOfText(column: CGFloat) throws {
        let row = try Self.row(column: column)
        let label = try #require(row.drawn.litRows(in: CGRect(x: SettingsStyle.inset, y: 0, width: 8, height: row.height)))

        #expect(abs(label.upperBound - row.baseline) <= 1, "\(label) \(row.baseline)")
    }
}
