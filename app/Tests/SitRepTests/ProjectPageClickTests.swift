@testable import SitRep
import SitRepLines
import SitRepWindow
import Testing

/// A row of a project's Sessions, or a line of its Waiting on you, clicked: its session's page pushed over the
/// project's, which Back returns to.
@MainActor
struct ProjectPageClickTests {
    /// Dashboard redesign's row or its stop's line, and Request ledger's row.
    @Test(arguments: ["sr-dash02", "sr-rq7dgr"])
    func aRowClickedPushesItsSessionsPageAndBackReturns(session: String) throws {
        let model = try WindowModel.made()

        model.show(HostedSidebar.heard(Lines.watch[0]))
        model.opened()
        model.actions.click(.project("switchboard"))
        model.actions.openSession(session)
        #expect(model.location == .session(session, from: .project("switchboard")))
        model.actions.back()
        #expect(model.location == .project("switchboard"))
    }
}
