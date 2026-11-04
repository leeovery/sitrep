import AppKit
import SitRepPanel

/// A Working row's title on the card, on one line, in black, as Paper's board I sets it: its verb in 13 medium, then 6
/// after it what it acts on or waits on, 13 regular, a command in mono 12, or a wake's countdown in tabular figures,
/// each in working's grey. On its own work the verb is #B4B4BA, still; working's is the shimmer's to light.
@MainActor
enum LineTitle {
    /// Between the verb and what follows it.
    static let gap = 6.0

    /// Its title, its verb in this ink, with what follows it where `isFollowed`: its command, else its subject or a
    /// wake's countdown, as `subject` says it at the time.
    static func text(_ s: Session, verb ink: CGColor, subject: String?, isFollowed: Bool = true) -> NSMutableAttributedString {
        let follows = isFollowed ? after(s, subject: subject) : nil
        let font = EdgeStyle.lineMedium
        let verb = TextLine.text(follows == nil ? s.title : lead(s.title), font, ink, kern: EdgeStyle.tightKern(font))

        if let follows, verb.length > 0 {
            verb.addAttribute(.kern, value: gap, range: NSRange(location: verb.length - 1, length: 1))
            verb.append(follows)
        }
        return verb
    }

    /// Its verb as core's line gives it, less the space it ends with where something follows: the gap stands for it.
    private static func lead(_ title: String) -> String {
        title.hasSuffix(" ") ? String(title.dropLast()) : title
    }

    private static func after(_ s: Session, subject: String?) -> NSAttributedString? {
        if let code = s.code {
            return TextLine.text(code, EdgeStyle.lineCode, EdgeStyle.grey)
        }

        let plain = s.until == nil ? EdgeStyle.line : EdgeStyle.lineCountdown

        return subject.map { TextLine.text($0, plain, EdgeStyle.grey, kern: EdgeStyle.tightKern(plain)) }
    }
}
