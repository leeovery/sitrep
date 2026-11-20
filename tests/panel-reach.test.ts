import { expect, test } from './kit'
import { DEFAULT_COMMAND, typedOf } from '../cli/panel/command'
import { carriedOn, reachOf, type ClaudeThere, type Resume } from '../cli/panel/reach'
import {
  feedOf,
  foldSession,
  metaText,
  type Presence,
  type Project,
  type Session,
  type SessionFiles,
  type SessionMeta,
  type Where,
  type WindowState,
} from '../core'
import { META, MIN, T0, W1, W2, W3 } from './data'
import { beat, file, snoozeSession, yesAsk, type Line } from './lines'

/**
 * What a pick opens, decided from the feed core makes of the sessions on
 * the board, then from what `ps` saw on the window's device and the
 * command, as "Picking a row" settles it.
 */
const NOW = T0 + 60 * MIN

const NAME = META.name

const NORTHWIND: Project = { key: 'northwind', name: 'Northwind', directory: '/Users/me/Code/northwind' }

const FOLDER = '/Users/me/Code/northwind'

const inZmx = (device: string): Where => ({ device, terminal: 'ghostty', zmx: { session: 'northwind · help-desk' } })

const inTmux = (device: string): Where => ({ device, tmux: { socket: '/private/tmp/tmux-501/default', pane: '%12' } })

const inGhostty = (device: string): Where => ({ device, terminal: 'ghostty' })

const working = (since: number): WindowState => ({ is: 'working', since })

const yourTurn = (since: number): WindowState => ({ is: 'yourTurn', since })

/** A window's heartbeat, attached at T0 and seen now, saying `state` unless told otherwise. */
const windowOn = (writer: string, times: Partial<Omit<Presence, 'writer'>> = {}) => ({
  [writer]: beat(writer, { attachedAt: T0, seenAt: NOW, state: yourTurn(T0), ...times }),
})

