import { expect, test } from 'claude-code/testing'
import { findWords } from '../cli/apps'
import {
  BRING_FORWARD,
  bundleWords,
  FRONT,
  GHOSTTY_BUNDLE,
  LOOK_EVERY_MS,
  WATCH_MS,
} from '../cli/front'
import {
  ANSWER_SECONDS,
  FOCUS,
  FOCUSED,
  isTooOld,
  LEAST_VERSION,
  PAUSE_SECONDS,
  PROGRAM_MS,
} from '../cli/ghostty'
import { LOOK_MS } from '../cli/look'
import { EXIT } from '../cli/main'
import { PS } from '../cli/processes'
import { CLIENTS, PANES, selectWords } from '../cli/tmux'
import type { Where, WindowState } from '../core'
import { META, MIN, T0, W2 } from './support'
import {
  appClient,
  ENV,
  ghosttyClient,
  NOW,
  ownWindows,
  phoneClient,
  portalClient,
  relayedClient,
  SOCKET,
  sshClient,
  terminal,
  TERMINAL_APP,
  zmxClient,
  type FakeServer,
  type FakeTerminal,
  type FakeWindow,
  type FakeZmxClient,
} from './terminal'
import { ROOT } from './world'

/** The tmux window holding Claude's pane, another of its session, and one of another session. */
const CLAUDES = '@45'
const BESIDE = '@46'
const KIT = '@52'
const PANE = '%148'

/** Claude in tmux, on its pane's own device. */
const IN_TMUX: Where = {
  device: '/dev/ttys043',
  terminal: 'tmux',
  tmux: { socket: SOCKET, pane: PANE },
}

/** Claude in a Ghostty window of its own, outside tmux. */
const IN_GHOSTTY: Where = { device: '/dev/ttys041', terminal: 'ghostty' }

/** The device of the Ghostty window attached to the session's tmux session, and of Lee's phone. */
const WINDOW = '/dev/ttys000'
const PHONE = '/dev/ttys067'

const TERMINALS = ownWindows(
  { id: 'KIT-TERMINAL', device: IN_GHOSTTY.device ?? '' },
  { id: 'SWITCHBOARD-TERMINAL', device: WINDOW },
  { id: 'HOME-TERMINAL', device: '/dev/ttys090' },
)

/** The session's tmux server: its tmux session shown by the clients given, and another beside it. */
const serverShowing = (...clients: FakeServer['clients']): Record<string, FakeServer> => ({
  [SOCKET]: {
    panes: [
      [PANE, CLAUDES],
      ['%54', KIT],
    ],
    clients,
  },
})

const SHOWN = serverShowing(ghosttyClient('/dev/ttys041', KIT), ghosttyClient(WINDOW, CLAUDES))

const OFF_SCREEN = `sitrep: ${META.name} is not on screen: no terminal window on this Mac shows it.\n`

const SESSION = ['--session', META.id]

/** The session's one window, `where` it is, with tmux and Ghostty as given. */
const oneWindow = (
  where: Where,
  options: Parameters<typeof terminal>[0] = { tmux: SHOWN, ghostty: TERMINALS },
) => {
  const t = terminal(options)

  t.seed(META, { seenAt: NOW, where })

  return t
}

/** The programs a jump ran by that name, in order. */
const runsOf = (t: ReturnType<typeof terminal>, name: string) =>
  t.screen.ran.filter(([each]) => each === name)

/** Ghostty asked for the terminal on a device, and to focus it. */
const focusing = (device: string) => ['osascript', '-e', FOCUS, device]

const FOCUSED_RUN = { exit: EXIT.done, out: '', err: '' }

test("jump focuses the Ghostty window on the session's tmux session, and prints nothing", async () => {
  const t = oneWindow(IN_TMUX)

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test('jump asks tmux only to list and ps for one snapshot, and lsappinfo which app is in front, each within the time limit; then Ghostty once, for the terminal on the client’s device, within its own', async () => {
  const t = oneWindow(IN_TMUX)

  await t.run('jump', ...SESSION)

  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo')).toEqual([
    ['tmux', '-u', '-S', SOCKET, ...PANES],
    ['tmux', '-u', '-S', SOCKET, ...CLIENTS],
    PS,
    focusing(WINDOW),
  ])
  expect(runsOf(t, 'lsappinfo')).toEqual([FRONT, bundleWords('ASN:0x0-0x1:')])
  expect(
    t.screen.limits.filter(each => each.name !== 'osascript').map(each => each.limitMs),
  ).toEqual([LOOK_MS, LOOK_MS, LOOK_MS, LOOK_MS, LOOK_MS])
  expect(
    t.screen.limits.filter(each => each.name === 'osascript').map(each => each.limitMs),
  ).toEqual([PROGRAM_MS])
})

test('jump outside tmux asks Ghostty for the terminal on the window’s own device, asking tmux and ps nothing', async () => {
  const t = oneWindow(IN_GHOSTTY)

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused).toEqual(['KIT-TERMINAL'])
  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo')).toEqual([
    focusing(IN_GHOSTTY.device ?? ''),
  ])
})

/** The session's terminal, in Ghostty. */
const SWITCHBOARD: FakeTerminal = { id: 'SWITCHBOARD-TERMINAL', device: WINDOW }

/** One Ghostty window of two tabs, the first selected: `held`, the tab holding the session's terminal, at `place`, and a spare tab at the other. */
const twoTabs = (place: 0 | 1, held: FakeTerminal[] = [SWITCHBOARD]): FakeWindow => {
  const tabs = [[{ id: 'SPARE-TERMINAL', device: '/dev/ttys091' }]]

  tabs.splice(place, 0, held)

  return { id: 'TABBED-WINDOW', tabs, selected: 0 }
}

// The fake Ghostty plays the program's tab rule rather than running it: these tests show what a jump does with
// what Ghostty is told; the test pinning the program's lines, further down, guards the rule in the program itself.
test('a jump to a terminal in its window’s selected tab tells Ghostty only to focus it', async () => {
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: [twoTabs(0)] })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.told).toEqual([['focus', 'SWITCHBOARD-TERMINAL']])
})

test('a jump to a terminal in a tab not selected, alone in it or in a split, tells Ghostty to activate its window, pause, then focus it, in the one program within its limit', async () => {
  const cases: [string, FakeTerminal[]][] = [
    ['alone in its tab', [SWITCHBOARD]],
    ['in a split', [{ id: 'SPLIT-TERMINAL', device: '/dev/ttys092' }, SWITCHBOARD]],
  ]

  for (const [why, held] of cases) {
    const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: [twoTabs(1, held)] })

    expect(await t.run('jump', ...SESSION), why).toEqual(FOCUSED_RUN)
    expect(t.screen.told, why).toEqual([
      ['activate window', 'TABBED-WINDOW'],
      ['delay', PAUSE_SECONDS],
      ['focus', 'SWITCHBOARD-TERMINAL'],
    ])
    expect(runsOf(t, 'osascript'), why).toEqual([focusing(WINDOW)])
    expect(
      t.screen.limits.filter(each => each.name === 'osascript').map(each => each.limitMs),
      why,
    ).toEqual([PROGRAM_MS])
  }
})

