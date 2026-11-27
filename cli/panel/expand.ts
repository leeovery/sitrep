/**
 * The chosen row expanded: what the two-line rows showed until 26 November
 * 2026, whole, wrapped over as many lines as they need from the names'
 * column, where its one line cuts them. Layout counts its lines; draw.ts
 * draws them.
 *
 * - The first line: the name, then its count, the time kept at the right
 *   as its folded row fits it, in its section's lane; the name wraps on
 *   under it.
 * - Then, for a row of one line, its project and ` · `, its status line and
 *   a question's `+2`, wrapped as one, as the two-line rows' second line
 *   read them.
 * - For a row of several, its project alone, then each line's words on a
 *   line of its own, each wrapped.
 */
import { widthOf, wordsOf, wrapTagged, type Tagged } from './cells'
import { countOf, NAME, type Lane } from './line'
import type { PanelRow, StatusWords } from './view'

/** What a word of an expanded row is: the name's, drawn as the name is; the grey of a project, a count or `+2`; or a status line's. */
export type Tag = 'name' | 'meta' | 'status'

export type Expanded = { time: string; lines: Tagged<Tag>[][] }

const statusWords = ({ text, more }: StatusWords): Tagged<Tag>[] => [
  ...wordsOf(text, 'status' as const),
  ...(more === undefined ? [] : [{ text: `+${more}`, tag: 'meta' as const }]),
]

/** The project's words, ` ·` joined to the last where a status line follows, so no line starts on it. */
const projectWords = (project: string, isLed: boolean): Tagged<Tag>[] => {
  const words = wordsOf(project, 'meta' as const)
  const last = words.at(-1)

  return isLed && last !== undefined ? [...words.slice(0, -1), { text: `${last.text} ·`, tag: 'meta' }] : words
}

/** The lines under the name: the project and the status line as one; or, of several lines, the project, then each line's words. */
const detailsOf = (row: PanelRow, cells: number): Tagged<Tag>[][] => {
  const wrapped = (words: Tagged<Tag>[]) => wrapTagged(words, cells, cells)

  if (row.lines.length > 1) {
    return [...wrapped(projectWords(row.project, false)), ...row.lines.flatMap(line => wrapped(statusWords(line)))]
  }

  const hasStatus = row.status.text !== ''

  return wrapped([...projectWords(row.project, hasStatus), ...(hasStatus ? statusWords(row.status) : [])])
}

/** The row's name and count, wrapped from the names' column, the first line `first` cells wide at most and each after it `cells`. */
export const nameLines = (row: PanelRow, first: number, cells: number): Tagged<Tag>[][] => {
  const count = countOf(row)
  const counted: Tagged<Tag>[] = count === '' ? [] : [{ text: count.trim(), tag: 'meta' }]
  const name = wrapTagged([...wordsOf(row.name, 'name' as const), ...counted], first, cells)

  return name.length === 0 ? [[]] : name
}

/** The row expanded at a layout's width, in its section's lane: its time, and its lines, the first beside the time. */
export const expandedOf = (row: PanelRow, width: number, lane: Lane): Expanded => {
  const cells = width - 1 - NAME
  const time = lane.timeOf(row)
  const first = cells - (time === '' ? 0 : widthOf(time) + 2)

  return { time, lines: [...nameLines(row, first, cells), ...detailsOf(row, cells)] }
}
