import { expect, test } from 'claude-code/testing'
import { EXIT } from '../cli/main'
import { PS } from '../cli/processes'
import { STALE_MS, type SessionMeta, type Where } from '../core'
import { META, W2 } from './support'
import {
  appClient,
  type FakeClient,
  ghosttyClient,
  NOW,
  phoneClient,
  portalClient,
  SOCKET,
  sshClient,
  TERMINAL_APP,
  terminal,
  zmxClient,
} from './terminal'
import { ELSEWHERE } from './world'

const SESSION_SOCKET = '/private/tmp/tmux-501/session'
const GONE_SOCKET = '/private/tmp/tmux-501/gone'

const inTmux = (socket: string, pane: string): Where => ({
  device: '/dev/ttys043',
  terminal: 'tmux',
  tmux: { socket, pane },
})

const LOBBY: SessionMeta = { ...META, id: 'sr-bbbbbb', name: 'Lobby' }
const LEDGER: SessionMeta = { ...META, id: 'sr-cccccc', name: 'Request ledger' }
const GOOSE: SessionMeta = {
  ...META,
  id: 'sr-eeeeee',
  name: 'Onboarding',
  project: ELSEWHERE.key,
  root: '/Users/lee/Code/goosemates',
  by: W2,
}
const QUIETLY: SessionMeta = { ...GOOSE, id: 'sr-ffffff', name: 'Tidying' }
const GONE: SessionMeta = { ...GOOSE, id: 'sr-gggggg', name: 'Gone server' }
const UNSAID: SessionMeta = { ...GOOSE, id: 'sr-hhhhhh', name: 'Not saying where' }
const AWAY: SessionMeta = { ...META, id: 'sr-aaaaaa', name: 'Away' }
const STALE: SessionMeta = { ...META, id: 'sr-ssssss', name: 'Window gone quiet' }

/**
 * Sessions each with a live window: three in tmux on one server, their tmux
 * windows shown by a Ghostty window, by the phone alone, and by a Ghostty on
 * another Mac over ssh; one on a second server a Ghostty window shows; one in
 * a Ghostty window of its own; one on a server gone; one whose window says
 * not where it is; one whose window has gone quiet past its heartbeats; and
 * one away, no window holding it.
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
  t.seed(LEDGER, { seenAt: NOW, where: inTmux(SOCKET, '%3') })
  t.seed(GOOSE, { project: ELSEWHERE.key, seenAt: NOW, where: inTmux(SESSION_SOCKET, '%9') })
  t.seed(QUIETLY, {
    project: ELSEWHERE.key,
    seenAt: NOW,
    where: { device: '/dev/ttys020', terminal: 'ghostty' },
  })
  t.seed(GONE, { project: ELSEWHERE.key, seenAt: NOW, where: inTmux(GONE_SOCKET, '%1') })
  t.seed(UNSAID, { project: ELSEWHERE.key, seenAt: NOW })
  t.seed(STALE, { seenAt: NOW - STALE_MS - 1, where: inTmux(SOCKET, '%1') })
  t.seed(AWAY)

  return t
}

type Printed = {
  v: number
  sessions: { id: string; is: string; app: string | null }[]
  unanswered: string[]
}

const printed = (out: string) => JSON.parse(out) as Printed

/** Each session listed, by its id, saying whether it is on screen. */
const isOf = (out: string) =>
  Object.fromEntries(printed(out).sessions.map(session => [session.id, session.is]))

test('screen --json says, by id, whether a jump could reach each session a window holds: on where a Ghostty window of this Mac shows it, off where none does; an away session is left out', async () => {
  const { exit, out, err } = await onScreens().run('screen', '--json')

  expect([exit, err]).toEqual([EXIT.done, ''])
  expect(printed(out)).toEqual({
    v: 1,
    sessions: [
      { id: LOBBY.id, is: 'off', app: null },
      { id: LEDGER.id, is: 'off', app: null },
      { id: GOOSE.id, is: 'on', app: 'Ghostty' },
      { id: QUIETLY.id, is: 'on', app: 'Ghostty' },
      { id: GONE.id, is: 'off', app: null },
      { id: UNSAID.id, is: 'off', app: null },
      { id: META.id, is: 'on', app: 'Ghostty' },
    ],
    unanswered: [],
  })
})

