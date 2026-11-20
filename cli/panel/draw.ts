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
 * - The chosen row expanded cuts nothing: its words wrap over the lines the
 *   layout gives it (expand.ts), the band over them all.
 * - An empty board, and one not yet read, stand centred in the body's place.
 * - The snooze menu stands under the chosen row, a choice a line, the band
 *   on the choice picked rather than on the row.
 * - The key line drops whole hints from the right, `q quit` last, or in the
 *   menu `esc cancel`.
 * - There is no title: the body starts on row 0 (Lee, 20 November 2026).
 * - A board gone stale says when it was read, at the key line's right end;
 *   the keys are cut to the room left of it.
 * - Below 24 columns or 8 rows it draws only `Too small`.
 */
import { cellsOf, cut, graphemesOf, widthOf, wrapIn, type Size, type Tagged } from './cells'
import { countOf, expandedOf, LEAST_CUT, NAME, timeFitting, type Tag } from './expand'
import { isTooSmall, layoutOf, LEFT, type Layout, type Placed, type Section } from './layout'
import { pensOf, sgr, type Ink, type Level, type Paint, type Pen, type Pens, type Style } from './paint'
import { rowKey, type PanelRow, type PanelView } from './view'

export type Run = { text: string; pen: Pen }
export type Line = Run[]

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

  if (end <= layout.width - 3) {
    put(grid, layout.width - 2, y, section.isOpen ? '▿' : '▹', pens.of(STYLE.rule))
  }
}

/** A row's words in a style: an away row's dimmed as one, as the notch dims it. */
type Inking = (style: Style) => Pen

/** The style of a row's name: grey in Snoozed, an ask's bold. */
const nameStyle = (row: PanelRow): Style =>
  row.isSnoozed ? { tone: 'grey', bold: row.mark === 'ask', isMeta: true } : MARKS[row.mark].name

const firstLine = ({ grid, layout }: Frame, y: number, row: PanelRow, ink: Inking) => {
  const count = countOf(row)
  const room = layout.width - 1 - NAME - widthOf(count)
  const time = timeFitting(row, room)
  const nameRoom = room - (time === '' ? 0 : widthOf(time) + 2)
  const after = put(grid, NAME, y, cut(row.name, nameRoom), ink(nameStyle(row)))

  put(grid, after, y, count, ink(STYLE.meta))
  putRight(grid, layout.width - 1, y, time, ink(STYLE.meta))
}

/** The words of a line of an expanded row from the names' column, a space between each two, each in its tag's style. */
const words = (grid: Grid, y: number, line: readonly Tagged<Tag>[], styles: Record<Tag, Pen>) =>
  line.reduce((x, word, at) => put(grid, at === 0 ? x : x + 1, y, word.text, styles[word.tag]), NAME)

/**
 * The chosen row expanded, in the two lines or more the layout gives it: its
 * words whole, the time at the first line's right; where the body cuts it
 * short, its last line kept, never its first, says `…`.
 */
