/**
 * A drawing laid out in the terminal's cells, each a character and its
 * paint, for the README's picture of the pane: the board's own drawing
 * (tests/render.ts) laid out as Claude Code's terminal lays out its
 * elements, the colours as the board gives them.
 *
 * A Box lays its children out in a column, or by default a row, with its
 * gaps, padding, round border and background; given the cells across, a
 * row hands what it has spare to the children that grow, by how much each
 * grows, takes what it lacks from those that shrink, by their widths, and
 * otherwise sets its children by `justifyContent`; a column stretches each
 * child across it, and a fixed height cuts it or pads it out, giving the
 * spare rows to the children that grow. A row that wraps starts a line
 * where its next child no longer fits. A Text is its words, painted as it
 * and the Texts round it say, wrapped at its spaces where it has no room,
 * or cut with an ellipsis where it truncates; a Button its label, or its
 * children's words, in brackets unless plain, in the accent colour when
 * primary. A Box placed absolutely holds only what measures the board, and
 * is not drawn.
 */
import type { Element } from '../tests/matching'

/** How a cell is painted: no colour is the terminal's own foreground, no background its own. */
export type Paint = {
  color?: string
  background?: string
  bold?: boolean
  italic?: boolean
  dim?: boolean
}

export type Cell = { char: string; paint: Paint }

/** Claude Code's accent on its dark theme, its `suggestion`, which a primary Button is drawn in. */
export const ACCENT = '#b1b9f9'

type Node = Element | string

type Props = Record<string, unknown>

/** What a laid-out element takes: as many cells across every row. */
type Block = { width: number; rows: Cell[][] }

const numberOf = (value: unknown) => (typeof value === 'number' ? value : 0)

const sum = (values: readonly number[]) => values.reduce((total, value) => total + value, 0)

const blanks = (count: number): Cell[] =>
  Array.from({ length: Math.max(0, count) }, () => ({ char: ' ', paint: {} }))

const padded = (row: readonly Cell[], width: number) => [
  ...row.slice(0, width),
  ...blanks(width - row.length),
]

const block = (rows: readonly Cell[][], width: number): Block => ({
  width,
  rows: rows.map(row => padded(row, width)),
})

/** A Box's children it lays out: elements, but those placed absolutely. */
const laidChildren = ({ children = [] }: Element) =>
  children.filter(
    (child): child is Element =>
      typeof child !== 'string' && (child.type !== 'Box' || child.props.position !== 'absolute'),
  )

const fixedWidth = ({ props }: Element) =>
  typeof props.width === 'number' ? props.width : undefined

/** The paint a Text or a Button gives its words over the paint round it. */
const paintOf = (props: Props, round: Paint): Paint => ({
  ...round,
  ...(typeof props.color === 'string' ? { color: props.color } : {}),
  ...(typeof props.backgroundColor === 'string' ? { background: props.backgroundColor } : {}),
  ...(props.bold === true ? { bold: true } : {}),
  ...(props.italic === true ? { italic: true } : {}),
  ...(props.dimColor === true ? { dim: true } : {}),
})

const cellsOfText = (nodes: readonly Node[], paint: Paint): Cell[] =>
  nodes.flatMap(node =>
    typeof node === 'string'
      ? [...node].map(char => ({ char, paint }))
      : cellsOfText(node.children ?? [], paintOf(node.props, paint)),
  )

/** A Button's words: its label, or its children's words, in brackets unless plain, in the accent when primary. */
const cellsOfButton = ({ props, children = [] }: Element): Cell[] => {
  const paint = paintOf(
    { ...(props.variant === 'primary' ? { color: ACCENT } : {}), dimColor: props.dimColor },
    {},
  )
  const words =
    children.length === 0
      ? cellsOfText([String(props.label ?? '')], paint)
      : cellsOfText(children, paint)

  return props.plain === true
    ? words
    : [...cellsOfText(['[ '], paint), ...words, ...cellsOfText([' ]'], paint)]
}

/** Cells broken at each newline. */
const linesOf = (cells: readonly Cell[]) =>
  cells.reduce<Cell[][]>(
    (lines, cell) => {
      if (cell.char === '\n') {
        return [...lines, []]
      }

      lines.at(-1)?.push(cell)

      return lines
    },
    [[]],
  )

