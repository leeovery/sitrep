/**
 * The panel drawn: a view to lines at a size, with no clock and no terminal.
 *
 * - Row 0 is the title; the last row the key line; between them the body,
 *   from row 2: each section's heading and its rows, a blank row between
 *   sections. A pick's answer sits above the key line, a blank row over it.
 * - Every line starts at column 1, and the layout's last column is a margin
 *   too. Past 120 columns the layout stays 120 wide, at the left.
 * - A row is a session on two lines: its mark, name and time; then its
 *   project and status line. As the width falls, the status line is cut,
 *   then dropped; the project is cut; the name is cut to its least; then a
 *   Snoozed wake loses its clock, and the time goes.
 * - The body shows the rows that fit, in whole rows, from the view's `top`:
 *   the sessions scrolled past, said by `▲ N more` under their section's
 *   heading, kept at the top. Below 15 rows the blank row under the title
 *   gives way, then the blank rows between sections.
 * - A board gone stale says when it was read, at the title's right; before
 *   any board, the body says it's looking, or why it can't read one.
 * - Below 24 columns or 8 rows it draws only `Too small`.
 */
import { cellsOf, cut, graphemesOf, widthOf, wrap, type Size } from './cells'
import { pensOf, sgr, type Ink, type Level, type Paint, type Pen, type Pens, type Style } from './paint'
import { rowKey, type PanelRow, type PanelView } from './view'

export type Run = { text: string; pen: Pen }
export type Line = Run[]

/** The widest the layout grows. */
const MOST = 120

/** The least a frame is drawn at; below it, `Too small`. */
const LEAST: Size = { width: 24, height: 8 }

/** Below this many rows, the blank rows give way. */
const ROOMY = 15

/** The column of the marks and the headings, after the margin; and of the names and line two. */
const MARK = 1
const NAME = 3

/** The fewest cells a name or a status line is cut to. */
const LEAST_CUT = 6

/** The fewest cells a heading's rule is drawn in. */
const LEAST_RULE = 3

type Section = PanelView['sections'][number]

const STYLE = {
  title: { tone: 'ink', bold: true },
  heading: { tone: 'grey' },
  rule: { tone: 'rule', isMeta: true },
  meta: { tone: 'grey', isMeta: true },
  status: { tone: 'soft' },
  key: { tone: 'ink', bold: true },
  answer: { tone: 'ink' },
  arriving: { tone: 'orange', bold: true },
} satisfies Record<string, Style>

const MARKS: Record<PanelRow['mark'], { here: string; away: string; style: Style; name: Style }> = {
  ask: { here: '●', away: '○', style: { tone: 'orange' }, name: { tone: 'ink', bold: true } },
  turn: { here: '●', away: '○', style: { tone: 'blue' }, name: { tone: 'ink' } },
  working: { here: '✻', away: '✻', style: { tone: 'soft' }, name: { tone: 'soft' } },
  onItsWork: { here: '◌', away: '◌', style: { tone: 'grey' }, name: { tone: 'soft' } },
}

const ARRIVING = '◉'

const NEEDS = { ask: 'orange', turn: 'blue' } as const

const HEADINGS: Record<Section['kind'], string> = {
  needsYou: 'NEEDS YOU',
  working: 'WORKING',
  snoozed: 'SNOOZED',
}

const QUIET = 'Nothing needs you, and nothing is running.'

const LOOKING = 'Looking for sessions…'

const UNREADABLE = "Can't read the board"

// ---------------------------------------------------------------- the grid

type Cell = { glyph: string; pen: Pen }

/** The cells of a frame, a row each; the second cell of a wide glyph holds `''`. */
type Grid = Cell[][]

const BLANK: Cell = { glyph: ' ', pen: {} }

const gridOf = (size: Size): Grid =>
  Array.from({ length: Math.max(size.height, 0) }, () => Array.from({ length: Math.max(size.width, 0) }, () => BLANK))

