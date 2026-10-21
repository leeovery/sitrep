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

/// What `watch` said, in order, each heard a second after the last, and a run's first line for each run begun.
func heard(_ said: Heard..., runs: Int = 1) -> LastBoard {
    var last = LastBoard()

    for _ in 0 ..< runs {
        last.begin()
    }
    for (second, heard) in said.enumerated() {
        _ = last.hear(heard, at: printedAt.addingTimeInterval(Double(second)))
    }
    return last
}

/// `watch`'s line, by its place among those it printed.
func line(_ place: Int) -> Heard {
    .line(Lines.watch[place])
}

/// A line of `watch` with its `new` and `changed` as given, the board as its first line had it.
func line(new: [String] = [], changed: [String] = [], from place: Int = 0) -> Heard {
    .line(
        Lines.watch[place]
            .replacingOccurrences(of: #""new":[]"#, with: #""new":[\#(quoted(new))]"#)
            .replacingOccurrences(of: #""changed":["sr-macapp"]"#, with: #""changed":[]"#)
            .replacingOccurrences(of: #""changed":[]"#, with: #""changed":[\#(quoted(changed))]"#)
    )
}

/// `watch`'s first line with its projects in this order, by their keys, as a change in what needs Lee would order them.
func projects(_ order: [String]) -> String {
    var line = try! JSONSerialization.jsonObject(with: Data(Lines.watch[0].utf8)) as! [String: Any]
    let projects = line["projects"] as! [[String: Any]]

    line["projects"] = order.map { key in projects.first { $0["key"] as? String == key }! }
    return String(decoding: try! JSONSerialization.data(withJSONObject: line), as: UTF8.self)
}

/// `watch`'s line at this place with one session's `doing` as given, as its windows coming or going would leave it.
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
    return .line(String(decoding: try! JSONSerialization.data(withJSONObject: line), as: UTF8.self))
}

private func quoted(_ keys: [String]) -> String {
    keys.map { "\"\($0)\"" }.joined(separator: ",")
}

/// What `watch` says a session is doing.
func doing(_ kind: Doing.Kind, _ lead: String, mono: String? = nil, since: Date) -> Doing {
    Doing(kind: kind, line: Board.Row.Line(lead: lead, mono: mono, more: nil), since: since)
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

/// A session's board as the real CLI printed it.
func board(_ text: String) -> BoardAnswer {
    .board(try! SessionBoard.read(text))
}

/// A window open on the board `watch` first printed, with every read it asked for answered as given.
func opened(on last: LastBoard = heard(line(0)), boards: [String: String] = ["sr-macapp": Lines.board]) -> WindowRun {
    let run = WindowRun()

    _ = run.show(last, at: printedAt, reducesMotion: false)
    answer(run.open(), in: run, with: boards)
    return run
}

/// Each read answered with the board given for its session, if there is one.
func answer(_ reads: [Read], in run: WindowRun, with boards: [String: String], at time: Date = printedAt) {
    for read in reads {
        if let text = boards[read.session] {
            run.read(read, gave: board(text), at: time, reducesMotion: false)
        }
    }
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
