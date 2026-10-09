/**
 * Ready to send floating over the foot of a docked board's window, as the
 * board's scroll and focus hooks meet it. The engine scrolls the board as
 * it would any tree, so it counts the rows under the box as showing.
 *
 * So a page key moves by the rows above the box, not the whole window, and
 * a button of the board's that the focus lands on comes to the middle of
 * the window, clear of the box. Both read the window as it was last drawn,
 * kept here, since a render hook cannot write `$.state`.
 */
import type { SiteScroll, UiScrollInput } from 'claude-code'
import { isReadyKey } from './draw/ready'
import type { Host } from './host'
import { PANE } from './pane'

/** Where the board's window stood as it was last drawn, and the rows at its foot Ready to send floated over. */
let drawn = { offset: 0, footerRows: 0 }

/** Keeps where the board's window stands as it is drawn, and how many rows at its foot the box floats over: none where it does not float. */
export const drewBoard = ({ offset }: SiteScroll, footerRows: number) => {
  drawn = { offset, footerRows }
}

const isPageKey = (e: UiScrollInput) =>
  e.origin.kind === 'person' && e.pointer === undefined && Math.abs(e.by) === e.bodyRows

/**
 * Where a move takes the board's window: a page key, while the box floats,
 * by the rows showing above it, from where the window was drawn (the
 * engine's `e.offset` is clamped at the end, which loses it); any other
 * move, the wheel's, an arrow's, Home and End, as asked.
 */
export const movedTo = (e: UiScrollInput) =>
  drawn.footerRows > 0 && isPageKey(e)
    ? Math.max(0, drawn.offset + Math.sign(e.by) * (e.bodyRows - drawn.footerRows))
    : e.offset

/**
 * Follows the focus while the box floats. A board button the focus lands on
 * comes to the middle of the window, where the box never reaches; the box's
 * own buttons always show. Then the board is drawn again: the engine moves
 * the window itself to keep the focus in view, unasked, and a reveal that
 * finds the button in the middle by then moves nothing and draws nothing,
 * which would leave the box where the window was.
 */
export const followFocus = async (host: Host, element: string | undefined) => {
  if (drawn.footerRows === 0) {
    return
  }

  if (element !== undefined && !isReadyKey(element)) {
    await host.ui.reveal(PANE, element)
  }

  host.ui.redraw()
}
