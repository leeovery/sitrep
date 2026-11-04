import Foundation

/// What the real CLI printed on 20 October 2026, run over a board seeded in a scratch `XDG_STATE_HOME` of its own
/// (SitRep's "The Mac app", a window working on it, with a yes, a choice and a words ask waiting, one closed by Lee's
/// answer and one Claude resolved; Switchboard's two windows, one stopped on a permission prompt; Goosemates' away
/// session with a choice waiting; Kit's away one with nothing):
/// - `watch`, its four lines: the first; the yes answered and the words ask ignored, both on their way; both
///   delivered; and Goosemates' session finished;
/// - `board --json` for The Mac app at each of the first three, and for Goosemates' session.
///
/// `watch`'s lines printed before its version 2 (`watch`, `newAsk`, `onItsWork`) had their rows grouped by session on
/// 22 October 2026 by core's own order and head, every other field as printed; the same regrouping of version 1's lines
/// over `bySession`'s board gave, field for field, what the real version 2 printed over it. Each row's `name` and
/// `projectName`, which came after (22 October 2026, `v` unmoved), were set from its session and project on its own
/// line.
///
/// Every line and board here printed before 27 October 2026 was moved to version 3 that day as the CLI moved, every
/// other field as printed: a line's `changed` gave way to `boards`, `{}`, as nothing was followed; a board's `work`
/// became its `session`. `following` is what the real version 3 printed.
public enum Lines {
    /// `sitrep watch`'s four lines at version 3 over a board of its own, run on 27 October 2026, its standard input a
    /// fifo: Harness's Follow the boards, away, a yes (ayh1) and a choice (vx3g) waiting; then, after a follow line
    /// naming it and sr-n0n3zz, which no project files, its board and a null for the other; then, a third ask (0rzx)
    /// posted, new on the line, its board again; then, the yes answered, its board with the yes on its way.
    public static let following = printed("watch-boards.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s first two lines at version 2, rows by session, over a board of its own run on 22 October 2026:
    /// Harness's Finish the Harness modernisation, its window working, three asks waiting; Switchboard's Dashboard
    /// redesign, a words ask and its window stopped on a permission prompt since; Goosemates' Onboarding, away, a
    /// choice waiting; SitRep's The Mac app working; Kit's The bootstrap on its own work; Fumi's Licensing discussion
    /// on your turn. Then a fourth ask posted into Harness's session, new on the second line.
    public static let bySession = printed("watch-by-session.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s lines, in the order it printed them.
    public static let watch = printed("watch.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s first two lines over a board of its own, run the same day: Switchboard's Usage session, away,
    /// then an ask posted into it, new on the second line.
    public static let newAsk = printed("watch-new-ask.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s first line over a board of its own, run on 22 October 2026: SitRep's The Mac app, its window
    /// on its own work waiting on three agents, and Kit's The bootstrap, its window waiting on a one-off wake 12
    /// minutes off, its row first.
    public static let onItsWork = printed("watch-on-its-work.jsonl").trimmingCharacters(in: .newlines)

    /// `sitrep watch`'s three lines over a board of its own, run on 23 October 2026: Harness's Finish the Harness
    /// modernisation, away, three asks posted, k1 snoozed until five seconds on and k2 for an hour, k3 waiting, so the
    /// session has a row in Needs you and one in Snoozed; then k1 woken at its time, new on the line; then k2 woken now
    /// by `sitrep wake`, back in Needs you and new on no line.
    public static let snoozed = printed("watch-snoozed.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s two lines over a board of its own, run on 4 November 2026, its standard input a fifo, each
    /// session carrying when it started and what it parked: Northwind's Ledger export, away, two items parked, one with
    /// its where and ref; Contoso's Onboarding flow, away, a choice waiting and an item parked; Fabrikam's Release
    /// notes, nothing parked. Then, after a follow line naming Ledger export, its board.
    public static let parked = printed("watch-parked.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s first line at version 3, Needs you newest first, run on 4 November 2026 over a board of its own
    /// seeded with its times: Northwind's Ledger export, away, a yes waiting since 09:00 (k1) and another since 12:00
    /// (k2); Contoso's Onboarding flow, away, a yes waiting since 11:00.
    public static let newest = printed("watch-newest.jsonl").trimmingCharacters(in: .newlines)

    /// `board --json` for Finish the Harness modernisation as `snoozed`'s first line has it.
    public static let snoozedBoard = printed("board-snoozed.json")

    /// `board --json` for The Mac app, before anything was answered.
    public static let board = printed("board-macapp.json")
    /// The same, its yes answered and its words ask ignored, both on their way.
    public static let onItsWay = printed("board-onitsway.json")
    /// The same once its window marked both delivered: the yes closed by Lee's answer, the ignored ask gone.
    public static let delivered = printed("board-delivered.json")
    /// `board --json` for Goosemates' away session, its choice waiting.
    public static let away = printed("board-goose1.json")
    /// `board --json` for Switchboard's two sessions: Dashboard redesign's words ask, its window stopped on a
    /// permission prompt; Request ledger's, nothing waiting.
    public static let dashboard = printed("board-dash02.json")
    public static let ledger = printed("board-ledger.json")

    /// `sitrep screen --json` at version 1, run on 4 November 2026 in a tmux pane of this Mac over a board of its own,
    /// Harbor's four sessions: Shown here, its window in that pane (sr-0nscrn); Pane gone, in a pane the server has not
    /// (sr-n0pane); Server gone, under a socket no server runs on (sr-n0srvr); and Away, no window holding it
    /// (sr-awayyy), so left out.
    public static let screen = printed("screen.json")
    /// The same, tmux off the CLI's PATH, so every session in tmux is unknown.
    public static let screenUnanswered = printed("screen-unanswered.json")

    /// A line of `watch` that carried no board, carrying these sessions' boards, each as `board --json` printed it, or
    /// null, as a line carries them for the sessions the window follows.
    public static func carrying(_ boards: [String: String?], on line: String) -> String {
        let carried = boards.sorted { $0.key < $1.key }.map { "\"\($0.key)\":\($0.value ?? "null")" }
        let carrying = line.replacingOccurrences(of: #""boards":{}"#, with: #""boards":{\#(carried.joined(separator: ","))}"#)

        guard carrying != line || boards.isEmpty else {
            fatalError("The line carries boards already")
        }

        return carrying
    }

    private static func printed(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: "Printed/\(name)", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("The fixture \(name) is missing from SitRepLines")
        }

        return text
    }
}
