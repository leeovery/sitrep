import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow

/// When the board was seeded, which every time on it counts back from (`Lines`).
private let seededAt = Date(timeIntervalSince1970: 1_792_486_421)

/// So many minutes before the board was seeded.
func minutes(before minutes: Double) -> Date {
    seededAt.addingTimeInterval(-minutes * 60)
}

/// When the real `watch` printed its first line.
let printedAt = Date(timeIntervalSince1970: 1_792_486_421.238)

/// What a run of `watch` said, in order, each heard a second after the last.
func heard(_ said: Heard...) -> LastBoard {
    var last = LastBoard()

    last.begin()
    for (second, heard) in said.enumerated() {
        _ = last.hear(heard, at: printedAt.addingTimeInterval(Double(second)))
    }
    return last
}

/// `watch`'s line, by its place among those it printed.
func line(_ place: Int) -> Heard {
    .line(Lines.watch[place])
}

/// A line of `watch` with its `new` as given, the board as its first line had it.
func line(new: [String], from place: Int = 0) -> Heard {
    .line(Lines.watch[place].replacingOccurrences(of: #""new":[]"#, with: #""new":[\#(quoted(new))]"#))
}

/// The line given, `watch`'s first unless another, carrying these sessions' boards, each as the real CLI printed it, or
/// null.
func carrying(_ boards: [String: String?], on line: Heard = line(0)) -> Heard {
    guard case let .line(text) = line else {
        return line
    }

    return .line(Lines.carrying(boards, on: text))
}

/// The window hears a line carrying these sessions' boards, its board otherwise as the line given has it, `watch`'s
/// first unless another, as the line after the window follows them carries them.
func take(
    _ boards: [String: String?], in run: WindowRun, on line: Heard = line(0), at time: Date = printedAt,
    reducesMotion: Bool = false
) {
    run.show(heard(carrying(boards, on: line)), at: time, reducesMotion: reducesMotion)
}

/// `watch`'s first line with its projects in this order, by their keys, as a change in what needs Lee would order them.
func projects(_ order: [String]) -> String {
    var line = try! JSONSerialization.jsonObject(with: Data(Lines.watch[0].utf8)) as! [String: Any]
    let projects = line["projects"] as! [[String: Any]]

    line["projects"] = order.map { key in projects.first { $0["key"] as? String == key }! }
    return String(decoding: try! JSONSerialization.data(withJSONObject: line), as: UTF8.self)
}

/// `watch`'s line at this place with one session's `doing` as given, and its row away or not, as its windows coming or
/// going would leave it.
func line(_ place: Int = 0, with session: String, doing kind: Doing.Kind) -> Heard {
    var line = try! JSONSerialization.jsonObject(with: Data(Lines.watch[place].utf8)) as! [String: Any]

    line["projects"] = (line["projects"] as! [[String: Any]]).map { project in
        var project = project

        project["sessions"] = (project["sessions"] as! [[String: Any]]).map { each in
            var each = each

            if each["id"] as? String == session {
                var doing = each["doing"] as! [String: Any]

                doing["is"] = kind.rawValue
                each["doing"] = doing
            }
            return each
        }
        return project
    }
    line["rows"] = (line["rows"] as! [[String: Any]]).map { row in
        row["session"] as? String == session ? row.merging(["isAway": kind == .away]) { $1 } : row
    }
    return .line(String(decoding: try! JSONSerialization.data(withJSONObject: line), as: UTF8.self))
}

private func quoted(_ keys: [String]) -> String {
    keys.map { "\"\($0)\"" }.joined(separator: ",")
}

/// What `watch` says a session is doing.
func doing(_ kind: Doing.Kind, _ lead: String, mono: String? = nil, since: Date) -> Doing {
    Doing(kind: kind, line: Board.Row.Words(lead: lead, mono: mono, more: nil), since: since)
}

/// A board the real CLI printed, changed as given.
func edited(_ text: String, _ change: (inout [String: Any]) -> Void) -> String {
    var board = try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]

    change(&board)
    return String(decoding: try! JSONSerialization.data(withJSONObject: board), as: UTF8.self)
}

/// `watch`'s first line with nothing waiting on Lee in this session any more, its turn come, as its asks closing would
/// leave it.
func answered(_ session: String) -> Heard {
    .line(edited(Lines.watch[0]) { board in
        board["rows"] = (board["rows"] as! [[String: Any]]).filter { $0["session"] as? String != session }
        board["projects"] = (board["projects"] as! [[String: Any]]).map { project in
            var project = project

            project["sessions"] = (project["sessions"] as! [[String: Any]]).map { each in
                var each = each

                if each["id"] as? String == session {
                    each["state"] = "yourTurn"
                    each["waiting"] = 0
                }
                return each
            }
            return project
        }
    })
}

/// The Mac app's board once its yes was answered and its words ask ignored, both delivered, and a new ask, k4, came.
let deliveredAndNew = edited(Lines.delivered) { board in
    let asks = board["asks"] as! [[String: Any]]

    board["asks"] = asks + [asks[0].merging(["id": "k4", "title": "Pick the strip's width"]) { $1 }]
}

/// `watch`'s first line with this session's turn ended on an ask, its row in Needs you, as Claude posting one would
/// leave it.
func asked(_ session: String) -> Heard {
    .line(edited(Lines.watch[0]) { board in
        board["rows"] = (board["rows"] as! [[String: Any]]).map { row in
            guard row["session"] as? String == session else {
                return row
            }

            var asking = row

            asking["section"] = "needsYou"
            asking["lines"] = (row["lines"] as! [[String: Any]]).map { line in
                line.merging(["is": "ask", "key": "ask:\(session):k9", "ask": "k9"]) { $1 }
            }
            return asking
        }
    })
}

/// `watch`'s first line with these sessions' rows on Your turn, each ended so many minutes before the board was
/// seeded, as their turns ending would leave them, and Your turn the newest first, as core orders it.
func turned(_ ended: [String: Double]) -> Heard {
    .line(edited(Lines.watch[0]) { board in
        let rows = (board["rows"] as! [[String: Any]]).map { row in
            let session = row["session"] as! String
            guard let ago = ended[session] else {
                return row
            }

            let since = minutes(before: ago).timeIntervalSince1970 * 1000
            let words: [String: Any] = ["lead": "The turn of \(session)", "mono": NSNull(), "subject": NSNull(), "more": NSNull(), "until": NSNull()]
            let line: [String: Any] = [
                "key": "turn:\(session)", "is": "yourTurn", "ask": NSNull(), "writer": NSNull(), "first": words, "since": since,
            ]

            return row.merging(["section": "yourTurn", "isAway": false, "lines": [line], "since": since]) { $1 }
        }
        let isTurn = { (row: [String: Any]) in row["section"] as? String == "yourTurn" }

        board["rows"] = rows.filter { !isTurn($0) }
            + rows.filter(isTurn).sorted { ($0["since"] as! Double) > ($1["since"] as! Double) }
    })
}

/// A window open on the line given, `watch`'s first unless another, then hearing that line again carrying the boards
/// given, as the next line carries those of the sessions it follows, its wall clock at the moment `watch` printed its
/// first line unless given another.
func opened(
    on line: Heard = line(0), boards: [String: String?] = ["sr-macapp": Lines.board],
    wall: @escaping () -> Date = { printedAt }
) -> WindowRun {
    let run = WindowRun(wall: wall)

    run.show(heard(line), at: printedAt, reducesMotion: false)
    run.open()
    take(boards, in: run, on: line)
    return run
}

/// A region of the page, which says where the pointer is under its own identity.
final class Region: Sendable {}

/// Two regions, alive throughout, so neither's identity can be another's.
private let regions = (Region(), Region())
let pageRegion = ObjectIdentifier(regions.0)
let otherRegion = ObjectIdentifier(regions.1)

/// The pointer over the page, in the window key, from this time: an ask closing keeps its place.
func overThePage(_ run: WindowRun, at time: Date = printedAt) {
    run.window(isKey: true, at: time)
    run.pointer(overPage: true, from: pageRegion, at: time)
}

extension Page {
    var session: SessionPage? {
        if case let .session(page) = self {
            return page
        }
        return nil
    }

    var project: ProjectPage? {
        if case let .project(page) = self {
            return page
        }
        return nil
    }
}
