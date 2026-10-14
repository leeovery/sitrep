import ServiceManagement
@testable import SitRepCore
import Testing

struct LoginItemTests {
    @Test func anEnabledLoginItemShowsOnAndChoosingItStopsIt() {
        let login = LoginItem(.enabled)

        #expect(login.isOn)
        #expect(!login.needsApproval)
        #expect(login.choice == .unregister)
        #expect(login.title == "Start at login")
    }

    @Test(arguments: [SMAppService.Status.notRegistered, .notFound])
    func anUnregisteredLoginItemShowsOffAndChoosingItStartsIt(status: SMAppService.Status) {
        let login = LoginItem(status)

        #expect(!login.isOn)
        #expect(!login.needsApproval)
        #expect(login.choice == .register)
        #expect(login.title == "Start at login")
    }

    @Test func aLoginItemAwaitingApprovalSaysSoAndOpensSystemSettings() {
        let login = LoginItem(.requiresApproval)

        #expect(!login.isOn)
        #expect(login.needsApproval)
        #expect(login.choice == .openSettings)
        #expect(login.title == "Start at login (approve in System Settings)")
    }
}