/** A line broken at its spaces into rows of at most `width`, the space at each break dropped; a word wider than a row broken where it must. */
const wrapped = (line: readonly Cell[], width: number): Cell[][] => {
  const rows: Cell[][] = []
  let start = 0

  while (line.length - start > width) {
    const room = line.slice(start, start + width + 1)
    const space = room.map(cell => cell.char).lastIndexOf(' ')

    if (space > 0) {
      rows.push(line.slice(start, start + space))
      start += space + 1
    } else {
      rows.push(line.slice(start, start + width))
      start += width
    }
  }

  return [...rows, line.slice(start)]
}

/** A line cut to `width`, an ellipsis in its last cell where it was cut. */
const truncated = (line: readonly Cell[], width: number) => {
  const last = line[width - 1]

  return line.length <= width || last === undefined
    ? [...line]
    : [...line.slice(0, width - 1), { char: '…', paint: last.paint }]
}

/** Words laid out `width` across where given, wrapped or truncated where they lack the room, else as wide as their longest line. */
const layWords = (cells: readonly Cell[], width: number | undefined, truncates: boolean): Block => {
  const lines = linesOf(cells)
  const across = width ?? Math.max(0, ...lines.map(line => line.length))
  const rows = lines.flatMap(line =>
    line.length <= across ? [line] : truncates ? [truncated(line, across)] : wrapped(line, across),
  )

  return block(rows, across)
}

const isTruncating = (props: Props) =>
  typeof props.wrap === 'string' && props.wrap.startsWith('truncate')

type Sides = { top: number; right: number; bottom: number; left: number }

/** A Box's border: a cell each side where it has one. */
const borderOf = (props: Props) => (props.borderStyle === undefined ? 0 : 1)

/** A Box's padding. */
const paddingOf = (props: Props): Sides => {
  const all = numberOf(props.padding)
  const across = numberOf(props.paddingX) || all
  const down = numberOf(props.paddingY) || all

  return {
    top: numberOf(props.paddingTop) || down,
    right: numberOf(props.paddingRight) || across,
    bottom: numberOf(props.paddingBottom) || down,
    left: numberOf(props.paddingLeft) || across,
  }
}

const isColumn = (props: Props) => props.flexDirection === 'column'

const gapAcross = (props: Props) => numberOf(props.columnGap ?? props.gap)

const gapDown = (props: Props) => numberOf(props.rowGap ?? props.gap)

/** How wide an element is with nothing to fit it to. */
const naturalWidth = (element: Element): number => {
  const { type, props } = element

  switch (type) {
    case 'Text':
      return layWords(cellsOfText(element.children ?? [], {}), undefined, false).width
    case 'Button':
      return cellsOfButton(element).length
    case 'Box': {
      const padding = paddingOf(props)
      const children = laidChildren(element)
      const widths = children.map(child => fixedWidth(child) ?? naturalWidth(child))
      const inside = isColumn(props)
        ? Math.max(0, ...widths)
        : sum(widths) + gapAcross(props) * Math.max(0, children.length - 1)

      return fixedWidth(element) ?? padding.left + inside + padding.right + 2 * borderOf(props)
    }
    default:
      return numberOf(props.width)
  }
}

/** `total` shared out by `weights`, each share rounded down and what that leaves going one by one from the first. */
const shared = (total: number, weights: readonly number[]) => {
  const whole = sum(weights)

  if (whole <= 0) {
    return weights.map(() => 0)
  }

  const shares = weights.map(weight => Math.floor((total * weight) / whole))
  let left = total - sum(shares)

  return shares.map((share, i) => {
    const more = left > 0 && (weights[i] ?? 0) > 0 ? 1 : 0

    left -= more

    return share + more
  })
}

/** Blocks side by side, each at its own width, `gaps` cells before each but the first, as tall as the tallest. */
const sideBySide = (blocks: readonly Block[], gaps: readonly number[], lead = 0): Block => {
  const height = Math.max(0, ...blocks.map(each => each.rows.length))
  const rows = Array.from({ length: height }, (_, row) => [
    ...blanks(lead),
    ...blocks.flatMap((each, i) => [
      ...blanks(gaps[i] ?? 0),
      ...(each.rows[row] ?? blanks(each.width)),
    ]),
  ])

  return block(rows, lead + sum(blocks.map(each => each.width)) + sum(gaps))
}

