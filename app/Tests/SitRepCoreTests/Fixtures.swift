import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// An instant as the CLI prints it, in milliseconds since 1970.
func at(_ milliseconds: Double) -> Date {
    Date(timeIntervalSince1970: milliseconds / 1000)
}

/// The first line of `sitrep watch` over an empty board.
let watchedEmpty = WatchLine(at: 1_792_445_580_000).text
