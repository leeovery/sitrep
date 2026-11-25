import AppKit
import SitRepPanel

/// A title in the strip, a tab's or a count's row's, in its runs, each in its own type and spacing: its verb, then
/// what follows it, a command in code type, else what it acts on or waits on, plain or a wake's countdown in tabular
/// figures, then its count (`more`), 6 after it, the runs set as attributed text.
@MainActor
struct StripTitle {
    /// What a run is, for its colour.
    enum Part {
        case verb, follows, more
    }

    struct Run {
        var words: String
        let font: NSFont
        let part: Part
        /// Spaced as the prototype spaces it, where it does.
        var kern: CGFloat?
        /// Room after its last letter: the gap before the count.
        var gap: CGFloat?
    }

    private(set) var runs: [Run]

    /// Between a title and its count.
    static let countGap: CGFloat = 6

    /// A tab's title, saying this after its verb: at a title's size, its verb in medium, it and what follows it spaced
    /// tight but for a command, its count after them.
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
            if let last = runs.lastIndex(where: { !$0.words.isEmpty }) {
                runs[last].gap = Self.countGap
            }
            runs.append(Run(words: more, font: verb, part: .more))
        }
        self.runs = runs
    }

    /// How wide it is set whole.
    var width: CGFloat { TextLine.width(text { _ in .black }) }

    /// Cut short to fit this wide, the count kept whole, as it says how much more there is: the words before it give
    /// way first, cut at a character with an ellipsis, the most of them that fit, or none. With no count, as it is, for
    /// the line to cut at its end.
    func fitting(_ room: CGFloat) -> Self {
        guard width > room, runs.last?.part == .more, let cut = runs.lastIndex(where: { $0.part != .more }) else {
            return self
        }

        let words = Array(runs[cut].words)
        let kept = (0 ..< words.count).reversed().lazy.map { self.cutting(cut, to: String(words.prefix($0))) }

        return kept.first { $0.width <= room } ?? cutting(cut, to: nil)
    }

    /// This run's words cut to these, an ellipsis after them; none at all for nil.
    private func cutting(_ index: Int, to words: String?) -> Self {
        var cut = self

        cut.runs[index].words = words.map { $0.trimmingCharacters(in: .whitespaces) + "…" } ?? ""
        return cut
    }

    /// Set in black, each run in its part's ink.
    func text(_ ink: (Part) -> CGColor) -> NSMutableAttributedString {
        runs.reduce(into: NSMutableAttributedString()) { text, run in
            let set = TextLine.text(run.words, run.font, ink(run.part), kern: run.kern)

            if let gap = run.gap, set.length > 0 {
                let last = (set.string as NSString).rangeOfComposedCharacterSequence(at: set.length - 1)

                set.addAttribute(.kern, value: gap, range: last)
            }
            text.append(set)
        }
    }
}