const expandedLines = ({ grid, layout }: Frame, y: number, height: number, row: PanelRow, ink: Inking) => {
  const { time, lines } = expandedOf(row, layout.width)
  const styles: Record<Tag, Pen> = { name: ink(nameStyle(row)), meta: ink(STYLE.meta), status: ink(STYLE.status) }
  const isCut = lines.length > height

  lines.slice(0, height).forEach((line, at) => {
    const isLast = isCut && at === height - 1

    words(grid, y + at, isLast ? [{ text: '…', tag: 'meta' }] : line, styles)
  })
  putRight(grid, layout.width - 1, y, time, styles.meta)
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

const markOf = ({ pens }: Frame, row: PanelRow, dimmed: Inking) => {
  const mark = MARKS[row.mark]

  if (row.isNew) {
    return { glyph: ARRIVING, pen: pens.of(STYLE.arriving) }
  }

  if (row.isSnoozed) {
    return { glyph: mark.here, pen: dimmed(mark.style) }
  }

  return { glyph: row.isAway ? mark.away : mark.here, pen: pens.of(mark.style) }
}

/**
 * The snooze menu under its row, a choice a line: its name from the names'
 * column, in the terminal's ink, and its time at the right in grey, where
 * both fit; the band on the choice picked, its name bold.
 */
const menuAt = ({ grid, layout, pens }: Frame, menu: NonNullable<PanelView['menu']>) => {
  const room = layout.width - 1 - NAME
  const { y, lines, first } = layout.menu ?? { y: 0, lines: 0, first: 0 }

  menu.options.slice(first, first + lines).forEach((option, at) => {
    const isPicked = first + at === menu.at
    const time = widthOf(option.title) + 2 + widthOf(option.time) <= room ? option.time : ''

    put(grid, NAME, y + at, cut(option.title, room), pens.of({ tone: 'ink', bold: isPicked }))
    putRight(grid, layout.width - 1, y + at, time, pens.of(STYLE.meta))

    if (isPicked) {
      lay(grid, y + at, LEFT, layout.width - 1, pens.band)
    }
  })
}

/**
 * A row on its lines: folded, its two, or its first alone where its menu
 * leaves no more, expanded or not, so the menu always says whose it is;
 * expanded, as many as the layout gives it; the band or the
 * wash over every one. With its menu open the band is the menu's, on the
 * choice picked.
 */
const rowAt = (frame: Frame, { y, row, key, height, menu }: Extract<Placed, { kind: 'row' }>, view: PanelView) => {
  const { grid, layout, pens } = frame
  const isBand = key === view.band && view.menu === undefined
  const isDimmed = row.isAway && !row.isSnoozed
  const dimmed = isBand ? pens.bandDimmed : pens.dimmed
  const ink: Inking = style => (isDimmed ? dimmed(style) : pens.of(style))
  const mark = markOf(frame, row, dimmed)
  const ground = isBand ? pens.band : row.isNew ? pens.wash : undefined

  put(grid, LEFT, y, mark.glyph, mark.pen)

  if (key === view.expanded && height > 1) {
    expandedLines(frame, y, height, row, ink)
  } else {
    firstLine(frame, y, row, ink)

    if (height > 1) {
      secondLine(frame, y + 1, row, ink)
    }
  }

  for (let at = 0; ground !== undefined && at < height; at++) {
    lay(grid, y + at, LEFT, layout.width - 1, ground)
  }

  if (view.menu !== undefined && menu > 0) {
    menuAt(frame, view.menu)
  }
}

const drawPlaced = (frame: Frame, view: PanelView, placed: Placed) => {
  const { grid, pens } = frame

  switch (placed.kind) {
    case 'heading':
      return heading(frame, placed.y, placed.section)
    case 'row':
      return rowAt(frame, placed, view)
    case 'above':
      return put(grid, LEFT, placed.y, `▲ ${placed.count} more`, pens.of(STYLE.meta))
    case 'below':
      return put(grid, LEFT, placed.y, `▼ ${placed.count} more`, pens.of(STYLE.meta))
  }
}

/** A heading's lines over its words: the heading, a blank row, then the words wrapped in the rows left; the heading alone, cut, with no room for a word under it. */
const headed = (head: string, words: string, rows: number, cells: number) =>
  rows < 3 ? [cut(head, cells)].slice(0, rows) : [head, '', ...wrapIn(words, cells, rows - 2)]

/**
 * Words in the body's place, each line centred, the lines a little above
 * the middle: a heading in bold and a blank row, where there is one, then
 * the words in grey, wrapped at `cells`. Past the rows there are, the last
 * kept carries the rest, cut with `…`.
 */
const centred = ({ grid, layout, pens }: Frame, head: string | undefined, words: string, cells: number) => {
  const { from, to } = layout.words
  const right = layout.width - 1
  const lines = head === undefined ? wrapIn(words, cells, to - from) : headed(head, words, to - from, cells)
  const top = from + Math.max(0, Math.floor((to - from - lines.length) / 2) - 1)

  lines.forEach((line, at) => {
    const pen = head !== undefined && at === 0 ? pens.of(STYLE.strong) : pens.of(STYLE.meta)

    put(grid, LEFT + Math.floor((right - LEFT - widthOf(line)) / 2), top + at, line, pen)
  })
}

/** An empty board: `All clear`, then what it means, wrapped at 24 columns. */
const quiet = (frame: Frame) => centred(frame, 'All clear', QUIET, Math.min(frame.layout.width - 4, 24))

/** Before any board: `Looking for sessions…`, or why the board can't be read. */
const unread = (frame: Frame, reason: string | undefined) =>
  reason === undefined
    ? centred(frame, undefined, LOOKING, frame.layout.width - 4)
    : centred(frame, UNREADABLE, reason, frame.layout.width - 4)

/** The answer to a pick: `!`, then its words, hung under the first. */
const answer = ({ grid, layout, pens }: Frame) =>
  layout.answer.lines.forEach((line, at) => {
    if (at === 0) {
      put(grid, LEFT, layout.answer.from, '!', pens.of(STYLE.strong))
    }

    put(grid, LEFT + 2, layout.answer.from + at, line, pens.of(STYLE.answer))
  })

/** The keys the snooze menu takes, but `esc cancel`. */
const MENU_HINTS: Hint[] = [
  ['↑↓', 'pick'],
  ['⏎', 'snooze'],
]

const CANCEL: Hint = ['esc', 'cancel']

/** What `z` does to a row: wakes it in Snoozed, snoozes one that needs you, or nothing. */
const snoozeHint = (row: PanelRow | undefined): Hint[] => {
  if (row?.isSnoozed === true) {
    return [['z', 'wake']]
  }

  return row?.asks === undefined ? [] : [['z', 'snooze']]
}

/** The keys the band's row takes: `⏎` to expand it, or fold it again, `o` to open it, and `z` where it can be snoozed or woken. */
const bandHints = (view: PanelView): Hint[] => {
  const row = view.sections.flatMap(section => section.rows).find(each => rowKey(each) === view.band)

  return view.band === undefined
    ? []
    : [['⏎', view.expanded === undefined ? 'expand' : 'fold'], ['o', 'open'], ...snoozeHint(row)]
}

/**
 * The keys that work now, most needed first, and the one dropped last: in
 * the menu, its own and `esc cancel`; else `↑↓` only while a row is in view
 * to move to, the band's row's keys while there is one, `s` while Snoozed
 * holds rows, and `q quit`.
 */
const hintsOf = (view: PanelView, layout: Layout): { hints: Hint[]; last: Hint } => {
  if (view.menu !== undefined) {
    return { hints: MENU_HINTS, last: CANCEL }
  }

  const arrows: Hint[] = layout.rows.length === 0 ? [] : [['↑↓', view.band === undefined ? 'pick' : 'move']]
  const snoozed: Hint[] = layout.sections.some(section => section.kind === 'snoozed') ? [['s', 'snoozed']] : []

  return { hints: [...arrows, ...bandHints(view), ...snoozed], last: QUIT }
}

const hintsWidth = (hints: readonly Hint[]) =>
  hints.reduce((sum, [key, word], at) => sum + (at === 0 ? 0 : 2) + widthOf(key) + 1 + widthOf(word), 0)

/** On a board gone stale, when it was last read; else nothing. */
const staleOf = (view: PanelView) => (view.board === 'stale' && view.asOf !== undefined ? `as of ${view.asOf}` : undefined)

/**
 * The key line: on a board gone stale, when it was read, at the right end;
 * then the hints that fit left of it, dropped whole from the right, then the
 * last, which always applies, dropped last.
 */
const keyLine = ({ grid, layout, pens }: Frame, { hints, last }: { hints: readonly Hint[]; last: Hint }, stale: string | undefined) => {
  const y = layout.height - 1
  const room = layout.width - 1 - LEFT - (stale === undefined ? 0 : widthOf(stale) + 2)
  const kept = [...hints]

  if (stale !== undefined) {
    putRight(grid, layout.width - 1, y, stale, pens.of(STYLE.meta))
  }

  while (kept.length > 0 && hintsWidth([...kept, last]) > room) {
    kept.pop()
  }

  const shown = hintsWidth([...kept, last]) <= room ? [...kept, last] : []

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

  if (view.board === 'looking') {
    unread(frame, view.reason)
  } else if (layout.sections.length === 0) {
    quiet(frame)
  } else {
    layout.placed.forEach(placed => drawPlaced(frame, view, placed))
  }

  answer(frame)
  keyLine(frame, hintsOf(view, layout), staleOf(view))

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