/** A mark with no glyph of its own, joined to the cell before column `x`, the first of a wide glyph's two. */
const join = (row: Cell[] | undefined, x: number, mark: string) => {
  const before = row?.[x - 1]?.glyph === '' ? x - 2 : x - 1
  const cell = row?.[before]

  if (row !== undefined && cell !== undefined) {
    row[before] = { glyph: cell.glyph + mark, pen: cell.pen }
  }
}

/** Writes the text from column `x` on row `y`, clipped at the grid's edges; gives the column after it. */
const put = (grid: Grid, x: number, y: number, text: string, pen: Pen): number => {
  const row = grid[y]
  let at = x

  for (const glyph of graphemesOf(text)) {
    const cells = cellsOf(glyph)

    if (cells === 0) {
      join(row, at, glyph)
    } else if (row !== undefined && at >= 0 && at + cells <= row.length) {
      row[at] = { glyph, pen }

      if (cells === 2) {
        row[at + 1] = { glyph: '', pen }
      }
    }

    at += cells
  }

  return at
}

/** Writes the text so it ends at column `end`, exclusive. */
const putRight = (grid: Grid, end: number, y: number, text: string, pen: Pen) =>
  put(grid, end - widthOf(text), y, text, pen)

/** Lays `over` on row `y`'s cells from `from` to `to`, exclusive, their glyphs and inks kept. */
const lay = (grid: Grid, y: number, from: number, to: number, over: Pen) => {
  const row = grid[y] ?? []

  for (let x = from; x < to && x < row.length; x++) {
    const cell = row[x] ?? BLANK

    row[x] = { glyph: cell.glyph, pen: { ...cell.pen, ...over } }
  }
}

const isSameInk = (a: Ink | undefined, b: Ink | undefined) => JSON.stringify(a) === JSON.stringify(b)

const isSamePen = (a: Pen, b: Pen) =>
  isSameInk(a.fg, b.fg) &&
  isSameInk(a.bg, b.bg) &&
  a.bold === b.bold &&
  a.faint === b.faint &&
  a.reverse === b.reverse

/** A cell no one would see: a blank with no ground. */
const isBare = (cell: Cell) => cell.glyph === ' ' && cell.pen.bg === undefined && cell.pen.reverse !== true

/** A row's cells as runs of one pen, its bare cells at the end left off. */
const lineOf = (cells: Cell[]): Line => {
  let end = cells.length

  while (end > 0 && isBare(cells[end - 1] ?? BLANK)) {
    end--
  }

  return cells.slice(0, end).reduce<Line>((runs, cell) => {
    const last = runs.at(-1)

    if (last !== undefined && isSamePen(last.pen, cell.pen)) {
      last.text += cell.glyph
      return runs
    }

    return [...runs, { text: cell.glyph, pen: cell.pen }]
  }, [])
}

// ---------------------------------------------------------------- the frame

/** What every part of a frame draws on: the grid, the layout's width, the terminal's height, and the pens. */
type Frame = { grid: Grid; width: number; height: number; pens: Pens }

/** One of the body's pieces, in its order: a blank row between sections, a heading, or a row. */
type Block = { kind: 'gap' } | { kind: 'heading'; section: Section } | { kind: 'row'; row: PanelRow; section: Section }

const HEIGHT: Record<Block['kind'], number> = { gap: 1, heading: 1, row: 2 }

const heightOf = (blocks: readonly Block[]) => blocks.reduce((sum, block) => sum + HEIGHT[block.kind], 0)

const blocksOf = (sections: readonly Section[], hasGaps: boolean): Block[] =>
  sections.flatMap((section, at): Block[] => [
    ...(at > 0 && hasGaps ? [{ kind: 'gap' } as const] : []),
    { kind: 'heading', section },
    ...(section.isOpen ? section.rows.map(row => ({ kind: 'row', row, section }) as const) : []),
  ])

