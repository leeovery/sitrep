/**
 * A drawing read back as the rows of text it takes, for tests that assert
 * columns: a Box lays its children out in a row or a column, with its gaps,
 * padding and width; a Text is its words, a Button its label. Nothing wraps
 * or grows, so a row is as wide as what is on it, its ends trimmed.
 */
import type { FoundElement } from 'claude-code/testing'

type Drawn = { type?: string; props?: Record<string, unknown>; children?: unknown[] }

const width = (rows: readonly string[]) => Math.max(0, ...rows.map(row => [...row].length))

const padded = (row: string, cells: number) => row + ' '.repeat(cells - [...row].length)

const numberOf = (value: unknown) => (typeof value === 'number' ? value : 0)

const wordsOf = (children: readonly unknown[] = []): string =>
  children
    .map(child => (typeof child === 'string' ? child : wordsOf((child as Drawn).children)))
    .join('')

const side = (
  columns: readonly string[][],
  gap: number,
  cells: readonly (number | undefined)[],
) => {
  const widths = columns.map((rows, i) => cells[i] ?? width(rows))
  const height = Math.max(0, ...columns.map(rows => rows.length))

  return Array.from({ length: height }, (_, row) =>
    columns.map((rows, i) => padded(rows[row] ?? '', widths[i] ?? 0)).join(' '.repeat(gap)),
  )
}

const stacked = (columns: readonly string[][], gap: number) =>
  columns.flatMap((rows, i) => (i === 0 ? rows : [...Array<string>(gap).fill(''), ...rows]))

const rowsOfBox = ({ props = {}, children = [] }: Drawn): string[] => {
  const shown = children.filter((child): child is Drawn => typeof child === 'object' && !!child)
  const columns = shown.map(rowsOfElement)
  const isColumn = props.flexDirection === 'column'
  const gap = numberOf(isColumn ? (props.rowGap ?? props.gap) : (props.columnGap ?? props.gap))
  const laid = isColumn
    ? stacked(columns, gap)
    : side(
        columns,
        gap,
        shown.map(child => child.props?.width as number | undefined),
      )
  const left = ' '.repeat(numberOf(props.paddingLeft) + numberOf(props.paddingX))

  return [...Array<string>(numberOf(props.paddingTop)).fill(''), ...laid.map(row => left + row)]
}

const rowsOfElement = (element: Drawn): string[] => {
  switch (element.type) {
    case 'Box':
      return rowsOfBox(element)
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

/** The rows an element takes, each trimmed at its end. */
export const rowsOf = (element: FoundElement | undefined) =>
  element === undefined ? [] : rowsOfElement(element).map(row => row.trimEnd())
