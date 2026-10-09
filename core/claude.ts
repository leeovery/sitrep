/**
 * The board as Claude reads it: a piece of work's open items with their ids,
 * for the board tool and for the context a turn takes when the board
 * changed; and every project's pieces of work with their ids, for the start
 * of a session. Undelivered replies are left out: Claude has not been told
 * them.
 */
import { answerOf, isOpen } from './replies'
import type { Ask, Finished, Finisher, LogLine, Parked, Work } from './types'
import type { ProjectSummary, WorkSummary } from './views'

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

/** A work's line on the board: its project, its id and name, and what waits on Lee. */
const boardLine = (project: string, work: WorkSummary) =>
  `- ${project}: ${work.id} "${work.name}"${work.waiting === 0 ? '' : `, ${work.waiting} waiting on Lee`}`

/** Every current piece of work with its id, project by project in the order given, for Claude to join one by id. */
export const onBoardText = (projects: readonly ProjectSummary[]) =>
  [
    'On the board:',
    ...projects.flatMap(project => project.works.map(work => boardLine(project.name, work))),
  ].join('\n')

/** How Claude keeps the board: which project a piece of work is on, when to start one, and how much to post as it goes. */
const GUIDE = [
  "sitrep is Lee's board inside Claude Code: where each piece of work stands and what waits on Lee. The chat stays primary; the board mirrors your own tracking, for Lee.",
  '- Start a piece of work when the work will run across several turns or will need Lee: a feature, a design, an investigation. Not for a quick question. Name it in plain words, as Lee would say it, with no internal codes; record its id wherever the project tracks the work.',
  "- Touch the board only once it is clear which project the work is on: the project being discussed, whatever folder this session started in. When Lee carries on with a piece of work on the board, join it by its id with the sitrep join tool. Otherwise start one, naming its project as Lee would say it (SitRep, Switchboard), by the name it has on the board when it is one there, and giving the project's directory once you know it.",
  "- As it goes: set the status when what's under way changes; post an ask whenever you need something only Lee can do or decide, and say it in the chat as well (when Lee answers it in the chat, resolve the ask); note what Lee would want to know later, never running commentary; resolve what's done; when the piece of work is complete, with nothing left on it, finish it.",
].join('\n')

/** What a session starts knowing of the board: how to keep it, every current piece of work by project, and the one this window already holds. */
export const startText = (projects: readonly ProjectSummary[], held?: WorkSummary) => {
  if (projects.every(project => project.works.length === 0)) {
    return GUIDE
  }

  const holding =
    held === undefined
      ? []
      : [`This window already holds ${held.id} (${held.name}): post to its board as you go.`]

  return [GUIDE, onBoardText(projects), ...holding].join('\n')
}

const FINISHERS: Record<Finisher, string> = { lee: 'Lee', claude: 'Claude' }

/** What a join tells Claude of a finished work it reopened: who had marked it done, and why. */
export const reopenedText = ({ who, reason }: Finished) =>
  `${FINISHERS[who]} had marked it done${reason === undefined ? '' : ` (${reason})`}; joining it reopened it.`
