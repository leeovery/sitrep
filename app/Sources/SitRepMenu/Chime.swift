import SitRepCore

/// The sound a new ask plays (DESIGN, "Settings", Notifications): SitRep's since 27 October 2026, from each window's
/// mod before. It plays whatever shows at the edge, and whether or not banners are on, as they are silent.
public enum Chime {
    /// The sound this board plays, by name, with Lee's settings as they stand: the one he chose, once however many asks
    /// are new on it; none while his switch is off, nor for a board with no new ask.
    public static func due(_ last: LastBoard, _ settings: AppSettings) -> String? {
        settings.playsSound && !last.newAsks.isEmpty ? settings.sound : nil
    }
}
