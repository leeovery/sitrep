/**
 * Where a frame's parts go at a size, with no pens and no text drawn: the
 * one copy of the fit rules, for drawing (draw.ts) and for the keys, which
 * keep the band's row in sight (`topFor`), page by a body's height, and find
 * the row a tap lands on.
 *
 * - The last row is the key line, and always stays. There is no title (Lee,
 *   20 November 2026).
 * - A pick's answer sits above the key line, a blank row over it, in at most
 *   the rows above the key line, less that blank row; past them its last
 *   line is cut with `…`.
 * - Row 0 is blank, and the body runs from row 1 to the answer's blank row
 *   or the key line. Short of room, the top row gives way first: it stays
 *   only while every block fits under it, so it never costs the body a row.
 *   Then, below 13 rows, the blank rows between sections give way.
 * - It shows the rows that fit, in whole rows, from `top`. Above them, room
 *   allowing, their section's heading, pinned, and `▲ N more` for the rows
 *   scrolled past; or `▲` alone; or nothing. `▼ N more` says the rows below,
 *   its row kept free while any block is left after, but never at the cost
 *   of the first row shown.
 * - A row takes one line; the chosen row expanded, the lines its words
 *   need (expand.ts), cut to the body's height where it is taller, never
 *   below two. The snooze menu stands under the chosen row, a line a
 *   choice, the two as one block; short of room, the row's lines give way
 *   first, down to its first, then the menu shows the choices it has room
 *   for, scrolled the least from where it was that keeps the pick among
 *   them.
 * - The body never starts or ends on a blank row, or on an open section's
 *   heading, while blocks follow: a heading stands only with a row under it.
 *   A folded Snoozed heading is drawn last.
 * - `top` goes no further than the least from which the body shows the last
 *   block.
 */
import { wrapIn, type Size } from './cells'
import { expandedOf } from './expand'
import { rowKey, type PanelRow, type PanelView } from './view'

/** The left margin's width: every line starts here. */
export const LEFT = 1

/** The widest the layout grows. */
export const MOST = 120

/** The least a frame is laid out at; below it, `Too small`. */
const LEAST: Size = { width: 24, height: 8 }

/** Below this many rows, short of room, the blank rows between sections give way. */
const ROOMY = 13

export type Section = PanelView['sections'][number]

/** What the body shows, each at its terminal row: a heading; a row's lines, as many as it shows, and the snooze menu's choices under them, as many as it shows; or `▲`/`▼` and the rows they count. */
export type Placed =
  | { kind: 'heading'; y: number; section: Section }
  | { kind: 'row'; y: number; row: PanelRow; section: Section; key: string; height: number; menu: number }
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
  /** The rows the body's place holds from row 0, where words stand centred, under the top row while it stays (`topRowOf`). */
  words: Region
  /** The view's `top`, kept within `lastTop`. */
  top: number
  /** The least `top` from which the body shows the last block: any greater leaves blank rows. */
  lastTop: number
  placed: Placed[]
  /** Each row in view by its key, at the terminal row of its first line, and the lines it takes. */
  rows: { key: string; y: number; height: number }[]
  /** The snooze menu's choices in view: the terminal row of the first, how many, and which choice is first. */
  menu?: { y: number; lines: number; first: number }
}

/** One of the body's pieces, in its order: a blank row between sections, a heading, or a row, the lines it takes and its menu's. */
type Block =
  | { kind: 'gap' }
  | { kind: 'heading'; section: Section }
  | ({ kind: 'row'; row: PanelRow; section: Section } & RowShape)

/** The lines a row takes, and the snooze menu under it, none where it has no menu. */
type RowShape = { height: number; menu: number }

/** A row's lines, folded. */
const ROW = 1

/** The fewest lines an expanded row is cut to: its head and one more. */
const LEAST_EXPANDED = 2

/** The lines a block takes. */
const linesOf = (block: Block) => (block.kind === 'row' ? block.height + block.menu : 1)

/** What stands above the first row of a scrolled body: its heading, pinned, and `▲`; `▲` alone; or nothing. */
type Lead = 'pinned' | 'above' | 'none'

/** The rows each lead takes: it stands only with room under it for a row, and for `▼` while blocks follow the row. */
const LEAD_ROWS: Record<Lead, number> = { pinned: 2, above: 1, none: 0 }

const heightOf = (blocks: readonly Block[]) => blocks.reduce((sum, block) => sum + linesOf(block), 0)

/** The lines a row takes as it stands, the chosen row's when expanded, else its one; and its menu's, where its menu is open. */
type Shaping = (row: PanelRow) => RowShape

