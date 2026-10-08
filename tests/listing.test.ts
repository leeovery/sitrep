import { expect, test } from 'claude-code/testing'
import { EXIT } from '../cli/main'
import { projectOf, type WorkMeta } from '../core'
import { ask, META, MIN, note, park, resolve, status, T0, W1, W2 } from './support'
import { NOW, terminal } from './terminal'
import { ELSEWHERE, PROJECT } from './world'

const DAY = 24 * 60 * MIN

const QUIET = projectOf('/Users/lee/Code/quiet/.git')
const STALE = projectOf('/Users/lee/Code/stale/.git')

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

/** This project: an open work holding an ask and something parked, an idle one, and two from last week. */
const busyHere = () => {
  const t = terminal()

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

/** Every project: this one, one with asks waiting, one idle, and one with only an old work. */
const everywhere = () => {
  const t = busyHere()

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

test("list: this project's current works, an open one first, each with its id and what it holds", async () => {
  expect(await busyHere().run('list')).toEqual({
    exit: EXIT.done,
    out: [
      'switchboard',
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
        name: 'switchboard',
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

test('list --all: this project first, then the busiest, the idle last; one with no current work is left out', async () => {
  const t = everywhere()
  const { out } = await t.run('list', '--all', '--json')
  const projects = JSON.parse(out).projects as { key: string; name: string; works: unknown[] }[]

  expect(projects.map(project => [project.name, project.works.length])).toEqual([
    ['switchboard', 3],
    ['goosemates', 1],
    ['quiet', 1],
  ])
  expect(projects.map(project => project.key)).toEqual([PROJECT.key, ELSEWHERE.key, QUIET.key])
  expect((await t.run('list', '--all')).out).toBe(
    [
      'switchboard',
      '  sr-k3f9qa  Dashboard redesign (open, 1 waiting, 1 parked)',
      '  sr-bbbbbb  Lobby',
      '  sr-cccccc  Old but waiting (1 waiting)',
      'goosemates',
      '  sr-eeeeee  Onboarding (2 waiting)',
      'quiet',
      '  sr-ffffff  Tidying',
      '',
    ].join('\n'),
  )
})

test('list names this project even with nothing current in it', async () => {
  const t = terminal()

  expect((await t.run('list')).out).toBe('switchboard\n  no current pieces of work\n')
  expect(JSON.parse((await t.run('list', '--json')).out).projects).toEqual([
    {
      key: PROJECT.key,
      name: 'switchboard',
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
    project: { key: PROJECT.key, name: 'switchboard' },
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
