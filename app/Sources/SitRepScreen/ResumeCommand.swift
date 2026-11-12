import SitRepCore

/// The resume command, as Lee sets it in Settings: what a window opened for an away session runs where nothing is left
/// of its last window to attach to, its multiplexer session gone or the window in none. Its placeholders, `{claude}`
/// and `{dir}`, are filled with the facts of that window.
typealias ResumeCommand = TypedCommand<ResumeFact>

/// A fact of an away session's last window: the Claude Code session it ran, which a `/clear` moves on, so the latest
/// conversation; and the folder that Claude ran in.
enum ResumeFact: String, CommandPlaceholder {
    case claude, dir

    static let command = "resume command"

    static func unset(named name: String) -> String {
        "No window holds \(name). To carry it on, set a resume command in Settings."
    }
}

/// Its writer is the Claude Code session it ran; its folder, none from a window on a sitrep from before heartbeats said
/// it, the one fact it may lack.
extension Board.LastWindow: CommandFacts {
    var given: Set<ResumeFact> {
        directory == nil ? [.claude] : [.claude, .dir]
    }

    func none(of _: [ResumeFact], named name: String) -> String {
        "\(name)'s last window did not say which folder it ran in, as a window on an older sitrep does not, so SitRep "
            + "has nothing to put for {dir}."
    }

    func words(_ fact: ResumeFact) -> String {
        switch fact {
        case .claude: "the Claude Code session's id"
        case .dir: "the folder its Claude ran in"
        }
    }

    func values(wanted _: Set<ResumeFact>) -> [ResumeFact: String] {
        var values: [ResumeFact: String] = [.claude: writer]

        values[.dir] = directory
        return values
    }
}