/** A session folded now from its meta, the lines of the window that started it, and the heartbeats given. */
const sessionOf = ({ meta = {}, lines = [[T0, yesAsk('k1', 'Review round 1')]], presence = {} }: { meta?: Partial<SessionMeta>; lines?: Line[]; presence?: SessionFiles['presence'] } = {}): Session => {
  const { by } = { ...META, ...meta }
  const session = foldSession({ meta: metaText({ ...META, ...meta }), logs: { [by]: file(...lines) }, inbox: {}, presence }, NOW)

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

const feedWith = (...sessions: Session[]) => feedOf([{ project: NORTHWIND, sessions }], NOW)

const reach = (presence: SessionFiles['presence']) => reachOf(META.id, feedWith(sessionOf({ presence })))

const resumed = (given: Partial<Resume> & { claude: string }): { resume: Resume } => ({
  resume: { name: NAME, isHeld: true, ownsDevice: true, ...given },
})

test('a live window in tmux or zmx resumes from that window: its writer, its folder and its device, held, the device its own', () => {
  expect(reach(windowOn(W1, { where: inZmx('/dev/ttys041'), directory: FOLDER }))).toEqual(
    resumed({ claude: W1, dir: FOLDER, device: '/dev/ttys041' }),
  )
  expect(reach(windowOn(W1, { where: inTmux('/dev/ttys042') }))).toEqual(resumed({ claude: W1, device: '/dev/ttys042' }))
})

test("of several live windows, the first in core's jump order whose place names tmux or zmx: one working before one at its turn", () => {
  const presence = {
    ...windowOn(W1, { where: inZmx('/dev/ttys041'), directory: `${FOLDER}/a` }),
    ...windowOn(W2, { where: inGhostty('/dev/ttys042'), state: working(T0 + 5 * MIN) }),
    ...windowOn(W3, { where: inTmux('/dev/ttys043'), directory: `${FOLDER}/c`, state: working(T0 + 2 * MIN) }),
  }
  const feed = feedWith(sessionOf({ presence }))

  expect(feed.windows.map(window => [window.writer, window.jumpOrder])).toEqual([
    [W1, 2],
    [W2, 0],
    [W3, 1],
  ])
  expect(reachOf(META.id, feed)).toEqual(resumed({ claude: W3, dir: `${FOLDER}/c`, device: '/dev/ttys043' }))
})

test("live windows in no multiplexer can't be opened: a command could only start a second Claude beside the first", () => {
  expect(reach({ ...windowOn(W1, { where: inGhostty('/dev/ttys041') }), ...windowOn(W2) })).toEqual({
    answer: `${NAME} can't be opened here: its terminal has no tmux or zmx.`,
  })
})

test("a live window that says nothing of where it is can't be opened, saying so", () => {
  expect(reach(windowOn(W1))).toEqual({ answer: `${NAME} can't be opened here: its window didn't say where it is.` })
})

test("no live window, with a last window, resumes from the last window: its writer, folder and device, not held, the device its own as core says", () => {
  const gone = { seenAt: T0 + 10 * MIN, leftAt: T0 + 10 * MIN }
  const last = reach(windowOn(W1, { ...gone, where: inGhostty('/dev/ttys041'), directory: FOLDER }))
  const later = sessionOf({ meta: { id: 'sr-nw0002', by: W2 }, presence: windowOn(W2, { seenAt: T0 + 20 * MIN, leftAt: T0 + 20 * MIN, where: inGhostty('/dev/ttys041') }) })
  const taken = reachOf(META.id, feedWith(sessionOf({ presence: windowOn(W1, { ...gone, where: inGhostty('/dev/ttys041') }) }), later))

  expect(last).toEqual(resumed({ claude: W1, dir: FOLDER, device: '/dev/ttys041', isHeld: false }))
  expect(taken).toEqual(resumed({ claude: W1, device: '/dev/ttys041', isHeld: false, ownsDevice: false }))
})

test("no live window and none to resume can't be carried on, saying no window of it is left", () => {
  expect(reach({})).toEqual({ answer: `${NAME} can't be carried on from here: no window of it is left.` })
})

test('a session in Snoozed alone, as its row there names it, picks the same way', () => {
  const snoozed = sessionOf({
    lines: [
      [T0, yesAsk('k1', 'Review round 1')],
      [T0 + MIN, snoozeSession(NOW + 60 * MIN, 'k1')],
    ],
    presence: windowOn(W1, { where: inZmx('/dev/ttys041') }),
  })
  const feed = feedWith(snoozed)

  expect([feed.rows.length, feed.snoozed.map(row => row.name)]).toEqual([0, [NAME]])
  expect(reachOf(META.id, feed)).toEqual(resumed({ claude: W1, device: '/dev/ttys041' }))
})

test('a session gone from the board opens nothing, in the words of the app', () => {
  expect(reachOf('sr-nw0009', feedWith(sessionOf()))).toEqual({ answer: 'There is no such session on the board, in any project.' })
})

/** The user's own command, naming every placeholder. */
const OWN = 'attach {tty} {dir} {claude}'

const HELD: Resume = { name: NAME, claude: W1, dir: FOLDER, device: '/dev/ttys041', isHeld: true, ownsDevice: true }

const AWAY: Resume = { ...HELD, isHeld: false }

/** The pick carried on as the edge readies it, the command typed first; a test of a command not fit to fill throws. */
const carried = (resume: Resume, there: ClaudeThere, command = DEFAULT_COMMAND) => {
  const typed = typedOf(command, NAME)

  if (!typed.ok) {
    throw new Error(typed.error)
  }

  return carriedOn(resume, there, typed.value)
}

const ran = (value: string) => ({ ok: true, value })

const refused = (error: string) => ({ ok: false, error })

const STILL_RUNNING = refused(`${NAME}'s Claude is still running: set a resume command that can reach it, in SitRep's Settings.`)

const SUSPENDED = refused(`${NAME} is suspended in its window: type fg there to bring it back.`)

test("a Claude suspended on the window's device refuses whatever the command, a later conversation's device among them", () => {
  const resumes = [HELD, AWAY, { ...AWAY, ownsDevice: false }]

  expect(resumes.flatMap(resume => [DEFAULT_COMMAND, OWN].map(command => carried(resume, 'stopped', command)))).toEqual(Array(6).fill(SUSPENDED))
})

test('`ps` giving no answer refuses whatever the command, before anything runs', () => {
  expect([DEFAULT_COMMAND, OWN].map(command => carried(AWAY, 'unknown', command))).toEqual(
    Array(2).fill(refused(`Could not tell whether ${NAME}'s Claude is still running: the process table gave no answer.`)),
  )
})

test("a Claude running on its own device refuses the default, saved with spaces round it or not; the user's command runs, `{tty}` the device", () => {
  expect([HELD, AWAY].map(resume => carried(resume, 'running'))).toEqual([STILL_RUNNING, STILL_RUNNING])
  expect(carried(AWAY, 'running', `  ${DEFAULT_COMMAND}\n`)).toEqual(STILL_RUNNING)
  expect(carried(AWAY, 'running', OWN)).toEqual(ran(`attach '/dev/ttys041' '${FOLDER}' '${W1}'`))
})

test("a Claude of a later conversation on the device is not the session's: it refuses nothing and is no `{tty}`", () => {
  const taken = { ...AWAY, ownsDevice: false }

  expect(carried(taken, 'running')).toEqual(ran(`cd '${FOLDER}' && claude --resume '${W1}'`))
  expect(carried(taken, 'running', OWN)).toEqual(ran(`attach '' '${FOLDER}' '${W1}'`))
})

test('held with no Claude seen on its device, as a tab just closed, the default refuses as just stopped; the user\'s command runs, `{tty}` empty', () => {
  expect(carried(HELD, 'none')).toEqual(refused(`${NAME}'s window has just stopped answering: try again in a moment.`))
  expect(carried(HELD, 'none', OWN)).toEqual(ran(`attach '' '${FOLDER}' '${W1}'`))
})

test('away with no Claude on its device, the default resumes the conversation in its folder', () => {
  expect(carried(AWAY, 'none')).toEqual(ran(`cd '${FOLDER}' && claude --resume '${W1}'`))
  expect(carried({ ...AWAY, dir: "/Users/me/Code/team's work" }, 'none')).toEqual(ran(`cd '/Users/me/Code/team'\\''s work' && claude --resume '${W1}'`))
})

test("a window that said no folder refuses a command naming `{dir}`, in the window's words; one naming only `{claude}` runs", () => {
  const older: Resume = { name: NAME, claude: W1, device: '/dev/ttys041', isHeld: false, ownsDevice: true }

  expect(carried(older, 'none')).toEqual(
    refused(`${NAME}'s last window did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}.`),
  )
  expect(carried(older, 'none', 'claude --resume {claude}')).toEqual(ran(`claude --resume '${W1}'`))
})
