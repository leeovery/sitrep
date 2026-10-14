@testable import SitRepCore
import Testing

struct ListingTests {
    @Test func theWorksOnScreenComeInTheListingsOrderEachWithItsProject() throws {
        #expect(try Listing.read(listed).onScreen == [
            OnScreen(id: "sr-047c7y", project: "Fumi", name: "Management window discussion"),
            OnScreen(id: "sr-sa13jv", project: "Fumi", name: "Commercialization discussion"),
            OnScreen(id: "sr-y4d0qj", project: "Switchboard", name: "Milestone 7 stages 4 to 14"),
        ])
    }

    @Test func anEmptyBoardHasNothingOnScreen() throws {
        #expect(try Listing.read(listedEmpty).onScreen == [])
    }

    @Test func aWorkIsLabelledWithItsProjectThenItsName() {
        #expect(OnScreen(id: "sr-047c7y", project: "Fumi", name: "Library tags").label == "Fumi · Library tags")
    }

    @Test func anotherVersionIsNamedAsSuchWhateverItsShape() {
        #expect(throws: Listing.Unread.version(2)) { try Listing.read(#"{"v": 2, "boards": {}}"#) }
    }

    @Test(arguments: ["", "not json", #"{"projects": []}"#, #"{"v": 1, "projects": [{"name": "Fumi"}]}"#])
    func outputThatIsNotAListingIsUnread(json: String) {
        #expect(throws: Listing.Unread.shape) { try Listing.read(json) }
    }
}
