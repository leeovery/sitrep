import { expect, test } from 'claude-code/testing'
import { EXIT } from '../cli/main'
import { sessionPaths, type SessionMeta } from '../core'
import {
  choiceAsk,
  finish,
  META,
  MIN,
  note,
  park,
  PARKED_BEFORE,
  resolve,
  status,
  T0,
  W1,
  W2,
  wordsAsk,
  yesAsk,
} from './support'
import { NOW, terminal } from './terminal'
import { ELSEWHERE, HOME, PROJECT, REPO, ROOT } from './world'

const DAY = 24 * 60 * MIN

const QUIET = { key: 'quiet', name: 'Quiet' }
const STALE = { key: 'stale', name: 'Stale' }

const LOBBY: SessionMeta = { ...META, id: 'sr-bbbbbb', name: 'Lobby', summary: 'The lobby screen' }

const OLD_WAITING: SessionMeta = {
  ...META,
  id: 'sr-cccccc',
  name: 'Old but waiting',
  summary: 'An ask left from last week',
  created: T0 - 8 * DAY,
}

const OLD: SessionMeta = { ...OLD_WAITING, id: 'sr-dddddd', name: 'Old and idle' }

const GOOSE: SessionMeta = {
  ...META,
  id: 'sr-eeeeee',
  name: 'Onboarding',
  summary: 'The first-run flow',
  project: 'goosemates',
  root: '/Users/lee/Code/goosemates',
  by: W2,
}

const QUIETLY: SessionMeta = { ...GOOSE, id: 'sr-ffffff', name: 'Tidying', project: 'quiet' }

const STALE_SESSION: SessionMeta = { ...OLD, id: 'sr-gggggg', project: 'stale' }

/** Switchboard, living where the CLI runs: an open session holding an ask and something parked, an idle one, and two from last week. */
const busyHere = (cwd = REPO) => {
  const t = terminal({ cwd })

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  t.seed(META, {
    seenAt: NOW,
    lines: [
      [T0, status(['Drawing Usage'], { next: 'Usage, round 3' })],
      [T0, yesAsk('k1', 'Review round 1')],
      [T0, park('p1', 'A tmux indicator')],
    ],
  })
  t.seed(LOBBY)
  t.seed(OLD_WAITING, { lines: [[OLD_WAITING.created, yesAsk('k2', 'Run the apply', 'Done')]] })
  t.seed(OLD)

  return t
}

/** Every project: Switchboard, one with asks waiting, one idle, and one with only an old session. */
const everywhere = (cwd = REPO) => {
  const t = busyHere(cwd)

  t.seed(GOOSE, {
    project: ELSEWHERE.key,
    lines: [
      [T0, choiceAsk('k1', 'Email or Apple?', ['Email', 'Apple'])],
      [T0, yesAsk('k2', 'Try the flow', 'It works')],
    ],
  })
  t.seed(QUIETLY, { project: QUIET.key })
  t.seed(STALE_SESSION, { project: STALE.key })

  return t
}

test("list: each project's current sessions, an open one first, each with its id and what it holds", async () => {
  expect(await busyHere().run('list')).toEqual({
    exit: EXIT.done,
    out: [
      'Switchboard',
      '  sr-k3f9qa  Dashboard redesign (open, 1 waiting, 1 parked)',
      '  sr-bbbbbb  Lobby',
      '  sr-cccccc  Old but waiting (1 waiting)',
      '',
    ].join('\n'),
    err: '',
  })
})

