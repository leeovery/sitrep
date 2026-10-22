import { expect, test } from 'claude-code/testing'
import { LOOK_MS } from '../cli/look'
import { EXIT } from '../cli/main'
import { PS } from '../cli/screen'
import type { Where, SessionMeta } from '../core'
import {
  choiceAsk,
  finish,
  META,
  MIN,
  note,
  park,
  resolve,
  status,
  T0,
  W1,
  W2,
  wordsAsk,
  yesAsk,
} from './support'
import { ghosttyClient, NOW, phoneClient, SOCKET, sshClient, terminal } from './terminal'
import { ELSEWHERE, HOME, PROJECT, REPO } from './world'

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
    v: 1,
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
        works: [
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
            updatedAt: T0,
            onScreen: false,
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
            updatedAt: T0,
            onScreen: false,
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
            updatedAt: OLD_WAITING.created,
            onScreen: false,
          },
        ],
      },
    ],
  })
})

const SESSION_SOCKET = '/private/tmp/tmux-501/session'
const GONE_SOCKET = '/private/tmp/tmux-501/gone'

const inTmux = (socket: string, pane: string): Where => ({
  device: '/dev/ttys043',
  terminal: 'tmux',
  tmux: { socket, pane },
})

/**
 * Sessions each with a live window: in tmux on two servers and a third gone,
 * their tmux sessions shown by a Ghostty window, by the phone alone, or by a
 * Ghostty on another Mac over ssh; and one in a Ghostty window of its own.
 */
const onScreens = (options: Parameters<typeof terminal>[0] = {}) => {
  const t = terminal({
    tmux: {
      [SOCKET]: {
        panes: [
          ['%1', '@1'],
          ['%2', '@2'],
          ['%3', '@3'],
        ],
        clients: [
          ghosttyClient('/dev/ttys000', '@1'),
          phoneClient('/dev/ttys067', '@2'),
          sshClient('/dev/ttys080', '@3'),
        ],
      },
      [SESSION_SOCKET]: {
        panes: [['%9', '@9']],
        clients: [ghosttyClient('/dev/ttys010', '@9')],
      },
    },
    ...options,
  })

  t.seed(META, { seenAt: NOW, where: inTmux(SOCKET, '%1') })
  t.seed(LOBBY, { seenAt: NOW, where: inTmux(SOCKET, '%2') })
  t.seed(OLD_WAITING, { seenAt: NOW, where: inTmux(SOCKET, '%3') })
  t.seed(GOOSE, { project: ELSEWHERE.key, seenAt: NOW, where: inTmux(SESSION_SOCKET, '%9') })
  t.seed(QUIETLY, {
    project: QUIET.key,
    seenAt: NOW,
    where: { device: '/dev/ttys020', terminal: 'ghostty' },
  })
  t.seed(STALE_SESSION, { project: STALE.key, seenAt: NOW, where: inTmux(GONE_SOCKET, '%1') })

  return t
}

/** Whether each listed session is on screen, by its id. */
const onScreenOf = (out: string) => {
  const listed = JSON.parse(out) as { projects: { works: { id: string; onScreen: boolean }[] }[] }

  return Object.fromEntries(
    listed.projects.flatMap(project =>
      project.works.map(session => [session.id, session.onScreen]),
    ),
  )
}

test('list --json says whether a jump can reach each session, a Ghostty window of this Mac showing it, asking tmux twice a socket and ps once however many sessions, and knocking on nothing', async () => {
  const t = onScreens()
  const { exit, out } = await t.run('list', '--json')

  expect(exit).toBe(EXIT.done)
  expect(onScreenOf(out)).toEqual({
    [META.id]: true,
    [LOBBY.id]: false,
    [OLD_WAITING.id]: false,
    [GOOSE.id]: true,
    [QUIETLY.id]: true,
    [STALE_SESSION.id]: false,
  })
  const tmuxRuns = t.screen.ran.filter(([name]) => name === 'tmux')

  expect(tmuxRuns.map(([name, , , socket, command]) => [name, socket, command]).sort()).toEqual([
    ['tmux', SOCKET, 'list-clients'],
    ['tmux', SOCKET, 'list-panes'],
    ['tmux', GONE_SOCKET, 'list-clients'],
    ['tmux', GONE_SOCKET, 'list-panes'],
    ['tmux', SESSION_SOCKET, 'list-clients'],
    ['tmux', SESSION_SOCKET, 'list-panes'],
  ])
  expect(t.screen.ran.filter(([name]) => name !== 'tmux')).toEqual([PS])
  expect(t.screen.written).toEqual([])
  expect(t.screen.focused).toEqual([])
})

