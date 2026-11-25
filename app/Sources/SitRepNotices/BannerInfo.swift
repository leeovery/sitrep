import SitRepRelay

/// What a banner carries in its userInfo, read back from macOS: the session a click on it jumps to, and the new ask it
/// tells of, by which its banners are taken down.
enum BannerInfo {
    private static let workKey = "work"

    static func of(_ notice: Notice) -> [String: String] {
        (notice.ask?.fields ?? [:]).merging(notice.work.map { [workKey: $0] } ?? [:]) { _, work in work }
    }

    /// The session a banner's click jumps to, if it names one.
    static func work(_ userInfo: [AnyHashable: Any]) -> String? {
        userInfo[workKey] as? String
    }

    /// The new ask a banner tells of, if any.
    static func ask(_ userInfo: [AnyHashable: Any]) -> NoticeAsk? {
        (userInfo as? [String: String]).flatMap(NoticeAsk.init(fields:))
    }
}