test('the pause before focusing a tab not selected is half a second, which was enough live where none was not', () => {
  expect(PAUSE_SECONDS).toBe(0.5)
})

test('with no client on the session’s tmux server, the snapshot goes unused: ps failing then is no matter', async () => {
  const t = oneWindow(IN_TMUX, { tmux: serverShowing(), ghostty: TERMINALS, slow: ['ps'] })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: OFF_SCREEN })
})

test('a tmux session the phone and a Ghostty window both show goes to the Ghostty window, and Ghostty is never asked for the phone’s device', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(phoneClient(PHONE, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: [...TERMINALS, ...ownWindows({ id: 'NOT-THE-PHONE', device: PHONE })],
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(runsOf(t, 'osascript')).toEqual([focusing(WINDOW)])
})

/** A control-mode client (`tmux -C` over pipes) started from a Ghostty window's shell: tmux gives it no device, and ps puts it in Ghostty. */
const controlClient = (window: string, session?: string) => ({
  ...ghosttyClient('', window),
  ...(session === undefined ? {} : { session }),
})

test('a client tmux gives no device, as a control-mode client, is no place: the jump goes to the Ghostty window listed after it, and never asks Ghostty for an empty device', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(controlClient(CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript')).toEqual([focusing(WINDOW)])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test('a client with no device alone on the pane’s window is off screen, never a jump landed, and Ghostty is asked nothing', async () => {
  const t = oneWindow(IN_TMUX, { tmux: serverShowing(controlClient(CLAUDES)), ghostty: TERMINALS })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: OFF_SCREEN })
  expect(runsOf(t, 'osascript')).toEqual([])
  expect(t.waits, 'no watch of the front').toEqual([])
})

test('a session no Ghostty window shows is not on screen, and nothing is focused', async () => {
  const cases: [string, ReturnType<typeof terminal>][] = [
    [
      'a closed session, its window long gone',
      (() => {
        const t = terminal({ tmux: SHOWN, ghostty: TERMINALS })

        t.seed(META, { seenAt: T0 - 10 * MIN, where: IN_TMUX })

        return t
      })(),
    ],
    [
      'a window not saying where it is',
      (() => {
        const t = terminal({ tmux: SHOWN, ghostty: TERMINALS })

        t.seed(META, { seenAt: NOW })

        return t
      })(),
    ],
    [
      'a detached tmux session',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(ghosttyClient('/dev/ttys041', KIT)),
        ghostty: TERMINALS,
      }),
    ],
    [
      'a tmux session only the phone shows',
      oneWindow(IN_TMUX, { tmux: serverShowing(phoneClient(PHONE, CLAUDES)), ghostty: TERMINALS }),
    ],
    [
      'a tmux session only a Ghostty on another Mac shows, over ssh',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(sshClient('/dev/ttys080', CLAUDES)),
        ghostty: [...TERMINALS, ...ownWindows({ id: 'LOOKALIKE', device: '/dev/ttys080' })],
      }),
    ],
    ['tmux gone', oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS })],
    [
      'a window in a terminal app unknown to sitrep',
      oneWindow({ ...IN_GHOSTTY, terminal: 'Unknown' }, { ghostty: TERMINALS }),
    ],
  ]

  for (const [why, t] of cases) {
    expect(await t.run('jump', ...SESSION), why).toEqual({
      exit: EXIT.refused,
      out: '',
      err: OFF_SCREEN,
    })
    expect(t.screen.focused, why).toEqual([])
  }
})

test('a jump that could not ask tmux or ps says it could not tell, naming which, and asks Ghostty nothing', async () => {
  const cases: [Parameters<typeof terminal>[0], string][] = [
    [{ missing: ['tmux'] }, 'tmux'],
    [{ slow: ['tmux'] }, 'tmux'],
    [{ slow: ['ps'] }, 'ps'],
    [{ missing: ['tmux', 'ps'] }, 'tmux'],
  ]

  for (const [options, unanswered] of cases) {
    const why = JSON.stringify(options)
    const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, ...options })

    expect(await t.run('jump', ...SESSION), why).toEqual({
      exit: EXIT.refused,
      out: '',
      err: `sitrep: Could not tell whether ${META.name} is on screen: ${unanswered} gave no answer.\n`,
    })
    expect(runsOf(t, 'osascript'), why).toEqual([])
  }
})

test('a jump with tmux answering that no server runs on the socket is off screen, not unknown', async () => {
  expect(
    (await oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS }).run('jump', ...SESSION)).err,
  ).toBe(OFF_SCREEN)
})

test('a device no Ghostty terminal is on fails, saying which, with nothing focused', async () => {
  const cases: [string, ReturnType<typeof terminal>, string][] = [
    [
      'a client of a Ghostty window, as ps says, on a device none of its terminals is on',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(ghosttyClient('/dev/ttys099', CLAUDES)),
        ghostty: TERMINALS,
      }),
      '/dev/ttys099',
    ],
    ['Ghostty not running', oneWindow(IN_TMUX, { tmux: SHOWN }), WINDOW],
    ['Ghostty with no window open', oneWindow(IN_GHOSTTY, { ghostty: [] }), IN_GHOSTTY.device ?? ''],
  ]

  for (const [why, t, device] of cases) {
    expect(await t.run('jump', ...SESSION), why).toEqual({
      exit: EXIT.refused,
      out: '',
      err: `sitrep: ${META.name} shows on ${device}, but no Ghostty window there answered.\n`,
    })
    expect(runsOf(t, 'osascript'), why).toEqual([focusing(device)])
    expect(t.screen.focused, why).toEqual([])
  }
})

const REFUSAL = '0:42: execution error: Not authorized to send Apple events to Ghostty. (-1743)'

