@testable import SitRepCore
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct SaidTests {
    @Test func theCLIsOwnLastLineIsGivenWithoutItsPrefix() {
        #expect(Said("sitrep: first\nsitrep: what ended it\n").reason == "what ended it")
    }

    @Test(arguments: [
        "",
        " \n\n",
        "Bun v1.4.2 (macOS arm64)\n",
        "      at f (/Users/me/Code/sitrep/cli/watch.ts:2:13)\n",
        "2 |   throw new TypeError(\"boom\")\n                ^\n",
    ])
    func noiseIsNeverAReason(stderr: String) {
        #expect(Said(stderr).reason == nil)
    }

    @Test func aLineOfAnyOtherKindIsAReason() {
        #expect(Said("env: bun: No such file or directory\n").reason == "env: bun: No such file or directory")
    }
}
