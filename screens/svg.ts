/**
 * Rows of cells as an SVG of a terminal window, for the README: every
 * glyph placed at its own cell, so the columns line up in whatever
 * monospace font the reader's device has, and the box-drawing characters
 * drawn as lines across their cells, as Ghostty draws them, so rules and
 * trees join whatever the font. Painted over Tokyo Night, the theme the
 * board's palette is (hooks/look.ts); dim text at half strength over its
 * background, as Ghostty's faint is.
 */
import type { Cell, Paint } from './cells'

/** The terminal: Tokyo Night's background and foreground. */
export const TERMINAL = { background: '#1a1b26', foreground: '#c0caf5' } as const

/** A cell's size and the font's, in the SVG's units. */
const CELL = { across: 8.4, down: 18, font: 14, baseline: 13.5 }

/** The window round the cells: its title bar, its margin, its corner and its lights. */
const WINDOW = {
  bar: 30,
  margin: 14,
  radius: 10,
  barColor: '#16161e',
  edge: '#2f334d',
  lights: ['#ff5f57', '#febc2e', '#28c840'],
  title: '#7a82ab',
}

const FONT =
  "ui-monospace, 'SF Mono', SFMono-Regular, Menlo, Consolas, 'Liberation Mono', 'DejaVu Sans Mono', monospace"

/** How each box-drawing character joins its cell's sides: up, right, down, left, and whether its corner is round. */
const JOINS: Record<
  string,
  { up?: boolean; right?: boolean; down?: boolean; left?: boolean; round?: boolean }
> = {
  '─': { left: true, right: true },
  '━': { left: true, right: true },
  '│': { up: true, down: true },
  '├': { up: true, down: true, right: true },
  '└': { up: true, right: true },
  '┌': { down: true, right: true },
  '┐': { down: true, left: true },
  '┘': { up: true, left: true },
  '╭': { down: true, right: true, round: true },
  '╮': { down: true, left: true, round: true },
  '╰': { up: true, right: true, round: true },
  '╯': { up: true, left: true, round: true },
}

/** The characters drawn heavy. */
const HEAVY = new Set(['━'])

/** The characters that only run across their cells, a run of which is one line. */
const RULES = new Set(['─', '━'])

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
  const ink = color ?? TERMINAL.foreground

  return dim === true ? faint(ink, background ?? TERMINAL.background) : ink
}

const number = (value: number) => String(Math.round(value * 100) / 100)

const escaped = (text: string) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

/** Consecutive cells of a row alike by `key`, with the column each run starts at. */
const runsOf = <K>(row: readonly Cell[], key: (cell: Cell) => K | undefined) =>
  row.reduce<{ key: K; start: number; cells: Cell[] }[]>((runs, cell, column) => {
    const each = key(cell)
    const last = runs.at(-1)

    if (each === undefined) {
      return runs
    }

    if (last !== undefined && last.key === each && last.start + last.cells.length === column) {
      last.cells.push(cell)
    } else {
      runs.push({ key: each, start: column, cells: [cell] })
    }

    return runs
  }, [])

/** The backgrounds of a row, as rectangles. */
const backgrounds = (row: readonly Cell[], y: number) =>
  runsOf(row, cell => cell.paint.background).map(
    ({ key, start, cells }) =>
      `<rect x="${number(start * CELL.across)}" y="${number(y)}" width="${number(cells.length * CELL.across)}" height="${CELL.down}" fill="${key}"/>`,
  )

const textKey = (cell: Cell) =>
  cell.char === ' ' || cell.char in JOINS
    ? undefined
    : [inkOf(cell.paint), cell.paint.bold === true, cell.paint.italic === true].join(' ')

/** The glyphs of a row, as a text element for each run painted alike, each glyph at its own cell. */
const glyphs = (row: readonly Cell[], y: number) =>
  runsOf(row, textKey).map(({ start, cells }) => {
    const [first] = cells
    const paint = first?.paint ?? {}
    const xs = cells.map((_, i) => number((start + i) * CELL.across)).join(' ')
    const weight = paint.bold === true ? ' font-weight="700"' : ''
    const slant = paint.italic === true ? ' font-style="italic"' : ''
    const text = escaped(cells.map(cell => cell.char).join(''))

    return `<text x="${xs}" y="${number(y + CELL.baseline)}" fill="${inkOf(paint)}"${weight}${slant}>${text}</text>`
  })