test('list --json: the project the CLI runs in, and each project with its current sessions', async () => {
  const { exit, out } = await busyHere().run('list', '--json')

  expect(exit).toBe(EXIT.done)
  expect(JSON.parse(out)).toEqual({
    v: 2,
    here: PROJECT.key,
    projects: [
      {
        key: PROJECT.key,
        name: 'Switchboard',
        open: 1,
        waiting: 2,
        snoozed: 0,
        parked: 1,
        updatedAt: T0,
        sessions: [
          {
            id: META.id,
            name: META.name,
            summary: META.summary,
            now: ['Drawing Usage'],
            next: 'Usage, round 3',
            isOpen: true,
            waiting: 1,
            snoozed: 0,
            parked: 1,
            created: META.created,
            updatedAt: T0,
          },
          {
            id: LOBBY.id,
            name: LOBBY.name,
            summary: LOBBY.summary,
            now: [],
            next: null,
            isOpen: false,
            waiting: 0,
            snoozed: 0,
            parked: 0,
            created: LOBBY.created,
            updatedAt: T0,
          },
          {
            id: OLD_WAITING.id,
            name: OLD_WAITING.name,
            summary: OLD_WAITING.summary,
            now: [],
            next: null,
            isOpen: false,
            waiting: 1,
            snoozed: 0,
            parked: 0,
            created: OLD_WAITING.created,
            updatedAt: OLD_WAITING.created,
          },
        ],
      },
    ],
  })
})

test('list: every project, the one the CLI runs in first, then the busiest, the idle last; one with no current session is left out', async () => {
  const t = everywhere()
  const { out } = await t.run('list', '--json')
  const projects = JSON.parse(out).projects as { key: string; name: string; sessions: unknown[] }[]

  expect(projects.map(project => [project.name, project.sessions.length])).toEqual([
    ['Switchboard', 3],
    ['Goosemates', 1],
    ['Quiet', 1],
  ])
  expect(projects.map(project => project.key)).toEqual([PROJECT.key, ELSEWHERE.key, QUIET.key])
  expect((await t.run('list')).out).toBe(
    [
      'Switchboard',
      '  sr-k3f9qa  Dashboard redesign (open, 1 waiting, 1 parked)',
      '  sr-bbbbbb  Lobby',
      '  sr-cccccc  Old but waiting (1 waiting)',
      'Goosemates',
      '  sr-eeeeee  Onboarding (2 waiting)',
      'Quiet',
      '  sr-ffffff  Tidying',
      '',
    ].join('\n'),
  )
})

test('here is the nearest project whose directory holds the folder the CLI runs in, listed first; else null', async () => {
  const quietHome = '/Users/lee/Code/quiet'
  const t = everywhere(`${quietHome}/docs`)

  t.project(QUIET.key, { name: 'Quiet', directory: quietHome, created: T0, by: W1 })
  t.project('code', { name: 'Code', directory: '/Users/lee/Code', created: T0, by: W1 })

  const listed = JSON.parse((await t.run('list', '--json')).out)

  expect(listed.here).toBe(QUIET.key)
  expect(listed.projects.map((project: { key: string }) => project.key)).toEqual([
    QUIET.key,
    PROJECT.key,
    ELSEWHERE.key,
  ])
  expect(JSON.parse((await everywhere(HOME).run('list', '--json')).out).here).toBeNull()
})

test('list --project gives only that project, its name matched as start matches it', async () => {
  const t = everywhere(HOME)

  expect((await t.run('list', '--project', 'goose mates')).out).toBe(
    ['Goosemates', '  sr-eeeeee  Onboarding (2 waiting)', ''].join('\n'),
  )
  expect(JSON.parse((await t.run('list', '--project=STALE', '--json')).out)).toEqual({
    v: 2,
    here: null,
    projects: [
      {
        key: STALE.key,
        name: 'Stale',
        open: 0,
        waiting: 0,
        snoozed: 0,
        parked: 0,
        updatedAt: 0,
        sessions: [],
      },
    ],
  })
  expect(await t.run('list', '--project', 'Portal')).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: There is no project named Portal.\n',
  })
})

test('list takes no --all: every project is listed already', async () => {
  expect((await terminal().run('list', '--all')).err).toBe(
    'sitrep: There is no --all. sitrep list --help says more.\n',
  )
})

