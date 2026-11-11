import { expect, test } from 'claude-code/testing'
import {
  allProjects,
  brief,
  BRIEF_LOG_LINES,
  CURRENT_MS,
  foldSession,
  isCurrent,
  listedProjects,
  metaText,
  parkedBy,
  projectLog,
  projectParked,
  summarise,
  summariseProject,
  type ProjectSummary,
  type Session,
  type SessionFiles,
} from '../core'
import {
  CLI,
  delivered,
  file,
  finish,
  META,
  MIN,
  note,
  park,
  reply,
  resolve,
  seen,
  status,
  T0,
  W1,
  W2,
  yesAsk,
  type Line,
} from './support'

const NOW = T0 + 60 * MIN

/** A session of `project`, folded at NOW from its own meta and files. */
const sessionOf = (id: string, project: string, files: Partial<SessionFiles>, created = T0): Session => {
  const session = foldSession(
    { meta: metaText({ ...META, id, project, created }), logs: {}, ...files },
    NOW,
  )

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

/** A project summary with these counts, the rest empty; its asks waiting as posted count those waiting on Lee, as a project's do. */
const project = (key: string, counts: Partial<ProjectSummary> = {}): ProjectSummary => ({
  key,
  name: key,
  sessions: [],
  open: 0,
  waiting: 0,
  snoozed: 0,
  asked: counts.waiting ?? 0,
  parked: 0,
  updatedAt: T0,
  ...counts,
})

const keys = (projects: readonly ProjectSummary[]) => projects.map(each => each.key)

test('a session in brief: what it is doing, whether a window has it, what it holds for Lee, and when it started', () => {
  const session = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: {
      [W1]: file(
        [T0 + MIN, status(['Drawing Usage, round 2'], { next: 'Usage, round 3' })],
        [T0 + 2 * MIN, yesAsk('k1', 'Review round 1')],
        [T0 + 3 * MIN, yesAsk('k2', 'Run the apply', 'Done')],
        [T0 + 4 * MIN, park('p1', 'Later')],
      ),
    },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(summarise(session)).toEqual({
    id: 'sr-aaaaaa',
    name: 'Dashboard redesign',
    summary: 'Redesign the dashboard, area by area in Paper',
    project: 'Switchboard',
    now: ['Drawing Usage, round 2'],
    next: 'Usage, round 3',
    isOpen: true,
    isFinished: false,
    waiting: 2,
    snoozed: 0,
    asked: 2,
    parked: 1,
    created: T0,
    updatedAt: T0 + 4 * MIN,
  })
})

test('a project adds up its sessions, those with a window first, then the most recently updated, and counts what is parked in it', () => {
  const quiet = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file([T0 + 50 * MIN, yesAsk('k1', 'Try it', 'It works')]) },
  })
  const open = sessionOf('sr-bbbbbb', 'switchboard', {
    logs: { [W2]: file([T0 + 10 * MIN, park('p1', 'Later')]) },
    presence: { [W2]: seen(W2, NOW) },
  })
  const older = sessionOf('sr-cccccc', 'switchboard', { logs: {} })

  const sessions = [older, quiet, open]

  expect(
    summariseProject(
      'switchboard-1a2b3c4d',
      sessions.map(summarise),
      sessions.flatMap(parkedBy).length,
    ),
  ).toMatchObject({
    key: 'switchboard-1a2b3c4d',
    name: 'Switchboard',
    sessions: [{ id: 'sr-bbbbbb' }, { id: 'sr-aaaaaa' }, { id: 'sr-cccccc' }],
    open: 1,
    waiting: 1,
    parked: 1,
    updatedAt: T0 + 50 * MIN,
  })
})

test('All projects: this project first, then the busiest, by waiting, then windows, then parked', () => {
  const view = allProjects(
    [
      project('parked', { parked: 3 }),
      project('here'),
      project('open', { open: 2 }),
      project('waiting-1', { waiting: 1, open: 3 }),
      project('waiting-2', { waiting: 2 }),
    ],
    'here',
  )

  expect(keys(view.projects)).toEqual(['here', 'waiting-2', 'waiting-1', 'open', 'parked'])
})

