import SitRepTestSupport

/// A line of `sitrep watch`, cut to its rows: an ask, a permission prompt new on it, a question, an away ask, a turn,
/// and a window working.
let watchLine = watched(new: ["stop:sr-y6m1pr:w1:1792445500000"])

/// The same board with these rows new on it: with none, as a run's first line.
func watched(new: [String]) -> String {
    WatchLine(rows: watchRows, new: new).text
}

private let watchRows = [
    WatchLine.Row(
        session: "sr-7p4wd2", name: "Plan the launch", projectName: "Humongous",
        lines: [.init("ask:sr-7p4wd2:k1hs", .ask, first: "Approve the rollout plan", since: 1_791_991_983_206)]
    ),
    WatchLine.Row(
        session: "sr-y6m1pr", name: "Report caching and snags", projectName: "Woodgrove",
        lines: [
            .init(
                "stop:sr-y6m1pr:w1:1792445500000", .permission, first: .init(lead: "Allow Bash:", mono: "gh pr create"),
                since: 1_792_445_500_000
            ),
        ]
    ),
    WatchLine.Row(
        session: "sr-j3x7bn", name: "Close out the remaining questions", projectName: "Lucerne",
        lines: [
            .init(
                "stop:sr-j3x7bn:w2:1792445400000", .question,
                first: .init(lead: "Which edge should it start on?", more: "+2"), since: 1_792_445_400_000
            ),
        ]
    ),
    WatchLine.Row(
        session: "sr-5h1zr3", isAway: true, name: "The installer", projectName: "Litware",
        lines: [.init("ask:sr-5h1zr3:a2", .ask, first: "The installer", since: 1_791_900_000_000)]
    ),
    WatchLine.Row(
        session: "sr-a8n2xc", name: "Build the desktop app", projectName: "Trey Research",
        lines: [.init("turn:sr-a8n2xc", .yourTurn, first: "Build the notch", since: 1_792_259_685_462)]
    ),
    WatchLine.Row(
        session: "sr-q1f5hs", name: "Fix the reversed error totals", projectName: "BlueYonder",
        lines: [
            .init(
                "work:sr-q1f5hs", .working, first: .init(lead: "Editing", mono: "app/Report.php"),
                since: 1_792_445_000_000
            ),
        ]
    ),
]

/// One session working, nothing needing Lee.
let allClearLine = WatchLine(rows: [
    WatchLine.Row(
        session: "sr-q1f5hs", name: "Fix the reversed error totals", projectName: "BlueYonder",
        lines: [.init("work:sr-q1f5hs", .working, first: "Running the tests", since: 1_792_445_000_000)]
    ),
]).text
