@testable import SitRep

extension AlertSounds {
    /// macOS's alert sounds by name, as macOS 26 has them, so a test reads none from this Mac; `AlertSoundsTests` holds
    /// this Mac's list to having them all.
    static let macOSNames = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine",
        "Tink",
    ]

    /// macOS's sounds by name, none of them ever played.
    static var silent: AlertSounds {
        AlertSounds(names: macOSNames, play: { _ in })
    }
}
