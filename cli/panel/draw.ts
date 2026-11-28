/**
 * The panel drawn: a view to lines at a size, with no clock and no terminal.
 * Where each part goes is the layout's (layout.ts); this draws them.
 *
 * - Every line starts at column 1, and the layout's last column is a margin
 *   too.
 * - A section's heading: its words in grey capitals, its counts, a rule and
 *   the chevron. Without colour an ask's count is bold and a turn's regular,
 *   as their names are, since the two share `●`.
 * - A row is a session on one line, as the notch draws it: its mark, its
 *   words, its project in grey and its time in its section's lane; what
 *   each part shows, and how each gives way, is line.ts's.
 * - The chosen row expanded cuts nothing: its words wrap over the lines the
 *   layout gives it (expand.ts), the band over them all.
 * - On the chosen row, where the view answers one of its asks, `▹` stands
 *   in the time's place, expanded or not, in the terminal's ink, bold,
 *   dimmed with an away row's words; `▿` while its asks are open under it
 *   (asks.ts), the band over every line of the row and its asks, so they
 *   read as one card.
 * - An answer sending is ink on white, the background's colour on the
 *   terminal's ink, from its number's column to W−2, `✓` at W−2, the band
 *   not under it (round 5); the sending line stands in the foot's place,
 *   and the key line reads `u undo  esc close`.
 * - An empty board, and one not yet read, stand centred in the body's place.
 * - The snooze menu stands under the chosen row, a choice a line, each of
 *   the first nine after its number, the band on the choice picked rather
 *   than on the row.
 * - The key line drops whole hints from the right, `q quit` last, or in the
 *   menu `esc cancel`, or with a row's asks open `esc close`.
 * - There is no title: row 0 is blank, and gives way first, short of room
 *   (Lee, 20 November 2026). Nothing is drawn on it.
 * - A board gone stale says when it was read, at the key line's right end;
 *   the keys are cut to the room left of it.
 * - Below 24 columns or 8 rows it draws only `Too small`, on row 1 while
 *   there is one.
 */
import {
  ANSWER,
  askingIn,
  asksLinesOf,
  CHECK,
  hintColumns,
  hintsWidth,
  sendingColumns,
  UNDO,
  type AnswerTag,
  type Asking,
  type AsksLine,
  type Hint,
  type SendingLine,
} from './asks'
import { cellsOf, cut, graphemesOf, widthOf, wrapIn, type Size, type Tagged } from './cells'
import { expandedOf, type Tag } from './expand'
import { DIGITS } from './keys'
import { isTooSmall, layoutOf, LEFT, topRowOf, type Layout, type Placed, type Section } from './layout'
import { fittedOf, NAME, type Lane } from './line'
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
  pick: { tone: 'pick' },
  pickTag: { tone: 'pickTag', isMeta: true },
  shownDot: { tone: 'orange', bold: true },
  otherDot: { tone: 'rule', isMeta: true },
  ring: { tone: 'orange' },
} satisfies Record<string, Style>

/** On the chosen row, where the view answers one of its asks: its asks to open, or open. */
const ARROW = { folded: '▹', open: '▿' }

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

/** The style of a row's words, its name's or its status line's: grey in Snoozed, an ask's bold; else as its mark says. */
const nameStyle = (row: PanelRow): Style =>
  row.isSnoozed ? { tone: 'grey', bold: row.mark === 'ask', isMeta: true } : MARKS[row.mark].name

/** A row on its one line: its words from the names' column, then its count in grey; its project in grey, right-aligned in its section's column; and its time in the section's lane, or an arrow in its place. */
const oneLine = ({ grid, layout }: Frame, y: number, row: PanelRow, lane: Lane, ink: Inking, arrow?: string) => {
  const fitted = fittedOf(row, layout.width, lane)
  const after = put(grid, NAME, y, fitted.words, ink(nameStyle(row)))

  put(grid, after, y, fitted.count, ink(STYLE.meta))
  putRight(grid, fitted.projectEnd, y, fitted.project, ink(STYLE.meta))
  putRight(grid, layout.width - 1, y, arrow ?? fitted.time, ink(arrow === undefined ? STYLE.meta : STYLE.strong))
}