test('list leaves out a finished session, whatever it holds, and a project left with none', async () => {
  const t = everywhere()

  t.seed(LOBBY, {
    lines: [
      [T0, yesAsk('k3', 'Check the lobby', 'Done')],
      [T0 + MIN, finish('lee')],
    ],
  })
  t.seed(GOOSE, {
    project: ELSEWHERE.key,
    seenAt: NOW,
    lines: [
      [T0, yesAsk('k1', 'Try the flow', 'It works')],
      [T0 + MIN, finish('claude', 'Shipped')],
    ],
  })

  expect((await t.run('list')).out).toBe(
    [
      'Switchboard',
      '  sr-k3f9qa  Dashboard redesign (open, 1 waiting, 1 parked)',
      '  sr-cccccc  Old but waiting (1 waiting)',
      'Quiet',
      '  sr-ffffff  Tidying',
      '',
    ].join('\n'),
  )
})

test('list names the project the CLI runs in even with nothing current in it, and says when nothing is on the board', async () => {
  const t = terminal()

  expect((await t.run('list')).out).toBe('No current sessions on the board.\n')
  expect(JSON.parse((await t.run('list', '--json')).out)).toEqual({
    v: 2,
    here: null,
    projects: [],
  })

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  expect((await t.run('list')).out).toBe('Switchboard\n  no current sessions\n')
  expect(JSON.parse((await t.run('list', '--json')).out).projects).toEqual([
    {
      key: PROJECT.key,
      name: 'Switchboard',
      open: 0,
      waiting: 0,
      snoozed: 0,
      parked: 0,
      updatedAt: 0,
      sessions: [],
    },
  ])
})

test('board --json: the session as list gives it, its open asks, what it parked, its latest log lines and its resolved asks', async () => {
  const t = terminal()

  t.seed(META, {
    seenAt: NOW,
    lines: [
      [T0, status(['Drawing Usage'], { next: 'Usage, round 3' })],
      [T0 + 1, yesAsk('k1', 'Review round 1')],
      [T0 + 1, yesAsk('k2', 'Run the apply', 'Done')],
      [T0 + 1, wordsAsk('k3', 'Run sitrep list', "the command's output")],
      [T0 + 2, park('p1', 'A tmux indicator')],
      [T0 + 3, note('n1', 'Merged', ['PR #82'])],
      [T0 + 4, resolve('k2')],
    ],
  })

  const { exit, out } = await t.run('board', '--json', '--session', META.id)

  expect(exit).toBe(EXIT.done)
  expect(JSON.parse(out)).toEqual({
    v: 3,
    project: { key: PROJECT.key, name: 'Switchboard' },
    session: {
      id: META.id,
      name: META.name,
      summary: META.summary,
      now: ['Drawing Usage'],
      next: 'Usage, round 3',
      isOpen: true,
      waiting: 2,
      snoozed: 0,
      parked: 1,
      created: META.created,
      updatedAt: T0 + 4,
    },
    asks: [
      {
        id: 'k1',
        wants: 'yes',
        yes: 'Approve',
        title: 'Review round 1',
        where: null,
        options: [],
        needs: null,
        ref: null,
        state: 'waiting',
        at: T0 + 1,
        reply: null,
        snoozedUntil: null,
      },
      {
        id: 'k3',
        wants: 'words',
        yes: null,
        title: 'Run sitrep list',
        where: null,
        options: [],
        needs: "the command's output",
        ref: null,
        state: 'waiting',
        at: T0 + 1,
        reply: null,
        snoozedUntil: null,
      },
    ],
    parked: [{ id: 'p1', title: 'A tmux indicator', where: null, ref: null, at: T0 + 2 }],
    log: [
      { kind: 'note', id: 'n1', text: 'Merged', detail: ['PR #82'], ref: null, by: W1, at: T0 + 3 },
      {
        kind: 'status',
        id: null,
        text: 'Status: now drawing Usage',
        detail: ['Added: Drawing Usage', 'Next: Usage, round 3'],
        ref: null,
        by: W1,
        at: T0,
      },
    ],
    resolved: [
      {
        id: 'k2',
        wants: 'yes',
        yes: 'Done',
        title: 'Run the apply',
        where: null,
        options: [],
        needs: null,
        ref: null,
        state: 'closed',
        at: T0 + 1,
        reply: null,
        snoozedUntil: null,
        closedAt: T0 + 4,
        reason: null,
      },
    ],
  })
})

