import CoreGraphics
@testable import SitRepPanel
import Testing

/// The other edge's ghost during a drag, as the prototypes draw it: the notch at rest in the panel's black at 0.3,
/// in over 140ms past the screen's middle, out over 200 back, and over 420 as the notch lands there.
struct DragGhostTests {
    /// The ghost after this many ms, a frame at a time.
    private static func stepped(_ ghost: DragGhost, _ ms: Double) -> DragGhost {
        var ghost = ghost
        for _ in 0 ..< Int(ms / 4) {
            ghost.step(4)
        }
        return ghost
    }

    private static let shown: DragGhost = {
        var ghost = DragGhost()
        ghost.carried(across: true)
        return stepped(ghost, 1000)
    }()

    @Test func thereIsNoneUntilTheDragGoesAcross() {
        var ghost = DragGhost()
        ghost.carried(across: false)

        #expect(Self.stepped(ghost, 500).opacity == 0)
        #expect(!ghost.isMoving)
    }

    @Test func acrossTheMiddleItComesInOver140ToThePanelsBlackAt03() {
        var ghost = DragGhost()
        ghost.carried(across: true)

        #expect(ghost.isMoving)
        #expect(abs(Self.stepped(ghost, 140).opacity - 0.3 * 0.95) < 0.006)
        #expect(abs(Self.shown.opacity - 0.3) < 1e-3)
    }

    @Test func backItGoesOver200() {
        var ghost = Self.shown
        ghost.carried(across: false)

        #expect(abs(Self.stepped(ghost, 200).opacity - 0.3 * 0.05) < 0.006)
    }

    @Test func letGoItFadesOver420() {
        var ghost = Self.shown
        ghost.dropped()

        #expect(Self.stepped(ghost, 200).opacity > 0.1)
        #expect(abs(Self.stepped(ghost, 420).opacity - 0.3 * 0.05) < 0.006)
        #expect(!Self.stepped(ghost, 2000).isMoving)
    }

    @Test func itIsTheNotchAtRestWhereTheDragHasIt() {
        let lab = Lab(), card = CardLab()

        #expect(lab.model.restingOutline(at: 300).boundingBox.midY == 300)
        #expect(card.model.restingOutline(at: 300).boundingBox.midY == 300)
        #expect(abs(lab.model.restingOutline(at: 300).boundingBox.height - 76) < 0.5)
        #expect(abs(card.model.restingOutline(at: 300).boundingBox.height - 76) < 0.5)
    }

    @Test func itsNotchStaysInsideTheBand() {
        let lab = Lab()

        #expect(lab.model.restingOutline(at: 0).boundingBox.minY >= screen.bandTop - 0.5)
    }
}
