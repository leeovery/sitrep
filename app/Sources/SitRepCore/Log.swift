import os

extension Logger {
    /// SitRep's own log, for a live debug: `log show --predicate 'subsystem == "com.leeovery.sitrep"'`.
    public init(sitrep category: String) {
        self.init(subsystem: "com.leeovery.sitrep", category: category)
    }
}
