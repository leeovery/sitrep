/// A banner's words, and the work clicking it jumps to, if any.
public struct Banner: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let body: String
    public let work: String?

    /// The test banner: it names the first work on screen, and jumps to it.
    public static func test(_ listed: ListAnswer) -> Banner {
        switch listed {
        case let .works(works):
            guard let first = works.first else {
                return Banner(title: "SitRep", subtitle: nil, body: "A test banner. No work is on screen, so it jumps nowhere.", work: nil)
            }

            return Banner(title: first.name, subtitle: first.project, body: "A test banner. Click it to jump to this work.", work: first.id)
        case let .failed(why):
            return Banner(title: "SitRep", subtitle: nil, body: "A test banner, with no work to jump to: \(why)", work: nil)
        }
    }

    /// A jump that failed, in the CLI's words.
    public static func unjumped(_ why: String) -> Banner {
        refused("SitRep could not jump", why)
    }

    /// Something Lee chose that macOS refused, in its words.
    public static func refused(_ what: String, _ why: String) -> Banner {
        Banner(title: what, subtitle: nil, body: why, work: nil)
    }
}
