import Foundation

/// Each of Snooze's choices as Lee set it in Settings' Snooze pane: whether it is offered, and when it wakes (DESIGN,
/// "Lee sets the times"). Kept in the app's defaults, and written to `snooze.json` for the pane in Claude Code in the
/// same shape, which core's `snoozeSettingsOf` reads. Read leniently, as core reads the file: a choice, or a field of
/// one, missing or out of range keeps its default, and anything but an object reads as the defaults.
public struct SnoozeSettings: Codable, Equatable, Sendable {
    /// The file's format, which core's reader takes up to.
    public static let version = 1

    public var inAnHour = Switched(isOn: true)
    public var laterToday = HoursOn(isOn: true, hours: 3)
    public var tonight = AtTime(isOn: true, at: TimeOfDay(hour: 18))
    public var tomorrow = AtTime(isOn: true, at: TimeOfDay(hour: 9))
    public var thisWeekend = OnDay(isOn: false, day: .saturday, at: TimeOfDay(hour: 9))
    public var nextWeek = OnDay(isOn: true, day: .monday, at: TimeOfDay(hour: 9))

    public init() {}

    /// In an hour: on or off alone, its hour being real time.
    public struct Switched: Equatable, Sendable {
        public var isOn: Bool

        public init(isOn: Bool) {
            self.isOn = isOn
        }
    }

    /// Later today: so many hours on, of `HoursOn.choices`.
    public struct HoursOn: Equatable, Sendable {
        public var isOn: Bool
        public var hours: Int

        /// The hours on Lee can choose.
        public static let choices = [1, 2, 3, 4]

        public init(isOn: Bool, hours: Int) {
            self.isOn = isOn
            self.hours = hours
        }
    }

    /// Tonight and Tomorrow: a time of day.
    public struct AtTime: Equatable, Sendable {
        public var isOn: Bool
        public var at: TimeOfDay

        public init(isOn: Bool, at: TimeOfDay) {
            self.isOn = isOn
            self.at = at
        }
    }

    /// This weekend and Next week: a day of the week, and a time on it.
    public struct OnDay: Equatable, Sendable {
        public var isOn: Bool
        public var day: Weekday
        public var at: TimeOfDay

        public init(isOn: Bool, day: Weekday, at: TimeOfDay) {
            self.isOn = isOn
            self.day = day
            self.at = at
        }
    }

    /// Whether a choice is offered as Lee set it.
    public func isOn(_ choice: SnoozeChoice) -> Bool {
        switch choice {
        case .inAnHour: inAnHour.isOn
        case .laterToday: laterToday.isOn
        case .tonight: tonight.isOn
        case .tomorrow: tomorrow.isOn
        case .thisWeekend: thisWeekend.isOn
        case .nextWeek: nextWeek.isOn
        }
    }

    /// A choice switched on or off.
    public mutating func set(_ choice: SnoozeChoice, on isOn: Bool) {
        switch choice {
        case .inAnHour: inAnHour.isOn = isOn
        case .laterToday: laterToday.isOn = isOn
        case .tonight: tonight.isOn = isOn
        case .tomorrow: tomorrow.isOn = isOn
        case .thisWeekend: thisWeekend.isOn = isOn
        case .nextWeek: nextWeek.isOn = isOn
        }
    }

    private enum Keys: String, CodingKey {
        case v, hour, later, tonight, tomorrow, weekend, week
    }

    private enum ChoiceKeys: String, CodingKey {
        case on, hours, at, day
    }

