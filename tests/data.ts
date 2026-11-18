/**
 * The sample data the tests share: times, windows, the projects and sessions
 * under test, and the asks Claude posts. Every name is a placeholder.
 */
import type { AskBody, FolderKey, Project, ProjectKey, SessionMeta } from '../core'
import { itemKey } from '../hooks/places'

export const MIN = 60_000
export const HOUR = 60 * MIN
export const DAY = 24 * HOUR

/** When the session under test was started. */
export const T0 = 1_760_000_000_000

/** The window that started the session, a second window, two more on other sessions, and the CLI. */
export const W1 = 'b1c2d3e4-0000-4000-8000-000000000001'
export const W2 = 'b1c2d3e4-0000-4000-8000-000000000002'
export const W3 = 'b1c2d3e4-0000-4000-8000-000000000003'
export const W4 = 'b1c2d3e4-0000-4000-8000-000000000004'
export const CLI = 'cli'

/** A window on another session, sending replies into this one's inbox. */
export const SENDER = 'f0e1d2c3-0000-4000-8000-0000000000ff'

/** A subagent's loop. */
export const AGENT = 'a1b2c3d4'

/** The sitrep version the plugin's manifest gives, unless a test says otherwise. */
export const PLUGIN_VERSION = '0.2.0'

/** A name, or a guess at a pronoun, where a text Claude reads names the person the board is for "the user". */
export const PERSON = /\b(Lee|he|him|his|she|her|hers)\b/i

/** Where sitrep keeps its folder, as `XDG_STATE_HOME` names it, and that folder. */
export const STATE_HOME = '/state'
export const ROOT = `${STATE_HOME}/sitrep`

/** Lee's home folder, which a window may start in to talk of any project. */
export const HOME = '/Users/me'

/** The folder the window starts in: Northwind's repository, though that decides nothing. */
export const REPO = `${HOME}/Code/northwind`

/** A project's key as the tests give it: the folder of each session started in it, and the project those sessions are filed under until one moves, for a test to give as either kind. */
export type BothKeys = FolderKey & ProjectKey

/** A project's key, given as a string, as a test gives it in a ref kept in `$.state`, or drawn, as either kind. */
export const keyed = (key: string) => key as BothKeys

/** A project on the board, by a key of both kinds. */
type TestProject = Project & { key: BothKeys }

/** The key of the project the sessions under test are on, as a plain string: what the helpers file a session under unless told. */
export const PROJECT_KEY = 'northwind'

/** The project the sessions under test are on: named so by Claude as it starts one, its key the name's slug. */
export const PROJECT: TestProject = { key: keyed(PROJECT_KEY), name: 'Northwind' }

/** Another project, with a session of its own. */
export const ELSEWHERE: TestProject = { key: keyed('contoso'), name: 'Contoso' }

/** The session the window starts, as Claude names it. */
export const HELP_DESK = {
  name: 'Help desk redesign',
  summary: 'Redesign the help desk, page by page',
  project: PROJECT.name,
}

export const META: SessionMeta = {
  id: 'sr-k3f9qa',
  name: 'Help desk redesign',
  summary: 'Redesign the help desk, page by page in Paper',
  project: 'northwind',
  root: REPO,
  created: T0,
  by: W1,
}

/** A session started by `by`: summed up by its name, filed under `project`, Northwind unless told, at `created`, T0 unless told. */
export const meta = (
  id: string,
  name: string,
  by: string,
  { project = PROJECT.key, created = T0 }: { project?: string; created?: number } = {},
): SessionMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project,
  root: `${HOME}/Code/${project}`,
  created,
  by,
})

/** The session a pure test's window holds (render.ts): Help desk redesign, filed under Northwind, started by this window at T0. */
export const HELD: SessionMeta = {
  id: 'sr-he1d00',
  ...HELP_DESK,
  root: REPO,
  created: T0,
  by: W1,
}

/** An item of the held session by its address, as its buttons' keys and the pane name it. */
export const heldItem = (id: string) => itemKey(HELD.id, id)

/** A change of a session's status by its address, as its row and its press are keyed: its session, its time and its writer. */
export const changeKey = (session: string, at: number, writer: string) =>
  itemKey(session, `${at}:${writer}`)

/** Another session of Northwind's, started by the second window. */
export const LEDGER = meta('sr-1edger', 'Invoice ledger', W2)

/** Another session of Northwind's, started by a window on another session. */
export const THEMES = meta('sr-themes', 'Themes', W3)

/** A session of Contoso's. */
export const SHIFTS = meta('sr-0sh1ft', 'Shift schedules', W4, { project: ELSEWHERE.key })

/**
 * A session of Northwind's as a build before 11 November 2026 left it, its
 * files byte for byte, nine days idle and finished: two items still parked,
 * a third picked up. What its files say is literal, so no builder of today's
 * can make it look newer than it is.
 */
export const PARKED_BEFORE = {
  id: 'sr-1edger',
  writer: W2,
  meta: '{"v":1,"id":"sr-1edger","name":"Invoice ledger","summary":"The invoice ledger, area by area","project":"northwind","root":"/Users/me/Code/northwind","created":1759136000000,"by":"b1c2d3e4-0000-4000-8000-000000000002"}\n',
  log: [
    '{"v":1,"at":1759136000000,"seq":1,"type":"status","name":"Invoice ledger","summary":"The invoice ledger, area by area","now":["Drawing the ledger schema"]}',
    '{"v":1,"at":1759136060000,"seq":2,"type":"park","title":"Export the ledger as CSV","ref":"PR #82","id":"p1"}',
    '{"v":1,"at":1759136120000,"seq":3,"type":"park","title":"Archive old invoices","where":"After the release","id":"p2"}',
    '{"v":1,"at":1759136180000,"seq":4,"type":"park","title":"Retry the export","id":"p3"}',
    '{"v":1,"at":1759222400000,"seq":5,"type":"reply","id":"r1","item":"p3","verdict":"pickup"}',
    '{"v":1,"at":1759222400000,"seq":6,"type":"delivered","replies":["r1"]}',
    '{"v":1,"at":1759222460000,"seq":7,"type":"finish","who":"claude","reason":"Shipped"}',
    '',
  ].join('\n'),
}

/** An ask as Claude posts it with the ask tool. */
export type Asked = Omit<AskBody, 'type' | 'id'>

/** The asks Claude posts with the ask tool: a review wanting a yes, a go wanting one in its own words, and a choice. */
export const REVIEW = {
  wants: 'yes',
  yes: 'Approve',
  title: 'Review Tickets & Replies, round 1',
} satisfies Asked
export const GO = { wants: 'yes', yes: 'Go', title: 'Give the ok for phase 3' } satisfies Asked
export const FRAMES = {
  wants: 'choice',
  title: 'Ship round 2, or redraw?',
  options: ['Ship it', 'Redraw'],
} satisfies Asked

/** A review of round `n`, for a test asking several. */
export const reviewRound = (n: number) =>
  ({
    wants: 'yes',
    yes: 'Approve',
    title: `Review round ${n}`,
  }) satisfies Asked

/** Reviews of rounds 1 to `count`. */
export const reviewRounds = (count: number) =>
  Array.from({ length: count }, (_, i) => reviewRound(i + 1))

/** The line under a reply to an ask in Lee's message saying it closed the ask. */
export const CLOSES = '\n  This closes the ask: nothing more to do with it.'

/** The line under a comment in Lee's message saying it left its ask open. */
export const LEAVES_OPEN = '\n  This leaves the ask open: act on it, then resolve it.'
