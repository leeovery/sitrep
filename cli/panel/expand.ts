/**
 * The chosen row expanded: what the two-line rows showed until 26 November
 * 2026, whole, wrapped over as many lines as they need from the names'
 * column, where its one line cuts them. Layout counts its lines; draw.ts
 * draws them.
 *
 * - The first line: the name, then its count, the time kept at the right
 *   as the row keeps it; the name wraps on under it.
 * - Then, for a row of one line, its project and ` · `, its status line and
 *   a question's `+2`, wrapped as one, as the two-line rows' second line
 *   read them.
 * - For a row of several, its project alone, then each line's words on a
 *   line of its own, each wrapped.
 */
import { widthOf, wordsOf, wrapTagged, type Tagged } from './cells'
import type { PanelRow, StatusWords } from './view'

/** The column of a row's words, and of an expanded row's lines. */
export const NAME = 3

/** The fewest cells a name or a status line is cut to. */
export const LEAST_CUT = 6

/** What a word of an expanded row is: the name's, drawn as the name is; the grey of a project, a count or `+2`; or a status line's. */
export type Tag = 'name' | 'meta' | 'status'

export type Expanded = { time: string; lines: Tagged<Tag>[][] }

/** A Snoozed wake without its clock, `tomorrow` for `tomorrow 09:00`; none for a bare clock. */
export const withoutClock = (time: string) => /^(.+) \d{1,2}:\d{2}$/.exec(time)?.[1]

/** The row's time as it fits beside its name: whole, a Snoozed wake without its clock, or none, whichever first leaves the name its least. */
export const timeFitting = (row: PanelRow, room: number) => {
  const day = row.isSnoozed ? withoutClock(row.time) : undefined
  const least = Math.min(LEAST_CUT, widthOf(row.name))
  const tries = [row.time, ...(day === undefined ? [] : [day]), '']

  return tries.find(each => room - (each === '' ? 0 : widthOf(each) + 2) >= least) ?? ''
}

/** The count a row of several lines shows after its name, ` 3`; none for one. */
export const countOf = (row: PanelRow) => (row.count !== undefined && row.count > 1 ? ` ${row.count}` : '')

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

/** The row expanded at a layout's width: its time, and its lines, the first beside the time. */
export const expandedOf = (row: PanelRow, width: number): Expanded => {
  const cells = width - 1 - NAME
  const count = countOf(row)
  const time = timeFitting(row, cells - widthOf(count))
  const first = cells - (time === '' ? 0 : widthOf(time) + 2)
  const counted: Tagged<Tag>[] = count === '' ? [] : [{ text: count.trim(), tag: 'meta' }]
  const name = wrapTagged([...wordsOf(row.name, 'name' as const), ...counted], first, cells)

  return { time, lines: [...(name.length === 0 ? [[]] : name), ...detailsOf(row, cells)] }
}