test('a project with nothing open, waiting or parked folds into one line, the most recent first', () => {
  const view = allProjects(
    [
      project('busy', { waiting: 1 }),
      project('idle-old', { updatedAt: T0 }),
      project('idle-new', { updatedAt: T0 + MIN }),
    ],
    'busy',
  )

  expect(keys(view.projects)).toEqual(['busy'])
  expect(keys(view.folded)).toEqual(['idle-new', 'idle-old'])
})

test("a project whose asks wait only on a window to deliver Lee's answers is not folded: its sessions are current", () => {
  const answered = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file([T0, yesAsk('k1', 'Run it', 'Done')]) },
    inbox: { [CLI]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })
  const summary = summariseProject('switchboard-1a2b3c4d', [summarise(answered)], 0)
  const view = allProjects([summary, project('here')], 'here')

  expect(summary).toMatchObject({ waiting: 0, asked: 1 })
  expect(keys(view.projects)).toEqual(['here', 'switchboard-1a2b3c4d'])
  expect(view.folded).toEqual([])
})

test('this project is never folded away, however quiet', () => {
  const view = allProjects([project('elsewhere', { open: 1 }), project('here')], 'here')

  expect(keys(view.projects)).toEqual(['here', 'elsewhere'])
  expect(view.folded).toEqual([])
})

test('equally busy projects order by their latest update, then by name', () => {
  const view = allProjects([
    project('b', { waiting: 1, updatedAt: T0 }),
    project('a', { waiting: 1, updatedAt: T0 }),
    project('c', { waiting: 1, updatedAt: T0 + MIN }),
  ])

  expect(keys(view.projects)).toEqual(['c', 'a', 'b'])
})

test("a project's log holds every session's lines, newest first, each naming its session", () => {
  const first = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file([T0 + 1 * MIN, note('n1', 'one')], [T0 + 4 * MIN, note('n4', 'four')]) },
  })
  const second = sessionOf('sr-bbbbbb', 'switchboard', {
    logs: { [W2]: file([T0 + 2 * MIN, note('n2', 'two')], [T0 + 3 * MIN, status(['Drawing'])]) },
  })

  expect(projectLog([first, second]).map(line => [line.session, line.text])).toEqual([
    ['sr-aaaaaa', 'four'],
    ['sr-bbbbbb', 'Status: now drawing'],
    ['sr-bbbbbb', 'two'],
    ['sr-aaaaaa', 'one'],
  ])
})

test('an idle session shows for 7 days after its last update, then drops out of the views', () => {
  const idle = summarise(
    sessionOf('sr-aaaaaa', 'switchboard', { logs: { [W1]: file([NOW, note('n1', 'Drew it')]) } }),
  )

  expect(isCurrent(idle, NOW + CURRENT_MS)).toBe(true)
  expect(isCurrent(idle, NOW + CURRENT_MS + 1)).toBe(false)
})

test('open or waiting on Lee, a session shows however long ago it was updated', () => {
  const later = T0 + 30 * CURRENT_MS
  const open = sessionOf('sr-aaaaaa', 'switchboard', { presence: { [W1]: seen(W1, NOW) } })
  const waiting = sessionOf('sr-bbbbbb', 'switchboard', {
    logs: { [W1]: file([T0, yesAsk('k1', 'Run it', 'Done')]) },
  })

  for (const session of [open, waiting]) {
    expect(isCurrent(summarise(session), later), session.id).toBe(true)
  }
})

test("something parked keeps no session current: it is its project's, and its session leaves the views after its 7 days", () => {
  const parked = summarise(
    sessionOf('sr-cccccc', 'switchboard', { logs: { [W1]: file([T0, park('p1', 'Later')]) } }),
  )

  expect(parked.parked).toBe(1)
  expect(isCurrent(parked, T0 + CURRENT_MS)).toBe(true)
  expect(isCurrent(parked, T0 + CURRENT_MS + 1)).toBe(false)
})

test('a project with something parked is listed, unfolded, counting it from every session filed under it, finished and idle ones included, though none of its sessions is current', () => {
  const later = T0 + 30 * CURRENT_MS
  const finished = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: {
      [W1]: file(
        [T0, park('p1', 'Export the ledger as CSV')],
        [T0 + MIN, finish('claude', 'Shipped')],
      ),
    },
  })
  const idle = sessionOf('sr-bbbbbb', 'switchboard', {
    logs: { [W2]: file([T0, park('p2', 'Archive old requests')]) },
  })
  const quiet = sessionOf('sr-cccccc', 'portal', { logs: {} })
  const listed = listedProjects(
    [
      {
        project: { key: 'switchboard', name: 'Switchboard' },
        sessions: [finished, idle].map(summarise),
      },
      { project: { key: 'portal', name: 'Portal' }, sessions: [summarise(quiet)] },
    ],
    '/Users/lee',
    later,
  )

  expect(listed.map(each => [each.key, each.parked, each.sessions])).toEqual([
    ['switchboard', 2, []],
  ])
  expect(allProjects(listed).folded).toEqual([])
})

