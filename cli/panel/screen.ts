/**
 * What the panel writes to own the terminal's screen, and to give it back,
 * and the writes that turn one frame into the next.
 *
 * - Entering: the alternate screen, the cursor hidden, autowrap off, so a
 *   line written to the last column never scrolls the screen, and mouse
 *   reporting on in SGR's form, buttons only, never motion.
 * - Leaving undoes each, in the other order.
 * - A frame rewrites only the rows that changed, each whole from its first
 *   column and cleared to its end, since a drawn line leaves off its
 *   trailing blank cells; all of them, the screen cleared first, where what
 *   the screen shows isn't known, as after a resize. It goes in
 *   synchronized output, so a terminal that holds it shows it at once.
 */

const CSI = '\x1b['

export const ENTER = `${CSI}?1049h${CSI}?25l${CSI}?7l${CSI}?1000h${CSI}?1006h`

export const LEAVE = `${CSI}?1006l${CSI}?1000l${CSI}?7h${CSI}?25h${CSI}?1049l`

const SYNC = { from: `${CSI}?2026h`, to: `${CSI}?2026l` }

const CLEAR = `${CSI}2J`

/** The row `y`, counted from 0, written over from its first column and cleared to its end. */
const rowAt = (y: number, line: string) => `${CSI}${y + 1};1H${line}${CSI}K`

/**
 * The writes that turn the screen from showing `shown` to `lines`, a line a
 * row as `ansi` writes it: nothing where no row changed. Given nothing
 * shown, as the screen holds what isn't known, it is cleared first.
 */
export const repaint = (shown: readonly string[] | undefined, lines: readonly string[]): string => {
  const was = shown ?? []
  const rows = lines.flatMap((line, y) => (line === (was[y] ?? '') ? [] : [rowAt(y, line)]))

  if (shown !== undefined && rows.length === 0) {
    return ''
  }

  return `${SYNC.from}${shown === undefined ? CLEAR : ''}${rows.join('')}${SYNC.to}`
}
