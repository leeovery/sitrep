import SitRepCore

extension Board.Window.Where {
    /// The device, where it is a tty; none for anything else, as core's `parseWhere` drops it.
    var tty: String? {
        isDevice(device) ? device : nil
    }
}

/// Whether a value is a terminal device, `/dev/ttys043`, as core's `isDevice` tells it (`^/dev/tty\w+$`): only a tty,
/// the form Ghostty's terminals give as their `tty`. tmux gives a control-mode client over pipes an empty one.
public func isDevice(_ value: String?) -> Bool {
    let tty = "/dev/tty"

    guard let value, value.hasPrefix(tty) else {
        return false
    }

    let name = value.dropFirst(tty.count)

    return !name.isEmpty && name.allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) }
}
