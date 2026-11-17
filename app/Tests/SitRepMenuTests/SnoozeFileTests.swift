import Foundation
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

/// `snooze.json` (DESIGN, "Storage"): at the top of the board's folder, found as core's `rootOf` finds it; its text the
/// text core's reader is held to, in `tests/choices.ts`; written whole, so a reader never sees half a file.
@Suite(.backstop)
struct SnoozeFileTests {
    /// A folder of the test's own, gone once the test is done with it.
    private final class Folder {
        let url = FileManager.default.temporaryDirectory.appending(path: "sitrep-snooze-\(UUID().uuidString)")

        deinit {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// The settings `tests/choices.ts` gives, every choice set other than its default.
    private static let leesOwn: SnoozeSettings = {
        var settings = SnoozeSettings()

        settings.inAnHour.isOn = false
        settings.laterToday.hours = 1
        settings.tonight.at = TimeOfDay(hour: 20, minute: 30)
        settings.tomorrow.at = TimeOfDay(hour: 7)
        settings.thisWeekend = .init(isOn: true, day: .sunday, at: TimeOfDay(hour: 10))
        settings.nextWeek = .init(isOn: true, day: .friday, at: TimeOfDay(hour: 8, minute: 30))
        return settings
    }()

    /// The file as core's tests read it: the text between the backticks of `APP_FILE` in `tests/choices.ts`.
    private static func coresFixture(sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../../tests/choices.ts")
        let text = try String(contentsOf: file, encoding: .utf8)
        let start = try #require(text.range(of: "export const APP_FILE = `"), sourceLocation: sourceLocation)

        return String(text[start.upperBound...].prefix { $0 != "`" })
    }

    /// The app's file and the mod's reader agree: what the app writes for these settings is, byte for byte, the file
    /// core's tests read as these settings.
    @Test func itsTextIsTheFileCoresReaderIsHeldTo() throws {
        #expect(try String(decoding: SnoozeFile.text(Self.leesOwn), as: UTF8.self) == Self.coresFixture())
    }

    @Test func theSameSettingsAreAlwaysTheSameBytes() throws {
        #expect(try SnoozeFile.text(Self.leesOwn) == SnoozeFile.text(Self.leesOwn))
    }

    /// `$XDG_STATE_HOME/sitrep` where it names a folder from the root, a trailing slash or not; else under `$HOME`, or
    /// the home given where `HOME` names none, as core's `rootOf` has it, a relative or empty one passed over.
    @Test(arguments: [
        (["XDG_STATE_HOME": "/state", "HOME": "/Users/me"], "/state/sitrep/snooze.json"),
        (["XDG_STATE_HOME": "/state/", "HOME": "/Users/me"], "/state/sitrep/snooze.json"),
        (["XDG_STATE_HOME": "state", "HOME": "/Users/me"], "/Users/me/.local/state/sitrep/snooze.json"),
        (["XDG_STATE_HOME": "", "HOME": "/Users/me"], "/Users/me/.local/state/sitrep/snooze.json"),
        (["HOME": "/Users/me"], "/Users/me/.local/state/sitrep/snooze.json"),
        ([:], "/Users/given/.local/state/sitrep/snooze.json"),
    ])
    func itSitsAtTheTopOfTheBoardsFolder(environment: [String: String], path: String) {
        let file = SnoozeFile(environment: environment, home: URL(filePath: "/Users/given"))

        #expect(file.url.standardizedFileURL.path(percentEncoded: false) == path)
    }

    /// Written into a folder not there yet, which it makes, and the file alone left in it.
    @Test func itIsWrittenItsFolderMadeAndNothingLeftBesideIt() throws {
        let folder = Folder()
        let file = SnoozeFile(url: folder.url.appending(path: "state/sitrep/snooze.json"))

        file.write(Self.leesOwn)

        #expect(try Data(contentsOf: file.url) == SnoozeFile.text(Self.leesOwn))
        #expect(try FileManager.default.contentsOfDirectory(atPath: file.url.deletingLastPathComponent().path) == [
            SnoozeFile.name,
        ])
    }

    /// Written whole, beside the file then renamed over it: a reader holding the file open as it is written still
    /// reads the old whole, never the new one half written over it, and the next to open it reads the new whole.
    @Test func itIsWrittenWholeAReaderNeverSeesHalfAFile() throws {
        let folder = Folder()
        let file = SnoozeFile(url: folder.url.appending(path: SnoozeFile.name))

        file.write(SnoozeSettings())

        let reader = try FileHandle(forReadingFrom: file.url)

        defer { try? reader.close() }
        file.write(Self.leesOwn)

        #expect(try reader.readToEnd() == SnoozeFile.text(SnoozeSettings()))
        #expect(try Data(contentsOf: file.url) == SnoozeFile.text(Self.leesOwn))
    }

    /// A write that fails, its folder a file, is logged, and nothing else happens.
    @Test func aWriteThatFailsIsLoggedAndGoesNoFurther() throws {
        let folder = Folder()
        let blocker = folder.url.appending(path: "sitrep")

        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: blocker)
        SnoozeFile(url: blocker.appending(path: SnoozeFile.name)).write(Self.leesOwn)

        #expect(try String(contentsOf: blocker, encoding: .utf8) == "not a folder")
    }

    /// Kept in the app's defaults under "snooze", and read back the same.
    @Test func itIsKeptInTheAppsDefaults() {
        let defaults = MemoryDefaults()

        SavedSettings<SnoozeSettings>(defaults).save(Self.leesOwn)

        #expect(SavedSettings<SnoozeSettings>.key == "snooze")
        #expect(defaults.data(forKey: "snooze") != nil)
        #expect(SavedSettings<SnoozeSettings>(defaults).read() == Self.leesOwn)
    }
}
