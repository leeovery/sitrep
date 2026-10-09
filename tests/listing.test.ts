import { expect, test } from 'claude-code/testing'
import { EXIT } from '../cli/main'
import type { WorkMeta } from '../core'
import { ask, finish, META, MIN, note, park, resolve, status, T0, W1, W2 } from './support'
import { NOW, terminal } from './terminal'
import { ELSEWHERE, HOME, PROJECT, REPO } from './world'

const DAY = 24 * 60 * MIN

const QUIET = { key: 'quiet', name: 'Quiet' }
const STALE = { key: 'stale', name: 'Stale' }

const LOBBY: WorkMeta = { ...META, id: 'sr-bbbbbb', name: 'Lobby', summary: 'The lobby screen' }

const OLD_WAITING: WorkMeta = {
  ...META,
  id: 'sr-cccccc',
  name: 'Old but waiting',
  summary: 'An ask left from last week',
  created: T0 - 8 * DAY,
}

const OLD: WorkMeta = { ...OLD_WAITING, id: 'sr-dddddd', name: 'Old and idle' }

const GOOSE: WorkMeta = {
  ...META,
  id: 'sr-eeeeee',
  name: 'Onboarding',
  summary: 'The first-run flow',
  project: 'goosemates',
  root: '/Users/lee/Code/goosemates',
  by: W2,
}

const QUIETLY: WorkMeta = { ...GOOSE, id: 'sr-ffffff', name: 'Tidying', project: 'quiet' }

const STALE_WORK: WorkMeta = { ...OLD, id: 'sr-gggggg', project: 'stale' }

/** Switchboard, living where the CLI runs: an open work holding an ask and something parked, an idle one, and two from last week. */
const busyHere = (cwd = REPO) => {
  const t = terminal({ cwd })

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  t.seed(META, {
    seenAt: NOW,
    lines: [
      [T0, status(['Drawing Usage'], { next: 'Usage, round 3' })],
      [T0, ask('k1', 'review', 'Review round 1')],
      [T0, park('p1', 'A tmux indicator')],
    ],
  })
  t.seed(LOBBY)
  t.seed(OLD_WAITING, { lines: [[OLD_WAITING.created, ask('k2', 'do', 'Run the apply')]] })
  t.seed(OLD)

  return t
}

/** Every project: Switchboard, one with asks waiting, one idle, and one with only an old work. */
const everywhere = (cwd = REPO) => {
  const t = busyHere(cwd)

  t.seed(GOOSE, {
    project: ELSEWHERE.key,
    lines: [
      [T0, ask('k1', 'decide', 'Email or Apple?', ['Email', 'Apple'])],
      [T0, ask('k2', 'try', 'Try the flow')],
    ],
  })
  t.seed(QUIETLY, { project: QUIET.key })
  t.seed(STALE_WORK, { project: STALE.key })

  return t
}

test("list: each project's current works, an open one first, each with its id and what it holds", async () => {
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

test('list --json: the project the CLI runs in, and each project with its current works', async () => {
  const { exit, out } = await busyHere().run('list', '--json')

  expect(exit).toBe(EXIT.done)
  expect(JSON.parse(out)).toEqual({
    v: 1,
    here: PROJECT.key,
    projects: [
      {
        key: PROJECT.key,
        name: 'Switchboard',
        open: 1,
        waiting: 2,
        parked: 1,
        updatedAt: T0,
        works: [
          {
            id: META.id,
            name: META.name,
            summary: META.summary,
            now: ['Drawing Usage'],
            next: 'Usage, round 3',
            isOpen: true,
            waiting: 1,
            parked: 1,
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
            parked: 0,
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
            parked: 0,
            updatedAt: OLD_WAITING.created,
          },
        ],
      },
    ],
  })
})

test('list: every project, the one the CLI runs in first, then the busiest, the idle last; one with no current work is left out', async () => {
  const t = everywhere()
  const { out } = await t.run('list', '--json')
  const projects = JSON.parse(out).projects as { key: string; name: string; works: unknown[] }[]

  expect(projects.map(project => [project.name, project.works.length])).toEqual([
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
    v: 1,
    here: null,
    projects: [
      {
        key: STALE.key,
        name: 'Stale',
        open: 0,
        waiting: 0,
        parked: 0,
        updatedAt: 0,
        works: [],
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

test('list leaves out a finished work, whatever it holds, and a project left with none', async () => {
  const t = everywhere()

  t.seed(LOBBY, {
    lines: [
      [T0, ask('k3', 'do', 'Check the lobby')],
      [T0 + MIN, finish('lee')],
    ],
  })
  t.seed(GOOSE, {
    project: ELSEWHERE.key,
    seenAt: NOW,
    lines: [
      [T0, ask('k1', 'try', 'Try the flow')],
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

  expect((await t.run('list')).out).toBe('No current pieces of work on the board.\n')
  expect(JSON.parse((await t.run('list', '--json')).out)).toEqual({
    v: 1,
    here: null,
    projects: [],
  })

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  expect((await t.run('list')).out).toBe('Switchboard\n  no current pieces of work\n')
  expect(JSON.parse((await t.run('list', '--json')).out).projects).toEqual([
    {
      key: PROJECT.key,
      name: 'Switchboard',
      open: 0,
      waiting: 0,
      parked: 0,
      updatedAt: 0,
      works: [],
    },
  ])
})

test('board --json: the work as list gives it, its open asks, what it parked and its latest log lines', async () => {
  const t = terminal()

  t.seed(META, {
    seenAt: NOW,
    lines: [
      [T0, status(['Drawing Usage'], { next: 'Usage, round 3' })],
      [T0 + 1, ask('k1', 'review', 'Review round 1')],
      [T0 + 1, ask('k2', 'do', 'Run the apply')],
      [T0 + 2, park('p1', 'A tmux indicator')],
      [T0 + 3, note('n1', 'Merged', ['PR #82'])],
      [T0 + 4, resolve('k2')],
    ],
  })

  const { exit, out } = await t.run('board', '--json', '--work', META.id)

  expect(exit).toBe(EXIT.done)
  expect(JSON.parse(out)).toEqual({
    v: 1,
    project: { key: PROJECT.key, name: 'Switchboard' },
    work: {
      id: META.id,
      name: META.name,
      summary: META.summary,
      now: ['Drawing Usage'],
      next: 'Usage, round 3',
      isOpen: true,
      waiting: 1,
      parked: 1,
      updatedAt: T0 + 4,
    },
    asks: [
      {
        id: 'k1',
        kind: 'review',
        title: 'Review round 1',
        where: null,
        options: [],
        ref: null,
        state: 'waiting',
        at: T0 + 1,
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
  })
})