const rowsIn = (blocks: readonly Block[]) => blocks.filter(block => block.kind === 'row').length

/** The title; on a board gone stale, the time of the last read at the right. */
const title = ({ grid, width, pens }: Frame, view: PanelView) => {
  put(grid, MARK, 0, 'sitrep', pens.of(STYLE.title))

  if (view.board === 'stale' && view.asOf !== undefined) {
    putRight(grid, width - 1, 0, `as of ${view.asOf}`, pens.of(STYLE.meta))
  }
}

/** A section's counts from column `x`, a space between each two; gives the column after them. */
const counts = ({ grid, pens }: Frame, x: number, y: number, section: Section) =>
  section.counts.reduce((at, count, index) => {
    const from = index === 0 ? at : at + 1

    if (count.need === undefined) {
      return put(grid, from, y, String(count.value), pens.of(STYLE.meta))
    }

    const tone = NEEDS[count.need]
    const after = put(grid, from, y, '●', pens.of({ tone }))

    return put(grid, after, y, String(count.value), pens.of({ tone, bold: true }))
  }, x)

const heading = (frame: Frame, y: number, section: Section) => {
  const { grid, width, pens } = frame
  const words = put(grid, MARK, y, HEADINGS[section.kind], pens.of(STYLE.heading))
  const end = section.counts.length === 0 ? words : counts(frame, words + 1, y, section)
  const rule = width - 4 - end

  if (rule >= LEAST_RULE) {
    put(grid, end + 1, y, '─'.repeat(rule), pens.of(STYLE.rule))
  }

  put(grid, width - 2, y, section.isOpen ? '▿' : '▹', pens.of(STYLE.rule))
}

/** A Snoozed wake without its clock, `tomorrow` for `tomorrow 09:00`; none for a bare clock. */
const withoutClock = (time: string) => /^(.+) \d{1,2}:\d{2}$/.exec(time)?.[1]

/** The row's time as it fits beside its name: whole, a Snoozed wake without its clock, or none, whichever first leaves the name its least. */
const timeFitting = (row: PanelRow, room: number) => {
  const day = row.isSnoozed ? withoutClock(row.time) : undefined
  const least = Math.min(LEAST_CUT, widthOf(row.name))
  const tries = [row.time, ...(day === undefined ? [] : [day]), '']

  return tries.find(each => room - (each === '' ? 0 : widthOf(each) + 2) >= least) ?? ''
}

/** A row's words in a style: an away row's dimmed as one, as the notch dims it. */
type Inking = (style: Style) => Pen

const firstLine = ({ grid, width }: Frame, y: number, row: PanelRow, ink: Inking) => {
  const count = row.count !== undefined && row.count > 1 ? ` ${row.count}` : ''
  const room = width - 1 - NAME - widthOf(count)
  const time = timeFitting(row, room)
  const nameRoom = room - (time === '' ? 0 : widthOf(time) + 2)
  const style = row.isSnoozed ? { tone: 'grey', bold: row.mark === 'ask', isMeta: true } as const : MARKS[row.mark].name
  const after = put(grid, NAME, y, cut(row.name, nameRoom), ink(style))

  put(grid, after, y, count, ink(STYLE.meta))
  putRight(grid, width - 1, y, time, ink(STYLE.meta))
}

/** Line two: the project and ` · `, then the status line and a question's `+2`; the project alone, cut, once the status line has no room. */
const secondLine = ({ grid, width }: Frame, y: number, row: PanelRow, ink: Inking) => {
  const { project, status: { text: status } } = row
  const more = row.status.more === undefined ? '' : ` +${row.status.more}`
  const lead = `${project} · `
  const room = width - 1 - NAME - widthOf(lead) - widthOf(more)
  const hasStatus = status !== '' && (widthOf(status) <= room || room >= LEAST_CUT)

  if (!hasStatus) {
    put(grid, NAME, y, cut(project, width - 1 - NAME), ink(STYLE.meta))
    return
  }

  const after = put(grid, NAME, y, lead, ink(STYLE.meta))
  const end = put(grid, after, y, cut(status, room), ink(STYLE.status))

  put(grid, end, y, more, ink(STYLE.meta))
}

