import Foundation
import SitRepCore

/// Something parked, and opened, where it was parked from.
public struct Parked: Equatable, Sendable, Identifiable {
    public let id: String
    public let session: String?
    public let title: String
    public let `where`: String?
    public let at: Date

    /// It opens to more than its line: where it was parked from. Without, it opens only while its line is cut short.
    public var hasMore: Bool { `where` != nil }
}

extension Parked {
    /// A session's parked items on its own page, as its board last kept them, each by its own id.
    static func items(of board: SessionBoard) -> [Parked] {
        board.parked.map { Parked($0, id: $0.id, session: nil) }
    }

    /// A session's parked items in its project's view, as its board last kept them, each by its session's id and its
    /// own, so two sessions' items never share one. In a view of several sessions each names its session.
    static func items(of board: SessionBoard, from session: Board.Session, named: Bool) -> [Parked] {
        board.parked.map { Parked($0, id: "\(session.id):\($0.id)", session: named ? session.name : nil) }
    }

    private init(_ item: SessionBoard.Parked, id: String, session: String?) {
        self.init(id: id, session: session, title: item.title, where: item.where, at: item.at)
    }
}
