/**
 * Terminal output read into cells, and one grid of cells held to another, as
 * a golden frame is held to what the panel draws: termgrid's `read_ansi`,
 * `compare` and `describe` (design/paper/termgrid.py), in TypeScript.
 *
 * - A cell holds a grapheme in a pen: its foreground, its background, bold,
 *   faint and reverse. A colour is the terminal's own (`default`, `ansi:0`
 *   to `ansi:15`, `256:N`) or 24-bit (`#RRGGBB`), as the SGR said it.
 * - The reader applies output as a terminal its size would: SGR, newlines
 *   as carriage return and line feed, carriage returns, tabs, backspaces,
 *   the cursor moves and erases a live region makes (CSI A B C D G H f J K),
 *   and the wrap at the width. OSC draws nothing and is skipped, as are the
 *   cursor shown or hidden and synchronised output. Anything else is an
 *   error rather than a guess.
 * - A blank's ink and weight aren't compared, as nothing shows them.
 */
import { cellsOf, graphemesOf } from '../panel/cells'

export type Pen = { fg: string; bg: string; bold: boolean; faint: boolean; reverse: boolean }

/** A grapheme in its pen; the second cell of a wide one holds `''`. */
export type Cell = { glyph: string; pen: Pen }

export type Grid = { width: number; height: number; rows: Cell[][] }

/** A cell drawn otherwise than its frame, its row and column counted from 1. */
export type Difference = { row: number; col: number; frame: Cell; drawn: Cell }

const DEFAULT = 'default'

export const PLAIN: Pen = { fg: DEFAULT, bg: DEFAULT, bold: false, faint: false, reverse: false }

const BLANK: Cell = { glyph: ' ', pen: PLAIN }

/** The private modes read and drawn as nothing: the cursor shown or hidden, and synchronised output. */
const IGNORED_PRIVATE = new Set(['?25', '?2026'])