/** The gaps before each of `count` children set apart by `gap`, the spare `room` placed as `justify` says. */
const gapsOf = (count: number, gap: number, room: number, justify: unknown) => {
  const between = (i: number) => (i === 0 ? 0 : gap)

  switch (justify) {
    case 'flex-end':
      return { lead: room, gaps: Array.from({ length: count }, (_, i) => between(i)) }
    case 'center':
      return {
        lead: Math.floor(room / 2),
        gaps: Array.from({ length: count }, (_, i) => between(i)),
      }
    case 'space-between': {
      const spread = [0, ...shared(room, Array<number>(Math.max(0, count - 1)).fill(1))]

      return { lead: 0, gaps: spread.map((more, i) => between(i) + more) }
    }
    default:
      return { lead: 0, gaps: Array.from({ length: count }, (_, i) => between(i)) }
  }
}

/** Children in a row: given the cells across, those that grow share what is spare, and those that shrink give what is short. */
const layRow = (box: Element, inside: number | undefined): Block => {
  const children = laidChildren(box)
  const gap = gapAcross(box.props)
  const widths = children.map(child => fixedWidth(child) ?? naturalWidth(child))
  const spare =
    inside === undefined ? 0 : inside - sum(widths) - gap * Math.max(0, children.length - 1)
  const growth = children.map(child => numberOf(child.props.flexGrow))
  const shrink = children.map((child, i) => (child.props.flexShrink === 0 ? 0 : (widths[i] ?? 0)))
  const given = spare > 0 ? shared(spare, growth) : shared(-spare, shrink).map(less => -less)
  const laid = widths.map((width, i) => Math.max(0, width + (given[i] ?? 0)))
  const room = Math.max(0, (inside ?? 0) - sum(laid) - gap * Math.max(0, children.length - 1))
  const { lead, gaps } = gapsOf(
    children.length,
    gap,
    sum(growth) > 0 ? 0 : room,
    box.props.justifyContent,
  )

  return sideBySide(
    children.map((child, i) => {
      const each = lay(child, laid[i])

      return block(each.rows, laid[i] ?? each.width)
    }),
    gaps,
    lead,
  )
}

/** Children in a row that wraps, `inside` across: each on the line before while it fits there, else starting one. */
const layWrapping = (box: Element, inside: number): Block => {
  const gap = gapAcross(box.props)
  const lines: Block[][] = []
  let used = 0

  for (const child of laidChildren(box)) {
    const natural = fixedWidth(child) ?? naturalWidth(child)
    const line = lines.at(-1)
    const fits = line !== undefined && used + gap + natural <= inside
    const laid = lay(child, Math.min(natural, fits ? inside - used - gap : inside))

    if (fits) {
      line.push(laid)
      used += gap + laid.width
    } else {
      lines.push([laid])
      used = laid.width
    }
  }

  return stacked(
    lines.map(line =>
      sideBySide(
        line,
        line.map((_, i) => (i === 0 ? 0 : gap)),
      ),
    ),
    gapDown(box.props),
    inside,
  )
}

/** Blocks one under another, `gap` blank rows between them, `width` across or as wide as the widest. */
const stacked = (blocks: readonly Block[], gap: number, width?: number): Block => {
  const across = width ?? Math.max(0, ...blocks.map(each => each.width))
  const rows = blocks.flatMap((each, i) => [
    ...(i === 0 ? [] : Array.from({ length: gap }, () => [])),
    ...each.rows,
  ])

  return block(rows, across)
}

/** A child's rows below its top margin, which may not be negative: a docked board drawn here is never scrolled. */
const marginOf = (child: Element) => {
  const margin = numberOf(child.props.marginTop)

  if (margin < 0) {
    throw new Error('a negative top margin is a scrolled list, which is not drawn here')
  }

  return margin
}

