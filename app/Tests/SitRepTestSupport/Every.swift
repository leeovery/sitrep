import Testing

/// Checks that each of the items holds, at the caller: where `#expect(items.allSatisfy { … })` passes on none at all
/// and on a failure names no item, this fails on none, as a check of nothing hides the bug that left it nothing, and
/// names each item that does not hold, by its place.
public func expectEvery<Items: Sequence>(
    _ items: Items, _ comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation,
    _ holds: (Items.Element) throws -> Bool
) rethrows {
    let about = comment.map { " (\($0.rawValue))" } ?? ""
    var count = 0
    var failing: [String] = []

    for item in items {
        if try !holds(item) {
            failing.append("\(count): \(item)")
        }
        count += 1
    }
    if count == 0 {
        Issue.record("There was nothing to check\(about).", sourceLocation: sourceLocation)
    } else if !failing.isEmpty {
        Issue.record(
            "\(failing.count) of \(count) do not hold\(about), by place: \(failing.joined(separator: "; "))",
            sourceLocation: sourceLocation
        )
    }
}
