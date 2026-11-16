/**
 * The sample data the tests share: times, windows, the projects and sessions
 * under test, and the asks Claude posts. Every name is a placeholder.
 */
import type { Project, SessionMeta } from '../core'

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

/** Where sitrep keeps its folder, as `XDG_STATE_HOME` names it, and that folder. */
export const STATE_HOME = '/state'
export const ROOT = `${STATE_HOME}/sitrep`

/** Lee's home folder, which a window may start in to talk of any project. */
export const HOME = '/Users/me'

/** The folder the window starts in: Northwind's repository, though that decides nothing. */
export const REPO = `${HOME}/Code/northwind`

/** The project the sessions under test are on: named so by Claude as it starts one, its key the name's slug. */
export const PROJECT: Project = { key: 'northwind', name: 'Northwind' }

/** Another project, with a session of its own. */
export const ELSEWHERE: Project = { key: 'contoso', name: 'Contoso' }

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

/** The asks Claude posts with the ask tool: a review wanting a yes, a go wanting one in its own words, and a choice. */
export const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Tickets & Replies, round 1' }
export const GO = { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' }
export const FRAMES = {
  wants: 'choice',
  title: 'Ship round 2, or redraw?',
  options: ['Ship it', 'Redraw'],
}

/** A review of round `n`, for a test asking several. */
export const reviewRound = (n: number) => ({
  wants: 'yes',
  yes: 'Approve',
  title: `Review round ${n}`,
})

/** Reviews of rounds 1 to `count`. */
export const reviewRounds = (count: number) =>
  Array.from({ length: count }, (_, i) => reviewRound(i + 1))

/** The line under a reply to an ask in Lee's message saying it closed the ask. */
export const CLOSES = '\n  This closes the ask: nothing more to do with it.'

/** The line under a comment in Lee's message saying it left its ask open. */
export const LEAVES_OPEN = '\n  This leaves the ask open: act on it, then resolve it.'
