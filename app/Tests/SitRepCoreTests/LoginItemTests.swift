import ServiceManagement
@testable import SitRepCore
import Testing

struct LoginItemTests {
    @Test func anEnabledLoginItemShowsOnAndChoosingItStopsIt() {
        let login = LoginItem(.enabled)

        #expect(login.isOn)
        #expect(!login.needsApproval)
        #expect(login.choice == .unregister)
        #expect(login.line == nil)
    }

    @Test(arguments: [SMAppService.Status.notRegistered, .notFound])
    func anUnregisteredLoginItemShowsOffAndChoosingItStartsIt(status: SMAppService.Status) {
        let login = LoginItem(status)

        #expect(!login.isOn)
        #expect(!login.needsApproval)
        #expect(login.choice == .register)
        #expect(login.line == nil)
    }

    @Test func aLoginItemAwaitingApprovalSaysSoAndOpensSystemSettings() {
        let login = LoginItem(.requiresApproval)

        #expect(!login.isOn)
        #expect(login.needsApproval)
        #expect(login.choice == .openSettings)
        #expect(login.line == "Waiting for your approval in System Settings")
    }
}
