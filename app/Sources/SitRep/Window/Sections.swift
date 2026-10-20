import SitRepWindow
import SwiftUI

/// A session's status: what is under way, then what comes next, dim.
struct StatusSection: View {
    let status: Status
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Status", note: status.updated.map { Words.updated($0, at: now) }).padding(.bottom, 8)
            ForEach(Array(status.now.enumerated()), id: \.offset) { _, line in
                SectionLine(bullet: "•", text: line)
            }
            if let next = status.next {
                SectionLine(bullet: "◦", bulletColour: WindowStyle.faint, text: "next: \(next)", textColour: WindowStyle.soft)
            }
        }
    }
}

/// What happened: the log's latest lines, the newest first, each naming its session in a project's view.
struct NotesSection: View {
    let notes: [Note]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Notes", note: "what happened").padding(.bottom, 8)
            ForEach(notes) { note in
                SectionLine(bullet: "•", session: note.session, text: note.text, time: Words.age(note.at, at: now))
            }
        }
    }
}

/// What was parked to come back to, the oldest first, in grey: the window has one colour.
struct ParkedSection: View {
    let parked: [Parked]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Parked", note: Words.parked(parked.count)).padding(.bottom, 8)
            ForEach(parked) { item in
                SectionLine(bullet: "◇", session: item.session, text: item.title, time: Words.age(item.at, at: now))
            }
        }
    }
}

/// The asks closed, the newest first, the latest three until "show all" opens it to every one, in grey.
struct ResolvedSection: View {
    let resolved: [Resolved]
    let now: Date

    @State private var showsAll = false

    private static let shown = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(name: "Resolved", note: Words.resolved(resolved.count)).padding(.bottom, 8)
            ForEach(showsAll ? resolved : Array(resolved.prefix(Self.shown))) { ask in
                SectionLine(bullet: "✓", text: ask.title, time: Words.age(ask.closed, at: now))
                    .help(Words.closed(ask.how))
            }
            if resolved.count > Self.shown {
                Button(showsAll ? "show fewer" : "show all \(resolved.count)") { showsAll.toggle() }
                    .buttonStyle(.plain)
                    .font(WindowStyle.ui(12))
                    .foregroundStyle(WindowStyle.faint)
                    .padding(.leading, 22)
                    .padding(.top, 6)
            }
        }
    }
}