test('an ask whose answer from Lee is on its way keeps its session current as an ask waiting on Lee does, however long the answer waits; delivered, it ages out', () => {
  const later = NOW + 30 * CURRENT_MS
  const asked: Line = [T0, yesAsk('k1', 'Run it', 'Done')]
  const letters = { [CLI]: file([NOW, reply('r1', 'k1', 'yes')]) }
  const answered = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file(asked) },
    inbox: letters,
  })
  const closed = sessionOf('sr-bbbbbb', 'switchboard', {
    logs: { [W1]: file(asked, [NOW, delivered('r1')]) },
    inbox: letters,
  })

  expect(summarise(answered)).toMatchObject({ waiting: 0, asked: 1 })
  expect(isCurrent(summarise(answered), later)).toBe(true)
  expect(summarise(closed)).toMatchObject({ waiting: 0, asked: 0 })
  expect(isCurrent(summarise(closed), later)).toBe(false)
})

test('a finished session is out of the views whatever it holds, and its asks count nowhere', () => {
  const finished = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: {
      [W1]: file(
        [NOW - MIN, yesAsk('k1', 'Run it', 'Done')],
        [NOW - MIN, park('p1', 'Later')],
        [NOW, finish('lee')],
      ),
    },
    presence: { [W1]: seen(W1, NOW) },
  })
  const summary = summarise(finished)

  expect(summary).toMatchObject({ isOpen: true, isFinished: true, waiting: 0, parked: 1 })
  expect(isCurrent(summary, NOW)).toBe(false)
  expect(summariseProject('switchboard-1a2b3c4d', [summary], 1).waiting).toBe(0)
})

test('a brief carries the latest log lines a view shows, and what the session has parked', () => {
  const notes = Array.from(
    { length: BRIEF_LOG_LINES + 2 },
    (_, i): Line => [T0 + i * MIN, note(`n${i}`, `note ${i}`)],
  )
  const session = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file(...notes, [T0, park('p1', 'Later')]) },
  })
  const briefed = brief(session)

  expect(briefed.log).toHaveLength(BRIEF_LOG_LINES)
  expect(briefed.log[0]?.text).toBe(`note ${BRIEF_LOG_LINES + 1}`)
  expect(briefed.parkedItems.map(each => each.id)).toEqual(['p1'])
  expect(briefed.parked).toBe(1)
})

test('a brief carries the asks still open, a replied one among them, and none closed', () => {
  const session = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: {
      [W1]: file(
        [T0, yesAsk('k1', 'Review round 1')],
        [T0 + MIN, yesAsk('k2', 'Review round 2')],
        [T0 + 2 * MIN, yesAsk('k3', 'Review round 3')],
        [T0 + 3 * MIN, resolve('k1', 'Done in the chat')],
        [T0 + 4 * MIN, reply('r1', 'k2', 'comment', { note: 'thinner bars' })],
        [T0 + 4 * MIN, delivered('r1')],
      ),
    },
  })

  expect(brief(session).asks.map(ask => [ask.id, ask.state])).toEqual([
    ['k2', 'replied'],
    ['k3', 'waiting'],
  ])
})

test("a project's parked items, oldest first, each naming the session that parked it by its id and its name", () => {
  const first = sessionOf('sr-aaaaaa', 'switchboard', {
    logs: { [W1]: file([T0, status([], { name: 'Ledger' })], [T0 + 2 * MIN, park('p1', 'B')]) },
  })
  const second = sessionOf('sr-bbbbbb', 'switchboard', {
    logs: { [W2]: file([T0 + MIN, park('p2', 'A')]) },
  })

  const parked = projectParked([first, second].flatMap(parkedBy))

  expect(parked.map(each => [each.session, each.name, each.id])).toEqual([
    ['sr-bbbbbb', META.name, 'p2'],
    ['sr-aaaaaa', 'Ledger', 'p1'],
  ])
})
