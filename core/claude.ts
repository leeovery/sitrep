/**
 * The board as Claude reads it: a session's open items with their ids, for
 * the board tool and for the context a turn takes when the board changed;
 * and every project's sessions with their ids, for the start of a
 * conversation. Undelivered replies are left out: Claude has not been told
 * them, so an ask with a reply of Lee's on its way still waits on Lee here,
 * or stays snoozed. A snoozed ask says until when, whole and local, so the
 * words change only as the snooze does.
 */
import { answerOf, isOpen, yesOf } from './replies'
import { wholeTime } from './snooze'
import type { Ask, Finished, Finisher, LogLine, Parked, Session } from './types'
import { summarise, type ProjectSummary, type SessionSummary } from './views'

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

/** Where an open ask stands for Claude: replied, with Lee's reply; snoozed, by its time alone, whatever is on its way to it; else waiting on Lee. */
const standingOf = (ask: Ask) => {
  if (ask.state === 'replied' && ask.answer !== undefined) {
    return `${STANDING.replied} (${answerOf(ask, ask.answer)})`
  }

  return ask.snoozedUntil === undefined
    ? STANDING.waiting
    : `snoozed by Lee until ${wholeTime(ask.snoozedUntil)} (leave it until then)`
}

const askLine = (ask: Ask) =>
  `${ask.id} wants ${wantsWords(ask)}, ${standingOf(ask)}: ${withExtras(ask.title, {
    options: ask.options?.join(' | '),
    needs: ask.needs,
    where: ask.where,
    ref: ask.ref,
  })}`

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

/**
 * A session in brief as Claude knows it, for the first message's listing:
 * its asks waiting as posted count, a reply of Lee's on its way to one or
 * not, as its board text lists them, since Claude has not been told that
 * reply; those snoozed apart from the rest.
 */
export const toldSummary = (session: Session): SessionSummary => {
  const summary = summarise(session)
  const snoozed =
    session.finished === undefined
      ? session.asks.filter(ask => ask.snoozedUntil !== undefined).length
      : 0

  return { ...summary, waiting: summary.asked - snoozed, snoozed }
}

/** What waits on Lee in a session, as the listing says it: those waiting, then those snoozed. */
const waitingWords = ({ waiting, snoozed }: SessionSummary) =>
  [
    ...(waiting === 0 ? [] : [`, ${waiting} waiting on Lee`]),
    ...(snoozed === 0 ? [] : [`, ${snoozed} snoozed by Lee`]),
  ].join('')

/** A session's line on the board: its project, its id and name, and what waits on Lee. */
const boardLine = (project: string, session: SessionSummary) =>
  `- ${project}: ${session.id} "${session.name}"${waitingWords(session)}`

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
  "- As it goes: set the status when what's under way changes; post an ask whenever you need something only Lee can do or decide, and say it in the chat as well, in your words after the turn's last tool call, since words written before a tool call can reach Lee only as a short rewrite, their steps and questions lost (when Lee answers it in the chat, resolve the ask); a turn that ends on a decision or a question for Lee posts it as an ask, so it shows in Needs you, never only in the status; plain conversation needs none; note what Lee would want to know later, never running commentary; resolve what's done; when the session is complete, with nothing left on it, finish it.",
  "- Item and session ids are yours alone: Lee sees none of them on the board or in the app, so never name one to him. Name an ask, a parked item or a session by its words.",
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