test('screen --json names the terminal app showing each session on screen: in tmux the app its client is in, which $TERM_PROGRAM, tmux there, cannot tell; none where it is not on screen or not known', async () => {
  const appOf = (out: string) =>
    Object.fromEntries(printed(out).sessions.map(session => [session.id, session.app]))

  expect(appOf((await onScreens().run('screen', '--json')).out)).toMatchObject({
    [META.id]: 'Ghostty',
    [GOOSE.id]: 'Ghostty',
    [QUIETLY.id]: 'Ghostty',
    [LOBBY.id]: null,
  })
  expect(appOf((await onScreens({ missing: ['tmux'] }).run('screen', '--json')).out)).toMatchObject({
    [META.id]: null,
    [QUIETLY.id]: 'Ghostty',
  })
})

test('screen --json names, of two apps whose tmux clients show a session, the one a jump would bring forward first, the first client as tmux lists them', async () => {
  const appWith = async (clients: FakeClient[]) => {
    const t = terminal({ tmux: { [SOCKET]: { panes: [['%1', '@1']], clients } } })

    t.seed(META, { seenAt: NOW, where: inTmux(SOCKET, '%1') })
    return printed((await t.run('screen', '--json')).out).sessions.map(({ app }) => app)
  }
  const inTerminal = appClient('/dev/ttys030', '@1', TERMINAL_APP)
  const inGhostty = ghosttyClient('/dev/ttys000', '@1')

  expect(await appWith([inTerminal, inGhostty])).toEqual(['Terminal'])
  expect(await appWith([inGhostty, inTerminal])).toEqual(['Ghostty'])
})

test('a tmux client with no device, as a control-mode client in a Ghostty window, shows no session: on only by a client a jump can reach', async () => {
  const screenWith = async (clients: FakeClient[]) => {
    const t = terminal({ tmux: { [SOCKET]: { panes: [['%1', '@1']], clients } } })

    t.seed(META, { seenAt: NOW, where: inTmux(SOCKET, '%1') })

    return printed((await t.run('screen', '--json')).out).sessions.map(({ is, app }) => [is, app])
  }
  const control = ghosttyClient('', '@1')

  expect(await screenWith([control])).toEqual([['off', null]])
  expect(await screenWith([control, ghosttyClient('/dev/ttys000', '@1')])).toEqual([
    ['on', 'Ghostty'],
  ])
})

test('a session no live window holds is read no further than its heartbeats', async () => {
  const t = onScreens()
  const read: string[] = []
  const { read: readFile } = t.io.fs

  t.io.fs.read = path => {
    read.push(path)

    return readFile(path)
  }
  await t.run('screen', '--json')

  for (const away of [AWAY.id, STALE.id]) {
    expect(
      read.filter(path => path.includes(`/${away}/`) && !path.includes('/presence/')),
      away,
    ).toEqual([])
  }
  expect(read.some(path => path.includes(`/${META.id}/`) && !path.includes('/presence/'))).toBe(true)
})

test('screen asks tmux twice for each socket and ps once, however many sessions run under them, and selects and focuses nothing', async () => {
  const t = onScreens()

  await t.run('screen', '--json')

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
  expect(t.screen.focused).toEqual([])
})

test('a session in tmux is unknown, never off, when tmux is not on PATH or does not answer; one in a Ghostty window of its own still says where it is', async () => {
  for (const options of [{ missing: ['tmux'] }, { slow: ['tmux'] }]) {
    const why = JSON.stringify(options)
    const { exit, out, err } = await onScreens(options).run('screen', '--json')

    expect([exit, err], why).toEqual([EXIT.done, ''])
    expect(isOf(out), why).toEqual({
      [META.id]: 'unknown',
      [LOBBY.id]: 'unknown',
      [LEDGER.id]: 'unknown',
      [GOOSE.id]: 'unknown',
      [QUIETLY.id]: 'on',
      [GONE.id]: 'unknown',
      [UNSAID.id]: 'off',
    })
    expect(printed(out).unanswered, why).toEqual(['tmux'])
  }
})

test('a session in tmux whose server has clients is unknown when ps is not on PATH or does not answer, as which apps they are in is not known', async () => {
  for (const options of [{ missing: ['ps'] }, { slow: ['ps'] }]) {
    const why = JSON.stringify(options)
    const { exit, out, err } = await onScreens(options).run('screen', '--json')

    expect([exit, err], why).toEqual([EXIT.done, ''])
    expect(isOf(out), why).toEqual({
      [META.id]: 'unknown',
      [LOBBY.id]: 'unknown',
      [LEDGER.id]: 'unknown',
      [GOOSE.id]: 'unknown',
      [QUIETLY.id]: 'on',
      [GONE.id]: 'off',
      [UNSAID.id]: 'off',
    })
    expect(printed(out).unanswered, why).toEqual(['ps'])
  }
})

