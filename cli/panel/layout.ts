/**
 * Where a frame's parts go at a size, with no pens and no text drawn: the
 * one copy of the fit rules, for drawing (draw.ts) and for the keys, which
 * keep the band's row in sight, page by a body's height, and find the row a
 * tap lands on.
 *
 * - Row 0 is the title, the last row the key line; both always stay.
 * - A pick's answer sits above the key line, a blank row over it, in at most
 *   the rows between the title and the key line, less that blank row; past
 *   them its last line is cut with `…`.
 * - The body runs from row 2, or row 1 below 15 rows, to the answer's blank
 *   row or the key line. Its blank rows between sections give way when the
 *   body is short of rows below 15.
 * - It shows the rows that fit, in whole rows, from `top`: the rows scrolled
 *   past, said by `▲ N more` under their section's heading, kept at the top,
 *   given room for both and a row. `▼ N more` says the rows below, its row
 *   kept free while any block is left after.
 * - `top` goes no further than the greatest that still fills the body.
 */
import { fitted, wrap, type Size } from './cells'
import { rowKey, type PanelRow, type PanelView } from './view'

/** The left margin's width: every line starts here. */
export const LEFT = 1

/** The widest the layout grows. */
const MOST = 120

/** The least a frame is laid out at; below it, `Too small`. */
const LEAST: Size = { width: 24, height: 8 }

/** Below this many rows, the blank rows give way. */
const ROOMY = 15

export type Section = PanelView['sections'][number]

/** What the body shows, each at its terminal row: a heading, a row's two lines, or `▲`/`▼` and the rows they count. */
export type Placed =
  | { kind: 'heading'; y: number; section: Section }
  | { kind: 'row'; y: number; row: PanelRow; key: string }
  | { kind: 'above' | 'below'; y: number; count: number }

/** Rows of the terminal, from `from` up to `to`, exclusive. */
export type Region = { from: number; to: number }

export type Layout = {
  /** The layout's width: the terminal's, up to 120. */
  width: number
  height: number
  /** The sections that hold rows: the others draw nothing. */
  sections: Section[]
  /** The answer's lines, fitted, from its first row. */
  answer: { from: number; lines: string[] }
  /** The body's rows. */
  body: Region
  /** The rows under the title the body's place holds, where words stand centred in it. */
  words: Region
  /** The view's `top`, kept within `lastTop`. */
  top: number
  /** The greatest `top` that still fills the body: past it, the body would show blank rows. */
  lastTop: number
  placed: Placed[]
  /** Each row in view by its key, at the terminal row of its first line. */
  rows: { key: string; y: number }[]
}

/** One of the body's pieces, in its order: a blank row between sections, a heading, or a row. */
type Block = { kind: 'gap' } | { kind: 'heading'; section: Section } | { kind: 'row'; row: PanelRow; section: Section }

const HEIGHT: Record<Block['kind'], number> = { gap: 1, heading: 1, row: 2 }

/** A pinned heading and `▲`, and a row under them. */
const PINNED_ROWS = 2
const PINNED_ROOM = PINNED_ROWS + HEIGHT.row

const heightOf = (blocks: readonly Block[]) => blocks.reduce((sum, block) => sum + HEIGHT[block.kind], 0)

const blocksOf = (sections: readonly Section[], hasGaps: boolean): Block[] =>
  sections.flatMap((section, at): Block[] => [
    ...(at > 0 && hasGaps ? [{ kind: 'gap' } as const] : []),
    { kind: 'heading', section },
    ...(section.isOpen ? section.rows.map(row => ({ kind: 'row', row, section }) as const) : []),
  ])

const rowsIn = (blocks: readonly Block[]) => blocks.filter(block => block.kind === 'row').length

export const isTooSmall = (size: Size) => size.width < LEAST.width || size.height < LEAST.height

/** The body's view from `top`: where it starts, whether its heading is pinned, and the index after the last block that fits. */
type Window = { start: number; isPinned: boolean; end: number }

/** The blocks from `start` that fit in `room` rows with `used` taken, a row kept for `▼` while any are left after; gives the index after the last. */
const endOf = (blocks: readonly Block[], start: number, used: number, room: number) => {
  let end = start
  let taken = used

  while (end < blocks.length) {
    const block = blocks[end] as Block
    const below = end + 1 < blocks.length ? 1 : 0

    if (taken + HEIGHT[block.kind] + below > room) {
      break
    }

    taken += HEIGHT[block.kind]
    end++
  }

  return end
}

const windowOf = (blocks: readonly Block[], top: number, room: number): Window => {
  const first = blocks.filter(block => block.kind === 'row')[top]
  const start = top === 0 || first === undefined ? 0 : blocks.indexOf(first)
  const isPinned = start > 0 && room >= PINNED_ROOM

  return { start, isPinned, end: endOf(blocks, start, isPinned ? PINNED_ROWS : 0, room) }
}

/** The least `top` from which the body shows the last block: any greater leaves blank rows. */
const lastTopOf = (blocks: readonly Block[], room: number) => {
  const rows = rowsIn(blocks)
  const fills = Array.from({ length: rows }, (_, top) => top).find(
    top => windowOf(blocks, top, room).end === blocks.length,
  )

  return fills ?? Math.max(rows - 1, 0)
}

const placedIn = (blocks: readonly Block[], window: Window, top: number, body: Region): Placed[] => {
  const placed: Placed[] = []
  const first = blocks[window.start]
  let y = body.from

  if (window.isPinned && first?.kind === 'row') {
    placed.push({ kind: 'heading', y, section: first.section }, { kind: 'above', y: y + 1, count: top })
    y += PINNED_ROWS
  }

  for (const block of blocks.slice(window.start, window.end)) {
    if (block.kind === 'heading') {
      placed.push({ kind: 'heading', y, section: block.section })
    } else if (block.kind === 'row') {
      placed.push({ kind: 'row', y, row: block.row, key: rowKey(block.row) })
    }

    y += HEIGHT[block.kind]
  }

  const below = rowsIn(blocks.slice(window.end))

  return below > 0 && y < body.to ? [...placed, { kind: 'below', y, count: below }] : placed
}

/** The view's parts at the size: the answer's rows, the body's, and what the body shows from `top`. */
export const layoutOf = (view: PanelView, size: Size): Layout => {
  const width = Math.min(size.width, MOST)
  const { height } = size
  const sections = view.sections.filter(section => section.rows.length > 0)
  const said = view.answer === undefined ? [] : fitted(wrap(view.answer, width - 4), height - 3, width - 4)
  const foot = height - 1 - (said.length === 0 ? 0 : said.length + 1)
  const body = { from: height < ROOMY ? 1 : 2, to: foot }
  const room = Math.max(body.to - body.from, 0)
  const hasGaps = height >= ROOMY || heightOf(blocksOf(sections, true)) <= room
  const blocks = isTooSmall(size) || room === 0 ? [] : blocksOf(sections, hasGaps)
  const lastTop = lastTopOf(blocks, room)
  const top = Math.min(Math.max(view.top, 0), lastTop)
  const placed = placedIn(blocks, windowOf(blocks, top, room), top, body)

  return {
    width,
    height,
    sections,
    answer: { from: height - 1 - said.length, lines: said },
    body,
    words: { from: 1, to: foot },
    top,
    lastTop,
    placed,
    rows: placed.flatMap(each => (each.kind === 'row' ? [{ key: each.key, y: each.y }] : [])),
  }
}
