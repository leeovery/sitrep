import AppKit

/// macOS's alert sounds, Basso … Tink, by name: the ones a new ask can play (DESIGN, "Settings", Notifications), each
/// played as an ordinary sound, at the output volume. Never as a notification's or as an alert sound, which follow
/// the alert volume, 0 on Lee's Mac.
@MainActor
struct AlertSounds {
    /// Their names, as Settings' pop-up lists them.
    let names: [String]
    let play: (String) -> Void

    /// The sounds macOS keeps, played through `NSSound`.
    static var live: AlertSounds {
        AlertSounds(names: names(in: URL(filePath: "/System/Library/Sounds")), play: playFromTheStart)
    }

    /// The sound files in a folder by name, in Finder's order.
    static func names(in folder: URL) -> [String] {
        let files = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )

        return (files ?? []).map { $0.deletingPathExtension().lastPathComponent }.sorted(using: .localizedStandard)
    }

    /// `NSSound(named:)` gives back the one sound for a name, which a play while it sounds would leave unheard.
    private static func playFromTheStart(_ name: String) {
        guard let sound = NSSound(named: name) else {
            return
        }

        sound.stop()
        sound.play()
    }
}
