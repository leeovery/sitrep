/**
 * The panel drawn: a view to lines at a size, with no clock and no terminal.
 * Where each part goes is the layout's (layout.ts); this draws them.
 *
 * - Every line starts at column 1, and the layout's last column is a margin
 *   too.
 * - A section's heading: its words in grey capitals, its counts, a rule and
 *   the chevron. Without colour an ask's count is bold and a turn's regular,
 *   as their names are, since the two share `●`.
 * - A row is a session on two lines: its mark, name and time; then its
 *   project and status line. As the width falls, the status line is cut,
 *   then dropped; the project is cut; the name is cut to its least; then a
 *   Snoozed wake loses its clock, and the time goes.
 * - An empty board, and one not yet read, stand centred in the body's place.
 * - The key line drops whole hints from the right, `q quit` last.
 * - A board gone stale says when it was read, at the title's right.
 * - Below 24 columns or 8 rows it draws only `Too small`.
 */
import { cellsOf, cut, fitted, graphemesOf, widthOf, wrap, type Size } from './cells'
import { isTooSmall, layoutOf, LEFT, type Layout, type Placed, type Section } from './layout'
import { pensOf, sgr, type Ink, type Level, type Paint, type Pen, type Pens, type Style } from './paint'
import type { PanelRow, PanelView } from './view'

export type Run = { text: string; pen: Pen }
export type Line = Run[]

/** The column of the names and of line two. */
const NAME = 3

/** The fewest cells a name or a status line is cut to. */
const LEAST_CUT = 6

/** The fewest cells a heading's rule is drawn in. */
const LEAST_RULE = 3

