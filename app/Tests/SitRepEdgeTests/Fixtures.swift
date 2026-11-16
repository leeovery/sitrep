import SitRepTestSupport

/// A line of `sitrep watch`, cut to its rows: an ask, a permission prompt new on it, a question, an away ask, a turn,
/// and a window working.
let watchLine = watched(new: ["stop:sr-y4d0qj:w1:1792445500000"])

/// The same board with these rows new on it: with none, as a run's first line.
func watched(new: [String]) -> String {
    WatchLine(rows: watchRows, new: new).text
}

/// Each lettered `Pr`, as no project is, so the letters a surface shows are seen to be the line's own.
private let watchRows = [
    WatchLine.Row(
        session: "sr-7e68fj", name: "Plan the tool", projectName: "Terrace",
        lines: [.init("ask:sr-7e68fj:k1hs", .ask, first: "Approve saved plans", since: 1_791_991_983_206)]
    ),
    WatchLine.Row(
        session: "sr-y4d0qj", name: "Dashboard memory and snags", projectName: "Switchboard",
        lines: [
            .init(
                "stop:sr-y4d0qj:w1:1792445500000", .permission, first: .init(lead: "Allow Bash:", mono: "gh pr create"),
                since: 1_792_445_500_000
            ),
        ]
    ),
    WatchLine.Row(
        session: "sr-j94s0e", name: "Settle the older open questions", projectName: "Goosemates",
        lines: [
            .init(
                "stop:sr-j94s0e:w2:1792445400000", .question,
                first: .init(lead: "Which edge should it start on?", more: "+2"), since: 1_792_445_400_000
            ),
        ]
    ),
    WatchLine.Row(
        session: "sr-50f7g8", isAway: true, name: "The bootstrap", projectName: "Kit",
        lines: [.init("ask:sr-50f7g8:a2", .ask, first: "The bootstrap", since: 1_791_900_000_000)]
    ),
    WatchLine.Row(
        session: "sr-aw3bgs", name: "Build the Mac app", projectName: "SitRep",
        lines: [.init("turn:sr-aw3bgs", .yourTurn, first: "Build the notch", since: 1_792_259_685_462)]
    ),
    WatchLine.Row(
        session: "sr-q7njzv", name: "Fix inverted exception reporting", projectName: "DocMan",
        lines: [
            .init(
                "work:sr-q7njzv", .working, first: .init(lead: "Editing", mono: "app/Report.php"),
                since: 1_792_445_000_000
            ),
        ]
    ),
].map { row in
    var lettered = row

    lettered.project = "p"
    lettered.letters = "Pr"
    return lettered
}

/// One session working, nothing needing Lee.
let allClearLine = WatchLine(rows: [
    WatchLine.Row(
        session: "sr-q7njzv", name: "Fix inverted exception reporting", projectName: "DocMan",
        lines: [.init("work:sr-q7njzv", .working, first: "Running the tests", since: 1_792_445_000_000)]
    ),
]).text
