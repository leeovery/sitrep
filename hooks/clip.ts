/**
 * The docked board's list, clipped between its header and Ready to send
 * (DESIGN.md, "One engine, two front ends"). The board's tree is a row
 * shorter than its window, so the engine never has anything to scroll; the
 * list sits in the rows between the two, shifted up by how far down it
 * stands, which the board's own scroll and focus hooks move and `$.state`
 * keeps for the place the board looks at. Every way to a place puts it at
 * the top there. Nothing else moves it: a list that has shrunk under it
 * only stops it short.
 *
 * Each block of the list is measured by a `Client` spanning it: the list is
 * as tall as its blocks, and a block sits as far down as those above it.
 * Both hooks read the list as last drawn, kept here, since a render hook
 * cannot write `$.state`; and the rows each block was measured at, which
 * the `Client`s post again after a reload.
 */
import type { UiFocusInput, UiScrollInput } from 'claude-code'
import type { SitrepPlace, SitrepScroll } from '../types'
import type { Block } from './draw/kit'
import { logFailure, type Host } from './host'
import { samePlace } from './places'

/** The docked board's list as drawn: where the board looks, how many of the list's rows show, and its blocks in order. */
export type ClipList = { place: SitrepPlace; listRows: number; blocks: readonly Block[] }

/** The window over the docked board's list for one drawing: given the list, its first row showing. */
export type Clip = (list: ClipList) => number

/** The list as last drawn; none while the board does not clip it. */
let drawn: ClipList | undefined

/** The rows each block drawn was measured at, by its key. */
const measured = new Map<string, number>()

/** The rows a block takes: as measured, or until it is, the one row it takes at least. */
const rowsOf = ({ key }: Block) => measured.get(key) ?? 1

const sumRows = (blocks: readonly Block[]) => blocks.reduce((sum, block) => sum + rowsOf(block), 0)

/** The furthest down the list goes: its last row at the foot of those showing. */
const furthest = ({ blocks, listRows }: ClipList) => Math.max(0, sumRows(blocks) - listRows)

const clampTop = (top: number, end: number) => Math.max(0, Math.min(top, end))

/** How far down the list stands at a place: as it was moved there, else at its top. */
const keptAt = (kept: SitrepScroll | null, place: SitrepPlace) =>
  kept !== null && samePlace(kept.place, place) ? kept.top : 0

/** Forgets the rows of blocks no longer drawn: their `Client`s are gone, and new ones measure them again. */
const keepOnly = (blocks: readonly Block[]) => {
  const keys = new Set(blocks.map(block => block.key))

  for (const key of measured.keys()) {
    if (!keys.has(key)) {
      measured.delete(key)
    }
  }
}

/**
 * The clip for one drawing of the board, from how far down its list was
 * kept: the list it is given is recorded for the scroll and focus hooks,
 * and starts as kept, stopped short at its end. A drawing that clips no
 * list (inline, or with no session) leaves the engine's moves to the engine.
 */
export const clipOf = (kept: SitrepScroll | null): Clip => {
  drawn = undefined

  return list => {
    drawn = list
    keepOnly(list.blocks)

    return clampTop(keptAt(kept, list.place), furthest(list))
  }
}

/**
 * Puts the board at the top of the place it goes to, wherever it was there
 * before: docked, its own list; where the engine scrolls the board (inline,
 * or a dock nothing measures), the engine's window.
 */
export const fromTheTop = async (host: Host) => {
  await host.state.scroll.write(null)

  if (drawn === undefined) {
    await host.ui.toTop().catch(logFailure(host, 'putting the board at its top'))
  }
}

/** Keeps the rows a block's `Client` posted, and draws the board again for them once they change. */
export const heardRows = (host: Host, data: unknown) => {
  const { id, rows } = (data ?? {}) as { id?: unknown; rows?: unknown }

  if (typeof id !== 'string' || typeof rows !== 'number' || measured.get(id) === rows) {
    return
  }

  measured.set(id, rows)
  host.ui.redraw()
}

/**
 * How far a move takes the list: the wheel as it turns, a page key by the
 * rows showing, Home and End to an end, and anything else as asked. Under a
 * tree a row shorter than the window, a page (the window's rows) and Home
 * or End (the tree's) are told apart.
 */
export const stepOf = (e: UiScrollInput, listRows: number) => {
  if (e.pointer !== undefined) {
    return e.by
  }

  if (Math.abs(e.by) === e.bodyRows) {
    return Math.sign(e.by) * listRows
  }

  return Math.abs(e.by) === e.contentRows ? Math.sign(e.by) * Infinity : e.by
}

/** Where the list stands to show rows `from` to `to` whole from `top`, moving the least; rows more than show, from their first. */
export const topShowing = (from: number, to: number, top: number, listRows: number) =>
  from < top || to - from > listRows ? from : Math.max(top, to - listRows)

/** Moves the list where the board clips it, as `move` takes it from where it stands, stopped at either end. */
const moveList = (host: Host, list: ClipList, move: (top: number, end: number) => number) => {
  const end = furthest(list)

  return host.state.scroll.update(kept => ({
    place: list.place,
    top: clampTop(move(clampTop(keptAt(kept, list.place), end), end), end),
  }))
}

/** Moves the list as the board's window is asked to move; whether the board clips it, its window then held at the top. */
export const scrollList = async (host: Host, e: UiScrollInput) => {
  const list = drawn

  if (list === undefined) {
    return false
  }

  await moveList(host, list, top => top + stepOf(e, list.listRows))

  return true
}

/** An element of a drawing, as far as finding a button in it goes. */
type Drawn = { type?: unknown; props?: { key?: unknown }; children?: unknown }

/** Whether a drawing holds the button keyed `key`. */
const holds = (node: unknown, key: string): boolean => {
  if (Array.isArray(node)) {
    return node.some(child => holds(child, key))
  }

  if (typeof node !== 'object' || node === null) {
    return false
  }

  const { type, props, children } = node as Drawn

  return (type === 'Button' && props?.key === key) || holds(children, key)
}

/**
 * Brings the block holding the button Lee's focus lands on (by Tab,
 * Shift-Tab or an arrow) into view, moving the list the least; a block
 * taller than the rows showing, from its top. A button no block holds is
 * the header's or Ready to send's, which always show. A plugin's move of
 * the focus never moves the list, and nor does a click: the engine raises
 * it as a press, the focus left where it was (live, 2.1.295).
 */
export const revealFocus = async (
  host: Host,
  { element, origin }: Pick<UiFocusInput, 'element' | 'origin'>,
) => {
  const list = drawn
  const at =
    list === undefined || element === undefined || origin.kind !== 'person'
      ? -1
      : list.blocks.findIndex(block => holds(block.element, element))

  if (list === undefined || at < 0) {
    return
  }

  const from = sumRows(list.blocks.slice(0, at))
  const to = sumRows(list.blocks.slice(0, at + 1))

  await moveList(host, list, top => topShowing(from, to, top, list.listRows))
}
