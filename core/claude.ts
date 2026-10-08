/**
 * The board as Claude reads it: a piece of work's open items with their ids,
 * for the board tool and for the context a turn takes when the board
 * changed; and a project's pieces of work with their ids, for the start of a
 * session. Undelivered replies are left out: Claude has not been told them.
 */
import { answerOf, isOpen } from './replies'
import type { Ask, LogLine, Parked, Work } from './types'
import type { WorkSummary } from './views'

/** How many of the latest notes the board text lists, for Claude to correct. */
const RECENT_NOTES = 5

/** Where an open ask stands, as Claude reads it. */
const STANDING: Record<'waiting' | 'replied', string> = {
  waiting: 'waiting on Lee',
  replied: 'Lee replied, yours to act on',
}

/** A heading, and its lines as a list; `none` when it has none. */
const section = (heading: string, lines: readonly string[]) =>
  [`${heading}:`, ...(lines.length === 0 ? ['none'] : lines).map(line => `- ${line}`)].join('\n')

/** A line's head, then each extra it has, labelled. */
const withExtras = (head: string, extras: Record<string, string | undefined>) =>
  [
    head,
    ...Object.entries(extras).flatMap(([label, value]) => (value ? [`${label}: ${value}`] : [])),
  ].join('; ')

const askLine = (ask: Ask) => {
  const standing =
    ask.state === 'replied' && ask.answer !== undefined
      ? `${STANDING.replied} (${answerOf(ask, ask.answer)})`
      : STANDING.waiting

  return `${ask.id} ${ask.kind}, ${standing}: ${withExtras(ask.title, {
    options: ask.options?.join(' | '),
    where: ask.where,
    ref: ask.ref,
  })}`
}

const parkedLine = (parked: Parked) =>
  `${parked.id}: ${withExtras(parked.title, { where: parked.where, ref: parked.ref })}`

const noteLine = (note: LogLine) => `${note.id}: ${note.text}`

/** A piece of work's open items with their ids, for Claude to check against what it knows and repair. */
export const boardText = (work: Work) => {
  const { name, summary, now, next } = work.status
  const notes = work.log.filter(line => line.id !== undefined).slice(0, RECENT_NOTES)

  return [
    `sitrep board: ${name} (${work.id})`,
    `Summary: ${summary}`,
    section('Now', now),
    `Next: ${next ?? 'none'}`,
    section('Open asks', work.asks.filter(isOpen).map(askLine)),
    section('Parked', work.parked.map(parkedLine)),
    section('Latest notes', notes.map(noteLine)),
  ].join('\n')
}

const workLine = (work: WorkSummary) => {
  const window = work.isOpen ? 'open in a window' : 'no window has it open'
  const waiting = work.waiting === 0 ? '' : `; ${work.waiting} waiting on Lee`

  return `${work.id}: ${work.name}. ${work.summary} (${window}${waiting})`
}

/** Pieces of work with their ids, in the order given, for Claude to join one by id. */
export const worksText = (works: readonly WorkSummary[]) =>
  section('sitrep pieces of work', works.map(workLine))
