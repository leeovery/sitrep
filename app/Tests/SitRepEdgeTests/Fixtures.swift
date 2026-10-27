/// A line of `sitrep watch` as cli/output.ts's `watchLine` prints it, cut to its rows: an ask, a permission prompt new
/// on it, a question, an away ask, a turn, and a window working.
let watchLine = watched(new: ["stop:sr-y4d0qj:w1:1792445500000"])

/// The same board with these rows new on it: with none, as a run's first line.
func watched(new: [String]) -> String {
    line(needYou: 4, sessions: 6, new: new, rows: watchRows)
}

private let watchRows = [
    row("ask:sr-7e68fj:k1hs", "ask", session: "sr-7e68fj", lead: "Approve saved plans", second: "Terrace · Plan the tool", since: 1_791_991_983_206),
    row("stop:sr-y4d0qj:w1:1792445500000", "permission", session: "sr-y4d0qj", lead: "Allow Bash:", mono: "gh pr create", second: "Switchboard · Dashboard memory and snags", since: 1_792_445_500_000),
    row("stop:sr-j94s0e:w2:1792445400000", "question", session: "sr-j94s0e", lead: "Which edge should it start on?", more: "+2", second: "Goosemates · Settle the older open questions", since: 1_792_445_400_000),
    row("ask:sr-50f7g8:a2", "ask", away: true, session: "sr-50f7g8", lead: "The bootstrap", second: "Kit · The bootstrap", since: 1_791_900_000_000),
    row("turn:sr-aw3bgs", "yourTurn", session: "sr-aw3bgs", lead: "Build the notch", second: "SitRep · Build the Mac app", since: 1_792_259_685_462),
    row("work:sr-q7njzv", "working", session: "sr-q7njzv", lead: "Editing", mono: "app/Report.php", second: "DocMan · Fix inverted exception reporting", since: 1_792_445_000_000),
]

