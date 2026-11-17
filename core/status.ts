/**
 * The line a changed status earns in its session's history. The board
 * compares each status with the one before it as it folds, so Claude never
 * writes a status change down, and no such line is ever stored.
 */
import type { Status } from './types'

/** The fields a status change is read from. */
export type StatusFields = Pick<Status, 'name' | 'summary' | 'now' | 'next'>

/** A status change as the history shows it: a headline, and the detail it opens to. */
export type StatusChange = { text: string; detail: string[] }

/** What each detail line of a status change opens with: what the line says changed. */
const STATUS_LABELS = {
  added: 'Added:',
  gone: 'No longer:',
  kept: 'Still there:',
  next: 'Next:',
  name: 'Name:',
  summary: 'Summary:',
} as const

const labelled = (label: string) => (text: string) => `${label} ${text}`

/** A status change's detail line as the label it opens with and the text after it; undefined for a line no label opens. */
export const labelOf = (line: string) => {
  const label = Object.values(STATUS_LABELS).find(each => line.startsWith(`${each} `))

  return label === undefined ? undefined : { label, text: line.slice(label.length + 1) }
}

const more = (count: number) => (count > 0 ? ` (and ${count} more)` : '')

// Claude's now-lines open with a verb (the status tool's wording rule), so a
// capital opening one is the sentence's own, not a name's.
const lead = (line: string) =>
  /^[A-Z][a-z]/.test(line) ? `${line.charAt(0).toLowerCase()}${line.slice(1)}` : line

const nowHeadline = (added: string[], gone: string[], kept: string[]) => {
  const [first, ...others] = added

  if (first !== undefined) {
    const also = gone.length === 0 && kept.length > 0 ? 'now also' : 'now'

    return `${also} ${lead(first)}${more(others.length)}`
  }

  const [firstGone, ...othersGone] = gone

  return firstGone === undefined
    ? undefined
    : `no longer ${lead(firstGone)}${more(othersGone.length)}`
}

const restHeadline = (before: StatusFields, after: StatusFields) => {
  if (before.next !== after.next) {
    return after.next === undefined ? 'nothing next' : `next is ${after.next}`
  }

  if (before.name !== after.name) {
    return `renamed to ${after.name}`
  }

  return before.summary === after.summary ? undefined : 'summary changed'
}

/**
 * What changed between two statuses, headed by the change that matters most:
 * what is under way, then what is next, the name, the summary. Undefined
 * when nothing did (the same lines in another order included).
 */
export const statusChange = (
  before: StatusFields,
  after: StatusFields,
): StatusChange | undefined => {
  const added = after.now.filter(line => !before.now.includes(line))
  const gone = before.now.filter(line => !after.now.includes(line))
  const kept = after.now.filter(line => before.now.includes(line))
  const headline = nowHeadline(added, gone, kept) ?? restHeadline(before, after)

  if (headline === undefined) {
    return undefined
  }

  const isNowChanged = added.length + gone.length > 0

  return {
    text: headline,
    detail: [
      ...added.map(labelled(STATUS_LABELS.added)),
      ...gone.map(labelled(STATUS_LABELS.gone)),
      ...(isNowChanged ? kept.map(labelled(STATUS_LABELS.kept)) : []),
      ...(before.next === after.next ? [] : [labelled(STATUS_LABELS.next)(after.next ?? 'none')]),
      ...(before.name === after.name ? [] : [labelled(STATUS_LABELS.name)(after.name)]),
      ...(before.summary === after.summary ? [] : [labelled(STATUS_LABELS.summary)(after.summary)]),
    ],
  }
}
