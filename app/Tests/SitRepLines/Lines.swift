import Foundation

/// What the real CLI printed on 20 October 2026, run over a board seeded in a scratch `XDG_STATE_HOME` of its own
/// (SitRep's "The Mac app", a window working on it, with a yes, a choice and a words ask waiting, one closed by Lee's
/// answer and one Claude resolved; Switchboard's two windows, one stopped on a permission prompt; Goosemates' away
/// session with a choice waiting; Kit's away one with nothing): `watch`, its four lines: the first; the yes answered
/// and the words ask ignored, both on their way; both delivered; and Goosemates' session finished.
///
/// `watch`'s lines printed before its version 2 (`watch`, `newAsk`, `onItsWork`) had their rows grouped by session on
/// 22 October 2026 by core's own order and head, every other field as printed; the same regrouping of version 1's lines
/// over `bySession`'s board gave, field for field, what the real version 2 printed over it. Each row's `name` and
/// `projectName`, which came after (22 October 2026, `v` unmoved), were set from its session and project on its own
/// line.
///
/// Every line here printed before 27 October 2026 was moved to version 3 that day as the CLI moved, every other field
/// as printed: a line's `changed` gave way to `boards`, `{}`, as nothing was followed.
public enum Lines {
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

    /// `sitrep watch`'s three lines over a board of its own, run on 4 November 2026 at 19:19, each session's window at
    /// Lee's turn: Northwind's Ledger export, its turn snoozed until it moves by `sitrep snooze --turn`; Contoso's
    /// Onboarding flow, its turn snoozed until 09:00 tomorrow; Fabrikam's Release notes, its turn not snoozed. Then
    /// Contoso's woken by `sitrep wake --turn`, back on Your turn; then Northwind's window at a new turn, which ends its
    /// snooze, back on Your turn at the top.
    public static let snoozedTurn = printed("watch-snoozed-turn.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s first line at version 3, Needs you newest first, run on 4 November 2026 over a board of its own
    /// seeded with its times: Northwind's Ledger export, away, a yes waiting since 09:00 (k1) and another since 12:00
    /// (k2); Contoso's Onboarding flow, away, a yes waiting since 11:00.
    public static let newest = printed("watch-newest.jsonl").trimmingCharacters(in: .newlines)

    private static func printed(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: "Printed/\(name)", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("The fixture \(name) is missing from SitRepLines")
        }

        return text
    }
}
