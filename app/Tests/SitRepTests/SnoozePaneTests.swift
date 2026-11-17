import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// Settings' Snooze pane (DESIGN, "Settings"): one card of Snooze's six choices in their order, each with what Lee sets
/// of its time and its switch, the controls greyed while it is off, every change saved as it is made; hosted offscreen
/// in a window never shown, and drawn.
@MainActor
@Suite(.backstop)
struct SnoozePaneTests {
    /// The pane's column at the drawings' 704, and at the window's least width.
    nonisolated private static let column: CGFloat = 704
    nonisolated private static let leastColumn = SettingsWindow.smallest.width - 188 - 40

    /// The pane over Settings kept in `defaults`, its column `column` wide, and Settings.
    private static func pane(
        _ defaults: UserDefaults = MemoryDefaults(), column: CGFloat = column
    ) async -> (Hosted, SettingsModel) {
        let settings = await Hosted.settings(defaults: defaults)

        return (Hosted(Hosted.content(.snooze, settings), size: CGSize(width: column + 40, height: 620)), settings)
    }

    /// Its switches, top to bottom: one a row, in Snooze's order.
    private static func switches(_ hosted: Hosted) -> [NSSwitch] {
        hosted.all(NSSwitch.self)
    }

    private static func popUp(
        _ hosted: Hosted, _ label: String, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> NSPopUpButton {
        try #require(
            hosted.all(NSPopUpButton.self).first { $0.accessibilityLabel() == label }, sourceLocation: sourceLocation
        )
    }

    private static func timeField(
        _ hosted: Hosted, _ choice: SnoozeChoice, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> NSDatePicker {
        try #require(
            hosted.all(NSDatePicker.self).first { $0.accessibilityLabel() == "\(choice.title)'s time" },
            sourceLocation: sourceLocation
        )
    }

    /// Flipped as Lee clicks it.
    private static func flip(_ control: NSSwitch, _ hosted: Hosted) {
        control.state = control.state == .on ? .off : .on
        _ = control.sendAction(control.action, to: control.target)
        hosted.hosting.layoutSubtreeIfNeeded()
    }

    private static func choose(_ title: String, in button: NSPopUpButton) {
        button.selectItem(withTitle: title)
        _ = button.sendAction(button.action, to: button.target)
    }

    @Test func itIsInTheSidebarAfterNotificationsWithTheMoonsSymbol() {
        #expect(SettingsPane.allCases.firstIndex(of: .snooze) == SettingsPane.allCases.firstIndex(of: .notifications)! + 1)
        #expect(NSImage(systemSymbolName: SettingsPane.snooze.symbol, accessibilityDescription: nil) != nil)
    }

    /// By default: a switch a row, every one on but This weekend's; Later today 3 hours; Tonight 18:00, Tomorrow 09:00,
    /// This weekend Saturday 09:00, Next week Monday 09:00.
    @Test func itShowsTodaysChoicesByDefault() async throws {
        let (hosted, _) = await Self.pane()

        #expect(Self.switches(hosted).map(\.state) == [.on, .on, .on, .on, .off, .on])
        #expect(Self.switches(hosted).map(\.controlSize) == Array(repeating: .mini, count: 6))

        let hours = try Self.popUp(hosted, "Later today's hours")
        let weekend = try Self.popUp(hosted, "This weekend's day")
        let week = try Self.popUp(hosted, "Next week's day")

        #expect(hours.itemTitles == ["1 hour", "2 hours", "3 hours", "4 hours"])
        #expect(hours.titleOfSelectedItem == "3 hours")
        #expect(weekend.itemTitles == ["Saturday", "Sunday"])
        #expect(weekend.titleOfSelectedItem == "Saturday")
        #expect(week.itemTitles == ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        #expect(week.titleOfSelectedItem == "Monday")

        let times = try [SnoozeChoice.tonight, .tomorrow, .thisWeekend, .nextWeek].map {
            try TimeField.time(of: Self.timeField(hosted, $0).dateValue)
        }

        #expect(times == [TimeOfDay(hour: 18), TimeOfDay(hour: 9), TimeOfDay(hour: 9), TimeOfDay(hour: 9)])
    }

    /// The time field with its stepper, its hour and minute alone, as System Settings sets a schedule.
    @Test func aTimeIsTheSystemsTimeFieldWithItsStepper() async throws {
        let (hosted, _) = await Self.pane()
        let pickers = hosted.all(NSDatePicker.self)

        #expect(pickers.count == 4)
        expectEvery(pickers) { $0.datePickerStyle == .textFieldAndStepper && $0.datePickerElements == .hourMinute }
    }

    /// While a choice is off its controls grey, and come back as it is switched on: This weekend's by default.
    @Test func aChoicesControlsGreyWhileItIsOff() async throws {
        let (hosted, settings) = await Self.pane()
        let weekend = { (hosted: Hosted) in
            try [Self.popUp(hosted, "This weekend's day").isEnabled, Self.timeField(hosted, .thisWeekend).isEnabled]
        }

        #expect(try weekend(hosted) == [false, false])
        #expect(try Self.popUp(hosted, "Next week's day").isEnabled)
        #expect(try Self.timeField(hosted, .tonight).isEnabled)

        Self.flip(Self.switches(hosted)[4], hosted)
        #expect(settings.preferences.snooze.thisWeekend.isOn)
        #expect(try weekend(hosted) == [true, true])

        Self.flip(Self.switches(hosted)[2], hosted)
        #expect(!settings.preferences.snooze.tonight.isOn)
        #expect(try !Self.timeField(hosted, .tonight).isEnabled)
    }

