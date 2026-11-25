import AppKit
import SitRepPanel

/// The edge's colours and type in black, from the prototype's CSS (meniscus.html's `--p-` colours and its row styles).
@MainActor
enum EdgeStyle {
    /// The black: the notch and the panel, as black as the display's bezel they flare into.
    nonisolated static let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let ink = srgb(0xF5F5F7)
    static let ink2 = srgb(0x98989F)
    static let ink3 = srgb(0x5C5C63)
    static let hover = srgb(0x141416)
    /// A row a click is jumping from, pressed in.
    static let press = srgb(0x1C1C20)
    /// A lifted notch's shadow at full lift: the prototype's CSS blur of 12, which Core Animation's radius halves.
    static let liftBlur = 6.0
    static let rule = srgb(0x232327)
    static let track = srgb(0x2C2C31)
    static let shim = srgb(0x9A9AA1)
    /// The strip's (`prototypes/strip/strip.html`'s `--p-` colours beyond the panel's): a working mark's letters, and
    /// its arc.
    static let grey = srgb(0x8E8E95)
    static let arc = srgb(0xC9C9CF)
    /// A row on its own work's verb, from Paper's board D; its subject and its dotted ring are `grey`.
    static let waitingVerb = srgb(0xB4B4BA)
    /// Board D's eyebrows: a section's name, its count where it is not needs you's orange, and its chevron.
    static let eyebrow = white(0.55)
    static let eyebrowCount = white(0.30)
    static let chevron = white(0.25)
    static let orange = color(LiveLight.orange)
    static let blue = color(LiveLight.blue)
    /// A new row's wash, and the ring round it (the prototype's `--wash-bg` and `--wash-ring`).
    static let wash = color(LiveLight.orange, alpha: 0.12)
    static let washRing = color(LiveLight.orange, alpha: 0.26)

    /// A row's title, an ask's among them (board D: every ask's line medium, as Lee approved it).
    static let title = NSFont.systemFont(ofSize: 14, weight: .medium)
    /// Regular at a title's size: in a tab a row on its own work's subject, where it is no command; a wake's countdown
    /// in its tabular figures, so a row can leave room for every reading it will take (`Session.countdownRoom`).
    static let subject = NSFont.systemFont(ofSize: 14, weight: .regular)
    static let countdown = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    static let code = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
    static let sub = NSFont.systemFont(ofSize: 12)
    static let age = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    /// A Needs you row's count, "3", after its session's name, in tabular figures (board F).
    static let count = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    static let headTitle = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let headCount = NSFont.systemFont(ofSize: 12)
    /// An eyebrow's name, and its count in tabular figures.
    static let eyebrowTitle = NSFont.systemFont(ofSize: 11, weight: .semibold)
    static let eyebrowFigures = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    /// A card row's plain words: a your-turn row's, a Working row's subject and a Snoozed row's name (board J), regular
    /// (board D, as Lee approved it).
    static let line = NSFont.systemFont(ofSize: 13, weight: .regular)
    /// A card row's medium words: a Needs you row's name, and a Working row's verb, its command in mono after it, and a
    /// wake's countdown in tabular figures.
    static let lineMedium = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let lineCode = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    static let lineCountdown = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    /// A mark's letters, and a count's rows, needs you's bolder.
    static let letters = NSFont.systemFont(ofSize: 9.5, weight: .semibold)
    /// A mark's letters spaced at 0.01em, as the prototype's.
    static let lettersKern = 0.01 * letters.pointSize
    static let rowTitle = NSFont.systemFont(ofSize: 13, weight: .medium)
    /// A wake's countdown in a count's row, in tabular figures, as `countdown`.
    static let rowCountdown = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
    static let rowSub = NSFont.systemFont(ofSize: 11)

    /// The row's arrow, lit (Paper's board E2).
    static let arrowLit = srgb(0x34343B)
    /// The asks panel's (boards F and H3): its hairline, an answer's row and its border, lifted under the pointer, an
    /// outlined pill's border, a page dot not current, and the words on an answer's row held, white.
    static let asksBorder = white(0.15)
    static let answer = srgb(0x1C1C1F)
    static let answerBorder = srgb(0x34343A)
    static let answerLifted = srgb(0x26262A)
    static let answerLiftedBorder = srgb(0x46464D)
    static let outline = srgb(0x2C2C31)
    /// Claude's pick's row: Claude Code's suggestion lilac, #B1B9F9, the board pane's primary button's, at 20% with its
    /// border at 36%, and under the pointer at 28% and 50%; and its tag, "Recommended", in a lilac of its own.
    static let pick = srgb(0xB1B9F9, alpha: 0x33)
    static let pickBorder = srgb(0xB1B9F9, alpha: 0x5C)
    static let pickLifted = srgb(0xB1B9F9, alpha: 0x47)
    static let pickLiftedBorder = srgb(0xB1B9F9, alpha: 0x80)
    static let pickTag = srgb(0x9AA2EE)
    static let dot = srgb(0x3A3A40)
    static let onWhite = srgb(0x111113)
    /// The asks panel's type: the session's name, the ask's title, an answer's words and its pick's "Recommended",
    /// and the foot's words, medium and regular.
    static let asksName = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let asksTitle = NSFont.systemFont(ofSize: 17, weight: .semibold)
    static let asksLabel = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let asksNote = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let asksFoot = NSFont.systemFont(ofSize: 12, weight: .medium)
    static let asksFootPlain = NSFont.systemFont(ofSize: 12, weight: .regular)
    /// The ask's title spaced at -0.02em.
    static let asksTitleKern = -0.02 * asksTitle.pointSize

    /// What a row in Needs you waits on, as its mark's colour says it: an ask's orange, or Lee's turn's blue.
    static func colour(of need: Need) -> CGColor {
        need == .ask ? orange : blue
    }

    /// A mark asleep in Snoozed: its colour dimmed as an away row's words are, which stands it about as bright on the
    /// black as the faint grey it was until 13 November 2026.
    static func asleep(_ colour: CGColor) -> CGColor {
        colour.copy(alpha: colour.alpha * Away.dim) ?? colour
    }

    /// The prototype's letter-spacing of -0.01em, as a kern in points.
    static func tightKern(_ font: NSFont) -> CGFloat { -0.01 * font.pointSize }

    nonisolated static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    nonisolated static func color(_ rgb: LiveLight.RGB, alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255, alpha: alpha)
    }

    private static func white(_ alpha: Double) -> CGColor {
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha)
    }

    /// A colour as CSS writes it, #RRGGBB, at an alpha out of 255.
    static func srgb(_ hex: UInt32, alpha: UInt32 = 0xFF) -> CGColor {
        CGColor(
            srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: CGFloat(alpha) / 255
        )
    }
}