    public init(from decoder: any Decoder) {
        let defaults = SnoozeSettings()
        guard let file = try? decoder.container(keyedBy: Keys.self) else {
            self = defaults
            return
        }

        let choice = { (key: Keys) in try? file.nestedContainer(keyedBy: ChoiceKeys.self, forKey: key) }
        let isOn = { (key: Keys, fallback: Bool) in choice(key)?.value(.on, or: fallback) ?? fallback }
        let at = { (key: Keys, fallback: TimeOfDay) in choice(key)?.value(.at, or: fallback) ?? fallback }
        let day = { (key: Keys, among: [Weekday], fallback: Weekday) in
            let day = choice(key)?.value(.day, or: fallback) ?? fallback

            return among.contains(day) ? day : fallback
        }
        let hours = choice(.later)?.value(.hours, or: defaults.laterToday.hours) ?? defaults.laterToday.hours

        inAnHour = Switched(isOn: isOn(.hour, defaults.inAnHour.isOn))
        laterToday = HoursOn(
            isOn: isOn(.later, defaults.laterToday.isOn),
            hours: HoursOn.choices.contains(hours) ? hours : defaults.laterToday.hours
        )
        tonight = AtTime(isOn: isOn(.tonight, defaults.tonight.isOn), at: at(.tonight, defaults.tonight.at))
        tomorrow = AtTime(isOn: isOn(.tomorrow, defaults.tomorrow.isOn), at: at(.tomorrow, defaults.tomorrow.at))
        thisWeekend = OnDay(
            isOn: isOn(.weekend, defaults.thisWeekend.isOn),
            day: day(.weekend, Weekday.weekend, defaults.thisWeekend.day),
            at: at(.weekend, defaults.thisWeekend.at)
        )
        nextWeek = OnDay(
            isOn: isOn(.week, defaults.nextWeek.isOn), day: day(.week, Weekday.allCases, defaults.nextWeek.day),
            at: at(.week, defaults.nextWeek.at)
        )
    }

    /// The file's shape, each choice by core's name for it: `{"v":1,"hour":{"on":true},"later":{"on":true,"hours":3},
    /// "tonight":{"on":true,"at":"18:00"},…,"week":{"on":true,"day":"monday","at":"09:00"}}`.
    public func encode(to encoder: any Encoder) throws {
        var file = encoder.container(keyedBy: Keys.self)
        let choice = { (key: Keys) in file.nestedContainer(keyedBy: ChoiceKeys.self, forKey: key) }

        try file.encode(Self.version, forKey: .v)

        var hour = choice(.hour)
        try hour.encode(inAnHour.isOn, forKey: .on)

        var later = choice(.later)
        try later.encode(laterToday.isOn, forKey: .on)
        try later.encode(laterToday.hours, forKey: .hours)

        for (key, timed) in [(Keys.tonight, tonight), (.tomorrow, tomorrow)] {
            var each = choice(key)
            try each.encode(timed.isOn, forKey: .on)
            try each.encode(timed.at, forKey: .at)
        }
        for (key, dated) in [(Keys.weekend, thisWeekend), (.week, nextWeek)] {
            var each = choice(key)
            try each.encode(dated.isOn, forKey: .on)
            try each.encode(dated.day, forKey: .day)
            try each.encode(dated.at, forKey: .at)
        }
    }
}

/// A local time of day, on the 24-hour clock, as a setting holds it: `HH:MM` in JSON, as core's reader takes it, and
/// anything else unreadable.
public struct TimeOfDay: Codable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int

    /// Clamped to a day's hours and an hour's minutes.
    public init(hour: Int, minute: Int = 0) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// `09:00`.
    public var text: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public init(from decoder: any Decoder) throws {
        let parts = try decoder.singleValueContainer().decode(String.self).split(
            separator: ":", omittingEmptySubsequences: false
        )
        let isTwoDigits = { (part: Substring) in part.count == 2 && part.allSatisfy { ("0" ... "9").contains($0) } }

        guard parts.count == 2, parts.allSatisfy(isTwoDigits), let hour = Int(parts[0]), let minute = Int(parts[1]),
              hour < 24, minute < 60
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not HH:MM"))
        }

        self.init(hour: hour, minute: minute)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// A day of the week a setting names, in the week's order, Monday first, as This weekend and Next week count it.
public enum Weekday: String, Codable, CaseIterable, Sendable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    /// The days This weekend wakes on.
    public static let weekend: [Weekday] = [.saturday, .sunday]

    /// Its name, as Settings shows it.
    public var title: String {
        rawValue.capitalized
    }

    /// Its place in the week, Monday 0 to Sunday 6.
    var place: Int {
        Self.allCases.firstIndex(of: self)!
    }

    /// The place in the week of a weekday as a Gregorian calendar numbers it, Sunday 1.
    static func place(ofCalendarWeekday weekday: Int) -> Int {
        (weekday + 5) % 7
    }
}
