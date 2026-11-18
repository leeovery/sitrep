/**
 * A screen as Ghostty paints it in Lee's theme, Nord Wave, for the app to
 * draw (app/screens): each row's runs of cells painted alike, from the
 * column each starts at, every paint worked out to the colours drawn. A cell
 * with no colour is the theme's foreground; one with no background has the
 * theme's own. Dim is drawn at half strength over its background, as
 * Ghostty's faint is.
 */
import type { Cell, Paint } from './cells'
import type { Screen } from './claude'

/** Nord Wave, Ghostty's theme of the name: its background, foreground and cursor. */
export const NORD_WAVE = { background: '#212121', foreground: '#d8dee9', cursor: '#ebcb8b' } as const

/** Cells painted alike, from the column the first of them stands in. */
export type Run = {
  column: number
  text: string
  ink: string
  ground?: string
  bold?: true
  italic?: true
}

/** What the app draws: the terminal's columns, its theme, its rows of runs, and its cursor. */
export type Terminal = {
  columns: number
  background: string
  rows: Run[][]
  cursor: { row: number; column: number; color: string }
}

const channels = (hex: string) => [1, 3, 5].map(at => Number.parseInt(hex.slice(at, at + 2), 16))

const hexOf = (values: readonly number[]) =>
  `#${values.map(value => Math.round(value).toString(16).padStart(2, '0')).join('')}`

/** Half way from `over` to `color`: faint text on its background. */
export const faint = (color: string, over: string) => {
  const under = channels(over)

  return hexOf(channels(color).map((value, i) => (value + (under[i] ?? 0)) / 2))
}

/** The colour a cell's glyph is drawn in. */
export const inkOf = ({ color, background, dim }: Paint) => {
  const ink = color ?? NORD_WAVE.foreground

  return dim === true ? faint(ink, background ?? NORD_WAVE.background) : ink
}

/** A cell's paint as drawn: its ink, its own background where it has one, bold and italic where it is. */
const drawn = (paint: Paint): Omit<Run, 'column' | 'text'> => ({
  ink: inkOf(paint),
  ...(paint.background === undefined ? {} : { ground: paint.background }),
  ...(paint.bold === true ? { bold: true } : {}),
  ...(paint.italic === true ? { italic: true } : {}),
})

const alike = (a: Omit<Run, 'column' | 'text'>, b: Omit<Run, 'column' | 'text'>) =>
  a.ink === b.ink && a.ground === b.ground && a.bold === b.bold && a.italic === b.italic

/** A row's cells as runs painted alike. */
export const runsOf = (row: readonly Cell[]) =>
  row.reduce<Run[]>((runs, cell, column) => {
    const paint = drawn(cell.paint)
    const last = runs.at(-1)

    if (last !== undefined && alike(last, paint)) {
      last.text += cell.char
    } else {
      runs.push({ column, text: cell.char, ...paint })
    }

    return runs
  }, [])

/** A screen as Ghostty paints it. */
export const terminalOf = (screen: Screen): Terminal => ({
  columns: Math.max(0, ...screen.rows.map(row => row.length)),
  background: NORD_WAVE.background,
  rows: screen.rows.map(runsOf),
  cursor: { ...screen.cursor, color: NORD_WAVE.cursor },
})
