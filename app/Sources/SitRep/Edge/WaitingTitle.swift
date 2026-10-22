import AppKit
import SitRepPanel

/// A row on its own work's title in black, as Paper's board D sets it: its verb in the title's medium, brighter than
/// what follows, its subject in regular or, a command, in code type, or a wake's countdown. It never shimmers: it needs
/// nothing, and nothing of its own runs.
@MainActor
enum WaitingTitle {
    /// Its title, with what it says after its verb where that is no command: its subject, or a wake's countdown.
    static func text(_ s: Session, subject: String?) -> NSMutableAttributedString {
        let verb = EdgeStyle.title, plain = EdgeStyle.subject
        let text = TextLine.text(s.title, verb, EdgeStyle.waitingVerb, kern: EdgeStyle.tightKern(verb))

        if let code = s.code {
            text.append(TextLine.text(code, EdgeStyle.code, EdgeStyle.grey))
        } else if let subject {
            text.append(TextLine.text(subject, plain, EdgeStyle.grey, kern: EdgeStyle.tightKern(plain)))
        }
        return text
    }
}
