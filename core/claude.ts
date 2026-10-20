/**
 * The board as Claude reads it: a session's open items with their ids, for
 * the board tool and for the context a turn takes when the board changed;
 * and every project's sessions with their ids, for the start of a
 * conversation. Undelivered replies are left out: Claude has not been told
 * them.
 */
import { answerOf, isOpen, yesOf } from './replies'
import type { Ask, Finished, Finisher, LogLine, Parked, Session } from './types'
import type { ProjectSummary, SessionSummary } from './views'

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

/** What an ask wants back, as Claude reads it: a yes in its button's words, a choice, or words. */
const wantsWords = (ask: Ask) => {
  switch (ask.wants) {
    case 'yes':
      return `a yes (${yesOf(ask)})`
    case 'choice':
      return 'a choice'
    case 'words':
      return 'words'
  }
}

const askLine = (ask: Ask) => {
  const standing =
    ask.state === 'replied' && ask.answer !== undefined
      ? `${STANDING.replied} (${answerOf(ask, ask.answer)})`
      : STANDING.waiting

  return `${ask.id} wants ${wantsWords(ask)}, ${standing}: ${withExtras(ask.title, {
    options: ask.options?.join(' | '),
    needs: ask.needs,
    where: ask.where,
    ref: ask.ref,
  })}`
}

const parkedLine = (parked: Parked) =>
  `${parked.id}: ${withExtras(parked.title, { where: parked.where, ref: parked.ref })}`

const noteLine = (note: LogLine) => `${note.id}: ${note.text}`

/** A session's open items with their ids, for Claude to check against what it knows and repair. */
export const boardText = (session: Session) => {
  const { name, summary, now, next } = session.status
  const notes = session.log.filter(line => line.id !== undefined).slice(0, RECENT_NOTES)

  return [
    `sitrep board: ${name} (${session.id})`,
    `Summary: ${summary}`,
    section('Now', now),
    `Next: ${next ?? 'none'}`,
    section('Open asks', session.asks.filter(isOpen).map(askLine)),
    section('Parked', session.parked.map(parkedLine)),
    section('Latest notes', notes.map(noteLine)),
  ].join('\n')
}

/** A session's line on the board: its project, its id and name, and what waits on Lee. */
const boardLine = (project: string, session: SessionSummary) =>
  `- ${project}: ${session.id} "${session.name}"${session.waiting === 0 ? '' : `, ${session.waiting} waiting on Lee`}`

/** Every current session with its id, project by project in the order given, for Claude to join one by id. */
export const onBoardText = (projects: readonly ProjectSummary[]) =>
  [
    'On the board:',
    ...projects.flatMap(project =>
      project.sessions.map(session => boardLine(project.name, session)),
    ),
  ].join('\n')

/** How Claude keeps the board: which project a session is on, when to start one, and how much to post as it goes. */
const GUIDE = [
  "sitrep is Lee's board inside Claude Code: where each session stands and what waits on Lee. The chat stays primary; the board mirrors your own tracking, for Lee.",
  '- Start a session when the work will run across several turns or will need Lee: a feature, a design, an investigation. Not for a quick question. Name it in plain words, as Lee would say it, with no internal codes; record its id wherever the project tracks the work.',
  "- Touch the board only once it is clear which project the work is on: the project being discussed, whatever folder this window started in. When Lee carries on with a session on the board, join it by its id with the sitrep join tool. Otherwise start one, naming its project as Lee would say it (SitRep, Switchboard), by the name it has on the board when it is one there, and giving the project's directory once you know it.",
  "- As it goes: set the status when what's under way changes; post an ask whenever you need something only Lee can do or decide, and say it in the chat as well (when Lee answers it in the chat, resolve the ask); note what Lee would want to know later, never running commentary; resolve what's done; when the session is complete, with nothing left on it, finish it.",
].join('\n')

/** What a conversation starts knowing of the board: how to keep it, every current session by project, and the one this window already holds. */
export const startText = (projects: readonly ProjectSummary[], held?: SessionSummary) => {
  if (projects.every(project => project.sessions.length === 0)) {
    return GUIDE
  }

  const holding =
    held === undefined
      ? []
      : [`This window already holds ${held.id} (${held.name}): post to its board as you go.`]

  return [GUIDE, onBoardText(projects), ...holding].join('\n')
}

const FINISHERS: Record<Finisher, string> = { lee: 'Lee', claude: 'Claude' }

/** What a join tells Claude of a finished session it reopened: who had finished it, and why. */
export const reopenedText = ({ who, reason }: Finished) =>
  `${FINISHERS[who]} had finished it${reason === undefined ? '' : ` (${reason})`}; joining it reopened it.`
