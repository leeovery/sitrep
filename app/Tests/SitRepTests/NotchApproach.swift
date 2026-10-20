import CoreGraphics
import SitRepPanel

/// A notch's frames as the pointer comes in from the screen, eases onto the notch and holds there until the panel is
/// out and settled: the notch at rest, reaching for the pointer, the panel pouring and the panel out.
enum NotchApproach {
    enum Style: CaseIterable {
        case meniscus, card

        func make(_ input: Input) -> any Notch {
            switch self {
            case .meniscus: Meniscus(input)
            case .card: Card(input)
            }
        }
    }

    static func frames(
        _ style: Style, needsLee: Bool, on stage: Stage, content: Content, reducesMotion: Bool = false
    ) -> [Frame] {
        let input = { (time: Double, pointer: CGPoint?) in
            Input(
                time: time, pointer: pointer, needsLee: needsLee, stage: stage, content: content,
                reducesMotion: reducesMotion
            )
        }
        let notch = style.make(input(0, nil))
        var frames = [notch.frame(input(0, nil))], time = 0.0

        while time < 3000, notch.phase != .open || frames.last?.isMoving == true {
            time += 1000 / 60
            frames.append(notch.frame(input(time, CGPoint(x: max(3, 120 - time / 4), y: notch.notchY))))
        }
        return frames
    }
}