test('macOS refusing control of Ghostty is told in osascript’s words', async () => {
  const t = oneWindow(IN_GHOSTTY, { ghostty: TERMINALS, refused: () => REFUSAL })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: osascript: ${REFUSAL}\n`,
  })
  expect(t.screen.focused).toEqual([])
})

/** What osascript says when Ghostty does not answer in time, as it does with the screen locked. */
const TIMED_OUT = '131:133: execution error: Ghostty got an error: AppleEvent timed out. (-1712)'

const NO_ANSWER = `sitrep: Ghostty did not answer within ${ANSWER_SECONDS} seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty.\n`

test('Ghostty not answering in time is refused in plain words, with nothing focused', async () => {
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, refused: () => TIMED_OUT })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: NO_ANSWER })
  expect(t.screen.focused).toEqual([])
})

const TOO_SLOW = `sitrep: Ghostty did not answer within ${PROGRAM_MS / 1_000} seconds: most likely the Mac is too busy.\n`

test('a focus that never ends, as osascript under heavy load, is killed at its limit and the jump ends unanswered, in plain words', async () => {
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, stalls: () => true })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.unanswered, out: '', err: TOO_SLOW })
  expect(runsOf(t, 'osascript')).toEqual([focusing(WINDOW)])
  expect(t.screen.limits.filter(each => each.name === 'osascript')).toEqual([
    { name: 'osascript', limitMs: PROGRAM_MS },
  ])
  expect(t.screen.focused).toEqual([])
})

/** What the jump says of a Ghostty too old to say a terminal's device. */
const TOO_OLD = `sitrep: This Ghostty cannot say which of its windows is on a device, so sitrep cannot jump to one: update Ghostty to ${LEAST_VERSION} or later.\n`

test('a Ghostty before 1.4, whose terminals do not say their device, or before it could be scripted, is refused in plain words, with nothing focused', async () => {
  for (const before of ['tty', 'scripting'] as const) {
    for (const where of [IN_TMUX, IN_GHOSTTY]) {
      const why = `before ${before}, ${where.terminal}`
      const t = oneWindow(where, { tmux: SHOWN, ghostty: TERMINALS, ghosttyBefore: before })

      expect(await t.run('jump', ...SESSION), why).toEqual({
        exit: EXIT.refused,
        out: '',
        err: TOO_OLD,
      })
      expect(runsOf(t, 'osascript'), why).toHaveLength(1)
      expect(t.screen.focused, why).toEqual([])
    }
  }

  expect(LEAST_VERSION).toBe('1.4')
})

test('only the words of a Ghostty not knowing the program’s terms read as too old: a term unknown as it runs (-2753), or as it compiles (-2741)', () => {
  expect(isTooOld('179:183: execution error: The variable tty is not defined. (-2753)')).toBe(true)
  expect(isTooOld('12: error: Expected end of line, etc. but found class name. (-2741)')).toBe(true)
  expect(isTooOld(REFUSAL)).toBe(false)
  expect(isTooOld(TIMED_OUT)).toBe(false)
  expect(isTooOld('Ghostty got an error: Can’t get terminal 1. (-1728)')).toBe(false)
})

test('the Ghostty program asks Ghostty within the time limit, its running checked first, and prints its fixed word only once it has focused', () => {
  const lines = FOCUS.split('\n')
  const at = (line: string) => lines.indexOf(line)

  expect(at(`with timeout of ${ANSWER_SECONDS} seconds`)).toBeGreaterThan(
    at('if application "Ghostty" is not running then return ""'),
  )
  expect(at('tell application "Ghostty"')).toBe(at(`with timeout of ${ANSWER_SECONDS} seconds`) + 1)
  expect(at('end timeout')).toBe(at('end tell') + 1)
  expect(at('focus item 1 of found')).toBeGreaterThan(at('if found is {} then return ""'))
  expect(at(`return "${FOCUSED}"`)).toBeGreaterThan(at('focus item 1 of found'))
  expect(FOCUS, 'never the device it was given, which tmux gives empty for a control-mode client').not.toContain(
    'return wanted',
  )
})

// The guard of the tab rule: the fake Ghostty only plays it.
test('the Ghostty program, once a terminal is found, activates its window and pauses only where its tab is not selected, then focuses it either way', () => {
  const lines = FOCUS.split('\n')
  const found = lines.indexOf('if found is {} then return ""')

  expect(lines.slice(found, found + 6)).toEqual([
    'if found is {} then return ""',
    'if selected of (tabs of (windows whose tty of terminals contains wanted) whose tty of terminals contains wanted) is {{false}} then',
    'activate window (first window whose tty of terminals contains wanted)',
    `delay ${PAUSE_SECONDS}`,
    'end if',
    'focus item 1 of found',
  ])
})

test('a device no Ghostty terminal is on is passed over for the next, which is focused', async () => {
  const SILENT = '/dev/ttys099'
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient(SILENT, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(runsOf(t, 'osascript')).toEqual([focusing(SILENT), focusing(WINDOW)])
})

test('when no Ghostty device answers, the failure names every one asked for', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(
      ghosttyClient('/dev/ttys097', CLAUDES),
      ghosttyClient('/dev/ttys098', CLAUDES),
      ghosttyClient('/dev/ttys099', CLAUDES),
    ),
    ghostty: TERMINALS,
  })

  expect((await t.run('jump', ...SESSION)).err).toBe(
    `sitrep: ${META.name} shows on /dev/ttys097, /dev/ttys098 and /dev/ttys099, but no Ghostty window there answered.\n`,
  )
  expect(runsOf(t, 'osascript')).toHaveLength(3)
})

test('jump names its session as every session command does, and an unknown one is no such session', async () => {
  const t = oneWindow(IN_TMUX)
  const named = terminal({ env: { ...ENV, SITREP_SESSION: META.id }, ghostty: TERMINALS })

  named.seed(META, { seenAt: NOW, where: IN_GHOSTTY })

  expect((await t.run('jump')).exit).toBe(EXIT.refused)
  expect(await t.run('jump', '--session', 'sr-zzzzzz')).toEqual({
    exit: EXIT.noSession,
    out: '',
    err: 'sitrep: There is no session sr-zzzzzz on the board, in any project.\n',
  })
  expect(t.screen.ran).toEqual([])
  expect((await named.run('jump')).exit, 'SITREP_SESSION names it').toBe(EXIT.done)
  expect(named.screen.focused).toEqual(['KIT-TERMINAL'])
})

test("jump's help says what it does, and the help lists it", async () => {
  const t = terminal()

  expect((await t.run('jump', '--help')).out).toBe(
    [
      'Usage: sitrep jump [--session <id>]',
      '',
      'Bring the terminal window showing the session to the front, on whatever Space it is. Prints nothing.',
      '',
      '  --session <id>  the session: sr- and six characters; else $SITREP_SESSION',
      '',
    ].join('\n'),
  )
  expect((await t.run('--help')).out).toContain('  sitrep jump\n')
})

/** Where releases before 6 November 2026 remembered each device's Ghostty terminal. */
const REMEMBERED = `${ROOT}/ghostty-terminals.jsonl`

test('the terminals a jump remembered before it asked Ghostty by device are ignored: the file is neither followed nor written, and list never takes it for a project', async () => {
  const kept = `${JSON.stringify({ device: WINDOW, terminal: 'HOME-TERMINAL' })}\n`
  const t = oneWindow(IN_TMUX)

  t.files.set(REMEMBERED, { text: kept, mtimeMs: NOW })

  const listed = await t.run('list', '--json')

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.text(REMEMBERED)).toBe(kept)
  expect(await t.run('list', '--json')).toEqual(listed)
})

/** Lets every promise settle that can while a program is held: the fakes answer at once, so a hundred turns are ample. */
const settled = async () => {
  for (let turn = 0; turn < 100; turn += 1) {
    await Promise.resolve()
  }
}

test('Ghostty is asked only once the screen is read: nothing goes to Ghostty while ps is still answering', async () => {
  const t = oneWindow(IN_TMUX)
  const ps = t.screen.hold('ps')
  const jumped = t.run('jump', ...SESSION)

  await ps.arrived
  await settled()

  expect(runsOf(t, 'osascript')).toEqual([])

  ps.release()

  expect(await jumped).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript')).toEqual([focusing(WINDOW)])
})

test('a jump whose session no Ghostty window shows, or that cannot tell, asks Ghostty nothing', async () => {
  const cases: [string, ReturnType<typeof terminal>][] = [
    [
      'a window not saying where it is',
      (() => {
        const t = terminal({ tmux: SHOWN, ghostty: TERMINALS })

        t.seed(META, { seenAt: NOW })

        return t
      })(),
    ],
    [
      'a detached tmux session',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(ghosttyClient('/dev/ttys041', KIT)),
        ghostty: TERMINALS,
      }),
    ],
    [
      'a tmux session only the phone shows',
      oneWindow(IN_TMUX, { tmux: serverShowing(phoneClient(PHONE, CLAUDES)), ghostty: TERMINALS }),
    ],
    [
      'a tmux session only a Ghostty on another Mac shows, over ssh',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(sshClient('/dev/ttys080', CLAUDES)),
        ghostty: TERMINALS,
      }),
    ],
    ['tmux gone', oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS })],
    ['ps not answering', oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, slow: ['ps'] })],
    [
      'a window in a terminal app unknown to sitrep',
      oneWindow({ ...IN_GHOSTTY, terminal: 'Unknown' }, { ghostty: TERMINALS }),
    ],
  ]

  for (const [why, t] of cases) {
    expect((await t.run('jump', ...SESSION)).exit, why).toBe(EXIT.refused)
    expect(runsOf(t, 'osascript'), why).toEqual([])
  }
})

const FINDER = 'com.apple.finder'

/** How many times the watch looks when nothing ends it early. */
const LOOKS = WATCH_MS / LOOK_EVERY_MS

/** A jump with Finder in front as it begins, and the app in front at each look after as given. */
const fromFinder = async (front: string[], options: Parameters<typeof terminal>[0] = {}) => {
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, front, ...options })

  return { t, run: await t.run('jump', ...SESSION) }
}

const isFront = (words: readonly string[]) => words.join(' ') === FRONT.join(' ')

const broughtForward = (t: ReturnType<typeof terminal>) =>
  t.screen.ran.filter(words => words.join(' ') === BRING_FORWARD.join(' '))

test('with Ghostty in front as the jump begins, nothing watches the front after it', async () => {
  const t = oneWindow(IN_TMUX)

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.filter(isFront)).toHaveLength(1)
  expect(t.waits).toEqual([])
  expect(broughtForward(t)).toEqual([])
})

test('which app is in front is read as the jump begins, before tmux answers', async () => {
  const t = oneWindow(IN_TMUX)
  const tmux = t.screen.hold('tmux')
  const jumped = t.run('jump', ...SESSION)

  await tmux.arrived

  expect(t.screen.ran.filter(isFront)).toHaveLength(1)

  tmux.release()

  expect(await jumped).toEqual(FOCUSED_RUN)
})

test('the focus waits for the read of which app is in front, however slow lsappinfo is, so the jump never reads its own focus', async () => {
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, front: [FINDER] })
  const lsappinfo = t.screen.hold('lsappinfo')
  const jumped = t.run('jump', ...SESSION)

  await lsappinfo.arrived
  await settled()

  expect(t.screen.ran.filter(([name]) => name === 'tmux' || name === 'ps')).toHaveLength(3)
  expect(runsOf(t, 'osascript'), 'nothing listed or focused yet').toEqual([])

  lsappinfo.release()

  expect(await jumped).toEqual(FOCUSED_RUN)
  expect(t.waits.length, 'the watch ran: Finder was in front').toBeGreaterThan(0)
})

test('another app taking the front back after Ghostty came forward brings Ghostty forward once, at that look, by `open` within the time limit', async () => {
  const { t, run } = await fromFinder([FINDER, FINDER, GHOSTTY_BUNDLE, GHOSTTY_BUNDLE, FINDER])

  expect(run).toEqual(FOCUSED_RUN)
  expect(
    t.screen.ran.filter(isFront),
    'the look as the jump began, and four after the focus',
  ).toHaveLength(5)
  expect(t.waits).toEqual([LOOK_EVERY_MS, LOOK_EVERY_MS, LOOK_EVERY_MS, LOOK_EVERY_MS])
  expect(broughtForward(t)).toHaveLength(1)
  expect(t.screen.ran.at(-1)).toEqual(BRING_FORWARD)
  expect(t.screen.limits.at(-1)).toEqual({ name: 'open', limitMs: LOOK_MS })
  expect(BRING_FORWARD).toEqual(['open', '-b', GHOSTTY_BUNDLE])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test('Ghostty never coming forward is never brought forward: the watch runs its whole second, and `open` could make a window', async () => {
  const { t, run } = await fromFinder([FINDER])

  expect(run).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.filter(isFront)).toHaveLength(1 + LOOKS)
  expect(t.waits.reduce((sum, ms) => sum + ms, 0)).toBe(WATCH_MS)
  expect(broughtForward(t)).toEqual([])
})

test('Ghostty coming forward and keeping the front needs nothing more', async () => {
  const { t, run } = await fromFinder([FINDER, FINDER, GHOSTTY_BUNDLE])

  expect(run).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.filter(isFront)).toHaveLength(1 + LOOKS)
  expect(broughtForward(t)).toEqual([])
})

test('Ghostty is brought forward never more than once, however often the front is taken back', async () => {
  const { t } = await fromFinder([
    FINDER,
    GHOSTTY_BUNDLE,
    FINDER,
    GHOSTTY_BUNDLE,
    FINDER,
    GHOSTTY_BUNDLE,
    FINDER,
  ])

  expect(broughtForward(t)).toHaveLength(1)
  expect(t.screen.ran.filter(isFront), 'no look after it').toHaveLength(3)
})

test("each app's bundle id is asked once a jump, an ASN naming one app for its life: a look is one run of lsappinfo after that", async () => {
  const { t } = await fromFinder([FINDER, FINDER, GHOSTTY_BUNDLE, GHOSTTY_BUNDLE, FINDER])
  const infos = runsOf(t, 'lsappinfo').filter(words => !isFront(words))

  expect(t.screen.ran.filter(isFront)).toHaveLength(5)
  expect(infos).toEqual([bundleWords('ASN:0x0-0x1:'), bundleWords('ASN:0x0-0x2:')])
  expect(broughtForward(t)).toHaveLength(1)
})

test('a look lsappinfo gives no answer to is no hand-back', async () => {
  const { t } = await fromFinder([FINDER, GHOSTTY_BUNDLE, '', '', FINDER])

  expect(broughtForward(t)).toHaveLength(1)
  expect(t.screen.ran.filter(isFront)).toHaveLength(5)
})

test('lsappinfo or open failing never fails the jump: nothing watches when lsappinfo cannot tell, and a failed bringing forward is let go', async () => {
  const cases: [string, Parameters<typeof terminal>[0]][] = [
    ['lsappinfo not on PATH', { missing: ['lsappinfo'] }],
    ['lsappinfo not answering', { slow: ['lsappinfo'] }],
    ['no ASN for the front', { front: [''] }],
  ]

  for (const [why, options] of cases) {
    const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, ...options })

    expect(await t.run('jump', ...SESSION), why).toEqual(FOCUSED_RUN)
    expect(t.waits, why).toEqual([])
    expect(broughtForward(t), why).toEqual([])
  }

  for (const options of [{ missing: ['open'] }, { slow: ['open'] }]) {
    const { t, run } = await fromFinder([FINDER, GHOSTTY_BUNDLE, FINDER], options)

    expect(run, JSON.stringify(options)).toEqual(FOCUSED_RUN)
    expect(broughtForward(t), JSON.stringify(options)).toHaveLength(1)
  }
})

test('a jump that brings no window forward watches nothing', async () => {
  const offScreen = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient('/dev/ttys041', KIT)),
    ghostty: TERMINALS,
    front: [FINDER],
  })
  const unanswered = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient('/dev/ttys099', CLAUDES)),
    ghostty: TERMINALS,
    front: [FINDER],
  })

  expect((await offScreen.run('jump', ...SESSION)).exit).toBe(EXIT.refused)
  expect((await unanswered.run('jump', ...SESSION)).exit).toBe(EXIT.refused)

  for (const t of [offScreen, unanswered]) {
    expect(t.waits).toEqual([])
    expect(broughtForward(t)).toEqual([])
  }
})

/** The tmux sessions of the selecting tests: Claude's own, and another. */
const CLAUDES_SESSION = '$7'
const OTHER_SESSION = '$8'

/** The runs of tmux selecting a window. */
const selectsOf = (t: ReturnType<typeof terminal>) =>
  runsOf(t, 'tmux').filter(words => words.includes('select-window'))

/** The select that makes Claude's tmux window current in the session. */
const selecting = (session: string) => selectWords({ socket: SOCKET, session, window: CLAUDES })

/** The time limit each run of tmux was given. */
const tmuxLimits = (t: ReturnType<typeof terminal>) =>
  t.screen.limits.filter(each => each.name === 'tmux').map(each => each.limitMs)

/** Claude's tmux session of two windows, its Ghostty window on the other, with tmux and Ghostty otherwise as given. */
const beside = (options: Parameters<typeof terminal>[0] = {}) =>
  oneWindow(IN_TMUX, {
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          ['%149', BESIDE, CLAUDES_SESSION],
        ],
        clients: [{ ...ghosttyClient(WINDOW, BESIDE), session: CLAUDES_SESSION }],
      },
    },
    ghostty: TERMINALS,
    ...options,
  })

test("a pane whose tmux window no client shows is shown by tmux selecting it in the session holding it, within tmux's time limit, and that session's Ghostty window is then focused by its device", async () => {
  const t = beside()

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo')).toEqual([
    ['tmux', '-u', '-S', SOCKET, ...PANES],
    ['tmux', '-u', '-S', SOCKET, ...CLIENTS],
    PS,
    ['tmux', '-u', '-S', SOCKET, 'select-window', '-t', `${CLAUDES_SESSION}:${CLAUDES}`],
    focusing(WINDOW),
  ])
  expect(tmuxLimits(t)).toEqual([LOOK_MS, LOOK_MS, LOOK_MS])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test("a client with no device on the pane's window does not stop the select that makes the session's Ghostty window show it", async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          ['%149', BESIDE, CLAUDES_SESSION],
          [PANE, CLAUDES, OTHER_SESSION],
          ['%149', BESIDE, OTHER_SESSION],
        ],
        clients: [
          controlClient(CLAUDES, OTHER_SESSION),
          { ...ghosttyClient(WINDOW, BESIDE), session: CLAUDES_SESSION },
        ],
      },
    },
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(selectsOf(t)).toEqual([selecting(CLAUDES_SESSION)])
  expect(runsOf(t, 'osascript')).toEqual([focusing(WINDOW)])
})

test("a grouped session's Ghostty window on another window has the pane's window selected in its own session, never in the group's other, which the phone shows", async () => {
  const grouped = (window: string) =>
    oneWindow(IN_TMUX, {
      tmux: {
        [SOCKET]: {
          panes: [
            [PANE, CLAUDES, CLAUDES_SESSION],
            ['%149', BESIDE, CLAUDES_SESSION],
            [PANE, CLAUDES, OTHER_SESSION],
            ['%149', BESIDE, OTHER_SESSION],
          ],
          clients: [
            { ...phoneClient(PHONE, CLAUDES), session: CLAUDES_SESSION },
            { ...ghosttyClient(WINDOW, window), session: OTHER_SESSION },
          ],
        },
      },
      ghostty: TERMINALS,
    })
  const elsewhere = grouped(BESIDE)
  const there = grouped(CLAUDES)

  expect(await elsewhere.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(selectsOf(elsewhere)).toEqual([selecting(OTHER_SESSION)])
  expect(elsewhere.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(await there.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(selectsOf(there), 'shown already, so nothing is selected').toEqual([])
  expect(there.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test("a window linked into another session has the pane's window selected in that session, whose Ghostty window shows another", async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          [PANE, CLAUDES, OTHER_SESSION],
          ['%54', KIT, OTHER_SESSION],
        ],
        clients: [{ ...ghosttyClient(WINDOW, KIT), session: OTHER_SESSION }],
      },
    },
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(selectsOf(t)).toEqual([selecting(OTHER_SESSION)])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test('a client attached to a session not holding the pane’s window has nothing selected: off screen', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          ['%54', KIT, OTHER_SESSION],
        ],
        clients: [{ ...ghosttyClient(WINDOW, KIT), session: OTHER_SESSION }],
      },
    },
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: OFF_SCREEN })
  expect(selectsOf(t)).toEqual([])
})

test('a select tmux refuses, or does not answer in time, refuses the jump in plain words, with nothing focused', async () => {
  const cases: [Parameters<typeof terminal>[0], string][] = [
    [
      { select: { said: "can't find window: @45" } },
      "tmux would not select it: can't find window: @45",
    ],
    [{ select: { said: '' } }, 'tmux would not select it.'],
    [{ select: 'slow' }, 'tmux gave no answer when asked to select it.'],
  ]

  for (const [options, why] of cases) {
    const t = beside(options)

    expect(await t.run('jump', ...SESSION), why).toEqual({
      exit: EXIT.refused,
      out: '',
      err: `sitrep: ${META.name} is in a tmux window no terminal shows, and ${why}\n`,
    })
    expect(tmuxLimits(t), why).toEqual([LOOK_MS, LOOK_MS, LOOK_MS])
    expect(runsOf(t, 'osascript'), why).toEqual([])
    expect(t.screen.focused, why).toEqual([])
  }
})

test("a Ghostty window on the pane's window shows it, so no other is made to by a select", async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          ['%149', BESIDE, CLAUDES_SESSION],
        ],
        clients: [
          { ...ghosttyClient('/dev/ttys041', BESIDE), session: CLAUDES_SESSION },
          { ...ghosttyClient(WINDOW, CLAUDES), session: CLAUDES_SESSION },
        ],
      },
    },
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(selectsOf(t)).toEqual([])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

const openRuns = (t: ReturnType<typeof terminal>) => runsOf(t, 'open')

/** lsappinfo's runs finding whether an app is running. */
const finds = (t: ReturnType<typeof terminal>) =>
  runsOf(t, 'lsappinfo').filter(words => words[1] === 'find')

test('a window outside tmux in a terminal app with no driver is brought forward as an app, by its bundle id within the time limit once lsappinfo finds it running, and nothing more', async () => {
  const cases: [string, string, string[]][] = [
    ['iTerm.app', 'com.googlecode.iterm2', ['com.googlecode.iterm2']],
    ['Apple_Terminal', 'com.apple.Terminal', ['com.apple.Terminal']],
    ['WezTerm', 'com.github.wez.wezterm', ['com.github.wez.wezterm']],
    ['WarpTerminal', 'dev.warp.Warp-Stable', ['dev.warp.Warp-Stable']],
    ['WarpTerminal', 'dev.warp.Warp-Preview', ['dev.warp.Warp-Stable', 'dev.warp.Warp-Preview']],
  ]

  for (const [program, bundle, found] of cases) {
    const why = `${program} as ${bundle}`
    const t = oneWindow(
      { ...IN_GHOSTTY, terminal: program },
      { ghostty: TERMINALS, front: ['com.apple.finder'], running: [bundle] },
    )

    expect(await t.run('jump', ...SESSION), why).toEqual(FOCUSED_RUN)
    expect(finds(t), why).toEqual(found.map(findWords))
    expect(openRuns(t), why).toEqual([['open', '-b', bundle]])
    expect(
      t.screen.limits.filter(each => each.name === 'open' || each.name === 'lsappinfo'),
      why,
    ).toEqual(
      ['lsappinfo', 'lsappinfo', ...found.map(() => 'lsappinfo'), 'open'].map(name => ({
        name,
        limitMs: LOOK_MS,
      })),
    )
    expect(
      t.screen.ran.filter(([name]) => name !== 'lsappinfo' && name !== 'open'),
      `${why}: no tmux, ps or Ghostty`,
    ).toEqual([])
    expect(t.waits, `${why}: no watch of the front`).toEqual([])
  }
})

test('an app with no driver that is not running is never opened, which might launch it: its place does not answer', async () => {
  const t = oneWindow({ ...IN_GHOSTTY, terminal: 'iTerm.app' }, { ghostty: TERMINALS })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: ${META.name} shows on ${IN_GHOSTTY.device}, but no iTerm2 window there answered.\n`,
  })
  expect(finds(t)).toEqual([findWords('com.googlecode.iterm2')])
  expect(openRuns(t)).toEqual([])
})

