import SwiftUI

extension ProposedViewSize {
    /// The width proposed, or `fallback` where none is or it is unbounded: what a layout that fills its width takes.
    func width(or fallback: CGFloat) -> CGFloat {
        width.flatMap { $0.isFinite ? $0 : nil } ?? fallback
    }
}
