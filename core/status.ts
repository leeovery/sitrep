/**
 * The log line a changed status earns. The board compares each status with
 * the one before it as it folds, so Claude never logs a status change, and
 * no such line is ever stored.
 */
import type { Status } from './types'

/** The fields a status change is read from. */
export type StatusFields = Pick<Status, 'name' | 'summary' | 'now' | 'next'>

/** A status change as the log shows it: a headline, and the detail it opens to. */
export type StatusChange = { text: string; detail: string[] }

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
    text: `Status: ${headline}`,
    detail: [
      ...added.map(line => `Added: ${line}`),
      ...gone.map(line => `No longer: ${line}`),
      ...(isNowChanged ? kept.map(line => `Still there: ${line}`) : []),
      ...(before.next === after.next ? [] : [`Next: ${after.next ?? 'none'}`]),
      ...(before.name === after.name ? [] : [`Name: ${after.name}`]),
      ...(before.summary === after.summary ? [] : [`Summary: ${after.summary}`]),
    ],
  }
}