/** The words of a line of an expanded row from the names' column, a space between each two, each in its tag's style, the space before it among them. */
const words = (grid: Grid, y: number, line: readonly Tagged<Tag>[], styles: Record<Tag, Pen>) =>
  line.reduce((x, word, at) => put(grid, x, y, at === 0 ? word.text : ` ${word.text}`, styles[word.tag]), NAME)

/**
 * The chosen row expanded, in the two lines or more the layout gives it (in a
 * body of one row it is drawn as its folded line instead): its words whole,
 * the time at the first line's right, or an arrow in its place; where the
 * body cuts it short, its last line kept, never its first, says `…`.
 */
const expandedLines = ({ grid, layout }: Frame, y: number, height: number, row: PanelRow, lane: Lane, ink: Inking, arrow?: string) => {
  const { time, lines } = expandedOf(row, layout.width, lane)
  const styles: Record<Tag, Pen> = { name: ink(nameStyle(row)), meta: ink(STYLE.meta), status: ink(STYLE.status) }
  const isCut = lines.length > height

  lines.slice(0, height).forEach((line, at) => {
    const isLast = isCut && at === height - 1

    words(grid, y + at, isLast ? [{ text: '…', tag: 'meta' }] : line, styles)
  })
  putRight(grid, layout.width - 1, y, arrow ?? time, arrow === undefined ? styles.meta : ink(STYLE.strong))
}

/** Hints from column `x`, each key bold in the terminal's ink and its word grey, two spaces between each two. */
const hinted = (grid: Grid, pens: Pens, x: number, y: number, hints: readonly Hint[]) =>
  hintColumns(hints, x).forEach(({ hint: [key, word], x: at }) => {
    put(grid, put(grid, at, y, key, pens.of(STYLE.strong)), y, ` ${word}`, pens.of(STYLE.meta))
  })

const ANSWER_STYLES: Record<AnswerTag, Style> = { answer: STYLE.answer, pick: STYLE.pick, tag: STYLE.pickTag }

/** An answer's line: its number in grey on its first, for the first nine, then its words; held, all in ink on white, the check at its first line's right. */
const answerLine = ({ grid, layout, pens }: Frame, y: number, line: Extract<AsksLine, { part: 'answer' }>) => {
  const number = line.isFirst && line.index < DIGITS ? String(line.index + 1) : ''
  const runPen = (tag: AnswerTag) => (line.isHeld ? (tag === 'tag' ? pens.heldTag : pens.held) : pens.of(ANSWER_STYLES[tag]))

  put(grid, NAME, y, number.padEnd(1), line.isHeld ? pens.held : pens.of(STYLE.meta))
  line.runs.reduce((x, run) => put(grid, x, y, run.text, runPen(run.tag)), ANSWER)

  if (line.isHeld && line.isFirst) {
    put(grid, layout.width - 2, y, CHECK, pens.held)
  }
}

/** The sending line: `Sending` in grey and the answer's words in the ink, or `Ignoring`, then the ring in orange and `u undo`. */
const sendingLine = ({ grid, pens }: Frame, y: number, line: SendingLine) => {
  const at = sendingColumns(line)

  put(grid, NAME, y, line.lead, pens.of(STYLE.meta))
  put(grid, at.words, y, line.words, pens.of(STYLE.answer))
  put(grid, at.ring, y, line.ring, pens.of(STYLE.ring))
  hinted(grid, pens, at.undo, y, [UNDO])
}

/** A line of the opened row: the head's in the row's own looks, dimmed as the row is; the ask's in its own. */
const asksLine = (frame: Frame, y: number, line: AsksLine, asking: Asking, lane: Lane, ink: Inking) => {
  const { grid, pens } = frame
  const styles: Record<Tag, Pen> = { name: ink(nameStyle(asking.row)), meta: ink(STYLE.meta), status: ink(STYLE.status) }

  switch (line.part) {
    case 'head':
    case 'project':
      return words(grid, y, line.words, styles)
    case 'folded':
      return oneLine(frame, y, asking.row, lane, ink, ARROW.open)
    case 'title':
      return put(grid, NAME, y, line.text, pens.of(STYLE.strong))
    case 'asked':
      put(grid, NAME, y, line.text, pens.of(STYLE.meta))

      return line.dots.forEach(dot => put(grid, dot.x, y, dot.text, pens.of(dot.isShown ? STYLE.shownDot : STYLE.otherDot)))
    case 'answer':
      return answerLine(frame, y, line)
    case 'foot':
      return hinted(grid, pens, NAME, y, line.hints)
    case 'sending':
      return sendingLine(frame, y, line)
  }
}