const markOf = ({ pens }: Frame, row: PanelRow) => {
  const mark = MARKS[row.mark]

  if (row.isNew) {
    return { glyph: ARRIVING, pen: pens.of(STYLE.arriving) }
  }

  if (row.isSnoozed) {
    return { glyph: mark.here, pen: pens.dimmed(mark.style) }
  }

  return { glyph: row.isAway ? mark.away : mark.here, pen: pens.of(mark.style) }
}

const rowAt = (frame: Frame, y: number, row: PanelRow, isBand: boolean) => {
  const { grid, width, pens } = frame
  const isDimmed = row.isAway && !row.isSnoozed
  const ink: Inking = style => (isDimmed ? pens.dimmed(style) : pens.of(style))
  const mark = markOf(frame, row)
  const ground = isBand ? pens.band : row.isNew ? pens.wash : undefined

  put(grid, MARK, y, mark.glyph, mark.pen)
  firstLine(frame, y, row, ink)
  secondLine(frame, y + 1, row, ink)

  if (ground !== undefined) {
    lay(grid, y, MARK, width - 1, ground)
    lay(grid, y + 1, MARK, width - 1, ground)
  }
}

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

const body = (frame: Frame, view: PanelView, sections: readonly Section[], from: number, to: number) => {
  const { grid, height, pens } = frame
  const room = to - from
  const hasGaps = height >= ROOMY || heightOf(blocksOf(sections, true)) <= room
  const blocks = blocksOf(sections, hasGaps)
  const rows = blocks.filter(block => block.kind === 'row')
  const top = Math.max(0, Math.min(view.top, rows.length - 1))
  const first = rows[top]
  const start = top === 0 || first === undefined ? 0 : blocks.indexOf(first)
  const pinned = start === 0 ? undefined : first?.section
  const end = endOf(blocks, start, start === 0 ? 0 : 2, room)
  const below = rowsIn(blocks.slice(end))
  let y = from

  if (pinned !== undefined) {
    heading(frame, y++, pinned)
    put(grid, MARK, y++, `▲ ${top} more`, pens.of(STYLE.meta))
  }

  for (const block of blocks.slice(start, end)) {
    if (block.kind === 'heading') {
      heading(frame, y, block.section)
    } else if (block.kind === 'row') {
      rowAt(frame, y, block.row, rowKey(block.row) === view.band)
    }

    y += HEIGHT[block.kind]
  }

  if (below > 0) {
    put(grid, MARK, y, `▼ ${below} more`, pens.of(STYLE.meta))
  }
}

/** Words in the body's place: each line centred, the lines a little above the middle. */
const centred = ({ grid, width, height }: Frame, lines: readonly Run[]) => {
  const [left, right, top, bottom] = [MARK, width - 1, 1, height - 1]
  const from = top + Math.max(0, Math.floor((bottom - top - lines.length) / 2) - 1)

  lines.forEach(({ text, pen }, at) =>
    put(grid, left + Math.floor((right - left - widthOf(text)) / 2), from + at, text, pen),
  )
}

/** A heading in bold, a blank row, then its words in grey, wrapped at `cells`. */
const told = ({ pens }: Frame, heading: string, words: string, cells: number): Run[] => [
  { text: heading, pen: pens.of(STYLE.title) },
  { text: '', pen: {} },
  ...wrap(words, cells).map(text => ({ text, pen: pens.of(STYLE.meta) })),
]

/** An empty board: `All clear`, then what it means, wrapped at 24 columns. */
const quiet = (frame: Frame) => centred(frame, told(frame, 'All clear', QUIET, Math.min(frame.width - 4, 24)))

