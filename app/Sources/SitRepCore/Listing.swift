import Foundation

/// A piece of work a Ghostty window shows, which a jump can reach.
public struct OnScreen: Sendable, Equatable, Identifiable {
    public let id: String
    public let project: String
    public let name: String

    public init(id: String, project: String, name: String) {
        self.id = id
        self.project = project
        self.name = name
    }

    /// How the menu names it: its project, then its own name.
    public var label: String { "\(project) · \(name)" }
}

/// What `sitrep list --json` prints, as far as the app reads it: the projects, each with its works.
struct Listing: Decodable {
    /// The output's version this app reads; it moves only with a change a reader would trip on.
    static let version = 1

    struct Project: Decodable {
        let name: String
        let works: [Work]
    }

    struct Work: Decodable {
        let id: String
        let name: String
        let onScreen: Bool
    }

    /// Read first, so output of another version is named as such, whatever its shape.
    private struct Versioned: Decodable {
        let v: Int
    }

    let projects: [Project]

    /// The works on screen, in the order the listing gives them.
    var onScreen: [OnScreen] {
        projects.flatMap { project in
            project.works.filter(\.onScreen).map { OnScreen(id: $0.id, project: project.name, name: $0.name) }
        }
    }

    enum Unread: Error, Equatable, CustomStringConvertible {
        case version(Int)
        case shape

        var description: String {
            switch self {
            case let .version(given):
                "gave output version \(given), and this SitRep reads version \(Listing.version)"
            case .shape:
                "gave output this SitRep cannot read"
            }
        }
    }

    /// The listing in the JSON given; throws `Unread` when it is not one this app reads.
    static func read(_ json: String) throws(Unread) -> Listing {
        let data = Data(json.utf8)

        guard let given = try? JSONDecoder().decode(Versioned.self, from: data) else {
            throw .shape
        }

        guard given.v == version else {
            throw .version(given.v)
        }

        guard let listing = try? JSONDecoder().decode(Listing.self, from: data) else {
            throw .shape
        }

        return listing
    }
}