test('a window outside tmux in an app with no driver needs no device: the app is brought forward whole', async () => {
  const running = oneWindow({ terminal: 'iTerm.app' }, { running: ['com.googlecode.iterm2'] })
  const stopped = oneWindow({ terminal: 'iTerm.app' })

  expect(await running.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(openRuns(running)).toEqual([['open', '-b', 'com.googlecode.iterm2']])
  expect(await stopped.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: ${META.name} shows in iTerm2, which did not come forward.\n`,
  })
})

test('a tmux client in a terminal app with no driver is brought forward as the app it descends from, by its path; and after a select, where it shows another window', async () => {
  const shown = oneWindow(IN_TMUX, {
    tmux: serverShowing(appClient(WINDOW, CLAUDES, TERMINAL_APP)),
    ghostty: TERMINALS,
  })
  const elsewhere = oneWindow(IN_TMUX, {
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          ['%149', BESIDE, CLAUDES_SESSION],
        ],
        clients: [{ ...appClient(WINDOW, BESIDE, TERMINAL_APP), session: CLAUDES_SESSION }],
      },
    },
    ghostty: TERMINALS,
  })
  const opening = ['open', '-a', '/System/Applications/Utilities/Terminal.app']

  for (const t of [shown, elsewhere]) {
    expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
    expect(openRuns(t)).toEqual([opening])
    expect(runsOf(t, 'osascript')).toEqual([])
  }

  expect(selectsOf(shown)).toEqual([])
  expect(
    elsewhere.screen.ran.filter(words => words[0] === 'open' || words.includes('select-window')),
    'the select first',
  ).toEqual([selecting(CLAUDES_SESSION), opening])
})

test('an app with no driver that does not come forward is passed over for the next place, and the failure names each app tried', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(
      appClient('/dev/ttys099', CLAUDES, TERMINAL_APP),
      ghosttyClient('/dev/ttys098', CLAUDES),
    ),
    ghostty: TERMINALS,
    missing: ['open'],
  })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: ${META.name} shows on /dev/ttys099 and /dev/ttys098, but no Terminal or Ghostty window there answered.\n`,
  })
  expect(openRuns(t)).toHaveLength(1)
  expect(runsOf(t, 'osascript')).toEqual([focusing('/dev/ttys098')])
})

