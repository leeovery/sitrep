/**
 * A drawing read back as the rows of text it takes, for tests that assert
 * columns: a Box lays its children out in a row or a column, with its gaps,
 * padding (blank rows above and below it too) and width; a Text is its words, a Button its label.
 * Given the cells across, a row that wraps starts a line wherever its next
 * child no longer fits on the one before; nothing else wraps.
 * Given the cells across, a row hands what it has spare to its first child
 * that grows, so what comes after sits at the right edge; given none,
 * nothing grows, and a row is as wide as what is on it. Its ends are trimmed.
 */
import type { FoundElement, Mounted } from 'claude-code/testing'

type Drawn = { type?: string; props?: Record<string, unknown>; children?: unknown[] }

const width = (rows: readonly string[]) => Math.max(0, ...rows.map(row => [...row].length))

const padded = (row: string, cells: number) => row + ' '.repeat(cells - [...row].length)

const numberOf = (value: unknown) => (typeof value === 'number' ? value : 0)

const wordsOf = (children: readonly unknown[] = []): string =>
  children
    .map(child => (typeof child === 'string' ? child : wordsOf((child as Drawn).children)))
    .join('')

const side = (columns: readonly string[][], gap: number, widths: readonly number[]) => {
  const height = Math.max(0, ...columns.map(rows => rows.length))

  return Array.from({ length: height }, (_, row) =>
    columns.map((rows, i) => padded(rows[row] ?? '', widths[i] ?? 0)).join(' '.repeat(gap)),
  )
}

const stacked = (columns: readonly string[][], gap: number) =>
  columns.flatMap((rows, i) => (i === 0 ? rows : [...Array<string>(gap).fill(''), ...rows]))

const fixedWidth = (element: Drawn) => element.props?.width as number | undefined

const grows = (element: Drawn) => numberOf(element.props?.flexGrow) > 0

/** Children side by side, each as wide as it is or is told to be; given the cells, the first that grows takes what is spare. */
const sideBySide = (children: readonly Drawn[], gap: number, cells?: number) => {
  const columns = children.map(child => rowsOfElement(child, fixedWidth(child)))
  const widths = children.map((child, i) => fixedWidth(child) ?? width(columns[i] ?? []))
  const grower = cells === undefined ? -1 : children.findIndex(grows)

  if (cells !== undefined && grower >= 0) {
    const used = widths.reduce((sum, each) => sum + each, 0) + gap * (children.length - 1)
    const room = (widths[grower] ?? 0) + Math.max(0, cells - used)

    widths[grower] = room
    columns[grower] = rowsOfElement(children[grower] ?? {}, room)
  }

  return side(columns, gap, widths)
}

/** Children in a row that wraps, `cells` across: each on the line before while it fits there, else starting one. */
const wrapped = (children: readonly Drawn[], gap: number, rowGap: number, cells: number) => {
  const lines: Drawn[][] = []
  let used = 0

  for (const child of children) {
    const across = fixedWidth(child) ?? width(rowsOfElement(child))
    const line = lines.at(-1)

    if (line === undefined || used + gap + across > cells) {
      lines.push([child])
      used = across
    } else {
      line.push(child)
      used += gap + across
    }
  }

  return stacked(
    lines.map(line => sideBySide(line, gap, cells)),
    rowGap,
  )
}

const rowsOfBox = ({ props = {}, children = [] }: Drawn, cells?: number): string[] => {
  const shown = children.filter((child): child is Drawn => typeof child === 'object' && !!child)
  const isColumn = props.flexDirection === 'column'
  const rowGap = numberOf(props.rowGap ?? props.gap)
  const gap = isColumn ? rowGap : numberOf(props.columnGap ?? props.gap)
  const indent = numberOf(props.paddingLeft) + numberOf(props.paddingX)
  const inside = cells === undefined ? undefined : cells - indent - numberOf(props.paddingX)
  const wraps = !isColumn && props.flexWrap === 'wrap' && inside !== undefined
  const laid = isColumn
    ? stacked(
        shown.map(child => rowsOfElement(child, inside)),
        gap,
      )
    : wraps
      ? wrapped(shown, gap, rowGap, inside)
      : sideBySide(shown, gap, inside)
  const left = ' '.repeat(indent)

  return [
    ...Array<string>(numberOf(props.paddingTop)).fill(''),
    ...laid.map(row => left + row),
    ...Array<string>(numberOf(props.paddingBottom)).fill(''),
  ]
}

const rowsOfElement = (element: Drawn, cells?: number): string[] => {
  switch (element.type) {
    case 'Box':
      return rowsOfBox(element, cells)
    case 'Text':
      return wordsOf(element.children).split('\n')
    case 'Button': {
      const label = String(element.props?.label ?? '')

      return [element.props?.plain === true ? label : `[ ${label} ]`]
    }
    default:
      return []
  }
}

/** The rows an element takes, `cells` across where given, each trimmed at its end. */
export const rowsOf = (element: FoundElement | undefined, cells?: number) =>
  element === undefined ? [] : rowsOfElement(element, cells).map(row => row.trimEnd())

/** Ready to send as the rows it draws, each trimmed, the blank ones between its groups kept; none while it is not drawn. */
export const readyRows = async (ui: Pick<Mounted, 'find'>) =>
  rowsOf(await ui.find({ key: 'ready' })).map(row => row.trim())

/** Ready to send's heading row, by how many replies it holds not yet with Claude. */
export const readyHeading = (count: number) =>
  `READY TO SEND${count} ${count === 1 ? 'reply' : 'replies'}`