/** Before any board: `Looking for sessions…`, or why the board can't be read. */
const unread = (frame: Frame, reason: string | undefined) =>
  centred(
    frame,
    reason === undefined
      ? [{ text: LOOKING, pen: frame.pens.of(STYLE.meta) }]
      : told(frame, UNREADABLE, reason, frame.width - 4),
  )

/** The answer to a pick: `!`, then its words, hung under the first. */
const answer = ({ grid, pens }: Frame, from: number, lines: readonly string[]) =>
  lines.forEach((line, at) => {
    if (at === 0) {
      put(grid, MARK, from, '!', pens.of(STYLE.key))
    }

    put(grid, MARK + 2, from + at, line, pens.of(STYLE.answer))
  })

/** The keys that work now, most needed first. */
const hintsOf = (view: PanelView, sections: readonly Section[]): [string, string][] => {
  if (sections.length === 0) {
    return [['q', 'quit']]
  }

  const moves: [string, string][] = view.band === undefined ? [['↑↓', 'pick']] : [['↑↓', 'move'], ['⏎', 'open']]
  const snoozed: [string, string][] = sections.some(section => section.kind === 'snoozed') ? [['s', 'snoozed']] : []

  return [...moves, ...snoozed, ['q', 'quit']]
}

/** The key line, whole hints dropped from the right where they don't fit. */
const keyLine = ({ grid, width, height, pens }: Frame, hints: readonly [string, string][]) => {
  let x = MARK

  for (const [index, [key, word]] of hints.entries()) {
    const from = index === 0 ? x : x + 2

    if (from + widthOf(key) + 1 + widthOf(word) > width - 1) {
      return
    }

    x = put(grid, put(grid, from, height - 1, key, pens.of(STYLE.key)), height - 1, ` ${word}`, pens.of(STYLE.meta))
  }
}

const tooSmall = (size: Size): Line[] => {
  const grid = gridOf(size)

  put(grid, MARK, 0, cut('Too small', size.width - 2), {})

  return grid.map(lineOf)
}

/** The view drawn at the size, in the pens the terminal's answers give: a line a terminal row. */
export const draw = (view: PanelView, size: Size, paint: Paint): Line[] => {
  if (size.width < LEAST.width || size.height < LEAST.height) {
    return tooSmall(size)
  }

  const frame: Frame = {
    grid: gridOf(size),
    width: Math.min(size.width, MOST),
    height: size.height,
    pens: pensOf(paint),
  }
  const sections = view.sections.filter(section => section.rows.length > 0)
  const said = view.answer === undefined ? [] : wrap(view.answer, frame.width - 4)
  const foot = frame.height - 1 - (said.length === 0 ? 0 : said.length + 1)

  title(frame, view)

  if (view.board === 'looking') {
    unread(frame, view.reason)
  } else if (sections.length === 0) {
    quiet(frame)
  } else {
    body(frame, view, sections, frame.height < ROOMY ? 1 : 2, foot)
  }

  answer(frame, foot + 1, said)
  keyLine(frame, hintsOf(view, sections))

  return frame.grid.map(lineOf)
}

/** The lines as a terminal draws them, at the level: each run's pen set where it changes, reset at a line's end, the lines a newline apart. */
export const ansi = (lines: readonly Line[], level: Level): string => {
  const plain = sgr({}, level)

  return lines
    .map(line => {
      let pen = plain
      let out = ''

      for (const run of line) {
        const next = sgr(run.pen, level)

        out += (next === pen ? '' : next) + run.text
        pen = next
      }

      return pen === plain ? out : out + plain
    })
    .join('\n')
}

/** The lines' glyphs alone, each line's trailing blanks trimmed, a newline after each. */
export const text = (lines: readonly Line[]): string =>
  lines.map(line => `${line.map(run => run.text).join('').trimEnd()}\n`).join('')