/** A window's state since `since`. */
const stateOf = (is: WindowState['is'], since: number): WindowState => ({ is, since })

/** A window of the session: when it attached, and the state its heartbeat says, if any. */
type Attached = { at: number; state?: WindowState }

/**
 * The session's two windows, each attached and in the state given: the
 * first in a Ghostty window of its own, the second in tmux, on the window a
 * Ghostty window shows unless the servers given say otherwise.
 */
const twoWindows = (
  first: Attached,
  second: Attached,
  tmux: Record<string, FakeServer> = SHOWN,
) => {
  const t = terminal({ tmux, ghostty: TERMINALS })
  const paths = t.seed(META)

  t.window(paths, META.by, first.at, IN_GHOSTTY, undefined, first.state)
  t.window(paths, W2, second.at, IN_TMUX, undefined, second.state)

  return t
}

/** The Ghostty terminals of the first window and of the second. */
const FIRSTS = 'KIT-TERMINAL'
const SECONDS = 'SWITCHBOARD-TERMINAL'

test('of two windows on one session, the jump goes to the one stopped on Lee, at a permission prompt or a question, however active the other', async () => {
  for (const is of ['permission', 'question'] as const) {
    const t = twoWindows(
      { at: T0 + 30_000, state: stateOf('working', T0 + 50_000) },
      { at: T0, state: stateOf(is, T0 + 10_000) },
    )

    expect(await t.run('jump', ...SESSION), is).toEqual(FOCUSED_RUN)
    expect(t.screen.focused, is).toEqual([SECONDS])
  }
})