    /// Each switch is its own choice's, in Snooze's order, saved as it flips.
    @Test func eachSwitchIsItsChoicesSavedAsItFlips() async throws {
        let defaults = MemoryDefaults()
        let (hosted, _) = await Self.pane(defaults)

        for (place, choice) in SnoozeChoice.allCases.enumerated() {
            let was = SavedSettings<SnoozeSettings>(defaults).read().isOn(choice)

            Self.flip(Self.switches(hosted)[place], hosted)
            #expect(SavedSettings<SnoozeSettings>(defaults).read().isOn(choice) == !was, "\(choice)")
        }
    }

    /// A pop-up's choice or a time set is saved at once, and what the pane shows.
    @Test func whatLeeSetsIsSavedAtOnce() async throws {
        let defaults = MemoryDefaults()
        let (hosted, settings) = await Self.pane(defaults)
        let tonight = try Self.timeField(hosted, .tonight)

        Self.choose("1 hour", in: try Self.popUp(hosted, "Later today's hours"))
        Self.choose("Friday", in: try Self.popUp(hosted, "Next week's day"))
        tonight.dateValue = TimeField.date(of: TimeOfDay(hour: 20, minute: 30))
        _ = tonight.sendAction(tonight.action, to: tonight.target)
        hosted.hosting.layoutSubtreeIfNeeded()

        let saved = SavedSettings<SnoozeSettings>(defaults).read()

        #expect(saved.laterToday.hours == 1)
        #expect(saved.nextWeek.day == .friday)
        #expect(saved.tonight.at == TimeOfDay(hour: 20, minute: 30))
        #expect(settings.preferences.snooze == saved)
        #expect(try Self.popUp(hosted, "Next week's day").titleOfSelectedItem == "Friday")
    }

    /// A time set where the clocks change on the Mac is the same time of day: the field holds it in UTC.
    @Test(arguments: [TimeOfDay(hour: 0), TimeOfDay(hour: 1, minute: 30), TimeOfDay(hour: 23, minute: 59)])
    func aTimeOnTheFieldIsTheTimeOfDayItShows(time: TimeOfDay) {
        #expect(TimeField.time(of: TimeField.date(of: time)) == time)
    }

    /// Under its header, one card of six rows, each with a line under its name, so each 52 tall where its line fits,
    /// split by hairlines; then the caption. At the drawings' width each switch stands 10 in from the card's right,
    /// a row's other controls 8 before it, each to its left.
    @Test func itsRowsStandAsTheFormsDo() async throws {
        let (hosted, _) = await Self.pane()
        let drawn = try Drawn(hosted.hosting)
        let switches = Self.switches(hosted).map(hosted.frame(of:))
        let card = try #require(drawn.litSpans(atX: 20 + 232).first { $0.upperBound - $0.lowerBound > 100 })
        let right = 20 + Self.column - SettingsStyle.inset

        #expect(abs((card.upperBound - card.lowerBound) - (6 * SettingsStyle.twoLineRow + 5 * 0.5)) < 1)
        for frame in switches {
            #expect(abs(frame.maxX - right) < 1 / hosted.scale)
            #expect(frame.size == CGSize(width: 36, height: 16))
        }

        let tonight = try Self.laidOut(Self.timeField(hosted, .tonight), in: hosted)
        let week = try Self.laidOut(Self.popUp(hosted, "Next week's day"), in: hosted)
        let weekTime = try Self.laidOut(Self.timeField(hosted, .nextWeek), in: hosted)

        #expect(abs(switches[2].minX - 8 - tonight.maxX) < 1)
        #expect(abs(switches[5].minX - 8 - weekTime.maxX) < 1)
        #expect(abs(weekTime.minX - 8 - week.maxX) < 1)
    }

    /// A control as it is laid out: its alignment rect, which leaves out the room a time field keeps beside its stepper.
    private static func laidOut(_ control: NSView, in hosted: Hosted) -> CGRect {
        let frame = hosted.frame(of: control), insets = control.alignmentRectInsets

        return CGRect(
            x: frame.minX + insets.left, y: frame.minY + insets.top, width: frame.width - insets.left - insets.right,
            height: frame.height - insets.top - insets.bottom
        )
    }

    /// A time field takes more than AppKit gives it, so its last digit clears its edge.
    @Test func aTimeFieldHasRoomPastItsDigits() async throws {
        let (hosted, _) = await Self.pane()
        let field = try Self.timeField(hosted, .tonight)

        #expect(abs(Self.laidOut(field, in: hosted).width - (field.intrinsicContentSize.width + TimeField.room)) < 0.5)
    }

    /// At the window's least width every control keeps its own width, the switches still 10 in from the card's right,
    /// a row's words wrapping before its controls give way.
    @Test func atTheLeastWidthEveryControlKeepsItsWidth() async throws {
        let (wide, _) = await Self.pane()
        let (narrow, _) = await Self.pane(column: Self.leastColumn)
        let widths = { (hosted: Hosted) in
            hosted.all(NSPopUpButton.self).map { hosted.frame(of: $0).width }
                + hosted.all(NSDatePicker.self).map { hosted.frame(of: $0).width }
        }

        #expect(widths(narrow) == widths(wide))
        for frame in Self.switches(narrow).map(narrow.frame(of:)) {
            #expect(abs(frame.maxX - (20 + Self.leastColumn - SettingsStyle.inset)) < 1 / narrow.scale)
        }
    }
}
