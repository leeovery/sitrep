import AppKit
import SitRepEdge
import SitRepPanel

/// A tab's words in black, laid out once as the prototype's `.tl` lays them out: a session's panel row (its title, its
/// project and session, or why an away ask's takes no click, and its time at the right), a count's rows, or the notch
/// at rest's two lines. Each frame sets only their opacity, their slide along the strip, how far a count's rows are
/// scrolled, a click pressing them in, and the time as it ticks.
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
    /// A count's rows, by session, scrolled together; those of away asks never lift.
    private let list = CALayer()
    private(set) var rows: [String: CALayer] = [:]
    private var away: Set<String> = []
    private var session: Session?
    private var at: StripRowLayout?
    private var ageText = ""
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
        case let .rows(sessions): lay(sessions, width: frame.width)
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

        let id = words.pressedRow ?? hover.flatMap { away.contains($0) ? nil : $0 }

        light(id.flatMap { rows[$0] }, pressed: words.pressedRow != nil)
    }

    /// As wide as the words need, before the tab's slack: a session's row, the widest of a count's rows, or the notch
    /// at rest's lines, saying what the note says of the board at the time.
    nonisolated static func measure(_ note: @escaping () -> StripNote) -> StripMeasure {
        StripMeasure(
            row: { session in
                let said = note()

                return MainActor.assumeIsolated {
                    let words = max(TextLine.width(title(session)), TextLine.width(sub(session)))
                    let age = StripRowLayout.ageWidth(said.age(session, at: Displays.wallNow))

                    return StripRowLayout.pad.left + words + StripRowLayout.gap + age + StripRowLayout.pad.right
                }
            },
            rows: { sessions in
                MainActor.assumeIsolated {
                    let words = sessions.map { max(TextLine.width(rowTitle($0)), TextLine.width(rowSub($0))) }
                        .max() ?? 0

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
                grey: Self.title(session, EdgeStyle.shim), lit: Self.title(session, EdgeStyle.ink), in: at.title
            )

            shimmer.band.add(shimmer.sweep, forKey: "sweep")
            content.addSublayer(shimmer.layer)
        } else {
            content.addSublayer(TextLine(Self.title(session), in: at.title))
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

    /// The row's time at this moment on the wall clock, or as of when the board was last current, drawn again only
    /// when it reads differently.
    private func showAge(at now: Double) {
        guard let session, let at else {
            return
        }

        let text = note.age(session, at: now)

        guard text != ageText else {
            return
        }

        let line = TextLine(
            StripRowLayout.ageLine(text), in: CGRect(origin: .zero, size: at.ageBox.size), alignment: .right
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

    private func lay(_ sessions: [Session], width: Double) {
        list.frame = CGRect(origin: .zero, size: content.bounds.size)
        content.addSublayer(list)
        for (i, session) in sessions.enumerated() {
            let at = StripRowsLayout(i, width: width), box = CALayer()

            box.frame = at.box
            box.cornerRadius = StripRowsLayout.radius
            box.addSublayer(TextLine(Self.rowTitle(session), in: at.title))
            box.addSublayer(TextLine(Self.rowSub(session), in: at.sub))
            list.addSublayer(box)
            rows[session.id] = box
            if session.away {
                away.insert(session.id)
            }
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

    private static func title(_ s: Session, _ colour: CGColor? = nil) -> NSAttributedString {
        let font = s.kind == .needs ? EdgeStyle.needsTitle : EdgeStyle.title
        let ink = colour ?? (s.away ? EdgeStyle.quiet : EdgeStyle.ink)
        let text = TextLine.text(s.title, font, ink, kern: EdgeStyle.tightKern(font))

        append(s, to: text, ink, more: EdgeStyle.title)
        return text
    }

    /// A title's subject in code type after it, and its "+2", dim, 6 further on.
    private static func append(_ s: Session, to text: NSMutableAttributedString, _ ink: CGColor, more font: NSFont) {
        if let code = s.code {
            text.append(TextLine.text(code, EdgeStyle.code, ink))
        }
        if let more = s.more {
            text.addAttribute(.kern, value: 6, range: NSRange(location: text.length - 1, length: 1))
            text.append(TextLine.text(more, font, EdgeStyle.ink3))
        }
    }

    /// Core's second line: its project and session, or for an away ask, why a click does nothing.
    private static func sub(_ s: Session) -> NSAttributedString {
        TextLine.text(s.sub, EdgeStyle.sub, EdgeStyle.ink2)
    }

    /// One of a count's rows' titles: needs you and your turn in ink, needs you's bolder, an away ask's quiet, and
    /// working grey.
    private static func rowTitle(_ s: Session) -> NSAttributedString {
        let ink = s.away ? EdgeStyle.quiet : s.kind == .working ? EdgeStyle.grey : EdgeStyle.ink
        let font = s.kind == .needs ? EdgeStyle.needsRowTitle : EdgeStyle.rowTitle
        let text = TextLine.text(s.title, font, ink)

        append(s, to: text, ink, more: EdgeStyle.rowTitle)
        return text
    }

    private static func rowSub(_ s: Session) -> NSAttributedString {
        TextLine.text(s.sub, EdgeStyle.rowSub, EdgeStyle.ink2)
    }

    private static func idleTitle(_ note: StripNote) -> NSAttributedString {
        TextLine.text(note.idle, EdgeStyle.title, EdgeStyle.ink2, kern: EdgeStyle.tightKern(EdgeStyle.title))
    }

    private static func idleLine2(_ note: StripNote) -> NSAttributedString {
        TextLine.text(note.idleLine2, EdgeStyle.sub, EdgeStyle.ink2)
    }

}