test('of two windows on one session, else, the jump goes to one working, then by the latest state’s start, then by the latest attach', async () => {
  const cases: [string, Attached, Attached, string][] = [
    [
      'working, though its turn began before the other’s ended',
      { at: T0 + 30_000, state: stateOf('yourTurn', T0 + 50_000) },
      { at: T0, state: stateOf('working', T0 + 10_000) },
      SECONDS,
    ],
    [
      'both working, the turn begun last',
      { at: T0 + 30_000, state: stateOf('working', T0 + 20_000) },
      { at: T0, state: stateOf('working', T0 + 40_000) },
      SECONDS,
    ],
    [
      'both on their turn, the later end',
      { at: T0 + 30_000, state: stateOf('yourTurn', T0 + 40_000) },
      { at: T0, state: stateOf('yourTurn', T0 + 50_000) },
      SECONDS,
    ],
    [
      'the same start, so the later attach',
      { at: T0, state: stateOf('yourTurn', T0 + 40_000) },
      { at: T0 + 30_000, state: stateOf('yourTurn', T0 + 40_000) },
      SECONDS,
    ],
    [
      'both stopped on Lee, so the later stop',
      { at: T0 + 30_000, state: stateOf('question', T0 + 30_000) },
      { at: T0, state: stateOf('permission', T0 + 40_000) },
      SECONDS,
    ],
    [
      'one saying no state, as from a version before heartbeats said it: its attach stands for its start, among those on their turn',
      { at: T0, state: stateOf('yourTurn', T0 + 20_000) },
      { at: T0 + 30_000 },
      SECONDS,
    ],
    [
      'one saying no state, below one working',
      { at: T0, state: stateOf('working', T0 + 5_000) },
      { at: T0 + 30_000 },
      FIRSTS,
    ],
  ]

  for (const [why, first, second, focused] of cases) {
    const t = twoWindows(first, second)

    expect(await t.run('jump', ...SESSION), why).toEqual(FOCUSED_RUN)
    expect(t.screen.focused, why).toEqual([focused])
  }
})

