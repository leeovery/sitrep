import SitRepCore

/// The resume command, as Lee sets it in Settings: what a window opened for a session no terminal on this Mac shows
/// runs, held or away. Its placeholders, `{claude}`, `{dir}` and `{tty}`, are filled with the facts of the window the
/// click carries the session on from.
typealias ResumeCommand = TypedCommand<ResumeFact>

/// A fact of the window a click carries a session on from: the Claude Code session it ran, which a `/clear` moves on,
/// so the latest conversation; the folder that Claude ran in; and the terminal device that Claude still runs on.
enum ResumeFact: String, CommandPlaceholder {
    case claude, dir, tty

    static let command = "resume command"

    static let scripted = "~/bin/resume {claude} {dir}"

    static func unset(named name: String) -> String {
        "The resume command in Settings is empty. To carry \(name) on, set one, or restore the default."
    }
}

extension TypedCommand where Placeholder == ResumeFact {
    /// Whether it is the default, told by its text, so one saved the same as it is the default.
    var isDefault: Bool {
        text == OpenSettings.defaultResumeCommand
    }
}

/// What fills the resume command for a session: its window's writer and folder, the folder none from a window on a
/// sitrep from before heartbeats said it, the one fact it may lack; and the device its Claude still runs on, none
/// unless SitRep sees that Claude there, which is filled as empty. Its window is a live one where a window holds it,
/// else the last it was in, as a refusal names it.
struct ResumeFacts: CommandFacts {
    let window: Board.LastWindow
    let tty: String?
    var isHeld = false

    var given: Set<ResumeFact> {
        window.directory == nil ? [.claude, .tty] : [.claude, .dir, .tty]
    }

    func none(of _: [ResumeFact], named name: String) -> String {
        let window = isHeld ? "window" : "last window"

        return "\(name)'s \(window) did not say which folder it ran in, as a window on an older sitrep does not, so "
            + "SitRep has nothing to put for {dir}."
    }

    func words(_ fact: ResumeFact) -> String {
        switch fact {
        case .claude: "the Claude Code session's id"
        case .dir: "the folder its Claude ran in"
        case .tty: "the terminal its Claude runs on"
        }
    }

    func values(wanted _: Set<ResumeFact>) -> [ResumeFact: String] {
        var values: [ResumeFact: String] = [.claude: window.writer, .tty: tty ?? ""]

        values[.dir] = window.directory
        return values
    }
}