const blocksOf = (sections: readonly Section[], hasGaps: boolean, shape: Shaping): Block[] =>
  sections.flatMap((section, at): Block[] => [
    ...(at > 0 && hasGaps ? [{ kind: 'gap' } as const] : []),
    { kind: 'heading', section },
    ...(section.isOpen ? section.rows.map(row => ({ kind: 'row', row, section, ...shape(row) }) as const) : []),
  ])

const rowsIn = (blocks: readonly Block[]) => blocks.filter(block => block.kind === 'row').length

export const isTooSmall = (size: Size) => size.width < LEAST.width || size.height < LEAST.height

/** The body's view from a `top`: where it starts, what stands above its first row, and the index after the last block that fits. */
type Window = { start: number; lead: Lead; end: number }

/** Whether blocks follow the one at `at`, so `▼` may need a row under it. */
const isFollowed = (blocks: readonly Block[], at: number) => at + 1 < blocks.length

/** The rows the block at `at` takes, and one for `▼` while blocks follow it. */
const roomFor = (blocks: readonly Block[], at: number) => linesOf(blocks[at] as Block) + (isFollowed(blocks, at) ? 1 : 0)

/** A block a body may not end on while blocks follow: a blank row, or an open section's heading, which stands only with a row under it. */
const isBare = (block: Block | undefined) => block?.kind === 'gap' || (block?.kind === 'heading' && block.section.isOpen)

/**
 * The blocks from `start` that fit in `room` rows with `used` taken, a row
 * kept for `▼` while any are left after, though never at the cost of the
 * first; never ending on a heading or a blank row while any are left after.
 * Gives the index after the last.
 */
const endOf = (blocks: readonly Block[], start: number, used: number, room: number) => {
  let end = start
  let taken = used

  while (end < blocks.length) {
    const needs = end === start ? linesOf(blocks[end] as Block) : roomFor(blocks, end)

    if (taken + needs > room) {
      break
    }

    taken += linesOf(blocks[end] as Block)
    end++
  }

  while (end > start + 1 && end < blocks.length && isBare(blocks[end - 1])) {
    end--
  }

  return end
}

/** What fits above the first row of a body scrolled to `start` past `top` rows, with a row kept for `▼` while blocks follow it. */
const leadOf = (blocks: readonly Block[], start: number, top: number, room: number): Lead => {
  if (top === 0) {
    return 'none'
  }

  const needs = roomFor(blocks, start)

  return room >= LEAD_ROWS.pinned + needs ? 'pinned' : room >= LEAD_ROWS.above + needs ? 'above' : 'none'
}

/** Where a body from `top` starts: at its row, or, from the first, at the top, the headings over it kept where the row still fits under them. */
const startOf = (blocks: readonly Block[], top: number, room: number) => {
  const first = blocks.filter(block => block.kind === 'row')[top]
  const at = first === undefined ? 0 : blocks.indexOf(first)
  const needs = heightOf(blocks.slice(0, at)) + (first === undefined ? 0 : roomFor(blocks, at))

  return top === 0 && room >= needs ? 0 : at
}

const windowOf = (blocks: readonly Block[], top: number, room: number): Window => {
  const start = startOf(blocks, top, room)
  const lead = leadOf(blocks, start, top, room)

  return { start, lead, end: endOf(blocks, start, LEAD_ROWS[lead], room) }
}

/** The least `top` from which the body shows the last block: any greater leaves blank rows. */
const lastTopOf = (blocks: readonly Block[], room: number) => {
  if (room < ROW) {
    return 0
  }

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

  if (window.lead === 'pinned' && first?.kind === 'row') {
    placed.push({ kind: 'heading', y: y++, section: first.section })
  }

  if (window.lead !== 'none') {
    placed.push({ kind: 'above', y: y++, count: top })
  }

  for (const block of blocks.slice(window.start, window.end)) {
    if (block.kind === 'heading') {
      placed.push({ kind: 'heading', y, section: block.section })
    } else if (block.kind === 'row') {
      const { row, section, height, menu } = block

      placed.push({ kind: 'row', y, row, section, key: rowKey(row), height, menu })
    }

    y += linesOf(block)
  }

  const below = rowsIn(blocks.slice(window.end))

  return below > 0 && y < body.to ? [...placed, { kind: 'below', y, count: below }] : placed
}

/** The first row of the body's place: 1, the top row left blank, while `lines` fit under it in the `room` rows from row 0; else 0. */
export const topRowOf = (lines: number, room: number) => (lines < room ? 1 : 0)