test('the inbox’s deliverer, attached first, is not what the jump goes by', async () => {
  const t = twoWindows({ at: T0 + 30_000 }, { at: T0 })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused, 'the window attached last, not the deliverer').toEqual([FIRSTS])
})

test('the window that needs Lee, where no terminal shows it, gives way to the other', async () => {
  const t = twoWindows(
    { at: T0, state: stateOf('working', T0 + 50_000) },
    { at: T0 + 30_000, state: stateOf('permission', T0 + 40_000) },
    serverShowing(ghosttyClient('/dev/ttys041', KIT)),
  )

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused).toEqual([FIRSTS])
})

test("a tmux client under iTerm2's server, outside its bundle, is iTerm2's, brought forward by its bundle id once found running", async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(
      appClient(WINDOW, CLAUDES, '/Users/lee/Library/Application Support/iTerm2/iTermServer-3.5.4'),
    ),
    ghostty: TERMINALS,
    running: ['com.googlecode.iterm2'],
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(finds(t)).toEqual([findWords('com.googlecode.iterm2')])
  expect(openRuns(t)).toEqual([['open', '-b', 'com.googlecode.iterm2']])
})

test('a tmux client in an app found by its path in ps is running, so lsappinfo is not asked', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(appClient(WINDOW, CLAUDES, TERMINAL_APP)),
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(finds(t)).toEqual([])
})

/** The session's two windows: the first stopped on Lee in tmux, on a window no Ghostty window shows; the second in its own window outside tmux, on the device given. */
const stoppedBeside = (device: string | undefined, options: Parameters<typeof terminal>[0]) => {
  const t = terminal({
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          ['%149', BESIDE, CLAUDES_SESSION],
        ],
        clients: [{ ...ghosttyClient(WINDOW, BESIDE), session: CLAUDES_SESSION }],
      },
    },
    ghostty: TERMINALS,
    ...options,
  })
  const paths = t.seed(META)

  t.window(paths, META.by, T0, IN_TMUX, undefined, stateOf('permission', T0 + 10_000))
  t.window(paths, W2, T0, { ...IN_GHOSTTY, device }, undefined, stateOf('yourTurn', T0))

  return t
}

test('a select tmux does not make gives way to the next place, the next window’s, which is brought forward', async () => {
  const t = stoppedBeside(IN_GHOSTTY.device, { select: { said: "can't find window: @45" } })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(selectsOf(t)).toEqual([selecting(CLAUDES_SESSION)])
  expect(t.screen.focused).toEqual(['KIT-TERMINAL'])
})

