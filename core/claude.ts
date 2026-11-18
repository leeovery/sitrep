/**
 * The board as Claude reads it: a session's open items with their ids, and
 * what its project's other sessions parked, for the board tool and for the
 * context a turn takes when the board changed; and every project's sessions
 * with their ids, for the start of a conversation. Undelivered replies are
 * left out: Claude has not been told them, so an ask with a reply of the user's
 * on its way still waits on the user here, or stays snoozed. A snoozed ask says
 * until when, whole and local, so the words change only as the snooze does.
 */
import { answerOf, isOpen, reaches, yesOf } from './replies'
import { wholeTime } from './snooze'
import {
  UNTIL_IT_MOVES,
  type Ask,
  type Finished,
  type Finisher,
  type Parked,
  type Session,
} from './types'
import { USER } from './user'
import { summarise, type ProjectParked, type ProjectSummary, type SessionSummary } from './views'

/** Where an open ask stands, as Claude reads it. */
const STANDING: Record<'waiting' | 'replied' | 'finished', string> = {
  waiting: `waiting on ${USER.name}`,
  replied: `${USER.name} replied, yours to act on`,
  finished: "can't be answered (the session is finished)",
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

/**
 * Where an open ask stands for Claude, read where a window holds the session
 * or none does, as `isHeld` says: replied, with the user's reply; in a finished
 * session no window holds, which no reply reaches, unanswerable; snoozed,
 * by its time alone, whatever is on its way to it; else waiting on the user.
 */
const standingOf = (ask: Ask, session: Session, isHeld: boolean) => {
  if (ask.state === 'replied' && ask.answer !== undefined) {
    return `${STANDING.replied} (${answerOf(ask, ask.answer)})`
  }

  const held = isHeld ? session.id : undefined

  if (!reaches(held, { id: session.id, isFinished: session.finished !== undefined }, ask)) {
    return STANDING.finished
  }

  if (ask.snoozedUntil === undefined) {
    return STANDING.waiting
  }

  const until =
    ask.snoozedUntil === UNTIL_IT_MOVES
      ? "the session's next turn ends"
      : wholeTime(ask.snoozedUntil)

  return `snoozed by ${USER.name} until ${until} (leave it until then)`
}

const askLine = (ask: Ask, session: Session, isHeld: boolean) => {
  const text = withExtras(ask.title, {
    options: ask.options?.join(' | '),
    recommended: ask.recommended,
    needs: ask.needs,
    where: ask.where,
    ref: ask.ref,
  })

  return `${ask.id} wants ${wantsWords(ask)}, ${standingOf(ask, session, isHeld)}: ${text}`
}

const parkedText = (parked: Parked) =>
  withExtras(parked.title, { where: parked.where, ref: parked.ref })

const parkedLine = (parked: Parked) => `${parked.id}: ${parkedText(parked)}`

/** An item another session of the project parked: by its session's name, its id given as the `session` the tools take to act on it. */
const parkedElsewhereLine = (parked: ProjectParked) =>
  `${parked.id}, parked by "${parked.name}" (session: ${parked.session}): ${parkedText(parked)}`

/**
 * A session's open items with their ids, for Claude to check against what
 * it knows and repair. Parked lists what the session parked, then what the
 * project's other sessions parked, of `projectParked`, the project's.
 * `isHeld` says whether a window holds the session, where a reply to a
 * finished session's ask still goes in: so the window that reads it does,
 * and the CLI reads whether a live one is attached.
 */
export const boardText = (
  session: Session,
  projectParked: readonly ProjectParked[] = [],
  isHeld = true,
) => {
  const { name, summary, now, next } = session.status
  const elsewhere = projectParked.filter(parked => parked.session !== session.id)

  return [
    `sitrep board: ${name} (${session.id})`,
    `Summary: ${summary}`,
    section('Now', now),
    `Next: ${next ?? 'none'}`,
    section(
      'Open asks',
      session.asks.filter(isOpen).map(ask => askLine(ask, session, isHeld)),
    ),
    section('Parked', [...session.parked.map(parkedLine), ...elsewhere.map(parkedElsewhereLine)]),
  ].join('\n')
}

/**
 * A session in brief as Claude knows it, for the first message's listing:
 * its asks waiting as posted count, a reply of the user's on its way to one or
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

/** What waits on the user in a session, as the listing says it: those waiting, then those snoozed. */
const waitingWords = ({ waiting, snoozed }: SessionSummary) =>
  [
    ...(waiting === 0 ? [] : [`, ${waiting} waiting on ${USER.name}`]),
    ...(snoozed === 0 ? [] : [`, ${snoozed} snoozed by ${USER.name}`]),
  ].join('')

/** A session's line on the board: its project, its id and name, and what waits on the user. */
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

/** How Claude keeps the board and talks to the user beside it: which project a session is on, when to start one, what to post as it goes, and the turn's order. */
const GUIDE = [
  `sitrep is ${USER.possessive} board inside Claude Code: where each session stands and what waits on ${USER.name}. Keep it current, since away from this window it tells ${USER.name} what waits; but in the chat talk as if it weren't there: the chat alone says everything ${USER.name} needs.`,
  `- Start a session when the work will run across several turns or will need ${USER.name}: a feature, a design, an investigation. Not for a quick question. Name it in plain words, as ${USER.name} would say it, with no internal codes; record its id wherever the project tracks the work.`,
  `- Touch the board only once it is clear which project the work is on: the project being discussed, whatever folder this window started in. When ${USER.name} carries on with a session on the board, join it by its id with the sitrep join tool. Otherwise start one, naming its project as ${USER.name} would say it (SitRep, Switchboard), by the name it has on the board when it is one there, and giving the project's directory once you know it.`,
  `- When ${USER.name} asks to move this session to another project, move it with the sitrep move tool: the whole session goes, so never start a new one there instead. Move one only at ${USER.possessive} word.`,
  `- As it goes: set the status when what's under way changes; post an ask whenever you need something only ${USER.name} can do or decide, and resolve it yourself when ${USER.name} answers it in the chat; resolve what's done; when the session is complete, with nothing left on it, finish it: what it parked stays its project's, and holds no finish back.`,
  `- A turn that ends on a decision or a question for ${USER.name}, or that leaves ${USER.name} something to do, such as a release, a merge or a command to run, even said as a statement ("It's ready for you to release"), posts it as an ask, so the board shows it waiting on ${USER.name}, never only in the status. Plain conversation needs none.`,
  `- In the chat, give an ask's question and steps whole, and never point ${USER.name} to the board: no "it's on the board", no "check the board". Saying you parked something is fine, as is naming the asks still open now and then, when several wait, though not at every turn's end. An ask ${USER.name} hasn't answered that you still need, raise again in the chat.`,
  `- Every board call of a turn comes before your closing message to ${USER.name}, never after it. Before any tool call, write ${USER.name} a line at most: longer words before a tool call can reach ${USER.name} as a short summary, or not at all. What ${USER.name} must read goes after the turn's last tool call.`,
  `- Item and session ids are yours alone: ${USER.name} sees none of them on the board or in the app, so never name one in the chat. Name an ask, a parked item or a session by its words.`,
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

const FINISHERS: Record<Finisher, string> = { lee: USER.name, claude: 'Claude' }

/** What a join tells Claude of a finished session it reopened: who had finished it, and why. */
export const reopenedText = ({ who, reason }: Finished) =>
  `It had been finished by ${FINISHERS[who]}${reason === undefined ? '' : ` (${reason})`}; joining it reopened it.`
