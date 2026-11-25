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
        #expect(settings.length == .grows)
        #expect(settings.maxLength == .full)
        #expect(!settings.reducesMotion)
    }

    @Test func theyRoundTripThroughJSON() throws {
        var settings = EdgeSettings()
        settings.show = .strip
        settings.edge = .right
        settings.along = 0.7
        settings.display = "37D8832A-2D66-02CA-B9F7-8F30A301B230"
        settings.style = .card
        settings.length = .full
        settings.maxLength = StripMax(share: 0.25)
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
        let json = #"{"show":"strip","edge":"top","display":7,"maxLength":"lots","reducesMotion":true}"#

        let read = try JSONDecoder().decode(EdgeSettings.self, from: Data(json.utf8))

        var expected = EdgeSettings()
        expected.show = .strip
        expected.reducesMotion = true
        #expect(read == expected)
    }

    /// Settings saved while the edge had a Material read as they stand without it: a Glass saved draws in black.
    @Test(arguments: ["glass", "black"])
    func aMaterialSavedIsPassedOver(material: String) throws {
        let json = #"{"style":"card","material":"\#(material)"}"#

        var expected = EdgeSettings()
        expected.style = .card
        #expect(try JSONDecoder().decode(EdgeSettings.self, from: Data(json.utf8)) == expected)
    }

    /// Max is kept as how far along its slider it is, never in marks.
    @Test func maxIsKeptAsItsShareOfTheSlider() throws {
        var settings = EdgeSettings()
        settings.maxLength = StripMax(share: 0.25)

        let json = try String(decoding: JSONEncoder().encode(settings), as: UTF8.self)

        #expect(json.contains(#""maxLength":0.25"#))
    }

    @Test(arguments: [("3", 1.0), ("-1", 0), ("0.5", 0.5)])
    func maxReadsOntoItsSlider(_ json: String, _ share: Double) throws {
        let read = try JSONDecoder().decode(EdgeSettings.self, from: Data(#"{"maxLength":\#(json)}"#.utf8))

        #expect(read.maxLength.share == share)
    }

    @Test(arguments: [("1.5", 1.0), ("-0.2", 0), ("0.6", 0.6), (#""low""#, 0.42)])
    func thePlaceAlongTheEdgeReadsOntoTheScreen(_ json: String, _ along: Double) throws {
        let read = try JSONDecoder().decode(EdgeSettings.self, from: Data(#"{"along":\#(json)}"#.utf8))

        #expect(read.along == along)
    }

    /// A drag lets the notch or the strip go: there along the edge, held to the screen, and across the middle on the
    /// other edge; a strip at Full, carried nowhere along it, keeps its place.
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

    /// Dropped across, the strip saves where it went only as it swaps edges: what Lee changed meanwhile, Show among
    /// it, stands.
    @Test func aDropLandsOnTheSettingsAsTheyStandWhenItIsSaved() {
        var settings = EdgeSettings()
        settings.show = .strip
        settings.along = 0.3

        let move = settings.dropped(along: 0.6, across: true)
        var changed = settings
        changed.show = .notch
        changed.length = .full
        changed.maxLength = StripMax(share: 0.5)
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

/// Max on the strip: from five marks' length to Full, which leaves the strip all its full height holds.
@Suite(.backstop)
struct StripMaxTests {
    @Test func fullLeavesWhatFits() {
        #expect(StripMax.full.isFull)
        #expect(StripMax.full.places(longest: 16) == nil)
    }

    @Test(arguments: [(0.0, 5), (0.1, 6), (0.5, 11), (0.99, 16)])
    func alongTheSliderItRunsFromFivePlacesToTheFullStrips(_ share: Double, _ places: Int) {
        #expect(StripMax(share: share).places(longest: 16) == places)
    }

    @Test func aScreenTooShortForMoreLeavesWhatFits() {
        #expect(StripMax(share: 0.5).places(longest: 5) == 5)
        #expect(StripMax(share: 0.5).places(longest: 3) == 3)
    }
}
