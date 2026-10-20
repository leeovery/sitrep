import Foundation

/// What the real CLI printed on 20 October 2026, run over a board seeded in a scratch `XDG_STATE_HOME` of its own
/// (SitRep's "The Mac app", a window working on it, with a yes, a choice and a words ask waiting, one closed by Lee's
/// answer and one Claude resolved; Switchboard's two windows, one stopped on a permission prompt; Goosemates' away
/// session with a choice waiting; Kit's away one with nothing):
/// - `watch`, its four lines: the first; the yes answered and the words ask ignored, both on their way; both
///   delivered; and Goosemates' session finished;
/// - `board --json` for The Mac app at each of the first three, and for Goosemates' session.
public enum Lines {
    /// `sitrep watch`'s lines, in the order it printed them.
    public static let watch = printed("watch.jsonl").split(separator: "\n").map(String.init)

    /// `sitrep watch`'s first two lines over a board of its own, run the same day: Switchboard's Usage session, away,
    /// then an ask posted into it, new on the second line.
    public static let newAsk = printed("watch-new-ask.jsonl").split(separator: "\n").map(String.init)

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

    private static func printed(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: "Printed/\(name)", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("The fixture \(name) is missing from SitRepLines")
        }

        return text
    }
}
