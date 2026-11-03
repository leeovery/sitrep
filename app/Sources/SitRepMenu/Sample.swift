/// The words SitRep shows where it makes up what a place will hold: Settings' notification, the welcome's terminal, the
/// answer given in it, and its stage's board. Each is a placeholder saying what the place will show, never a real
/// project's or session's name (Lee, 2 November 2026); kept here alone, so none drifts back to one.
public enum Sample {
    /// A row's working line: its word, then what, in code type.
    public struct Working: Equatable, Sendable {
        public let title: String
        public let code: String
    }

    /// An ask: a notification's title, a terminal's line and an ask's own words.
    public static let ask = "The ask, in Claude's words"
    /// A session's project, by name.
    public static let project = "Project"
    /// What a notification says under its title, and a row under its own.
    public static let place = "Project · Session"
    /// A terminal's title.
    public static let terminal = "project · claude"
    /// The ask as Claude Code's window shows it.
    public static let terminalAsk = "● \(ask)"
    /// The tool the ask went through under it: the plugin's own, never a project's.
    public static let terminalTool = "⎿ sitrep · ask"
    /// Lee's answer, as the session's window shows it once he has given it there.
    public static let answer = "One choice"
    public static let terminalAnswer = "› \(answer)"

    /// The rows of a board, by the kind of row each is: Needs you's, two working, and Your turn's.
    public static let needsYou = "An ask that needs you"
    public static let running = Working(title: "Running ", code: "the tests")
    public static let writing = Working(title: "Writing ", code: "DESIGN.md")
    public static let yourTurn = "Your turn to review"
}
