import CoreGraphics
@testable import SitRepPanel
import Testing

/// The strip's two ends, the board's S under the menu bar and mirrored over the screen's bottom, which never change,
/// and a tab fitting into them (Lee's Fit, at Room 12).
struct StripFitTests {
    @Test func theFirstMarkIsRoomLowerThanTheBoardHasIt() {
        let lab = StripLab()
        #expect(lab.model.layout.places.first!.y == 26 + 28 + 2 + 12 + 12)

        lab.model.settings.room = 0

        #expect(lab.model.layout.places.first!.y == 68)
    }

    @Test func sixteenMarksFitOnTheRecordingsScreenTheLastKeepingRoomClearOfTheBottomEnd() {
        var lab = StripLab()

        lab.model.add(StripLab.asks)
        lab.settle()

        #expect(lab.model.layout.more == nil)
        #expect(lab.model.layout.places.count == 16)
        #expect(lab.model.layout.places.last!.y == 543)
        #expect(lab.model.bottomEnd - lab.model.endPad == 626 - 26 - 28 - 2 - 12 - 12)

        lab.model.add([StripSession(id: "s17", project: "Kit", kind: .working, title: "", sub: "", since: 0)])
        lab.settle()
        #expect(lab.model.layout.more?.y == 543)
    }

    @Test func theEndsStayTheSWhateverTabIsOut() {
        var lab = StripLab()
        let rest = lab.frame.strip

        lab.open("s1")
        #expect(lab.frame.strip == rest)

        lab.model.add(StripLab.tooMany)
        lab.settle()
        lab.pointer = CGPoint(x: 18, y: lab.model.layout.more!.y)
        lab.wait(1000) { $0.live?.phase == .open }
        lab.settle()

        #expect(lab.frame.strip == rest)
    }

    @Test func theBottomEndIsTheTopsSMirrored26OverTheScreensBottom() {
        let lab = StripLab()
        let points = lab.frame.strip.points, menu = 26.0, bottom = 626.0 - 26

        let top = points.filter { $0.y <= menu + StripTuning.topEnd }
        let mirrored = top.map { CGPoint(x: $0.x, y: bottom - ($0.y - menu)) }

        #expect(top.count == 8)
        #expect(mirrored.allSatisfy { p in points.contains { abs($0.x - p.x) < 1e-9 && abs($0.y - p.y) < 1e-9 } })
        #expect(points.allSatisfy { $0.y >= menu && $0.y <= bottom })
    }

    @Test func atFullUnderATallerMenuBarTheBottomEndIsStill26OverTheScreensBottom() {
        let input = StripInput(
            time: 0, pointer: nil, stage: StripStage(width: 1512, height: 982, menu: 37), reducesMotion: false
        )
        let model = Strip(settings: StripLab.full, sessions: StripLab.prototype, measure: StripLab.measure, input)

        let box = model.frame(input).strip.boundingBoxOfPath

        #expect(box.minY == 37 && box.maxY == 982 - 26)
    }

    @Test func theFirstMarksTabMeetsTheSInAFilletLeavingItNoHigherThanWhereItHasTurned70Degrees() {
        var lab = StripLab()

        lab.open("s1")
        let g = lab.model.tabGeometry(lab.live!), fit = lab.model.tabFit(g).top

        #expect(g.yt == 26 + 16 + 12)
        #expect(fit.onS)
        #expect(abs(fit.phi - 70 * .pi / 180) < 1e-8)
        #expect(fit.rho > 2 && fit.rho < 10)
        #expect(abs(fit.y + fit.rho * (1 - cos(fit.phi)) - 28) < 1e-9)
    }

    @Test(arguments: [31.0, 33, 36])
    func whereItFitsTheFilletIsTenOnTheSPastWhereItHasTurned70(_ yr: Double) {
        let fit = StripFit(yr)

        #expect(fit.onS)
        #expect(fit.rho == 10)
        #expect(fit.phi >= 70 * .pi / 180)
        #expect(abs(fit.y + 10 * (1 - cos(fit.phi)) - yr) < 1e-6)
    }

    @Test(arguments: [24.0, 20, 12])
    func tightTheFilletIsNeverUnderTwo(_ yr: Double) {
        #expect(StripFit(yr).rho == 2)
    }

    @Test func lowerThanTheSsEndTheTabLeavesTheStraightEdge() {
        let fit = StripFit(38)

        #expect(!fit.onS)
        #expect(fit.x == 36 && fit.y == 28 && fit.rho == 10 && fit.phi == .pi / 2)
    }

    @Test func theLastMarksTabFitsIntoTheBottomEndAsTheFirstsDoesTheTop() {
        var lab = StripLab()
        lab.model.add(StripLab.asks)
        lab.settle()

        lab.open("s8")
        let g = lab.model.tabGeometry(lab.live!), fit = lab.model.tabFit(g)

        #expect(abs(g.yb - (543 + 26)) < 1e-2)
        #expect(fit.bottom == StripFit(600 - g.yb))
        #expect(fit.bottom.onS && fit.bottom.rho == 10)
        #expect(!fit.top.onS)
    }

    @Test func theCountsTabAtItsTallestFitsIntoBothEndsAlike() {
        var lab = StripLab()
        lab.model.add(StripLab.tooMany)
        lab.settle()

        lab.pointer = CGPoint(x: 18, y: lab.model.layout.more!.y)
        lab.wait(1000) { $0.live?.phase == .open }
        lab.settle()
        let g = lab.model.tabGeometry(lab.live!), fit = lab.model.tabFit(g)

        #expect(g.yt == 26 + 16 + 12 && g.yb == 600 - 16 - 12)
        #expect(fit.top == fit.bottom && fit.top.onS)
    }

    @Test func belowTheBottomEndThePointerIsOffTheStrip() {
        let on = StripLab(pointer: CGPoint(x: 18, y: 600))
        let under = StripLab(pointer: CGPoint(x: 18, y: 601))

        #expect(on.model.over)
        #expect(!under.model.over)
    }

    @Test func changingRoomDrawsAnyTabBackAtOnceAndTheMarksSlideToTheirNewPlaces() {
        var lab = StripLab()
        lab.open("s5")

        lab.model.settings.room = 4

        #expect(lab.model.tabs.isEmpty)
        #expect(lab.model.mark(.session("s5"))!.y.target == 213 - 8)
        lab.pointer = nil
        lab.settle()
        #expect(abs(lab.model.mark(.session("s1"))!.y.x - 72) < 1e-3)
    }
}

extension CGPath {
    /// Every point the path passes through or steers by, in order.
    var points: [CGPoint] {
        var out: [CGPoint] = []
        applyWithBlock { element in
            let e = element.pointee
            let n = switch e.type {
            case .moveToPoint, .addLineToPoint: 1
            case .addQuadCurveToPoint: 2
            case .addCurveToPoint: 3
            default: 0
            }
            out += (0 ..< n).map { e.points[$0] }
        }
        return out
    }
}
