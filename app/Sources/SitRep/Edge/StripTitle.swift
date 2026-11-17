import AppKit
import SitRepPanel
import SwiftUI

/// A title in the strip, a tab's or a count's row's, in its runs, each in its own type and spacing: its verb, then
/// what follows it, a command in code type, else what it acts on or waits on, plain or a wake's countdown in tabular
/// figures, then its count (`more`), 6 after it. The black sets the runs as attributed text and glass as `Text`, so
/// the words glass draws are the words the black measures and draws.
@MainActor
struct StripTitle {
    /// What a run is, for its colour, which each material gives its own way.
    enum Part {
        case verb, follows, more
    }

    struct Run {
        let words: String
        let font: NSFont
        let part: Part
        /// Spaced as the prototype spaces it, where it does.
        var kern: CGFloat?
        /// Room after its last letter: the gap before the count.
        var gap: CGFloat?
    }

    let runs: [Run]

    /// Between a title and its count.
    static let countGap = 6.0

    /// A tab's title, saying this after its verb: at a title's size, its verb in medium, spaced tight, as all but its
    /// command.
    static func tab(_ s: Session, saying subject: String?) -> Self {
        Self(s, saying: subject, verb: EdgeStyle.title, plain: EdgeStyle.subject, countdown: EdgeStyle.countdown, isTight: true)
    }

    /// A count's row's title, saying this after its verb: 13 medium throughout, its countdown in tabular figures.
    static func row(_ s: Session, saying subject: String?) -> Self {
        Self(s, saying: subject, verb: EdgeStyle.rowTitle, plain: EdgeStyle.rowTitle, countdown: EdgeStyle.rowCountdown, isTight: false)
    }

    private init(_ s: Session, saying subject: String?, verb: NSFont, plain: NSFont, countdown: NSFont, isTight: Bool) {
        let kern = { (font: NSFont) in isTight ? EdgeStyle.tightKern(font) : nil }
        var runs = [Run(words: s.title, font: verb, part: .verb, kern: kern(verb))]

        if let code = s.code {
            runs.append(Run(words: code, font: EdgeStyle.code, part: .follows))
        } else if let subject {
            let font = s.until == nil ? plain : countdown

            runs.append(Run(words: subject, font: font, part: .follows, kern: kern(font)))
        }
        if let more = s.more {
            runs[runs.count - 1].gap = Self.countGap
            runs.append(Run(words: more, font: verb, part: .more))
        }
        self.runs = runs
    }

    /// Set in black, each run in its part's ink.
    func text(_ ink: (Part) -> CGColor) -> NSMutableAttributedString {
        runs.reduce(into: NSMutableAttributedString()) { text, run in
            let set = TextLine.text(run.words, run.font, ink(run.part), kern: run.kern)

            if let gap = run.gap, set.length > 0 {
                set.addAttribute(.kern, value: gap, range: NSRange(location: set.length - 1, length: 1))
            }
            text.append(set)
        }
    }

    /// Set on glass, its count in the tertiary label colour, the rest in whatever colour the view gives it.
    @available(macOS 26, *)
    var glass: Text {
        runs.reduce(Text("")) { $0 + Self.glass($1) }
    }

    @available(macOS 26, *)
    private static func glass(_ run: Run) -> Text {
        let set = { (words: String, kern: CGFloat?) in
            let text = Text(words).font(Font(run.font))

            return kern.map(text.kerning) ?? text
        }
        let text = run.gap.flatMap { gap in
            run.words.last.map { set(String(run.words.dropLast()), run.kern) + set(String($0), gap) }
        } ?? set(run.words, run.kern)

        return run.part == .more ? text.foregroundStyle(.tertiary) : text
    }
}
