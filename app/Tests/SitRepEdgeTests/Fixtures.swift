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

/// One session working, nothing needing Lee.
let allClearLine = line(
    needYou: 0, sessions: 1, new: [],
    rows: [
        row("work:sr-q7njzv", "working", session: "sr-q7njzv", lead: "Running the tests", second: "DocMan · Fix inverted exception reporting", since: 1_792_445_000_000),
    ]
)

private func line(needYou: Int, sessions: Int, new: [String], rows: [String]) -> String {
    """
    {"v":1,"at":1792445574706,"version":"0.1.0","head":{"needYou":\(needYou),"sessions":\(sessions)},\
    "rows":[\(rows.joined(separator: ","))],"projects":[],"windows":[],\
    "new":[\(new.map { "\"\($0)\"" }.joined(separator: ","))],"changed":[]}
    """
}

private func row(
    _ key: String, _ kind: String, away: Bool = false, session: String, lead: String, mono: String? = nil,
    more: String? = nil, second: String, since: Int
) -> String {
    """
    {"key":"\(key)","is":"\(kind)","isAway":\(away),"session":"\(session)","project":"p","letters":"Pr",\
    "ask":null,"writer":null,"first":{"lead":"\(lead)","mono":\(json(mono)),"more":\(json(more))},\
    "second":"\(second)","since":\(since)}
    """
}

private func json(_ text: String?) -> String {
    text.map { "\"\($0)\"" } ?? "null"
}