const CSI = /^\x1b\[([0-?]*)([ -/]*)([@-~])/

const OSC = /^\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/

/** A run of text with no escape and no control character in it. */
const PRINTABLE = /^[^\x00-\x1f\x7f-\x9f]+/

const unread = (what: string): never => {
  throw new Error(`${what} is not read`)
}

const isSamePen = (a: Pen, b: Pen) =>
  a.fg === b.fg && a.bg === b.bg && a.bold === b.bold && a.faint === b.faint && a.reverse === b.reverse

const isSameCell = (a: Cell, b: Cell) => a.glyph === b.glyph && isSamePen(a.pen, b.pen)

const hex = (channel: number) => channel.toString(16).toUpperCase().padStart(2, '0')

/** A number an SGR or a cursor move gives, empty read as 0; anything not digits refused. */
const numberIn = (code: string | undefined, seq: string): number =>
  code !== undefined && /^\d*$/.test(code) ? Number(code) : unread(`escape ${JSON.stringify(seq)}`)

/** 38 or 48's colour from the codes after it: `5;n` or `2;r;g;b`; and how many codes it took. */
const extendedColour = (codes: readonly string[], seq: string): { colour: string; took: number } => {
  const values = (count: number) => codes.slice(1, 1 + count).map(code => numberIn(code, seq))
  const inRange = (each: readonly number[], count: number) => each.length === count && each.every(value => value <= 255)

  if (codes[0] === '5' && inRange(values(1), 1)) {
    return { colour: `256:${values(1)[0]}`, took: 2 }
  }

  if (codes[0] === '2' && inRange(values(3), 3)) {
    return { colour: `#${values(3).map(hex).join('')}`, took: 4 }
  }

  return unread(`SGR ${JSON.stringify(seq)}: a colour neither 5;n nor 2;r;g;b`)
}

/** What each SGR attribute read sets, but the colours by number. */
const ATTRIBUTES: Readonly<Record<number, Partial<Pen>>> = {
  0: PLAIN,
  1: { bold: true },
  2: { faint: true },
  22: { bold: false, faint: false },
  7: { reverse: true },
  27: { reverse: false },
  39: { fg: DEFAULT },
  49: { bg: DEFAULT },
}

const isIn = (n: number, from: number, to: number) => n >= from && n <= to

/** What one SGR attribute sets; undefined for one not read. */
const attributeOf = (n: number): Partial<Pen> | undefined => {
  if (isIn(n, 30, 37) || isIn(n, 90, 97)) {
    return { fg: `ansi:${n < 90 ? n - 30 : n - 82}` }
  }

  if (isIn(n, 40, 47) || isIn(n, 100, 107)) {
    return { bg: `ansi:${n < 100 ? n - 40 : n - 92}` }
  }

  return ATTRIBUTES[n]
}

/** The pen an SGR's parameters leave, from `pen`. */
const withSgr = (pen: Pen, params: string, seq: string): Pen => {
  const codes = params === '' ? ['0'] : params.split(';')
  let at = 0
  let out = pen

  while (at < codes.length) {
    const n = numberIn(codes[at], seq)

    if (n === 38 || n === 48) {
      const { colour, took } = extendedColour(codes.slice(at + 1), seq)

      out = n === 38 ? { ...out, fg: colour } : { ...out, bg: colour }
      at += took + 1
      continue
    }

    out = { ...out, ...(attributeOf(n) ?? unread(`SGR ${JSON.stringify(seq)}: attribute ${n}`)) }
    at++
  }

  return out
}

/** The terminal's size, either or both left unbounded. */
export type Bounds = { width?: number; height?: number }

/** A terminal as the reader applies output to it: the rows written, the cursor, and the pen. */
class Screen {
  rows: Cell[][] = [[]]
  top = 0
  row = 0
  col = 0
  pen: Pen = PLAIN

  constructor(readonly bounds: Bounds) {}

  private get width() {
    return this.bounds.width ?? 0
  }

  private get height() {
    return this.bounds.height ?? 0
  }

  private blank(): Cell {
    return { glyph: ' ', pen: { ...PLAIN, bg: this.pen.bg } }
  }

  private at(row: number): Cell[] {
    while (this.rows.length <= row) {
      this.rows.push([])
    }

    return this.rows[row] as Cell[]
  }

  private lineFeed() {
    if (this.height > 0 && this.row === this.top + this.height - 1) {
      this.top++
    }

    this.row++
    this.at(this.row)
  }

  /** A mark with no cell of its own, joined to the glyph before the cursor. */
  private join(mark: string) {
    const row = this.at(this.row)

    for (let x = Math.min(this.col, row.length) - 1; x >= 0; x--) {
      const cell = row[x] as Cell

      if (cell.glyph !== '') {
        row[x] = { glyph: cell.glyph + mark, pen: cell.pen }
        return
      }
    }

    throw new Error(`${JSON.stringify(mark)} joins no glyph`)
  }

  private put(glyph: string) {
    const cells = cellsOf(glyph)

    if (cells === 0) {
      return this.join(glyph)
    }

    if (this.width > 0 && this.col + cells > this.width) {
      this.col = 0
      this.lineFeed()
    }

    const row = this.at(this.row)

    while (row.length < this.col + cells) {
      row.push(BLANK)
    }

    row[this.col] = { glyph, pen: this.pen }

    if (cells === 2) {
      row[this.col + 1] = { glyph: '', pen: this.pen }
    }

    this.col += cells
  }

  private eraseLine(mode: number) {
    const row = this.at(this.row)
    const col = this.width > 0 ? Math.min(this.col, this.width - 1) : this.col

    if (mode === 0) {
      row.length = Math.min(row.length, col)

      if (this.pen.bg !== DEFAULT && this.width > 0) {
        row.push(...Array.from({ length: this.width - col }, () => this.blank()))
      }
    } else if (mode === 1) {
      for (let x = 0; x < Math.min(col + 1, row.length); x++) {
        row[x] = this.blank()
      }
    } else {
      row.length = 0
    }
  }

  private eraseBelow(mode: number, seq: string) {
    if (mode === 0) {
      this.eraseLine(0)
      this.rows.length = this.row + 1
    } else if (mode === 2) {
      for (let y = this.top; y < this.rows.length; y++) {
        this.rows[y] = []
      }
    } else {
      unread(`escape ${JSON.stringify(seq)}`)
    }
  }

  /** A cursor move or an erase, its first number at least 1 where it counts. */
  private move(final: string, nums: readonly number[], seq: string) {
    const n = Math.max(nums[0] ?? 1, 1)

    switch (final) {
      case 'A':
        if (this.row - n < this.top) {
          throw new Error(`escape ${JSON.stringify(seq)} moves up past the screen's top`)
        }

        this.row -= n
        return
      case 'B':
        this.row = this.height > 0 ? Math.min(this.row + n, this.top + this.height - 1) : this.row + n
        this.at(this.row)
        return
      case 'C':
        this.col = this.width > 0 ? Math.min(this.col + n, this.width - 1) : this.col + n
        return
      case 'D':
        this.col = Math.max(this.col - n, 0)
        return
      case 'G':
        this.col = n - 1
        return
      case 'H':
      case 'f':
        this.row = this.top + n - 1
        this.col = Math.max(nums[1] ?? 1, 1) - 1
        this.at(this.row)
        return
      case 'J':
        return this.eraseBelow(nums[0] ?? 0, seq)
      case 'K':
        return this.eraseLine(nums[0] ?? 0)
      default:
        unread(`escape ${JSON.stringify(seq)}`)
    }
  }

  private csi(params: string, inter: string, final: string, seq: string) {
    if (params.startsWith('?')) {
      return inter === '' && (final === 'h' || final === 'l') && IGNORED_PRIVATE.has(params)
        ? undefined
        : unread(`escape ${JSON.stringify(seq)}`)
    }

    if (inter !== '') {
      return unread(`escape ${JSON.stringify(seq)}`)
    }

    if (final === 'm') {
      this.pen = withSgr(this.pen, params, seq)
      return
    }

    this.move(final, params === '' ? [] : params.split(';').map(each => numberIn(each, seq)), seq)

    if (this.width > 0 && this.col >= this.width) {
      this.col = this.width - 1
    }
  }

  /** An escape at the text's start, applied; gives how much of the text it took. */
  private escape(text: string): number {
    const csi = CSI.exec(text)

    if (csi !== null) {
      this.csi(csi[1] ?? '', csi[2] ?? '', csi[3] ?? '', csi[0])
      return csi[0].length
    }

    const osc = OSC.exec(text)

    return osc === null ? unread(`escape ${JSON.stringify(text.slice(0, 6))}`) : osc[0].length
  }

  /** A control character the reader moves by. */
  private control(char: string) {
    if (char === '\n') {
      this.col = 0
      this.lineFeed()
    } else if (char === '\r') {
      this.col = 0
    } else if (char === '\t') {
      const next = (Math.floor(this.col / 8) + 1) * 8

      this.col = this.width > 0 ? Math.min(next, this.width - 1) : next
    } else if (char === '\b') {
      this.col = Math.max(this.col - 1, 0)
    } else {
      throw new Error(`control character ${JSON.stringify(char)}`)
    }
  }

  feed(text: string) {
    let at = 0

    while (at < text.length) {
      const rest = text.slice(at)
      const printable = PRINTABLE.exec(rest)

      if (printable !== null) {
        graphemesOf(printable[0]).forEach(glyph => this.put(glyph))
        at += printable[0].length
      } else if (rest.startsWith('\x1b')) {
        at += this.escape(rest)
      } else {
        this.control(rest[0] as string)
        at++
      }
    }
  }
}

/**
 * Output as a grid, applied as a terminal of the bounds would apply it.
 * With no width, nothing wraps and the grid is as wide as its widest row.
 * The grid holds every row written, the scrollback too, the blank rows at
 * its foot left off; with a height and `scrollback` false, the screen only.
 */
export const read = (text: string, bounds: Bounds = {}, scrollback = true): Grid => {
  const screen = new Screen(bounds)

  screen.feed(text)

  const { height } = bounds
  let rows = screen.rows

  if (height !== undefined && !scrollback) {
    rows = rows.slice(screen.top, screen.top + height)
    rows.push(...Array.from({ length: height - rows.length }, () => []))
  } else {
    while (rows.length > 0 && rows.at(-1)?.length === 0) {
      rows = rows.slice(0, -1)
    }
  }

  const width = bounds.width ?? Math.max(0, ...rows.map(row => row.length))

  return {
    width,
    height: rows.length,
    rows: rows.map(row => Array.from({ length: width }, (_, x) => row[x] ?? BLANK)),
  }
}

/** A row's glyphs, its trailing blanks trimmed. */
export const textOf = (grid: Grid, y: number): string =>
  (grid.rows[y] ?? []).map(cell => cell.glyph).join('').trimEnd()

/** Whether two cells look alike: glyph, ground and reverse, and the pen whole but on a blank. */
const isAlike = (a: Cell, b: Cell) =>
  a.glyph === b.glyph &&
  a.pen.bg === b.pen.bg &&
  a.pen.reverse === b.pen.reverse &&
  (a.glyph === ' ' || isSamePen(a.pen, b.pen))

/**
 * The cells `drawn` differs from `frame` in. A drawn row may be shorter than
 * the frame's, read as blank, never wider; the heights must agree.
 */
export const compare = (frame: Grid, drawn: Grid): Difference[] => {
  if (drawn.height !== frame.height) {
    throw new Error(`drawn ${drawn.height} rows, where the frame has ${frame.height}`)
  }

  const width = Math.max(frame.width, drawn.width)
  const diffs: Difference[] = []

  for (let y = 0; y < frame.height; y++) {
    for (let x = 0; x < width; x++) {
      const a = frame.rows[y]?.[x] ?? BLANK
      const b = drawn.rows[y]?.[x] ?? BLANK

      if (x >= frame.width && !isSameCell(b, BLANK)) {
        throw new Error(`row ${y + 1} drawn past the frame's ${frame.width} columns`)
      }

      if (!isAlike(a, b)) {
        diffs.push({ row: y + 1, col: x + 1, frame: a, drawn: b })
      }
    }
  }

  return diffs
}

const named = ({ glyph, pen }: Cell) => {
  const attributes = (['bold', 'faint', 'reverse'] as const).filter(each => pen[each]).map(each => ` ${each}`)

  return `${JSON.stringify(glyph)} ${pen.fg} on ${pen.bg}${attributes.join('')}`
}

/** Where `name` is drawn otherwise than its frame: a line a cell for the first `shown`, then how many more. */
export const describe = (name: string, diffs: readonly Difference[], shown = 20): string =>
  [
    `${name} draws ${diffs.length} cells otherwise than its frame:`,
    ...diffs
      .slice(0, shown)
      .map(each => `  row ${each.row}, column ${each.col}: the frame's ${named(each.frame)}, drawn ${named(each.drawn)}`),
    ...(diffs.length > shown ? [`  and ${diffs.length - shown} more`] : []),
  ].join('\n')
