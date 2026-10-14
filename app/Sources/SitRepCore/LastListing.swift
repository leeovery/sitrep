/// What the menu shows of the works on screen: the last answer `list` gave,
/// kept between openings so the menu opens on it at once while a fresh
/// listing runs. Listings are numbered as they are asked for, so one
/// answering late never replaces a newer one.
public struct LastListing: Sendable {
    /// The last answer kept; nil until anything is listed, while the menu says it is looking.
    public private(set) var answer: ListAnswer?
    private var asked = 0

    public init() {}

    /// A fresh listing is asked for; the number its answer comes back under.
    public mutating func ask() -> Int {
        asked += 1

        return asked
    }

    /// Keeps the answer to the listing numbered when it is the newest asked
    /// for and differs from the one kept; whether it did, and so whether the
    /// menu redraws.
    public mutating func take(_ answer: ListAnswer, for listing: Int) -> Bool {
        guard listing == asked, answer != self.answer else {
            return false
        }

        self.answer = answer

        return true
    }
}