/** Children in a column, each stretched across it unless it is told its width, those that grow sharing the rows `height` leaves spare. */
const layColumn = (box: Element, inside: number | undefined, height: number | undefined) => {
  const children = laidChildren(box)
  const laid = children.map(child => {
    const each = lay(child, fixedWidth(child) ?? inside)

    return { ...each, rows: [...Array.from({ length: marginOf(child) }, () => []), ...each.rows] }
  })
  const gap = gapDown(box.props)
  const tall = sum(laid.map(each => each.rows.length)) + gap * Math.max(0, laid.length - 1)
  const more = shared(
    Math.max(0, (height ?? tall) - tall),
    children.map(child => numberOf(child.props.flexGrow)),
  )
  const grown = laid.map((each, i) => ({
    ...each,
    rows: [...each.rows, ...Array.from({ length: more[i] ?? 0 }, () => [])],
  }))

  return stacked(grown, gap, inside)
}

/** The round border's corners and sides; any other style is drawn as round. */
const ROUND = {
  topLeft: '╭',
  topRight: '╮',
  bottomLeft: '╰',
  bottomRight: '╯',
  across: '─',
  down: '│',
}

/** A block in its border, painted `color`. */
const bordered = (inside: Block, color: unknown): Block => {
  const paint: Paint = typeof color === 'string' ? { color } : {}
  const cell = (char: string): Cell => ({ char, paint })
  const rule = Array.from({ length: inside.width }, () => cell(ROUND.across))

  return block(
    [
      [cell(ROUND.topLeft), ...rule, cell(ROUND.topRight)],
      ...inside.rows.map(row => [cell(ROUND.down), ...row, cell(ROUND.down)]),
      [cell(ROUND.bottomLeft), ...rule, cell(ROUND.bottomRight)],
    ],
    inside.width + 2,
  )
}

/** A block with `sides` of blank cells round it. */
const inset = (inside: Block, { top, right, bottom, left }: Sides): Block => {
  const width = left + inside.width + right
  const empty = () => blanks(width)

  return block(
    [
      ...Array.from({ length: top }, empty),
      ...inside.rows.map(row => [...blanks(left), ...row, ...blanks(right)]),
      ...Array.from({ length: bottom }, empty),
    ],
    width,
  )
}

/** Every cell with no background of its own given `background`. */
const filled = (laid: Block, background: unknown): Block =>
  typeof background !== 'string'
    ? laid
    : {
        ...laid,
        rows: laid.rows.map(row =>
          row.map(cell =>
            cell.paint.background === undefined
              ? { ...cell, paint: { ...cell.paint, background } }
              : cell,
          ),
        ),
      }

/** A Box laid out `width` across where given, or told: its children inside its padding and border, as tall as it says, its background behind them. */
const layBox = (box: Element, width: number | undefined): Block => {
  const { props } = box
  const border = borderOf(props)
  const padding = paddingOf(props)
  const outer = fixedWidth(box) ?? width
  const inside =
    outer === undefined ? undefined : Math.max(0, outer - padding.left - padding.right - 2 * border)
  const told = typeof props.height === 'number' ? props.height : undefined
  const least = Math.max(told ?? 0, numberOf(props.minHeight))
  const down = padding.top + padding.bottom + 2 * border
  const rows = least > 0 ? Math.max(0, least - down) : undefined
  const laid = isColumn(props)
    ? layColumn(box, inside, rows)
    : props.flexWrap === 'wrap' && inside !== undefined
      ? layWrapping(box, inside)
      : layRow(box, inside)
  const kept = told === undefined ? laid.rows : laid.rows.slice(0, rows)
  const tall = [...kept, ...Array.from({ length: (rows ?? 0) - kept.length }, () => [])]
  const within = inset(block(tall, inside ?? laid.width), padding)

  return filled(border === 0 ? within : bordered(within, props.borderColor), props.backgroundColor)
}

/** An element laid out `width` across where given, or told. A Box paints no words: only a Text paints those inside it. */
const lay = (element: Element, width: number | undefined): Block => {
  switch (element.type) {
    case 'Box':
      return layBox(element, width)
    case 'Text':
      return layWords(
        cellsOfText(element.children ?? [], paintOf(element.props, {})),
        width,
        isTruncating(element.props),
      )
    case 'Button':
      return layWords(cellsOfButton(element), width, false)
    default:
      return block([], fixedWidth(element) ?? width ?? 0)
  }
}

/** A drawing's rows of cells, `columns` across. */
export const cellsOf = (drawing: Element, columns: number): Cell[][] => lay(drawing, columns).rows

/** The characters of a row of cells. */
export const charsOf = (row: readonly Cell[]) => row.map(cell => cell.char).join('')
