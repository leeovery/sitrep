import AppKit
import SitRepPanel

/// A row's arrow in black (board E2; DESIGN, "The row's arrow"), on a panel row: unlit, its chevron soft with no fill
/// of its own; lit, filled, its chevron white; pointing toward where the asks panel opens, away from the screen's edge,
/// and turning to point back while its asks panel is open, over `RowArrow.turning`, or at once under Reduce motion.
@MainActor
final class ArrowButton {
    let box = CALayer()
    let chevron = CAShapeLayer()
    private(set) var look: Look?

    /// How it shows: lit or not, which way it points, whether it is turned, and whether it turns at once, under Reduce
    /// motion.
    struct Look: Equatable {
        var isLit: Bool
        var pointsLeft: Bool
        var isTurned = false
        var turnsAtOnce = false

        /// How far, radians, its chevron is turned.
        var turn: Double { isTurned ? .pi : 0 }
    }

    /// Made in this frame of what it is drawn in, at this pixel density.
    init(in frame: CGRect, scale: CGFloat) {
        still {
            chevron.fillColor = nil
            chevron.lineWidth = AsksPanelParts.strokeWidth
            chevron.lineCap = .round
            chevron.lineJoin = .round
            box.cornerRadius = RowArrow.radius
            box.addSublayer(chevron)
            place(in: frame)
            rescale(box, to: scale)
        }
    }

    /// Placed in this frame, its chevron centred in it.
    func place(in frame: CGRect) {
        box.frame = frame
        chevron.frame = box.bounds
        if let look {
            chevron.path = RowArrow.chevron(pointsLeft: look.pointsLeft, in: frame.size)
        }
    }

    /// Shown as it now looks: lit as it is, pointing as it does, its chevron turning where it turned.
    func show(_ look: Look) {
        let was = self.look

        guard look != was else {
            return
        }

        still {
            box.backgroundColor = look.isLit ? EdgeStyle.arrowLit : nil
            chevron.path = RowArrow.chevron(pointsLeft: look.pointsLeft, in: box.bounds.size)
            chevron.strokeColor = look.isLit ? EdgeStyle.ink : EdgeStyle.ink2
            chevron.setValue(look.turn, forKeyPath: Self.turnKey)
        }
        if let was, was.isTurned != look.isTurned, !look.turnsAtOnce {
            turn(from: was.turn, to: look.turn)
        }
        self.look = look
    }

    /// The chevron turning, a rotation in the render server, from where it shows now, mid-turn or not.
    private func turn(from: Double, to: Double) {
        let turning = CABasicAnimation(keyPath: Self.turnKey)

        turning.fromValue = chevron.presentation()?.value(forKeyPath: Self.turnKey) ?? from
        turning.toValue = to
        turning.duration = RowArrow.turning
        turning.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        chevron.add(turning, forKey: Self.turnKey)
    }

    static let turnKey = "transform.rotation.z"
}
