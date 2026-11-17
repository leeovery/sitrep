import Foundation
import SitRepPanel
import SitRepTestSupport
import Testing

/// Snooze's choices as Lee sets them (DESIGN, "Lee sets the times"): today's choices by default, This weekend off;
/// kept in the file's shape, and read leniently, as core reads the file, a choice or a field missing or out of range
/// keeping its default.
@Suite(.backstop)
struct SnoozeSettingsTests {
    private static func read(_ json: String) throws -> SnoozeSettings {
        try JSONDecoder().decode(SnoozeSettings.self, from: Data(json.utf8))
    }

    @Test func theDefaultsAreTodaysChoicesThisWeekendOff() {
        let settings = SnoozeSettings()

        #expect(settings.inAnHour.isOn)
        #expect(settings.laterToday == .init(isOn: true, hours: 3))
        #expect(settings.tonight == .init(isOn: true, at: TimeOfDay(hour: 18)))
        #expect(settings.tomorrow == .init(isOn: true, at: TimeOfDay(hour: 9)))
        #expect(settings.thisWeekend == .init(isOn: false, day: .saturday, at: TimeOfDay(hour: 9)))
        #expect(settings.nextWeek == .init(isOn: true, day: .monday, at: TimeOfDay(hour: 9)))
        #expect(SnoozeChoice.allCases.map(settings.isOn) == [true, true, true, true, false, true])
    }

    /// Each choice switches on and off alone, the rest as they were.
    @Test(arguments: SnoozeChoice.allCases)
    func eachChoiceSwitchesAlone(choice: SnoozeChoice) {
        var settings = SnoozeSettings()

        settings.set(choice, on: !settings.isOn(choice))
        #expect(SnoozeChoice.allCases.map(settings.isOn) == SnoozeChoice.allCases.map { each in
            each == choice ? !SnoozeSettings().isOn(each) : SnoozeSettings().isOn(each)
        })
    }

    /// The file's shape, each choice by core's name for it, its version, its switch as `on`, a time as `HH:MM`, a day by
    /// its English name in lower case.
    @Test func itIsKeptInTheFilesShape() throws {
        var settings = SnoozeSettings()

        settings.tonight.at = TimeOfDay(hour: 20, minute: 5)
        settings.nextWeek.day = .friday

        let encoder = JSONEncoder()

        encoder.outputFormatting = .sortedKeys
        #expect(try String(decoding: encoder.encode(settings), as: UTF8.self) == """
        {"hour":{"on":true},"later":{"hours":3,"on":true},"tomorrow":{"at":"09:00","on":true},\
        "tonight":{"at":"20:05","on":true},"v":1,"week":{"at":"09:00","day":"friday","on":true},\
        "weekend":{"at":"09:00","day":"saturday","on":false}}
        """)
    }

    @Test func whatIsKeptReadsBackTheSame() throws {
        var settings = SnoozeSettings()

        settings.inAnHour.isOn = false
        settings.laterToday.hours = 4
        settings.tomorrow.at = TimeOfDay(hour: 7, minute: 45)
        settings.thisWeekend = .init(isOn: true, day: .sunday, at: TimeOfDay(hour: 23, minute: 59))
        settings.nextWeek = .init(isOn: false, day: .sunday, at: TimeOfDay(hour: 0))

        #expect(try JSONDecoder().decode(SnoozeSettings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test(arguments: ["null", "[]", "\"snooze\"", "3", "{}"])
    func anythingButAnObjectOfChoicesIsTheDefaults(json: String) throws {
        #expect(try Self.read(json) == SnoozeSettings())
    }

    /// A choice missing keeps its defaults, and a field missing keeps its own, the rest standing.
    @Test func partlyFilledTheRestTakeTheirDefaults() throws {
        var expected = SnoozeSettings()

        expected.laterToday.hours = 2
        expected.thisWeekend.isOn = true
        expected.nextWeek.isOn = false
        #expect(try Self.read(#"{"v":1,"later":{"hours":2},"weekend":{"on":true},"week":{"on":false}}"#) == expected)
    }

    /// A field out of range keeps its default and the rest of its choice stands: hours past 1 to 4, a time not `HH:MM`
    /// on the 24-hour clock, a day no weekday, This weekend on a weekday, a switch not true or false; a choice that is
    /// no object keeps its defaults.
    @Test func aFieldOutOfRangeKeepsItsDefault() throws {
        let read = try Self.read("""
        {"v":1,"hour":{"on":"yes"},"later":{"on":false,"hours":5},"tonight":{"on":false,"at":"24:00"},
         "tomorrow":"07:00","weekend":{"on":true,"day":"monday","at":"10:60"},"week":{"day":"Friday","at":"08:30"}}
        """)
        var expected = SnoozeSettings()

        expected.laterToday.isOn = false
        expected.tonight.isOn = false
        expected.thisWeekend.isOn = true
        expected.nextWeek.at = TimeOfDay(hour: 8, minute: 30)
        #expect(read == expected)
    }

    /// A time reads only as two digits, a colon and two, within a day, as core's reader takes it.
    @Test(arguments: ["9:00", "09:0", "24:00", "23:60", "+9:00", " 09:00", "09:00:00", "09.00", "٠٩:٠٠", ""])
    func aTimeNotHHMMOnTheTwentyFourHourClockDoesNotRead(text: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeOfDay.self, from: Data("\"\(text)\"".utf8))
        }
    }

    @Test func aTimeReadsAndIsWrittenAsHHMM() throws {
        #expect(try JSONDecoder().decode(TimeOfDay.self, from: Data(#""23:59""#.utf8)) == TimeOfDay(hour: 23, minute: 59))
        #expect(TimeOfDay(hour: 7, minute: 5).text == "07:05")
    }

    /// Monday first, as the week runs for This weekend and Next week; the weekend Saturday and Sunday.
    @Test func theWeekRunsMondayToSunday() {
        #expect(Weekday.allCases.map(\.title) == [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
        ])
        #expect(Weekday.weekend == [.saturday, .sunday])
    }
}
