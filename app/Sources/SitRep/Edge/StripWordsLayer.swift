import AppKit
import SitRepEdge
import SitRepPanel

/// A tab's words in black, laid out once as the prototype's `.tl` lays them out: a session's panel row (its title, the
/// line under it, an away ask's saying no window holds it, and its time at the right, or in Snoozed when it wakes, its
/// words soft as the card's Snoozed rows are), a count's rows, or the notch at rest's two lines. Each frame sets only
/// their opacity, their slide along the strip, how far a count's rows are scrolled, a click pressing them in, and the
/// time, and a wake's countdown, as they tick.
@MainActor
final class StripWordsLayer {
    let layer = CALayer()
    /// What they were laid out to say of the board, and whether with motion reduced.
    private let note: StripNote
    private let reducesMotion: Bool

    /// What presses in: the row, scaled from the strip's side.
    private let content = CALayer()
    private let age = CALayer()
    private let spinner: Arc
    /// A count's rows, by their marks' keys (`Session.markID`), scrolled together.
    private let list = CALayer()
    private(set) var rows: [String: CALayer] = [:]
    /// A count's rows waiting on a wake: each title, where it sits in its row, and what its countdown said.
    private var countdowns: [(session: Session, title: CALayer, box: CGRect, subject: String?)] = []
    private var session: Session?
    private var at: StripRowLayout?
    private var ageText = ""
    private var title: CALayer?
    /// What a row on its own work's title says after its verb, as last set: a wake's countdown changes it.
    private var subject: String?
    private var pressed = false
    /// The count's row lifted, or pressed in.
    private var lit: (row: CALayer, pressed: Bool)?
    private var scrolled = 0.0

    /// Laid out in this frame, as the scene has them: pressing in from the strip's side, saying what it says of the
    /// board, timed by its clock.
    init(_ words: StripFrame.Words, in frame: CGRect, _ scene: StripScene) {
        let now = scene.now

        note = scene.note
        reducesMotion = scene.reducesMotion
        spinner = Arc(from: -0.75 * .pi)
        layer.frame = frame
        layer.masksToBounds = true
        content.anchorPoint = CGPoint(x: scene.stripSide, y: 0.5)
        content.frame = CGRect(origin: .zero, size: frame.size)
        layer.addSublayer(content)
        switch words.content {
        case let .row(session): lay(session, in: frame.size, now: now)
        case let .rows(sessions): lay(sessions, width: frame.width, now: now)
        case .idle: layIdle(in: frame.size)
        }
    }

    /// Whether they were laid out as the scene would lay them.
    func says(_ scene: StripScene) -> Bool {
        note == scene.note && reducesMotion == scene.reducesMotion
    }

    func show(_ words: StripFrame.Words, in frame: CGRect, hover: String?, now: Double) {
        layer.frame = frame
        layer.opacity = Float(words.alpha)
        layer.transform = CATransform3DMakeTranslation(0, words.dy, 0)
        if words.scroll != scrolled {
            scrolled = words.scroll
            list.frame.origin.y = -scrolled
        }
        if words.isPressed != pressed {
            pressed = words.isPressed
            press()
        }
        showAge(at: now)
        showCountdowns(at: now)

        let id = words.pressedRow ?? hover

        light(id.flatMap { rows[$0] }, pressed: words.pressedRow != nil)
    }

    /// As wide as the words need, before the tab's slack: a session's row, the widest of a count's rows, or the notch
    /// at rest's lines, saying what the note says of the board at the time.
    nonisolated static func measure(_ note: @escaping () -> StripNote) -> StripMeasure {
        StripMeasure(
            row: { session in
                let said = note()

                return MainActor.assumeIsolated {
                    let now = Displays.wallNow
                    let words = rowWidth(session, at: now)
                    let age = StripRowLayout.ageWidth(said.age(session, at: now))

                    return StripRowLayout.pad.left + words + StripRowLayout.gap + age + StripRowLayout.pad.right
                }
            },
            rows: { sessions in
                MainActor.assumeIsolated {
                    let now = Displays.wallNow
                    let words = sessions.map { countRowWidth($0, at: now) }.max() ?? 0

                    return StripRowLayout.pad.left + words + StripRowLayout.pad.right
                }
            },
            idle: {
                let said = note()

                return MainActor.assumeIsolated {
                    let words = max(TextLine.width(idleTitle(said)), TextLine.width(idleLine2(said)))

                    return StripRowLayout.pad.left + words + StripRowLayout.pad.right
                }
            }
        )
    }

    // MARK: A session's row

