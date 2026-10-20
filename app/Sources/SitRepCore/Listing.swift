import Foundation

/// A piece of work a jump can reach: a terminal window shows it, or tmux can make one show it.
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
struct Listing: Versioned {
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

    let projects: [Project]

    /// The works on screen, in the order the listing gives them.
    var onScreen: [OnScreen] {
        projects.flatMap { project in
            project.works.filter(\.onScreen).map { OnScreen(id: $0.id, project: project.name, name: $0.name) }
        }
    }
}
