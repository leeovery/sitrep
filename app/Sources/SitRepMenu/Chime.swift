import SitRepCore

/// The sound a new ask plays, or Lee's turn (DESIGN, "Settings", Notifications): SitRep's since 27 October 2026, from
/// each window's mod before. It plays whatever shows at the edge, and whether or not banners are on, as they are
/// silent.
public enum Chime {
    /// The sound this board plays, by name, with Lee's settings as they stand: a new ask's, once however many are new
    /// on it, while his switch for it is on; else his turn's, once however many sessions moved into it, while its
    /// switch is on; else none. A board bringing both plays one sound, a new ask's.
    public static func due(_ last: LastBoard, _ settings: AppSettings) -> String? {
        if settings.playsSound, !last.newAsks.isEmpty {
            return settings.sound
        }

        return settings.playsTurnSound && !last.newTurnRows.isEmpty ? settings.turnSound : nil
    }
}