test('list --json still lists, every session in tmux off screen, when tmux or ps is not on PATH or does not answer', async () => {
  for (const options of [
    { missing: ['tmux'] },
    { slow: ['tmux'] },
    { missing: ['ps'] },
    { slow: ['ps'] },
  ]) {
    const why = JSON.stringify(options)
    const t = onScreens(options)
    const { exit, out, err } = await t.run('list', '--json')

    expect([exit, err], why).toEqual([EXIT.done, ''])
    expect(onScreenOf(out), why).toEqual({
      [META.id]: false,
      [LOBBY.id]: false,
      [OLD_WAITING.id]: false,
      [GOOSE.id]: false,
      [QUIETLY.id]: true,
      [STALE_SESSION.id]: false,
    })
    expect(
      t.screen.limits.every(each => each.limitMs === LOOK_MS),
      `${why}: tmux and ps are given the limit`,
    ).toBe(true)
  }
})

test('list --json asks tmux and ps nothing when no window runs in tmux', async () => {
  const t = terminal()

  t.seed(QUIETLY, { seenAt: NOW, where: { device: '/dev/ttys020', terminal: 'ghostty' } })
  t.seed(META, { seenAt: NOW })

  expect(onScreenOf((await t.run('list', '--json')).out)).toEqual({
    [META.id]: false,
    [QUIETLY.id]: true,
  })
  expect(t.screen.ran).toEqual([])
})

test('list --json counts a session on screen where a jump can reach it: a pane whose window tmux would select for a Ghostty window, or a window in a terminal app with no driver; and selects and opens nothing', async () => {
  const t = terminal({
    tmux: {
      [SOCKET]: {
        panes: [
          ['%1', '@1', '$1'],
          ['%2', '@2', '$1'],
          ['%3', '@3', '$3'],
        ],
        clients: [{ ...ghosttyClient('/dev/ttys000', '@2'), session: '$1' }],
      },
    },
  })

  t.seed(META, { seenAt: NOW, where: inTmux(SOCKET, '%1') })
  t.seed(LOBBY, { seenAt: NOW, where: inTmux(SOCKET, '%3') })
  t.seed(OLD_WAITING, { seenAt: NOW, where: { device: '/dev/ttys021', terminal: 'Unknown' } })
  t.seed(QUIETLY, {
    project: QUIET.key,
    seenAt: NOW,
    where: { device: '/dev/ttys020', terminal: 'iTerm.app' },
  })

  const { exit, out } = await t.run('list', '--json')

  expect(exit).toBe(EXIT.done)
  expect(JSON.parse(out).v).toBe(1)
  expect(onScreenOf(out)).toEqual({
    [META.id]: true,
    [LOBBY.id]: false,
    [OLD_WAITING.id]: false,
    [QUIETLY.id]: true,
  })
  expect(t.screen.ran.filter(([name]) => name !== 'tmux')).toEqual([PS])
  expect(t.screen.ran.filter(words => words.includes('select-window'))).toEqual([])
})

test('plain list runs no program at all, whatever windows its sessions are in', async () => {
  const t = onScreens()

  expect((await t.run('list')).exit).toBe(EXIT.done)
  expect(t.screen.ran).toEqual([])
})

test('list: every project, the one the CLI runs in first, then the busiest, the idle last; one with no current session is left out', async () => {
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
        snoozed: 0,
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
    v: 1,
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
      works: [],
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
    v: 2,
    project: { key: PROJECT.key, name: 'Switchboard' },
    work: {
      id: META.id,
      name: META.name,
      summary: META.summary,
      now: ['Drawing Usage'],
      next: 'Usage, round 3',
      isOpen: true,
      waiting: 2,
      snoozed: 0,
      parked: 1,
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