const isHeldLine = (line: AsksLine) => line.part === 'answer' && line.isHeld

/**
 * The row with its asks open under it, in the lines the layout gives it:
 * its head, `▿` at its first line's right, then the ask shown, an answer
 * sending ink on white from its number's column. Gives the lines the row's
 * ground lies over: every one but the answer sending's.
 */
const askingLines = (frame: Frame, y: number, height: number, asking: Asking, lane: Lane, ink: Inking): number[] => {
  const { grid, layout, pens } = frame
  const lines = asksLinesOf(asking, layout.width, lane, height)

  lines.forEach((line, at) => {
    if (isHeldLine(line)) {
      lay(grid, y + at, NAME, layout.width - 1, pens.held)
    }

    asksLine(frame, y + at, line, asking, lane, ink)
  })

  if (lines[0]?.part === 'head') {
    putRight(grid, layout.width - 1, y, ARROW.open, ink(STYLE.strong))
  }

  return lines.flatMap((line, at) => (isHeldLine(line) ? [] : [at]))
}

/** A row not opened, on its one line, or expanded on the lines the layout gives it. Gives the lines the row's ground lies over: all of them. */
const restingLines = (frame: Frame, { y, row, lane, key, height }: Extract<Placed, { kind: 'row' }>, view: PanelView, ink: Inking, arrow?: string): number[] => {
  if (key === view.expanded && height > 1) {
    expandedLines(frame, y, height, row, lane, ink, arrow)
  } else {
    oneLine(frame, y, row, lane, ink, arrow)
  }

  return Array.from({ length: height }, (_, at) => at)
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

/** Where a snooze choice's name starts: past its number and a space. */
const CHOICE = NAME + 2

/**
 * The snooze menu under its row, a choice a line: its number in the names'
 * column, in grey, as the key line's words, for the first nine; its name
 * after it, in the terminal's ink, numbered or not; and its time at the
 * right in grey, where both fit. The band on the choice picked, its name
 * bold.
 */
const menuAt = ({ grid, layout, pens }: Frame, menu: NonNullable<PanelView['menu']>) => {
  const room = layout.width - 1 - CHOICE
  const { y, lines, first } = layout.menu ?? { y: 0, lines: 0, first: 0 }

  menu.options.slice(first, first + lines).forEach((option, at) => {
    const index = first + at
    const isPicked = index === menu.at
    const time = widthOf(option.title) + 2 + widthOf(option.time) <= room ? option.time : ''

    if (index < DIGITS) {
      put(grid, NAME, y + at, String(index + 1), pens.of(STYLE.meta))
    }

    put(grid, CHOICE, y + at, cut(option.title, room), pens.of({ tone: 'ink', bold: isPicked }))
    putRight(grid, layout.width - 1, y + at, time, pens.of(STYLE.meta))

    if (isPicked) {
      lay(grid, y + at, LEFT, layout.width - 1, pens.band)
    }
  })
}

/**
 * A row on its lines: its one, folded, or where its menu leaves it no more,
 * expanded or not, so the menu always says whose it is; expanded, as many
 * as the layout gives it; the band or the wash over every one. With its
 * menu open the band is the menu's, on the choice picked.
 */
const rowAt = (frame: Frame, placed: Extract<Placed, { kind: 'row' }>, view: PanelView) => {
  const { grid, layout, pens } = frame
  const { y, row, lane, key, height, menu } = placed
  const isBand = key === view.band && view.menu === undefined
  const isDimmed = row.isAway && !row.isSnoozed
  const dimmed = isBand ? pens.bandDimmed : pens.dimmed
  const ink: Inking = style => (isDimmed ? dimmed(style) : pens.of(style))
  const mark = markOf(frame, row, dimmed)
  const ground = isBand ? pens.band : row.isNew ? pens.wash : undefined
  const asking = askingIn(view, row)
  const arrow = isBand && row.answerable !== undefined ? ARROW.folded : undefined

  put(grid, LEFT, y, mark.glyph, mark.pen)

  const grounded = asking === undefined ? restingLines(frame, placed, view, ink, arrow) : askingLines(frame, y, height, asking, lane, ink)

  grounded.forEach(at => ground !== undefined && lay(grid, y + at, LEFT, layout.width - 1, ground))

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
 * Words in the body's place, under its top row while that stays, each line
 * centred, the lines a little above the middle: a heading in bold and a
 * blank row, where there is one, then the words in grey, wrapped at
 * `cells`. Past the rows there are, the last kept carries the rest, cut
 * with `…`.
 */
const centred = ({ grid, layout, pens }: Frame, head: string | undefined, words: string, cells: number) => {
  const linesIn = (rows: number) => (head === undefined ? wrapIn(words, cells, rows) : headed(head, words, rows, cells))
  const { from: place, to } = layout.words
  const from = place + topRowOf(linesIn(to - place).length, to - place)
  const right = layout.width - 1
  const lines = linesIn(to - from)
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

const CLOSE: Hint = ['esc', 'close']

/** What `z` does to a row: wakes it in Snoozed, snoozes one that needs you, or nothing. */
const snoozeHint = (row: PanelRow | undefined): Hint[] => {
  if (row?.isSnoozed === true) {
    return [['z', 'wake']]
  }

  return row?.asks === undefined ? [] : [['z', 'snooze']]
}

/** What `⏎` does to the band's row: opens its asks, where the view answers one; else expands it, or folds it again. */
const lookCloser = (row: PanelRow | undefined, view: PanelView) => {
  if (row?.answerable !== undefined) {
    return 'asks'
  }

  return view.expanded === undefined ? 'expand' : 'fold'
}

const bandRowOf = (view: PanelView) => view.sections.flatMap(section => section.rows).find(each => rowKey(each) === view.band)

/** The keys the band's row takes: `⏎` to look closer, `o` to open it, and `z` where it can be snoozed or woken. */
const bandHints = (view: PanelView): Hint[] => {
  const row = bandRowOf(view)

  return view.band === undefined ? [] : [['⏎', lookCloser(row, view)], ['o', 'open'], ...snoozeHint(row)]
}

/** The keys a row's asks take, open: while an answer sends, `u undo`; else the digits of the ask's answers, `1–3`, or `1` for one; `←→` where the row has more than one ask. */
const askingHints = ({ ask, asks }: Asking, view: PanelView): Hint[] => {
  if (view.sending !== undefined) {
    return [UNDO]
  }

  const answers = Math.min(ask.answers.length, DIGITS)
  const digits: Hint[] = answers === 0 ? [] : [[answers === 1 ? '1' : `1–${answers}`, 'answer']]

  return [...digits, ...(asks.length > 1 ? [['←→', 'ask'] satisfies Hint] : [])]
}

/**
 * The keys that work now, most needed first, and the one dropped last: in
 * the menu, its own, `u undo` while an answer sends, and `esc cancel`; else
 * `↑↓` only while a row is in view to move to, the band's row's keys while
 * there is one, `s` while Snoozed holds rows, and `q quit`.
 */
const hintsOf = (view: PanelView, layout: Layout): { hints: Hint[]; last: Hint } => {
  if (view.menu !== undefined) {
    return { hints: [...MENU_HINTS, ...(view.sending === undefined ? [] : [UNDO])], last: CANCEL }
  }

  const row = bandRowOf(view)
  const asking = row === undefined ? undefined : askingIn(view, row)

  if (asking !== undefined) {
    return { hints: askingHints(asking, view), last: CLOSE }
  }

  const arrows: Hint[] = layout.rows.length === 0 ? [] : [['↑↓', view.band === undefined ? 'pick' : 'move']]
  const snoozed: Hint[] = layout.sections.some(section => section.kind === 'snoozed') ? [['s', 'snoozed']] : []

  return { hints: [...arrows, ...bandHints(view), ...snoozed], last: QUIT }
}

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

  hinted(grid, pens, LEFT, y, shown)
}

const tooSmall = (size: Size): Line[] => {
  const grid = gridOf(size)

  put(grid, LEFT, topRowOf(1, size.height), cut('Too small', size.width - 2), {})

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
