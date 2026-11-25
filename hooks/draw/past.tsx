/**
 * A list of the pane's that folds, and the presses that show it: Status's
 * history, PARKED and its picked up, a project's old sessions, and
 * RESOLVED. A list that folds away shows only its press until it is
 * opened (`show history 14`, then `hide history` over it); PARKED and
 * RESOLVED always show. Shown, it lists its latest few, and with more, a
 * press shows every one (`show all 14`, then `show fewer`). Only these
 * presses change what a list shows, kept in the pane per list; opening or
 * closing an item never does, but in PARKED: showing fewer, it shows too
 * the items Lee is acting on past the latest few, so one opened there
 * shows while it is open, and folds away as it closes.
 */
import { LATEST_SHOWN as LATEST, type Listing } from '../../core'
import type { SitrepShowing } from '../../types'
import type { Block, Drawing } from './kit'

/** The words of a list's press that opens it, before its count, and of the one that folds it away. */
export type Folding = { show: string; hide: string }

export type Past<T> = {
  /** The list, as the pane keeps what it shows: `history:<session>`. Its presses are keyed by it. */
  list: string
  /** The newest first, PARKED's in each of its parts: every one, or, for a project's views, the latest they show, with how many there are. */
  listing: Listing<T>
  /** An entry, as a block of its own. */
  draw: (entry: T) => Block
  /** What opens an entry, so a list that stops showing it closes it; none for a list whose entries open nothing. */
  opens?: (entry: T) => string
  /** The presses that open the list and fold it away; none for a list that always shows. */
  folding?: Folding
  /** Whether an entry past the latest few shows while the list shows fewer, Lee acting on it; none for a list that keeps none. */
  keeps?: (entry: T) => boolean
}

/**
 * A press of a list's, dim. Dim rather than a grey Text child: Claude Code
 * 2.1.294 refuses a Button with a label and children, and the refusal
 * blanks the whole board (seen live).
 */
const drawPress = (d: Drawing, key: string, label: string, onPress: () => void): Block => {
  const { Button } = d.els

  return { key, element: <Button key={key} plain dimColor label={label} onPress={onPress} /> }
}

/** A list's blocks: its press alone while it is folded away, none with nothing in it; else its entries, the latest few or every one, between its presses, `show all` only while showing fewer hides any. */
export const drawPast = <T,>(d: Drawing, past: Past<T>): Block[] => {
  const { list, listing, draw, opens, folding, keeps } = past
  const { entries, count } = listing
  const showing = d.scene.pane.shown?.[list]
  const show = (to: SitrepShowing | undefined, hidden: readonly T[]) => () =>
    d.act.show(list, to, opens === undefined ? [] : hidden.map(opens))

  if (count === 0) {
    return []
  }

  if (folding !== undefined && showing === undefined) {
    return [drawPress(d, list, `${folding.show} ${count}`, show('latest', []))]
  }

  const isInFull = showing === 'all'
  const isShownFewer = (entry: T, at: number) => at < LATEST || keeps?.(entry) === true
  const fewerShown = entries.filter(isShownFewer)
  const fewerHides = entries.filter((entry, at) => !isShownFewer(entry, at))
  const hide = folding && drawPress(d, list, folding.hide, show(undefined, entries))
  const fewer = folding === undefined ? undefined : 'latest'
  const all =
    count > fewerShown.length &&
    drawPress(
      d,
      `all:${list}`,
      isInFull ? 'show fewer' : `show all ${count}`,
      isInFull ? show(fewer, fewerHides) : show('all', []),
    )

  return [
    ...(hide ? [hide] : []),
    ...(isInFull ? entries : fewerShown).map(draw),
    ...(all ? [all] : []),
  ]
}
