import Foundation
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// What Lee sets for the edge: the design's defaults, kept as JSON, and read leniently.
@Suite(.backstop)
struct EdgeSettingsTests {
    @Test func theDefaultsAreTheDesigns() {
        let settings = EdgeSettings()

        #expect(settings.show == .notch)
        #expect(settings.edge == .left)
        #expect(settings.along == 0.42)
        #expect(settings.display == nil)
        #expect(settings.style == .meniscus)
        #expect(!settings.reducesMotion)
    }

    @Test func theyRoundTripThroughJSON() throws {
        var settings = EdgeSettings()
        settings.show = .nothing
        settings.edge = .right
        settings.along = 0.7
        settings.display = "37D8832A-2D66-02CA-B9F7-8F30A301B230"
        settings.style = .card
        settings.reducesMotion = true

        let data = try JSONEncoder().encode(settings)

        #expect(try JSONDecoder().decode(EdgeSettings.self, from: data) == settings)
    }

    @Test func nothingSavedReadsAsTheDefaults() throws {
        #expect(try JSONDecoder().decode(EdgeSettings.self, from: Data("{}".utf8)) == EdgeSettings())
    }

    @Test(arguments: ["null", "[]", "7", #""notch""#])
    func aFileThatIsNoObjectReadsAsTheDefaults(_ json: String) throws {
        #expect(try JSONDecoder().decode(EdgeSettings.self, from: Data(json.utf8)) == EdgeSettings())
    }

    @Test func aKeyMissingOrUnreadableKeepsItsDefault() throws {
        let json = #"{"show":"nothing","edge":"top","display":7,"style":"glass","reducesMotion":true}"#

        let read = try JSONDecoder().decode(EdgeSettings.self, from: Data(json.utf8))

        var expected = EdgeSettings()
        expected.show = .nothing
        expected.reducesMotion = true
        #expect(read == expected)
    }

    /// Settings saved while the strip could show read as they stand without it (26 November 2026): a Show of the
    /// strip reads as the notch, and its Length and Max are passed over.
    @Test func theStripSavedReadsAsTheNotch() throws {
        let json = #"{"show":"strip","edge":"right","style":"card","length":"full","maxLength":0.25}"#

        var expected = EdgeSettings()
        expected.edge = .right
        expected.style = .card
        #expect(try JSONDecoder().decode(EdgeSettings.self, from: Data(json.utf8)) == expected)
        #expect(expected.show == .notch)
    }

    /// Settings saved while the edge had a Material read as they stand without it: a Glass saved draws in black.
    @Test(arguments: ["glass", "black"])
    func aMaterialSavedIsPassedOver(material: String) throws {
        let json = #"{"style":"card","material":"\#(material)"}"#

        var expected = EdgeSettings()
        expected.style = .card
        #expect(try JSONDecoder().decode(EdgeSettings.self, from: Data(json.utf8)) == expected)
    }

    @Test(arguments: [("1.5", 1.0), ("-0.2", 0), ("0.6", 0.6), (#""low""#, 0.42)])
    func thePlaceAlongTheEdgeReadsOntoTheScreen(_ json: String, _ along: Double) throws {
        let read = try JSONDecoder().decode(EdgeSettings.self, from: Data(#"{"along":\#(json)}"#.utf8))

        #expect(read.along == along)
    }

    /// A drag lets the notch go: there along the edge, held to the screen, and across the middle on the other edge;
    /// carried nowhere along it, it keeps its place.
    @Test func aDropTakesThePlaceAlongTheEdgeAndAcrossTheMiddleTheOtherEdge() {
        var settings = EdgeSettings()
        settings.along = 0.3

        let moved = { (along: Double?, across: Bool) in
            settings.dropped(along: along, across: across).applied(to: settings)
        }

        #expect(moved(0.6, false).along == 0.6)
        #expect(moved(1.4, false).along == 1)
        #expect(moved(nil, false) == settings)
        #expect(moved(nil, true).edge == .right)
        #expect(moved(nil, true).along == 0.3)
    }

    /// Dropped across, the notch saves where it went only as it swaps edges: what Lee changed meanwhile, Show among
    /// it, stands.
    @Test func aDropLandsOnTheSettingsAsTheyStandWhenItIsSaved() {
        var settings = EdgeSettings()
        settings.along = 0.3

        let move = settings.dropped(along: 0.6, across: true)
        var changed = settings
        changed.show = .nothing
        changed.style = .card
        changed.display = "2"

        var expected = changed
        expected.edge = .right
        expected.along = 0.6
        #expect(move.applied(to: changed) == expected)
    }

    @Test func eachStyleMakesItsNotch() {
        let input = Input(time: 0, pointer: nil, needsLee: false, stage: screen, content: .css)

        #expect(NotchStyle.meniscus.notch(input) is Meniscus)
        #expect(NotchStyle.card.notch(input) is Card)
    }
}