test('with no place left, the jump is refused in the words of what stopped the most wanted: its select, though a later window did not answer', async () => {
  const t = stoppedBeside('/dev/ttys099', { select: 'slow' })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: ${META.name} is in a tmux window no terminal shows, and tmux gave no answer when asked to select it.\n`,
  })
  expect(runsOf(t, 'osascript'), 'the later window was tried').toEqual([
    focusing('/dev/ttys099'),
  ])
})

test('a select two places need is asked of tmux once: one that hangs costs its time once', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: {
      [SOCKET]: {
        panes: [
          [PANE, CLAUDES, CLAUDES_SESSION],
          ['%149', BESIDE, CLAUDES_SESSION],
        ],
        clients: [
          { ...ghosttyClient(WINDOW, BESIDE), session: CLAUDES_SESSION },
          { ...appClient('/dev/ttys030', BESIDE, TERMINAL_APP), session: CLAUDES_SESSION },
        ],
      },
    },
    ghostty: TERMINALS,
    select: 'slow',
  })

  expect((await t.run('jump', ...SESSION)).exit).toBe(EXIT.refused)
  expect(selectsOf(t)).toEqual([selecting(CLAUDES_SESSION)])
  expect(openRuns(t)).toEqual([])
})

/** Claude's tmux window shown by two Ghostty windows, then a Terminal window, with Ghostty as given. */
const ghosttyThenTerminal = (options: Parameters<typeof terminal>[0]) =>
  oneWindow(IN_TMUX, {
    tmux: serverShowing(
      ghosttyClient(WINDOW, CLAUDES),
      ghosttyClient('/dev/ttys031', CLAUDES),
      appClient('/dev/ttys030', CLAUDES, TERMINAL_APP),
    ),
    ...options,
  })


const OPENING_TERMINAL = ['open', '-a', '/System/Applications/Utilities/Terminal.app']

test('clients ps finds in Ghostty, on devices none of its terminals is on, each give way in turn, and the next app is brought forward', async () => {
  const t = ghosttyThenTerminal({ ghostty: ownWindows({ id: 'ELSEWHERE', device: '/dev/ttys090' }) })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript')).toEqual([focusing(WINDOW), focusing('/dev/ttys031')])
  expect(openRuns(t)).toEqual([OPENING_TERMINAL])
  expect(t.screen.focused).toEqual([])
})

test('Ghostty unable to ask, not answering, too old, or refused by macOS, is passed over at its places after, and the next app brought forward', async () => {
  const cases: [string, Parameters<typeof terminal>[0]][] = [
    ['not answering', { ghostty: TERMINALS, refused: () => TIMED_OUT }],
    ['too old', { ghostty: TERMINALS, ghosttyBefore: 'tty' }],
    ['refused by macOS', { ghostty: TERMINALS, refused: () => REFUSAL }],
  ]

  for (const [why, options] of cases) {
    const t = ghosttyThenTerminal(options)

    expect(await t.run('jump', ...SESSION), why).toEqual(FOCUSED_RUN)
    expect(runsOf(t, 'osascript'), `${why}: Ghostty asked once`).toEqual([focusing(WINDOW)])
    expect(openRuns(t), why).toEqual([OPENING_TERMINAL])
  }
})

test('what stopped Ghostty at the most wanted place is what the jump is refused for, once no place is left', async () => {
  const cases: [string, Parameters<typeof terminal>[0], string][] = [
    [
      'no terminal on its devices',
      { ghostty: [] },
      `sitrep: ${META.name} shows on ${WINDOW}, /dev/ttys031 and /dev/ttys030, but no Ghostty or Terminal window there answered.\n`,
    ],
    ['not answering', { ghostty: TERMINALS, refused: () => TIMED_OUT }, NO_ANSWER],
    ['too old', { ghostty: TERMINALS, ghosttyBefore: 'scripting' }, TOO_OLD],
    ['refused by macOS', { ghostty: TERMINALS, refused: () => REFUSAL }, `sitrep: osascript: ${REFUSAL}\n`],
  ]

  for (const [why, options, err] of cases) {
    const t = ghosttyThenTerminal({ ...options, missing: ['open'] })

    expect(await t.run('jump', ...SESSION), why).toEqual({ exit: EXIT.refused, out: '', err })
    expect(openRuns(t), `${why}: Terminal was tried`).toHaveLength(1)
  }
})

test('a tmux client behind a relaying pty in a Ghostty window jumps to the terminal on the device of Ghostty’s own child, not the relay’s', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(relayedClient('/dev/ttys050', WINDOW, CLAUDES)),
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript')).toEqual([focusing(WINDOW)])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

/** Claude's zmx session, its name with spaces and `·`, as Portal names one. */
const ZMX_SESSION = 'agentic-workflows-v2 · leeway-build'

/** Claude in zmx: on the session's own pty, which no terminal is on, Ghostty's `$TERM_PROGRAM` passed on. */
const IN_ZMX: Where = { device: '/dev/ttys087', terminal: 'ghostty', zmx: { session: ZMX_SESSION } }

/** The Ghostty window Portal attached to Claude's zmx session, on its own pty, Portal's relay on another. */
const PORTAL_WINDOW = '/dev/ttys036'
const PORTAL_RELAY = '/dev/ttys032'

const ZMX_TERMINALS = ownWindows(
  { id: 'PORTAL-TERMINAL', device: PORTAL_WINDOW },
  { id: 'OTHER-TERMINAL', device: '/dev/ttys040' },
)

test('jump in zmx focuses the Ghostty window holding its client, on the device of Ghostty’s own child through Portal’s relaying pty; it asks ps once and tmux nothing, and selects nothing', async () => {
  const t = oneWindow(IN_ZMX, {
    zmx: { [ZMX_SESSION]: [portalClient(PORTAL_RELAY, PORTAL_WINDOW)] },
    ghostty: ZMX_TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.focused).toEqual(['PORTAL-TERMINAL'])
  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo')).toEqual([
    PS,
    focusing(PORTAL_WINDOW),
  ])
})

test('a zmx session is matched by its whole name: the clients of a session whose name holds its own, begins as it does or ends as it does are not its clients, nor is its own server', async () => {
  const elsewhere = (relay: string) => [portalClient(relay, '/dev/ttys040')]
  const cases: [string, Record<string, FakeZmxClient[]>][] = [
    [
      'kit',
      {
        'kit · restore-card': elsewhere('/dev/ttys041'),
        'x kit': elsewhere('/dev/ttys042'),
        kit: [portalClient(PORTAL_RELAY, PORTAL_WINDOW)],
      },
    ],
    [
      ZMX_SESSION,
      {
        'agentic-workflows-v2': elsewhere('/dev/ttys041'),
        'leeway-build': elsewhere('/dev/ttys042'),
        [ZMX_SESSION]: [portalClient(PORTAL_RELAY, PORTAL_WINDOW)],
      },
    ],
  ]

  for (const [session, zmx] of cases) {
    const t = oneWindow({ ...IN_ZMX, zmx: { session } }, { zmx, ghostty: ZMX_TERMINALS })

    expect(await t.run('jump', ...SESSION), session).toEqual(FOCUSED_RUN)
    expect(runsOf(t, 'osascript'), session).toEqual([focusing(PORTAL_WINDOW)])
  }
})

test('a zmx session with no client, or only the clients of other sessions, is not on screen, and Ghostty is asked nothing', async () => {
  const cases: Record<string, FakeZmxClient[]>[] = [
    { [ZMX_SESSION]: [] },
    { kit: [portalClient(PORTAL_RELAY, PORTAL_WINDOW)] },
  ]

  for (const zmx of cases) {
    const t = oneWindow(IN_ZMX, { zmx, ghostty: ZMX_TERMINALS })

    expect(await t.run('jump', ...SESSION), JSON.stringify(zmx)).toEqual({
      exit: EXIT.refused,
      out: '',
      err: OFF_SCREEN,
    })
    expect(runsOf(t, 'osascript')).toEqual([])
  }
})

test('a zmx client in a terminal app with no driver brings that app forward by its path', async () => {
  const t = oneWindow(IN_ZMX, {
    zmx: { [ZMX_SESSION]: [zmxClient('/dev/ttys030', TERMINAL_APP)] },
    ghostty: ZMX_TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(openRuns(t)).toEqual([OPENING_TERMINAL])
  expect(runsOf(t, 'osascript')).toEqual([])
})

test('in zmx, tmux missing changes nothing, as tmux is never asked; ps giving no answer leaves the session unknown, never off', async () => {
  const zmx = { [ZMX_SESSION]: [portalClient(PORTAL_RELAY, PORTAL_WINDOW)] }
  const missing = oneWindow(IN_ZMX, { zmx, ghostty: ZMX_TERMINALS, missing: ['tmux'] })

  expect(await missing.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(missing, 'tmux')).toEqual([])

  for (const options of [{ missing: ['ps'] }, { slow: ['ps'] }]) {
    const t = oneWindow(IN_ZMX, { zmx, ghostty: ZMX_TERMINALS, ...options })

    expect(await t.run('jump', ...SESSION), JSON.stringify(options)).toEqual({
      exit: EXIT.refused,
      out: '',
      err: `sitrep: Could not tell whether ${META.name} is on screen: ps gave no answer.\n`,
    })
  }
})