/// The first line the real `sitrep watch` printed on 20 October 2026, run once over a board seeded in a scratch
/// `XDG_STATE_HOME`: SitRep's ask, which a window holds, and Switchboard's, which none does. Verbatim, but for the
/// line breaks, its rows, grouped by session as version 2 printed them, and its move to version 3 (`Lines`).
let realLine = #"""
    {"v":3,"at":1792453038194,"version":"0.1.0","head":{"needYou":2,"sessions":2},"rows":[{"session":"sr-n0tch1",\#
    "section":"needsYou","isAway":false,"project":"sitrep","name":"Build the Mac app","projectName":"SitRep",\#
    "letters":"SR","lines":[{"key":"ask:sr-n0tch1:k1ap",\#
    "is":"ask","ask":"k1ap","writer":null,"first":{"lead":"Approve the caption","mono":null,"more":null},\#
    "since":1792452732636}],"second":"SitRep · Build the Mac app","since":1792452732636},{"session":"sr-dash02",\#
    "section":"needsYou","isAway":true,"project":"switchboard","name":"Dashboard memory",\#
    "projectName":"Switchboard","letters":"Sw","lines":[{"key":"ask:sr-dash02:k2pc",\#
    "is":"ask","ask":"k2pc","writer":null,"first":{"lead":"Pick the cache size","mono":null,"more":null},\#
    "since":1792451832636}],"second":"No window holds it. Carry it on in Claude.","since":1792451832636}],\#
    "projects":[{"key":"sitrep","name":"SitRep","directory":"/Users/leeovery/Code/sitrep","open":1,"waiting":1,\#
    "parked":0,"updatedAt":1792452732636,"sessions":[{"id":"sr-n0tch1","name":"Build the Mac app",\#
    "summary":"The notch","now":["Building the notch"],"next":null,"isOpen":true,"waiting":1,"parked":0,\#
    "updatedAt":1792452732636,"state":"needsYou","since":1792452732636,\#
    "doing":{"is":"yourTurn","line":{"lead":"Building the notch","mono":null,"more":null},"since":1792452732636},\#
    "asks":[{"id":"k1ap","wants":"yes",\#
    "yes":"Approve","title":"Approve the caption","where":null,"options":[],"needs":null,"ref":null,\#
    "state":"waiting","at":1792452732636}]}]},{"key":"switchboard","name":"Switchboard",\#
    "directory":"/Users/leeovery/Code/switchboard","open":0,"waiting":1,"parked":0,"updatedAt":1792451832636,\#
    "sessions":[{"id":"sr-dash02","name":"Dashboard memory","summary":"Snags","now":["Reading the logs"],\#
    "next":null,"isOpen":false,"waiting":1,"parked":0,"updatedAt":1792451832636,"state":"needsYou",\#
    "since":1792451832636,\#
    "doing":{"is":"away","line":{"lead":"No window holds it. Carry it on in Claude.","mono":null,"more":null},\#
    "since":1792451832636},"asks":[{"id":"k2pc","wants":"yes","yes":"Approve","title":"Pick the cache size",\#
    "where":null,"options":[],"needs":null,"ref":null,"state":"waiting","at":1792451832636}]}]}],\#
    "windows":[{"writer":"b1c2d3e4-0000-4000-8000-0000000000aa","session":"sr-n0tch1","name":"Build the Mac app",\#
    "project":"SitRep","version":null,"needsReload":true,"where":null,"state":null,"attachedAt":1792449432636}],\#
    "new":[],"boards":{}}
    """#

/// One session working, nothing needing Lee.
let allClearLine = line(
    needYou: 0, sessions: 1, new: [],
    rows: [
        row("work:sr-q7njzv", "working", session: "sr-q7njzv", lead: "Running the tests", second: "DocMan · Fix inverted exception reporting", since: 1_792_445_000_000),
    ]
)

func line(needYou: Int, sessions: Int, new: [String], rows: [String]) -> String {
    """
    {"v":3,"at":1792445574706,"version":"0.1.0","head":{"needYou":\(needYou),"sessions":\(sessions)},\
    "rows":[\(rows.joined(separator: ","))],"projects":[],"windows":[],\
    "new":[\(new.map { "\"\($0)\"" }.joined(separator: ","))],"boards":{}}
    """
}

/// A session's row of one line, its key `key`, in the section its kind puts it in; with `newer`, more lines of the
/// same kind after it, by their keys, leads and times, as a session with several asks has.
func row(
    _ key: String, _ kind: String, away: Bool = false, session: String, lead: String, mono: String? = nil,
    more: String? = nil, until: Int? = nil, second: String, since: Int,
    newer: [(key: String, lead: String, since: Int)] = []
) -> String {
    let first = rowLine(key, kind, lead: lead, mono: mono, more: more, until: until, since: since)
    let lines = [first] + newer.map { rowLine($0.key, kind, lead: $0.lead, since: $0.since) }
    let names = names(of: second)

    return """
    {"session":"\(session)","section":"\(section(of: kind))","isAway":\(away),"project":"p",\
    "name":"\(names.session)","projectName":"\(names.project)","letters":"Pr","lines":[\(lines.joined(separator: ","))],"second":"\(second)","since":\(since)}
    """
}

private func rowLine(
    _ key: String, _ kind: String, lead: String, mono: String? = nil, more: String? = nil, until: Int? = nil,
    since: Int
) -> String {
    """
    {"key":"\(key)","is":"\(kind)","ask":null,"writer":null,"first":{"lead":"\(lead)","mono":\(json(mono)),\
    "more":\(json(more)),"until":\(until.map(String.init) ?? "null")},"since":\(since)}
    """
}

/// The project and the session a row's second line names, as core words it: "Terrace · Plan the tool".
func names(of second: String) -> (project: String, session: String) {
    let parts = second.components(separatedBy: " · ")

    return (parts[0], parts.count > 1 ? parts[1] : second)
}

/// The section core puts a row of this kind in.
private func section(of kind: String) -> String {
    switch kind {
    case "ask", "permission", "question": "needsYou"
    case "yourTurn": "yourTurn"
    default: "working"
    }
}

private func json(_ text: String?) -> String {
    text.map { "\"\($0)\"" } ?? "null"
}