const STYLE = {
  strong: { tone: 'ink', bold: true },
  heading: { tone: 'grey' },
  rule: { tone: 'rule', isMeta: true },
  meta: { tone: 'grey', isMeta: true },
  status: { tone: 'soft' },
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

type Hint = [key: string, word: string]

const QUIT: Hint = ['q', 'quit']

// ---------------------------------------------------------------- the grid

type Cell = { glyph: string; pen: Pen }

/** The cells of a frame, a row each; the second cell of a wide glyph holds `''`. */
type Grid = Cell[][]

const BLANK: Cell = { glyph: ' ', pen: {} }

const gridOf = (size: Size): Grid =>
  Array.from({ length: Math.max(size.height, 0) }, () => Array.from({ length: Math.max(size.width, 0) }, () => BLANK))

/** A mark with no glyph of its own, joined to the cell before column `x`. */
const join = (row: Cell[] | undefined, x: number, mark: string) => {
  const cell = row?.[x - 1]

  if (row !== undefined && cell !== undefined) {
    row[x - 1] = { glyph: cell.glyph + mark, pen: cell.pen }
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

const isSameInk = (a: Ink | undefined, b: Ink | undefined): boolean => {
  if (a === undefined || b === undefined) {
    return a === b
  }

  if ('ansi' in a) {
    return 'ansi' in b && a.ansi === b.ansi
  }

  return 'rgb' in b && a.rgb[0] === b.rgb[0] && a.rgb[1] === b.rgb[1] && a.rgb[2] === b.rgb[2]
}

const isSamePen = (a: Pen, b: Pen) =>
  isSameInk(a.fg, b.fg) &&
  isSameInk(a.bg, b.bg) &&
  a.bold === b.bold &&
  a.faint === b.faint &&
  a.reverse === b.reverse

/** A cell no one would see: a blank with no ground. */
const isBare = (cell: Cell) => cell.glyph === ' ' && cell.pen.bg === undefined && cell.pen.reverse !== true

/** A row's cells as runs of one pen, its bare cells at the end left off. */
const runsOf = (cells: Cell[]): Line => {
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

/** What every part of a frame draws on: the grid, where the parts go, and the pens. */
type Frame = { grid: Grid; layout: Layout; pens: Pens }

/** The title; on a board gone stale, the time of the last read at the right. */
const title = ({ grid, layout, pens }: Frame, view: PanelView) => {
  put(grid, LEFT, 0, 'sitrep', pens.of(STYLE.strong))

  if (view.board === 'stale' && view.asOf !== undefined) {
    putRight(grid, layout.width - 1, 0, `as of ${view.asOf}`, pens.of(STYLE.meta))
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
    const bold = pens.isColoured || count.need === 'ask'

    return put(grid, after, y, String(count.value), pens.of({ tone, bold }))
  }, x)

const heading = (frame: Frame, y: number, section: Section) => {
  const { grid, layout, pens } = frame
  const words = put(grid, LEFT, y, HEADINGS[section.kind], pens.of(STYLE.heading))
  const end = section.counts.length === 0 ? words : counts(frame, words + 1, y, section)
  const rule = layout.width - 4 - end

  if (rule >= LEAST_RULE) {
    put(grid, end + 1, y, '─'.repeat(rule), pens.of(STYLE.rule))
  }

  put(grid, layout.width - 2, y, section.isOpen ? '▿' : '▹', pens.of(STYLE.rule))
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

const firstLine = ({ grid, layout }: Frame, y: number, row: PanelRow, ink: Inking) => {
  const count = row.count !== undefined && row.count > 1 ? ` ${row.count}` : ''
  const room = layout.width - 1 - NAME - widthOf(count)
  const time = timeFitting(row, room)
  const nameRoom = room - (time === '' ? 0 : widthOf(time) + 2)
  const style = row.isSnoozed ? ({ tone: 'grey', bold: row.mark === 'ask', isMeta: true } as const) : MARKS[row.mark].name
  const after = put(grid, NAME, y, cut(row.name, nameRoom), ink(style))

  put(grid, after, y, count, ink(STYLE.meta))
  putRight(grid, layout.width - 1, y, time, ink(STYLE.meta))
}

/** Line two: the project and ` · `, then the status line and a question's `+2`; the project alone, cut, once the status line has no room. */
const secondLine = ({ grid, layout }: Frame, y: number, row: PanelRow, ink: Inking) => {
  const {
    project,
    status: { text: status },
  } = row
  const more = row.status.more === undefined ? '' : ` +${row.status.more}`
  const lead = `${project} · `
  const room = layout.width - 1 - NAME - widthOf(lead) - widthOf(more)
  const hasStatus = status !== '' && (widthOf(status) <= room || room >= LEAST_CUT)

  if (!hasStatus) {
    put(grid, NAME, y, cut(project, layout.width - 1 - NAME), ink(STYLE.meta))
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
  const { grid, layout, pens } = frame
  const isDimmed = row.isAway && !row.isSnoozed
  const ink: Inking = style => (isDimmed ? pens.dimmed(style) : pens.of(style))
  const mark = markOf(frame, row)
  const ground = isBand ? pens.band : row.isNew ? pens.wash : undefined

  put(grid, LEFT, y, mark.glyph, mark.pen)
  firstLine(frame, y, row, ink)
  secondLine(frame, y + 1, row, ink)

  if (ground !== undefined) {
    lay(grid, y, LEFT, layout.width - 1, ground)
    lay(grid, y + 1, LEFT, layout.width - 1, ground)
  }
}

const placedAt = (frame: Frame, view: PanelView, placed: Placed) => {
  const { grid, pens } = frame

  switch (placed.kind) {
    case 'heading':
      return heading(frame, placed.y, placed.section)
    case 'row':
      return rowAt(frame, placed.y, placed.row, placed.key === view.band)
    case 'above':
      return put(grid, LEFT, placed.y, `▲ ${placed.count} more`, pens.of(STYLE.meta))
    case 'below':
      return put(grid, LEFT, placed.y, `▼ ${placed.count} more`, pens.of(STYLE.meta))
  }
}

/** A heading's lines over its words: the heading, a blank row, then the words fitted to the rows left; the heading alone, cut, with no room for a word under it. */
const headed = (head: string, words: readonly string[], rows: number, cells: number) =>
  rows < 3 ? fitted([head], rows, cells) : [head, '', ...fitted(words, rows - 2, cells)]

/**
 * Words in the body's place, each line centred, the lines a little above
 * the middle: a heading in bold and a blank row, where there is one, then
 * the words in grey. Past the rows there are, the last kept carries the
 * rest, cut with `…`.
 */
const centred = ({ grid, layout, pens }: Frame, head: string | undefined, words: readonly string[]) => {
  const { from, to } = layout.words
  const right = layout.width - 1
  const cells = right - LEFT - 2
  const lines = head === undefined ? fitted(words, to - from, cells) : headed(head, words, to - from, cells)
  const top = from + Math.max(0, Math.floor((to - from - lines.length) / 2) - 1)

  lines.forEach((line, at) => {
    const pen = head !== undefined && at === 0 ? pens.of(STYLE.strong) : pens.of(STYLE.meta)

    put(grid, LEFT + Math.floor((right - LEFT - widthOf(line)) / 2), top + at, line, pen)
  })
}

/** An empty board: `All clear`, then what it means, wrapped at 24 columns. */
const quiet = (frame: Frame) => centred(frame, 'All clear', wrap(QUIET, Math.min(frame.layout.width - 4, 24)))

/** Before any board: `Looking for sessions…`, or why the board can't be read. */
const unread = (frame: Frame, reason: string | undefined) =>
  reason === undefined
    ? centred(frame, undefined, [LOOKING])
    : centred(frame, UNREADABLE, wrap(reason, frame.layout.width - 4))

/** The answer to a pick: `!`, then its words, hung under the first. */
const answer = ({ grid, layout, pens }: Frame) =>
  layout.answer.lines.forEach((line, at) => {
    if (at === 0) {
      put(grid, LEFT, layout.answer.from, '!', pens.of(STYLE.strong))
    }

    put(grid, LEFT + 2, layout.answer.from + at, line, pens.of(STYLE.answer))
  })

/** The keys that work now, but `q quit`, most needed first. */
const hintsOf = (view: PanelView, sections: readonly Section[]): Hint[] => {
  if (sections.length === 0) {
    return []
  }

  const moves: Hint[] = view.band === undefined ? [['↑↓', 'pick']] : [['↑↓', 'move'], ['⏎', 'open']]
  const snoozed: Hint[] = sections.some(section => section.kind === 'snoozed') ? [['s', 'snoozed']] : []

  return [...moves, ...snoozed]
}

const hintsWidth = (hints: readonly Hint[]) =>
  hints.reduce((sum, [key, word], at) => sum + (at === 0 ? 0 : 2) + widthOf(key) + 1 + widthOf(word), 0)

/** The key line: the hints that fit, dropped whole from the right, then `q quit`, which always applies, dropped last. */
const keyLine = ({ grid, layout, pens }: Frame, hints: readonly Hint[]) => {
  const room = layout.width - 1 - LEFT
  const kept = [...hints]

  while (kept.length > 0 && hintsWidth([...kept, QUIT]) > room) {
    kept.pop()
  }

  const shown = hintsWidth([...kept, QUIT]) <= room ? [...kept, QUIT] : []
  const y = layout.height - 1

  shown.reduce((x, [key, word], at) => {
    const after = put(grid, at === 0 ? x : x + 2, y, key, pens.of(STYLE.strong))

    return put(grid, after, y, ` ${word}`, pens.of(STYLE.meta))
  }, LEFT)
}

const tooSmall = (size: Size): Line[] => {
  const grid = gridOf(size)

  put(grid, LEFT, 0, cut('Too small', size.width - 2), {})

  return grid.map(runsOf)
}

/** The view drawn at the size, in the pens the terminal's answers give: a line a terminal row. */
export const draw = (view: PanelView, size: Size, paint: Paint): Line[] => {
  if (isTooSmall(size)) {
    return tooSmall(size)
  }

  const layout = layoutOf(view, size)
  const frame: Frame = { grid: gridOf(size), layout, pens: pensOf(paint) }

  title(frame, view)

  if (view.board === 'looking') {
    unread(frame, view.reason)
  } else if (layout.sections.length === 0) {
    quiet(frame)
  } else {
    layout.placed.forEach(placed => placedAt(frame, view, placed))
  }

  answer(frame)
  keyLine(frame, hintsOf(view, layout.sections))

  return frame.grid.map(runsOf)
}

/**
 * The lines as a terminal draws them: each run's pen set where it changes,
 * reset at a line's end, the lines a newline apart. The level must be the
 * one the lines were drawn at, the paint's that `draw` was given.
 */
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