    private func lay(_ session: Session, in size: CGSize, now: Double) {
        let at = StripRowLayout(session, note: note, in: size, now: now)

        self.session = session
        self.at = at
        if session.kind == .working, !reducesMotion {
            let shimmer = Shimmer(
                grey: Self.title(session, at: now, EdgeStyle.shim), lit: Self.title(session, at: now, EdgeStyle.ink),
                in: at.title
            )

            shimmer.band.add(shimmer.sweep, forKey: "sweep")
            content.addSublayer(shimmer.layer)
        } else {
            showTitle(of: session, in: at, now: now)
        }
        content.addSublayer(TextLine(Self.sub(session), in: at.sub))
        age.frame = at.ageBox
        content.addSublayer(age)
        showAge(at: now)
        spinner.fit(at.spinner)
        spinner.track.strokeColor = EdgeStyle.track
        spinner.arc.strokeColor = EdgeStyle.ink
        spinner.layer.isHidden = true
        spinner.turn(every: 1)
        content.addSublayer(spinner.layer)
    }

    /// A still title, set again in place of the last as a wake's countdown reads differently.
    private func showTitle(of session: Session, in at: StripRowLayout, now: Double) {
        let line = TextLine(Self.title(session, at: now), in: at.title)

        line.contentsScale = layer.contentsScale
        still {
            if let title {
                content.replaceSublayer(title, with: line)
            } else {
                content.addSublayer(line)
            }
        }
        title = line
        subject = session.subject(at: now)
    }

    /// The row's time at this moment on the wall clock, or as of when the board was last current, and a wake's
    /// countdown, each drawn again only when it reads differently.
    private func showAge(at now: Double) {
        guard let session, let at else {
            return
        }

        if session.until != nil, session.subject(at: now) != subject {
            showTitle(of: session, in: at, now: now)
        }

        let text = note.age(session, at: now)

        guard text != ageText else {
            return
        }

        let line = TextLine(
            StripRowLayout.ageLine(text, soft: session.isSnoozed), in: CGRect(origin: .zero, size: at.ageBox.size),
            alignment: .right
        )

        line.contentsScale = layer.contentsScale
        age.sublayers?.forEach { $0.removeFromSuperlayer() }
        age.addSublayer(line)
        ageText = text
    }

    // MARK: The notch at rest's

    /// Nothing running, or what the board is waiting on, its title quieter than a row's, and nothing to click.
    private func layIdle(in size: CGSize) {
        let at = StripRowLayout.idle(in: size)

        content.addSublayer(TextLine(Self.idleTitle(note), in: at.title))
        content.addSublayer(TextLine(Self.idleLine2(note), in: at.sub))
    }

    // MARK: A count's rows

    private func lay(_ sessions: [Session], width: Double, now: Double) {
        list.frame = CGRect(origin: .zero, size: content.bounds.size)
        content.addSublayer(list)
        for (i, session) in sessions.enumerated() {
            let at = StripRowsLayout(i, width: width), box = CALayer()

            let title = TextLine(Self.rowTitle(session, at: now), in: at.title)

            box.frame = at.box
            box.cornerRadius = StripRowsLayout.radius
            box.addSublayer(title)
            box.addSublayer(TextLine(Self.rowSub(session), in: at.sub))
            list.addSublayer(box)
            rows[session.markID] = box
            if session.until != nil {
                countdowns.append((session, title, at.title, session.subject(at: now)))
            }
        }
    }

    /// A count's rows waiting on a wake, each title set again in place of the last as its countdown reads differently.
    private func showCountdowns(at now: Double) {
        countdowns = countdowns.map { row in
            let subject = row.session.subject(at: now)

            guard subject != row.subject else {
                return row
            }

            let line = TextLine(Self.rowTitle(row.session, at: now), in: row.box)

            line.contentsScale = layer.contentsScale
            still { row.title.superlayer?.replaceSublayer(row.title, with: line) }
            return (row.session, line, row.box, subject)
        }
    }

