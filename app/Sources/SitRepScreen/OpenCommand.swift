import SitRepCore

/// The open command, as Lee sets it in Settings: what a window opened for a session no window shows runs, attaching to
/// its multiplexer session. Its placeholders, `{session}`, `{socket}` and `{pane}`, are filled with the facts of where
/// the session's window runs, as its multiplexer gives them.
typealias OpenCommand = TypedCommand<Fact>

extension Fact: CommandPlaceholder {
    static let command = "open command"

    static func unset(named name: String) -> String {
        "No terminal window shows \(name). To open one for it, set an open command in Settings."
    }
}

extension TypedCommand where Placeholder == Fact {
    /// The line to type for a window in the multiplexer, named as the board names its session: its placeholders filled
    /// with the facts the multiplexer gives, asked of it only once the command is known fit to type and to name only
    /// facts it has.
    func line(for where: Board.Window.Where, in multiplexer: any Multiplexer, named name: String) async throws
        -> String
    {
        try await line(from: MultiplexerFacts(where: `where`, multiplexer: multiplexer), named: name)
    }
}

/// The facts a multiplexer gives of a window in it: those of its kind, what can change under the window asked of it.
private struct MultiplexerFacts: CommandFacts {
    let `where`: Board.Window.Where
    let multiplexer: any Multiplexer

    var given: Set<Fact> {
        Set(multiplexer.kind.facts)
    }

    func none(of missing: [Fact], named name: String) -> String {
        let kind = multiplexer.kind.rawValue

        return "\(name) runs in \(kind), which gives no \(braced(missing.map(\.rawValue), "or")). A \(kind) session "
            + "gives \(braced(multiplexer.kind.facts.map(\.rawValue)))."
    }

    func words(_ fact: Fact) -> String {
        fact.words(in: multiplexer.kind)
    }

    func values(wanted: Set<Fact>) async throws -> [Fact: String] {
        try await multiplexer.facts(of: `where`, wanted: wanted)
    }
}
