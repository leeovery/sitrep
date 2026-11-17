/**
 * A list of the board's past at its section's foot, and the presses that
 * show it: Status's history, Parked's picked up, and RESOLVED. A list that
 * folds away shows only its press until it is opened (`show history 14`,
 * then `hide history` over it); RESOLVED always shows. Shown, it lists its
 * latest few, and with more, a press shows every one (`show all 14`, then
 * `show fewer`). Only these presses change what a list shows, kept in the
 * pane per list; opening or closing an item never does.
 */
import type { SitrepShowing } from '../../types'
import type { Block, Drawing } from './kit'

/** How many entries a list shows until it is shown in full. */
const LATEST = 3

/** The words of a list's press that opens it, before its count, and of the one that folds it away. */
export type Folding = { show: string; hide: string }

export type Past<T> = {
  /** The list, as the pane keeps what it shows: `history:<session>`. Its presses are keyed by it. */
  list: string
  /** The newest first. */
  entries: readonly T[]
  /** An entry, as a block of its own. */
  draw: (entry: T) => Block
  /** What opens an entry, so a list that stops showing it closes it. */
  opens: (entry: T) => string
  /** The presses that open the list and fold it away; none for a list that always shows. */
  folding?: Folding
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

/** A list's blocks: its press alone while it is folded away, none with nothing in it; else its entries, the latest or every one, between its presses. */
export const drawPast = <T,>(d: Drawing, past: Past<T>): Block[] => {
  const { list, entries, draw, opens, folding } = past
  const showing = d.scene.pane.shown?.[list]
  const show = (to: SitrepShowing | undefined, hidden: readonly T[]) => () =>
    d.act.show(list, to, hidden.map(opens))

  if (entries.length === 0) {
    return []
  }

  if (folding !== undefined && showing === undefined) {
    return [drawPress(d, list, `${folding.show} ${entries.length}`, show('latest', []))]
  }

  const isInFull = showing === 'all'
  const hide = folding && drawPress(d, list, folding.hide, show(undefined, entries))
  const fewer = folding === undefined ? undefined : 'latest'
  const all =
    entries.length > LATEST &&
    drawPress(
      d,
      `all:${list}`,
      isInFull ? 'show fewer' : `show all ${entries.length}`,
      isInFull ? show(fewer, entries.slice(LATEST)) : show('all', []),
    )

  return [
    ...(hide ? [hide] : []),
    ...(isInFull ? entries : entries.slice(0, LATEST)).map(draw),
    ...(all ? [all] : []),
  ]
}
