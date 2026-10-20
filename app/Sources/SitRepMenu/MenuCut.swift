/// The font a run of a menu item's words is drawn in, which the app measures it by.
public enum MenuFace: Sendable {
    /// The menu's own font: a title's words.
    case words
    /// SF Mono at the menu's size: a row's subject.
    case mono
    /// The menu's font in bold: what SitRep speaks up with.
    case bold
    /// The line under a title.
    case subtitle
}

/// A run of an item's words, in its face.
public struct MenuRun: Equatable, Sendable {
    public let text: String
    public let face: MenuFace

    public init(_ text: String, _ face: MenuFace) {
        self.text = text
        self.face = face
    }
}

/// The menu's words cut to its one width (DESIGN, "The menu bar item"). A native menu is as wide as its widest item, so
/// a row's title or line past the width is cut at its tail with an ellipsis, measured run by run in the font each is
/// drawn in, and the menu stays about Spaceman's width, a little wider.
public struct MenuCut: Sendable {
    /// The most a title or a line under it takes, in points.
    public static let width = 340.0
    static let ellipsis = "…"

    private let width: Double
    private let measure: @Sendable (String, MenuFace) -> Double

    /// `measure` gives the width of words drawn in a face, in points.
    public init(width: Double = Self.width, measure: @escaping @Sendable (String, MenuFace) -> Double) {
        self.width = width
        self.measure = measure
    }

    /// The runs as they fit: whole, or cut after as many characters as leave room for an ellipsis, in the face of
    /// the run it ends, with the space before it dropped; then the tail, kept whole.
    public func fit(_ runs: [MenuRun], keeping tail: [MenuRun] = []) -> [MenuRun] {
        let room = width - tail.map(measure).reduce(0, +)

        guard runs.map(measure).reduce(0, +) > room else {
            return runs + tail
        }

        var kept = 0, over = runs.map(\.text.count).reduce(0, +)

        while kept < over {
            let middle = (kept + over + 1) / 2

            if cut(runs, after: middle).map(measure).reduce(0, +) <= room {
                kept = middle
            } else {
                over = middle - 1
            }
        }
        return cut(runs, after: kept) + tail
    }

    /// One line in one face, cut to fit.
    public func fit(_ line: String, in face: MenuFace) -> String {
        fit([MenuRun(line, face)]).map(\.text).joined()
    }

    /// The first so many characters of the runs, the space at their end dropped and an ellipsis after them; the
    /// runs after the cut gone.
    private func cut(_ runs: [MenuRun], after count: Int) -> [MenuRun] {
        var left = count
        var kept: [MenuRun] = []

        for run in runs where left > 0 {
            kept.append(MenuRun(String(run.text.prefix(left)), run.face))
            left -= run.text.count
        }
        while let last = kept.last, last.text.allSatisfy(\.isWhitespace) {
            kept.removeLast()
        }

        let face = kept.last?.face ?? runs.first?.face ?? .words
        let end = kept.popLast().map { String($0.text.reversed().drop(while: \.isWhitespace).reversed()) } ?? ""

        return kept + [MenuRun(end + Self.ellipsis, face)]
    }

    private func measure(_ run: MenuRun) -> Double {
        measure(run.text, run.face)
    }
}

extension MenuTitle {
    /// The title cut to the menu's width: its words and subject at their tail, a question's "+2" kept whole after
    /// them, as it says there is more to the ask.
    public func cut(by cut: MenuCut) -> MenuTitle {
        let runs = [MenuRun(words, .words)] + (mono.map { [MenuRun($0, .mono)] } ?? [])
        let tail = more.map { [MenuRun($0, .words)] } ?? []
        let fitted = cut.fit(runs, keeping: tail).dropLast(tail.count)
        let words = fitted.first { $0.face == .words }?.text ?? ""
        let mono = fitted.first { $0.face == .mono }?.text

        return MenuTitle(words: words, mono: mono, more: more, isFaint: isFaint)
    }

    /// As one plain line, for a menu that shows no attributed titles with a subtitle.
    public var plain: String {
        words + (mono ?? "") + (more ?? "")
    }
}