/** Switchboard as busyHere has it, the lobby having parked something and finished, the idle session from last week something too; and Stale, its one session idle past the views, with something parked. */
const parkedAround = () => {
  const t = busyHere()

  t.seed(LOBBY, {
    lines: [
      [T0, park('p1', 'Theme the lobby')],
      [T0 + MIN, finish('lee')],
    ],
  })
  t.seed(OLD, { lines: [[OLD.created, park('p1', 'Archive old requests')]] })
  t.seed(STALE_SESSION, {
    project: STALE.key,
    lines: [[STALE_SESSION.created, park('p1', 'Export the ledger as CSV')]],
  })

  return t
}

test("list --json: a project's parked counts every item parked in it, finished and idle sessions' included, each session's its own; one with only parked items is listed, its sessions empty", async () => {
  const { projects } = JSON.parse((await parkedAround().run('list', '--json')).out)

  expect(projects).toMatchObject([
    {
      key: PROJECT.key,
      parked: 3,
      sessions: [
        { id: META.id, parked: 1 },
        { id: OLD_WAITING.id, parked: 0 },
      ],
    },
    {
      key: STALE.key,
      name: 'Stale',
      open: 0,
      waiting: 0,
      snoozed: 0,
      parked: 1,
      updatedAt: 0,
      sessions: [],
    },
  ])
  expect((await parkedAround().run('list')).out).toBe(
    [
      'Switchboard',
      '  sr-k3f9qa  Dashboard redesign (open, 1 waiting, 1 parked)',
      '  sr-cccccc  Old but waiting (1 waiting)',
      'Stale',
      '  no current sessions',
      '',
    ].join('\n'),
  )
})

test("board prints the project's parked items, this session's first, each other naming its session; board --json's parked stays the session's own", async () => {
  const t = parkedAround()
  const board = await t.run('board', '--session', META.id)

  expect(board.out).toContain(
    [
      'Parked:',
      '- p1: A tmux indicator',
      '- p1, parked by "Old and idle" (session: sr-dddddd): Archive old requests',
      '- p1, parked by "Lobby" (session: sr-bbbbbb): Theme the lobby',
    ].join('\n'),
  )
  expect(JSON.parse((await t.run('board', '--json', '--session', META.id)).out).parked).toEqual([
    { id: 'p1', title: 'A tmux indicator', where: null, ref: null, at: T0 },
  ])
})

test("a finished session's files as a build before parked items were the project's left them: its items are listed and counted as the project's, and no run rewrites a byte", async () => {
  const t = terminal()
  const paths = sessionPaths(ROOT, PROJECT.key, PARKED_BEFORE.id)
  const filesThere = () =>
    [...t.files].flatMap(([path, { text }]) => (path.startsWith(paths.dir) ? [[path, text]] : []))

  t.seed(META, { seenAt: NOW })
  t.files.set(paths.meta, { text: PARKED_BEFORE.meta, mtimeMs: T0 })
  t.files.set(paths.log(PARKED_BEFORE.writer), { text: PARKED_BEFORE.log, mtimeMs: T0 })

  const before = filesThere()

  expect(JSON.parse((await t.run('list', '--json')).out).projects).toMatchObject([
    { key: PROJECT.key, parked: 2, sessions: [{ id: META.id, parked: 0 }] },
  ])
  expect((await t.run('board', '--session', META.id)).out).toContain(
    [
      'Parked:',
      '- p1, parked by "Request ledger" (session: sr-1edger): Export the ledger as CSV; ref: PR #82',
      '- p2, parked by "Request ledger" (session: sr-1edger): Archive old requests; where: After the release',
      'Latest notes:',
    ].join('\n'),
  )
  expect(filesThere()).toEqual(before)
})