/** The body's rows, from the top to the foot, and its blocks: the blank top row, then the gaps between sections, each kept while every block fits with it. */
const bodyOf = (sections: readonly Section[], height: number, foot: number, shape: Shaping) => {
  const gapped = blocksOf(sections, true, shape)
  const from = topRowOf(heightOf(gapped), foot)
  const hasGaps = height >= ROOMY || heightOf(gapped) <= foot

  return { body: { from, to: foot }, blocks: hasGaps ? gapped : blocksOf(sections, false, shape) }
}

/**
 * A block cut to the body's `room` where it is taller: a row with its menu
 * keeps the menu whole under its first line at least, its own lines giving
 * way first, then the menu's last; one with none, an expanded row, is cut
 * to the body, never below two lines.
 */
const cutTo = (block: Block, room: number): Block => {
  if (block.kind !== 'row' || linesOf(block) <= room) {
    return block
  }

  if (block.menu === 0) {
    return { ...block, height: Math.max(room, LEAST_EXPANDED) }
  }

  const height = Math.min(block.height, Math.max(room - block.menu, 1))

  return { ...block, height, menu: Math.max(Math.min(block.menu, room - height), 0) }
}

/** The parts every `top` shares: the sizes, the answer, the body's rows and its blocks. */
const partsOf = (view: PanelView, size: Size) => {
  const width = Math.min(size.width, MOST)
  const { height } = size
  const sections = view.sections.filter(section => section.rows.length > 0)
  const said = view.answer === undefined ? [] : wrapIn(view.answer, width - 4, height - 2)
  const foot = height - 1 - (said.length === 0 ? 0 : said.length + 1)
  const shape: Shaping = row => ({
    height: rowKey(row) === view.expanded ? Math.max(expandedOf(row, width).lines.length, LEAST_EXPANDED) : ROW,
    menu: rowKey(row) === view.menu?.row ? view.menu.options.length : 0,
  })
  const { body, blocks } = bodyOf(sections, height, foot, shape)
  const room = Math.max(body.to - body.from, 0)
  const shown = isTooSmall(size) || room === 0 ? [] : blocks.map(block => cutTo(block, room))

  return { width, height, sections, said, foot, body, room, blocks: shown, lastTop: lastTopOf(shown, room) }
}

type Parts = ReturnType<typeof partsOf>

const placedAt = (parts: Parts, top: number) => placedIn(parts.blocks, windowOf(parts.blocks, top, parts.room), top, parts.body)

const rowsOf = (placed: readonly Placed[]) =>
  placed.flatMap(each => (each.kind === 'row' ? [{ key: each.key, y: each.y, height: each.height }] : []))

/** The first of `lines` choices drawn: the least move from `top` that keeps the pick `at` among them, within the choices there are. */
const firstOf = ({ options, at, top }: NonNullable<PanelView['menu']>, lines: number) =>
  Math.max(Math.min(Math.min(Math.max(top, at - lines + 1), at), options.length - lines), 0)

/** The snooze menu's choices in view, under their row's lines; none while no row shows one. */
const menuOf = (view: PanelView, placed: readonly Placed[]) => {
  const row = placed.find(each => each.kind === 'row' && each.menu > 0)

  return row?.kind === 'row' && view.menu !== undefined
    ? { menu: { y: row.y + row.height, lines: row.menu, first: firstOf(view.menu, row.menu) } }
    : {}
}

/** The view's parts at the size: the answer's rows, the body's, and what the body shows from `top`. */
export const layoutOf = (view: PanelView, size: Size): Layout => {
  const parts = partsOf(view, size)
  const top = Math.min(Math.max(view.top, 0), parts.lastTop)
  const placed = placedAt(parts, top)

  return {
    width: parts.width,
    height: parts.height,
    sections: parts.sections,
    answer: { from: parts.height - 1 - parts.said.length, lines: parts.said },
    body: parts.body,
    words: { from: 0, to: parts.foot },
    top,
    lastTop: parts.lastTop,
    placed,
    rows: rowsOf(placed),
    ...menuOf(view, placed),
  }
}

/** The `top` nearest the view's at which the row `key` lies whole in the body, the lesser of two as near; none where no `top` shows it. */
export const topFor = (view: PanelView, size: Size, key: string): number | undefined => {
  const parts = partsOf(view, size)
  const from = Math.min(Math.max(view.top, 0), parts.lastTop)
  const tops = Array.from({ length: parts.lastTop + 1 }, (_, top) => top)
    .filter(top => rowsOf(placedAt(parts, top)).some(row => row.key === key))
    .sort((a, b) => Math.abs(a - from) - Math.abs(b - from) || a - b)

  return tops[0]
}
