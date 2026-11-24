import SitRepEdge
import SitRepPanel

extension NotchRun.Setting {
    /// What the notch runs in on this screen edge, as Lee set it: the edge's stage and mirror, his style, motion as he
    /// and the Mac set it, whether he chose the notch to show the board, and whether its material draws the rows'
    /// arrows and the asks panel, which black alone does yet. The real notch's and the welcome stage's alike.
    @MainActor
    static func on(_ edge: ScreenEdge, _ settings: EdgeSettings) -> Self {
        Self(
            stage: edge.stage, mirror: edge.mirror, style: settings.style,
            reducesMotion: Displays.reducesMotion(settings), isChosen: settings.show == .notch,
            answers: NotchSurface.drawn(settings.material) == .black
        )
    }
}

extension StripRun.Setting {
    /// What the strip runs in on this screen edge, as Lee set it: the edge's stage, and motion as he and the Mac set
    /// it. The real strip's and the welcome stage's alike.
    @MainActor
    static func on(_ edge: ScreenEdge, _ settings: EdgeSettings) -> Self {
        Self(stage: edge.stripStage, reducesMotion: Displays.reducesMotion(settings))
    }
}

extension NotchRun {
    /// Whether its light, lit, changes from moment to moment at this time (`LiveLight.moves`): what the real notch and
    /// the welcome stage refresh it for.
    func lightMoves(at time: Double, reducesMotion: Bool) -> Bool {
        frame.light.level > 0.001 && LiveLight.moves(sinceAsk: sinceAsk(at: time), reducesMotion: reducesMotion)
    }
}