    /// The count's row under the pointer lifts, and one a click jumps from presses in, the one lit before coming
    /// down, each over 110ms.
    private func light(_ row: CALayer?, pressed: Bool) {
        guard row !== lit?.row || pressed != lit?.pressed else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0.11)
        if let was = lit?.row {
            was.backgroundColor = nil
            was.transform = CATransform3DIdentity
        }
        if let row {
            row.backgroundColor = pressed ? EdgeStyle.press : EdgeStyle.hover
            row.transform = pressed ? CATransform3DMakeScale(0.985, 0.985, 1) : CATransform3DIdentity
        }
        CATransaction.commit()
        lit = row.map { ($0, pressed) }
    }

    /// Pressed in, the row scales to 0.985 from the strip's side over 140ms, and back, an arc spinning in its time's
    /// place.
    private func press() {
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0.14)
        content.transform = pressed ? CATransform3DMakeScale(0.985, 0.985, 1) : CATransform3DIdentity
        CATransaction.commit()
        still {
            age.isHidden = pressed
            spinner.layer.isHidden = !pressed
        }
    }

    // MARK: The words

    /// A session's row's words at their widest from this time on: its title, leaving room for every reading a wake's
    /// countdown may yet take, or its second line.
    static func rowWidth(_ s: Session, at now: Double) -> Double {
        max(sayings(s, at: now).map { TextLine.width(title(s, saying: $0)) }.max() ?? 0, TextLine.width(sub(s)))
    }

    /// One of a count's rows' words at their widest from this time on, as a session's row's are.
    static func countRowWidth(_ s: Session, at now: Double) -> Double {
        max(sayings(s, at: now).map { TextLine.width(rowTitle(s, saying: $0)) }.max() ?? 0, TextLine.width(rowSub(s)))
    }

    /// What a row's title may say after its verb from this time on, to leave room for: what it says now, or each
    /// reading a wake's countdown leaves room for, as it widens from "in 1h" to "in 59m".
    private static func sayings(_ s: Session, at now: Double) -> [String?] {
        let room = s.countdownRoom(after: now)

        return room.isEmpty ? [s.subject(at: now)] : room
    }

    /// A row's title at this time on the wall clock, in a colour where given.
    private static func title(_ s: Session, at now: Double, _ colour: CGColor? = nil) -> NSAttributedString {
        title(s, saying: s.subject(at: now), colour)
    }

    /// A row's title saying this after its verb, in a colour where given, dimmed where it is away (`Away`); one on its
    /// own work as the card sets it, and one in Snoozed soft.
    private static func title(_ s: Session, saying subject: String?, _ colour: CGColor? = nil) -> NSAttributedString {
        if s.kind == .onItsWork {
            return WaitingTitle.text(s, subject: subject)
        }

        let font = EdgeStyle.title
        let ink = s.isSnoozed ? EdgeStyle.ink2 : Away.dimmed(colour ?? EdgeStyle.ink, s.away)
        let text = TextLine.text(s.title, font, ink, kern: EdgeStyle.tightKern(font))

        append(s, to: text, ink, more: EdgeStyle.title)
        return text
    }

    /// A title's subject in code type after it, and its count (`more`), dim, 6 further on, an away ask's dimmed with
    /// it.
    private static func append(_ s: Session, to text: NSMutableAttributedString, _ ink: CGColor, more font: NSFont) {
        if let code = s.code {
            text.append(TextLine.text(code, EdgeStyle.code, ink))
        }
        if let more = s.more {
            if text.length > 0 {
                text.addAttribute(.kern, value: 6, range: NSRange(location: text.length - 1, length: 1))
            }
            text.append(TextLine.text(more, font, Away.dimmed(EdgeStyle.ink3, dims(s))))
        }
    }

    /// Whether its words dim as an away row's (`Away`): never in Snoozed, whose words are soft already, as the card's.
    private static func dims(_ s: Session) -> Bool { s.away && !s.isSnoozed }

    /// Its second line (`Session.sub`): needing Lee, its project, or with no window holding it, why a click does
    /// nothing, dimmed with its title (`Away`); else its project and session.
    private static func sub(_ s: Session) -> NSAttributedString {
        TextLine.text(s.sub, EdgeStyle.sub, Away.dimmed(EdgeStyle.ink2, dims(s)))
    }

    /// One of a count's rows' titles at this time on the wall clock.
    private static func rowTitle(_ s: Session, at now: Double) -> NSAttributedString {
        rowTitle(s, saying: s.subject(at: now))
    }

    /// One of a count's rows' titles saying this after its verb, where it has no command: needs you and your turn in
    /// ink, working and on its own work grey, and Snoozed soft, an away row's dimmed (`Away`), a wake's countdown in
    /// tabular figures.
    private static func rowTitle(_ s: Session, saying subject: String?) -> NSAttributedString {
        let isGrey = s.kind == .working || s.kind == .onItsWork
        let ink = s.isSnoozed ? EdgeStyle.ink2 : Away.dimmed(isGrey ? EdgeStyle.grey : EdgeStyle.ink, s.away)
        let font = EdgeStyle.rowTitle
        let text = TextLine.text(s.title, font, ink)

        if s.code == nil, let subject {
            text.append(TextLine.text(subject, s.until == nil ? font : EdgeStyle.rowCountdown, ink))
        }
        append(s, to: text, ink, more: EdgeStyle.rowTitle)
        return text
    }

    private static func rowSub(_ s: Session) -> NSAttributedString {
        TextLine.text(s.sub, EdgeStyle.rowSub, Away.dimmed(EdgeStyle.ink2, dims(s)))
    }

    private static func idleTitle(_ note: StripNote) -> NSAttributedString {
        TextLine.text(note.idle, EdgeStyle.title, EdgeStyle.ink2, kern: EdgeStyle.tightKern(EdgeStyle.title))
    }

    private static func idleLine2(_ note: StripNote) -> NSAttributedString {
        TextLine.text(note.idleLine2, EdgeStyle.sub, EdgeStyle.ink2)
    }

}