test('with no session a window holds, screen lists none and asks no program', async () => {
  const t = terminal()

  t.seed(AWAY)

  expect(printed((await t.run('screen', '--json')).out)).toEqual({
    v: 1,
    sessions: [],
    unanswered: [],
  })
  expect((await t.run('screen')).out).toBe('No session is open in a window.\n')
  expect(t.screen.ran).toEqual([])
})

test('plain screen says each session a window holds, a line each by its id, and what gave no answer', async () => {
  expect((await onScreens().run('screen')).out).toBe(
    [
      'sr-bbbbbb  Lobby: not on screen',
      'sr-cccccc  Request ledger: not on screen',
      'sr-eeeeee  Onboarding: on screen',
      'sr-ffffff  Tidying: on screen',
      'sr-gggggg  Gone server: not on screen',
      'sr-hhhhhh  Not saying where: not on screen',
      `${META.id}  ${META.name}: on screen`,
      '',
    ].join('\n'),
  )
  const unanswered = (await onScreens({ missing: ['tmux'] }).run('screen')).out

  expect(unanswered).toContain('sr-bbbbbb  Lobby: not known\n')
  expect(unanswered.endsWith(`${META.id}  ${META.name}: not known\ntmux gave no answer.\n`)).toBe(
    true,
  )
})

/**
 * Sessions each with a live window in zmx: one Portal attached in a Ghostty
 * window, one in a Terminal window, and one whose zmx session has no client;
 * and one in tmux beside them.
 */
const inZmx = (options: Parameters<typeof terminal>[0] = {}) => {
  const t = terminal({
    zmx: {
      'sitrep-iFpz7T': [portalClient('/dev/ttys032', '/dev/ttys036')],
      'kit · restore-card': [zmxClient('/dev/ttys030', TERMINAL_APP)],
      'agentic-workflows-v2 · leeway-build': [],
    },
    tmux: { [SOCKET]: { panes: [['%1', '@1']], clients: [ghosttyClient('/dev/ttys000', '@1')] } },
    ...options,
  })
  const zmx = (session: string): Where => ({
    device: '/dev/ttys087',
    terminal: 'ghostty',
    zmx: { session },
  })

  t.seed(META, { seenAt: NOW, where: zmx('sitrep-iFpz7T') })
  t.seed(LOBBY, { seenAt: NOW, where: zmx('kit · restore-card') })
  t.seed(LEDGER, { seenAt: NOW, where: zmx('agentic-workflows-v2 · leeway-build') })
  t.seed(GOOSE, { project: ELSEWHERE.key, seenAt: NOW, where: inTmux(SOCKET, '%1') })

  return t
}

test('screen --json says a session in zmx is on screen where a client of its zmx session is in a terminal app, naming that app, and off where its zmx session has none; tmux is asked only for the session in tmux', async () => {
  const t = inZmx()
  const { exit, out, err } = await t.run('screen', '--json')

  expect([exit, err]).toEqual([EXIT.done, ''])
  expect(printed(out)).toEqual({
    v: 1,
    sessions: [
      { id: LOBBY.id, is: 'on', app: 'Terminal' },
      { id: LEDGER.id, is: 'off', app: null },
      { id: GOOSE.id, is: 'on', app: 'Ghostty' },
      { id: META.id, is: 'on', app: 'Ghostty' },
    ],
    unanswered: [],
  })
  expect(t.screen.ran.filter(([name]) => name !== 'tmux')).toEqual([PS])
})

test('with tmux not on PATH, a session in zmx still says where it is, and only the one in tmux is unknown', async () => {
  const { exit, out, err } = await inZmx({ missing: ['tmux'] }).run('screen', '--json')

  expect([exit, err]).toEqual([EXIT.done, ''])
  expect(isOf(out)).toEqual({
    [LOBBY.id]: 'on',
    [LEDGER.id]: 'off',
    [GOOSE.id]: 'unknown',
    [META.id]: 'on',
  })
  expect(printed(out).unanswered).toEqual(['tmux'])
})

test('a session in zmx is unknown, never off, when ps is not on PATH or does not answer, as only ps tells its clients', async () => {
  for (const options of [{ missing: ['ps'] }, { slow: ['ps'] }]) {
    const why = JSON.stringify(options)
    const { out } = await inZmx(options).run('screen', '--json')

    expect(isOf(out), why).toEqual({
      [LOBBY.id]: 'unknown',
      [LEDGER.id]: 'unknown',
      [GOOSE.id]: 'unknown',
      [META.id]: 'unknown',
    })
    expect(printed(out).unanswered, why).toEqual(['ps'])
  }
})