/** The path a box-drawing character takes across its cell, from the cell's middle to each side it joins. */
const strokeOf = (char: string, x: number, y: number) => {
  const join = JOINS[char] ?? {}
  const mx = x + CELL.across / 2
  const my = y + CELL.down / 2
  const r = CELL.across / 2

  if (join.round === true) {
    const toY = join.up === true ? y : y + CELL.down
    const toX = join.left === true ? x : x + CELL.across
    const sweep = (join.up === true) === (join.left === true) ? 1 : 0
    const bendY = join.up === true ? my - r : my + r
    const bendX = join.left === true ? mx - r : mx + r

    return `M${number(mx)} ${number(toY)}V${number(bendY)}A${number(r)} ${number(r)} 0 0 ${sweep} ${number(bendX)} ${number(my)}H${number(toX)}`
  }

  return [
    join.up === true ? `M${number(mx)} ${number(my)}V${number(y)}` : '',
    join.down === true ? `M${number(mx)} ${number(my)}V${number(y + CELL.down)}` : '',
    join.left === true ? `M${number(mx)} ${number(my)}H${number(x)}` : '',
    join.right === true ? `M${number(mx)} ${number(my)}H${number(x + CELL.across)}` : '',
  ].join('')
}

/** The box-drawing characters of a row, as a path for each run painted alike. */
const lines = (row: readonly Cell[], y: number) =>
  runsOf(row, cell =>
    cell.char in JOINS ? `${inkOf(cell.paint)} ${HEAVY.has(cell.char) ? 2 : 1}` : undefined,
  ).map(({ key, start, cells }) => {
    const [ink, width] = key.split(' ')
    const isRule = cells.every(cell => RULES.has(cell.char))
    const path = isRule
      ? `M${number(start * CELL.across)} ${number(y + CELL.down / 2)}H${number((start + cells.length) * CELL.across)}`
      : cells.map((cell, i) => strokeOf(cell.char, (start + i) * CELL.across, y)).join('')

    return `<path d="${path}" stroke="${ink}" stroke-width="${width}" fill="none"/>`
  })

/** The window round the cells, its title bar's lights and its title. */
const frame = (width: number, height: number, title: string) => {
  const lights = WINDOW.lights.map(
    (color, i) =>
      `<circle cx="${WINDOW.margin + 6 + i * 20}" cy="${WINDOW.bar / 2}" r="6" fill="${color}"/>`,
  )

  return [
    `<rect x="0.5" y="0.5" width="${number(width - 1)}" height="${number(height - 1)}" rx="${WINDOW.radius}" fill="${TERMINAL.background}" stroke="${WINDOW.edge}"/>`,
    `<path d="M0.5 ${WINDOW.bar}V${WINDOW.radius + 0.5}A${WINDOW.radius - 0.5} ${WINDOW.radius - 0.5} 0 0 1 ${WINDOW.radius} 0.5H${number(width - WINDOW.radius)}A${WINDOW.radius - 0.5} ${WINDOW.radius - 0.5} 0 0 1 ${number(width - 0.5)} ${WINDOW.radius + 0.5}V${WINDOW.bar}Z" fill="${WINDOW.barColor}"/>`,
    `<path d="M0.5 ${WINDOW.bar}H${number(width - 0.5)}" stroke="${WINDOW.edge}"/>`,
    ...lights,
    `<text x="${number(width / 2)}" y="${WINDOW.bar / 2 + 4.5}" fill="${WINDOW.title}" text-anchor="middle">${escaped(title)}</text>`,
  ]
}

/** Rows of cells in a terminal window titled `title`, `label` its accessible name. */
export const svgOf = (rows: readonly Cell[][], title: string, label: string) => {
  const columns = Math.max(0, ...rows.map(row => row.length))
  const width = columns * CELL.across + 2 * WINDOW.margin
  const height = WINDOW.bar + rows.length * CELL.down + 2 * WINDOW.margin
  const top = (row: number) => WINDOW.bar + WINDOW.margin + row * CELL.down
  const cells = rows.flatMap((row, i) => [
    ...backgrounds(row, top(i)),
    ...lines(row, top(i)),
    ...glyphs(row, top(i)),
  ])

  return [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${number(width)}" height="${number(height)}" viewBox="0 0 ${number(width)} ${number(height)}" role="img" aria-label="${escaped(label)}">`,
    `<g font-family="${FONT}" font-size="${CELL.font}">`,
    ...frame(width, height, title),
    `<g transform="translate(${WINDOW.margin} 0)">`,
    ...cells,
    '</g>',
    '</g>',
    '</svg>',
    '',
  ].join('\n')
}
