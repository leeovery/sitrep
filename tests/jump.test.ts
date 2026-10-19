import { expect, test } from 'claude-code/testing'
import {
  BRING_FORWARD,
  bundleWords,
  FRONT,
  GHOSTTY_BUNDLE,
  LOOK_EVERY_MS,
  WATCH_MS,
} from '../cli/front'
import { ANSWER_SECONDS, FIND_AND_FOCUS, FOCUS, LIST, reportText } from '../cli/ghostty'
import { LOOK_MS } from '../cli/look'
import { EXIT } from '../cli/main'
import { REMEMBERED_FILE, rememberedText } from '../cli/remembered'
import { PS } from '../cli/screen'
import { CLIENTS, PANES, selectWords } from '../cli/tmux'
import type { Where, WindowState } from '../core'
import { META, MIN, T0, W2 } from './support'
import {
  appClient,
  ENV,
  ghosttyClient,
  NOW,
  phoneClient,
  SOCKET,
  sshClient,
  terminal,
  TERMINAL_APP,
  type FakeServer,
  type FakeTerminal,
} from './terminal'
import { HOME, ROOT } from './world'

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

/** A folder with a space and a real `%` in its name, which a report must carry whole. */
const ODD_FOLDER = '/Users/lee/Code/a b%20c'

const TERMINALS: FakeTerminal[] = [
  { id: 'KIT-TERMINAL', device: IN_GHOSTTY.device ?? '', directory: '/Users/lee/.config/kit' },
  { id: 'SWITCHBOARD-TERMINAL', device: WINDOW, directory: ODD_FOLDER },
  { id: 'HOME-TERMINAL', device: '/dev/ttys090', directory: HOME },
]

const DIRECTORIES = Object.fromEntries(TERMINALS.map(each => [each.id, each.directory]))

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

/** The knocks' markers, from the terminal's first random draw and its next. */
const MARKER = '/sitrep-knock/0102030401020304'
const NEXT_MARKER = '/sitrep-knock/0506070805060708'

/** The session's one window, `where` it is, with tmux and Ghostty as given. */
const oneWindow = (
  where: Where,
  options: Parameters<typeof terminal>[0] = { tmux: SHOWN, ghostty: TERMINALS },
) => {
  const t = terminal(options)

  t.seed(META, { seenAt: NOW, where })

  return t
}

test("jump focuses the Ghostty window on the session's tmux session, prints nothing, and puts the terminal's directory back exactly", async () => {
  const t = oneWindow(IN_TMUX)

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.done, out: '', err: '' })
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
  expect(t.screen.written.map(each => each.device)).toEqual([WINDOW, WINDOW])
  expect(t.screen.written.at(-1)?.text).toBe(reportText(ODD_FOLDER))
})

/** The programs a jump ran by that name, in order. */
const runsOf = (t: ReturnType<typeof terminal>, name: string) =>
  t.screen.ran.filter(([each]) => each === name)

test('jump asks tmux only to list and ps for one snapshot, and lsappinfo which app is in front, each within the time limit; then Ghostty to list and to find', async () => {
  const t = oneWindow(IN_TMUX)

  await t.run('jump', ...SESSION)

  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo')).toEqual([
    ['tmux', '-S', SOCKET, ...PANES],
    ['tmux', '-S', SOCKET, ...CLIENTS],
    PS,
    ['osascript', '-e', LIST],
    ['osascript', '-e', FIND_AND_FOCUS, MARKER],
  ])
  expect(runsOf(t, 'lsappinfo')).toEqual([FRONT, bundleWords('ASN:0x0-0x1:')])
  expect(
    t.screen.limits.filter(each => each.name !== 'osascript').map(each => each.limitMs),
  ).toEqual([LOOK_MS, LOOK_MS, LOOK_MS, LOOK_MS, LOOK_MS])
  expect(
    t.screen.limits.filter(each => each.name === 'osascript').map(each => each.limitMs),
  ).toEqual([undefined, undefined])
})

test('jump outside tmux knocks on the window’s own device, asking tmux and ps nothing', async () => {
  const t = oneWindow(IN_GHOSTTY)

  expect((await t.run('jump', ...SESSION)).exit).toBe(EXIT.done)
  expect(t.screen.focused).toEqual(['KIT-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo').map(([name]) => name)).toEqual([
    'osascript',
    'osascript',
  ])
})

test('with no client on the session’s tmux server, the snapshot goes unused: ps failing then is no matter', async () => {
  const t = oneWindow(IN_TMUX, { tmux: serverShowing(), ghostty: TERMINALS, slow: ['ps'] })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: OFF_SCREEN })
})

test('a tmux session the phone and a Ghostty window both show goes to the Ghostty window, and nothing is written to the phone', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(phoneClient(PHONE, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: [...TERMINALS, { id: 'NOT-THE-PHONE', device: PHONE, directory: HOME }],
  })

  expect((await t.run('jump', ...SESSION)).exit).toBe(EXIT.done)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.written.filter(each => each.device === PHONE)).toEqual([])
})

test('a session no Ghostty window shows is not on screen: nothing is written and nothing focused', async () => {
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
        ghostty: [...TERMINALS, { id: 'LOOKALIKE', device: '/dev/ttys080', directory: HOME }],
      }),
    ],
    ['tmux gone', oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS })],
    ['Ghostty not running', oneWindow(IN_TMUX, { tmux: SHOWN })],
    ['Ghostty with no window open', oneWindow(IN_GHOSTTY, { ghostty: [] })],
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
    expect(t.screen.written, why).toEqual([])
    expect(t.screen.focused, why).toEqual([])
  }
})

test('a jump that could not ask tmux or ps says it could not tell, naming which, and knocks on nothing', async () => {
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
    expect(t.screen.written, why).toEqual([])
    expect(t.screen.focused, why).toEqual([])
  }
})

test('a jump with tmux answering that no server runs on the socket is off screen, not unknown', async () => {
  expect(
    (await oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS }).run('jump', ...SESSION)).err,
  ).toBe(OFF_SCREEN)
})

test('a device no Ghostty terminal answers on fails, saying which, and leaves no terminal on the marker', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient('/dev/ttys099', CLAUDES)),
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: ${META.name} shows on /dev/ttys099, but no Ghostty window there answered.\n`,
  })
  expect(t.screen.focused).toEqual([])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
})

test('a terminal taking the marker only after the find gave up is put back all the same', async () => {
  const late = { id: 'LATE-TERMINAL', device: WINDOW, directory: ODD_FOLDER, isLate: true }
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: [late] })

  expect((await t.run('jump', ...SESSION)).exit).toBe(EXIT.refused)
  expect(t.screen.focused).toEqual([])
  expect(t.screen.written.map(each => each.device)).toEqual([WINDOW, WINDOW])
  expect(t.screen.directories()).toEqual({ [late.id]: ODD_FOLDER })
})

test('a terminal that reported no directory is put back to $HOME', async () => {
  const blank = { id: 'BLANK-TERMINAL', device: WINDOW, directory: '' }
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: [blank] })

  expect((await t.run('jump', ...SESSION)).exit).toBe(EXIT.done)
  expect(t.screen.focused).toEqual([blank.id])
  expect(t.screen.directories()).toEqual({ [blank.id]: ENV.HOME })
})

test('a terminal found on another jump’s marker goes back to $HOME, never to that marker', async () => {
  const marked = {
    id: 'MARKED-TERMINAL',
    device: WINDOW,
    directory: '/sitrep-knock/aaaaaaaaaaaaaaaa',
  }
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: [marked] })

  expect((await t.run('jump', ...SESSION)).exit).toBe(EXIT.done)
  expect(t.screen.focused).toEqual([marked.id])
  expect(t.screen.directories()).toEqual({ [marked.id]: ENV.HOME })
})

test('a device a write fails on is passed over, with nothing to put back, and the next is knocked on', async () => {
  const CLOSED = '/dev/ttys099'
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient(CLOSED, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: TERMINALS,
    closed: [CLOSED],
  })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.done, out: '', err: '' })
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.written.map(each => each.device)).toEqual([WINDOW, WINDOW])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
})

test('a listing a terminal opened and closed during is taken again, and the knock puts back the right directory', async () => {
  const opened = { id: 'NEW-TERMINAL', device: '/dev/ttys091', directory: '/tmp/new' }
  const t = oneWindow(IN_TMUX, {
    tmux: SHOWN,
    ghostty: TERMINALS,
    changes: [
      terminals => {
        terminals.splice(0, 1)
        terminals.push(opened)
      },
    ],
  })

  expect((await t.run('jump', ...SESSION)).exit).toBe(EXIT.done)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.directories()).toEqual({
    'SWITCHBOARD-TERMINAL': ODD_FOLDER,
    'HOME-TERMINAL': HOME,
    [opened.id]: opened.directory,
  })
  expect(t.screen.ran.filter(words => words[2] === LIST)).toHaveLength(2)
})

test('a listing that never settles fails in plain words, with nothing written or focused', async () => {
  const opening = (id: string) => (terminals: FakeTerminal[]) =>
    void terminals.push({ id, device: '/dev/ttys091', directory: HOME })
  const t = oneWindow(IN_TMUX, {
    tmux: SHOWN,
    ghostty: TERMINALS,
    changes: [opening('A'), opening('B'), opening('C')],
  })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: "sitrep: Ghostty's windows kept opening or closing as they were listed. Try again.\n",
  })
  expect(t.screen.ran.filter(words => words[2] === LIST)).toHaveLength(3)
  expect(t.screen.written).toEqual([])
  expect(t.screen.focused).toEqual([])
})

const REFUSAL = '0:42: execution error: Not authorized to send Apple events to Ghostty. (-1743)'

test('macOS refusing control of Ghostty is told in osascript’s words, and nothing is written', async () => {
  const t = oneWindow(IN_GHOSTTY, { ghostty: TERMINALS, refused: () => REFUSAL })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: osascript: ${REFUSAL}\n`,
  })
  expect(t.screen.written).toEqual([])
})

test('a find that fails once the terminal took the marker puts the terminal back, and tells the failure', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: SHOWN,
    ghostty: TERMINALS,
    refused: run => (run === 2 ? REFUSAL : undefined),
  })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: osascript: ${REFUSAL}\n`,
  })
  expect(t.screen.focused).toEqual([])
  expect(t.screen.written.map(each => each.device)).toEqual([WINDOW, WINDOW])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
})

test('when the listing after a failed find fails too, the find’s failure is the one told', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: SHOWN,
    ghostty: TERMINALS,
    refused: run => ({ 2: REFUSAL, 3: 'the listing broke as well' })[run],
  })

  expect(await t.run('jump', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: `sitrep: osascript: ${REFUSAL}\n`,
  })
})

/** What osascript says when Ghostty does not answer in time, as it does with the screen locked. */
const TIMED_OUT = '131:133: execution error: Ghostty got an error: AppleEvent timed out. (-1712)'

const NO_ANSWER = `sitrep: Ghostty did not answer within ${ANSWER_SECONDS} seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty.\n`

test('Ghostty not answering the listing in time is refused in plain words, before anything is written or focused', async () => {
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, refused: () => TIMED_OUT })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: NO_ANSWER })
  expect(t.screen.written).toEqual([])
  expect(t.screen.focused).toEqual([])
})

test('Ghostty not answering the find in time is refused in plain words, and the terminal put back', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: SHOWN,
    ghostty: TERMINALS,
    refused: run => ({ 2: TIMED_OUT })[run],
  })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: NO_ANSWER })
  expect(t.screen.written.map(each => each.device)).toEqual([WINDOW, WINDOW])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
})

test('each Ghostty program asks Ghostty within the time limit, its running checked first', () => {
  for (const program of [LIST, FIND_AND_FOCUS, FOCUS]) {
    const lines = program.split('\n')
    const at = (line: string) => lines.indexOf(line)

    expect(at(`with timeout of ${ANSWER_SECONDS} seconds`)).toBeGreaterThan(
      at('if application "Ghostty" is not running then return ""'),
    )
    expect(at('tell application "Ghostty"')).toBe(
      at(`with timeout of ${ANSWER_SECONDS} seconds`) + 1,
    )
    expect(at('end timeout')).toBe(at('end tell') + 1)
  }
})

test('a Ghostty device that does not answer is passed over for the next, which does; Ghostty is listed once before the knocks', async () => {
  const SILENT = '/dev/ttys099'
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient(SILENT, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.done, out: '', err: '' })
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
  expect(t.screen.ran.filter(([name]) => name === 'osascript')).toEqual([
    ['osascript', '-e', LIST],
    ['osascript', '-e', FIND_AND_FOCUS, MARKER],
    ['osascript', '-e', LIST],
    ['osascript', '-e', FIND_AND_FOCUS, NEXT_MARKER],
  ])
  expect(t.screen.written.map(each => each.device)).toEqual([SILENT, WINDOW, WINDOW])
})

test('a put-back that fails does not stop the jump: the next device is knocked on', async () => {
  const SILENT = '/dev/ttys099'
  const opening = (id: string) => (terminals: FakeTerminal[]) =>
    void terminals.push({ id, device: '/dev/ttys091', directory: HOME })
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient(SILENT, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: TERMINALS,
    changes: [() => undefined, opening('A'), opening('B'), opening('C')],
  })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.done, out: '', err: '' })
  expect(
    t.screen.ran.filter(words => words[2] === LIST),
    'the put-back never settled',
  ).toHaveLength(4)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test('when no Ghostty device answers, the failure names every one knocked on', async () => {
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
  expect(t.screen.directories()).toEqual(DIRECTORIES)
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

/** Where a jump remembers each device's Ghostty terminal. */
const REMEMBERED = `${ROOT}/${REMEMBERED_FILE}`

/** The session's one window, in tmux, with these lines in the remembered file. */
const rememberedAs = (lines: string[], options?: Parameters<typeof terminal>[0]) => {
  const t = oneWindow(IN_TMUX, options)

  t.files.set(REMEMBERED, { text: lines.join(''), mtimeMs: NOW })

  return t
}

const FOCUSED_RUN = { exit: EXIT.done, out: '', err: '' }

test("a knock that answers remembers the device's terminal, and the next jump focuses it by its id: tmux and ps asked, nothing listed, nothing written", async () => {
  const t = oneWindow(IN_TMUX)

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.text(REMEMBERED)).toBe(rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL'))

  const first = t.screen.ran.length
  const written = t.screen.written.length

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.slice(first).filter(([name]) => name !== 'lsappinfo')).toEqual([
    ['tmux', '-S', SOCKET, ...PANES],
    ['tmux', '-S', SOCKET, ...CLIENTS],
    PS,
    ['osascript', '-e', FOCUS, 'SWITCHBOARD-TERMINAL'],
  ])
  expect(t.screen.written).toHaveLength(written)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL', 'SWITCHBOARD-TERMINAL'])
  expect(t.text(REMEMBERED), 'a terminal focused by its id is not written again').toBe(
    rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL'),
  )
})

test("a remembered terminal gone falls back to the knock, which remembers the device's new terminal and puts its directory back", async () => {
  const t = rememberedAs([rememberedText(WINDOW, 'CLOSED-TERMINAL')])

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript')).toEqual([
    ['osascript', '-e', FOCUS, 'CLOSED-TERMINAL'],
    ['osascript', '-e', LIST],
    ['osascript', '-e', FIND_AND_FOCUS, MARKER],
  ])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
  expect(t.text(REMEMBERED)).toBe(
    rememberedText(WINDOW, 'CLOSED-TERMINAL') + rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL'),
  )
})

test('a knock after a last line left torn ends that line first, so the new terminal is remembered and the torn line is the only one lost', async () => {
  const TORN = `{"device":"${WINDOW}","termi`
  const t = rememberedAs([rememberedText('/dev/ttys041', 'KIT-TERMINAL'), TORN])

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.text(REMEMBERED)).toBe(
    `${rememberedText('/dev/ttys041', 'KIT-TERMINAL')}${TORN}\n${rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL')}`,
  )

  const first = t.screen.ran.length

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(
    t.screen.ran.slice(first).filter(([name]) => name === 'osascript'),
    'the next jump focuses it by its id',
  ).toEqual([['osascript', '-e', FOCUS, 'SWITCHBOARD-TERMINAL']])
})

test("a remembered terminal's focus failing any way but a timeout falls back to the knock", async () => {
  const t = rememberedAs([rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL')], {
    tmux: SHOWN,
    ghostty: TERMINALS,
    refused: run => (run === 1 ? REFUSAL : undefined),
  })

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript').map(words => words[2])).toEqual([FOCUS, LIST, FIND_AND_FOCUS])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
})

test('Ghostty not answering for a remembered terminal in time is refused in plain words, with nothing listed, written or focused', async () => {
  const t = rememberedAs([rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL')], {
    tmux: SHOWN,
    ghostty: TERMINALS,
    refused: () => TIMED_OUT,
  })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: NO_ANSWER })
  expect(runsOf(t, 'osascript')).toEqual([['osascript', '-e', FOCUS, 'SWITCHBOARD-TERMINAL']])
  expect(t.screen.written).toEqual([])
  expect(t.screen.focused).toEqual([])
})

test('the last line for a device wins, and a torn or broken line never stops a jump', async () => {
  const t = rememberedAs([
    'not json\n',
    rememberedText(WINDOW, 'CLOSED-TERMINAL'),
    rememberedText('/dev/ttys041', 'KIT-TERMINAL'),
    rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL'),
    `{"device":"${WINDOW}","terminal":7}\n`,
    `{"device":"${WINDOW}","termi`,
  ])

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript')).toEqual([['osascript', '-e', FOCUS, 'SWITCHBOARD-TERMINAL']])
  expect(t.screen.written).toEqual([])
})

test('a device whose remembered terminal is gone, and whose knock nothing answers, is passed over for the next device’s remembered terminal', async () => {
  const SILENT = '/dev/ttys099'
  const t = rememberedAs(
    [rememberedText(SILENT, 'CLOSED-TERMINAL'), rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL')],
    {
      tmux: serverShowing(ghosttyClient(SILENT, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
      ghostty: TERMINALS,
    },
  )

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript')).toEqual([
    ['osascript', '-e', FOCUS, 'CLOSED-TERMINAL'],
    ['osascript', '-e', LIST],
    ['osascript', '-e', FIND_AND_FOCUS, MARKER],
    ['osascript', '-e', LIST],
    ['osascript', '-e', FOCUS, 'SWITCHBOARD-TERMINAL'],
  ])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
})

test('a remembered terminal with Ghostty not running is off screen, nothing written', async () => {
  const t = rememberedAs([rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL')], { tmux: SHOWN })

  expect(await t.run('jump', ...SESSION)).toEqual({ exit: EXIT.refused, out: '', err: OFF_SCREEN })
  expect(t.screen.written).toEqual([])
})

test('what the jump remembers sits beside the projects, and list never takes it for one', async () => {
  const t = oneWindow(IN_TMUX)
  const listed = await t.run('list')
  const listedJson = await t.run('list', '--json')

  await t.run('jump', ...SESSION)

  expect(t.files.has(REMEMBERED)).toBe(true)
  expect(await t.run('list')).toEqual(listed)
  expect(await t.run('list', '--json')).toEqual(listedJson)
})

/** Lets every promise settle that can while a program is held: the fakes answer at once, so a hundred turns are ample. */
const settled = async () => {
  for (let turn = 0; turn < 100; turn += 1) {
    await Promise.resolve()
  }
}

test("Ghostty's terminals are listed only once the screen is read: nothing is asked of Ghostty while ps is still answering", async () => {
  const t = oneWindow(IN_TMUX)
  const ps = t.screen.hold('ps')
  const jumped = t.run('jump', ...SESSION)

  await ps.arrived
  await settled()

  expect(runsOf(t, 'osascript')).toEqual([])

  ps.release()

  expect(await jumped).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript').map(words => words[2])).toEqual([LIST, FIND_AND_FOCUS])
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

test("a pane whose tmux window no client shows is shown by tmux selecting it in the session holding it, within tmux's time limit, and that session's Ghostty window is then knocked on", async () => {
  const t = beside()

  expect(await t.run('jump', ...SESSION)).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo')).toEqual([
    ['tmux', '-S', SOCKET, ...PANES],
    ['tmux', '-S', SOCKET, ...CLIENTS],
    PS,
    ['tmux', '-S', SOCKET, 'select-window', '-t', `${CLAUDES_SESSION}:${CLAUDES}`],
    ['osascript', '-e', LIST],
    ['osascript', '-e', FIND_AND_FOCUS, MARKER],
  ])
  expect(tmuxLimits(t)).toEqual([LOOK_MS, LOOK_MS, LOOK_MS])
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
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

test('a select tmux refuses, or does not answer in time, refuses the jump in plain words, with nothing written or focused', async () => {
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
    expect(t.screen.written, why).toEqual([])
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

test('a window outside tmux in a terminal app with no driver is brought forward as an app, by its bundle id within the time limit, and nothing more', async () => {
  const cases: [string, string][] = [
    ['iTerm.app', 'com.googlecode.iterm2'],
    ['Apple_Terminal', 'com.apple.Terminal'],
    ['WezTerm', 'com.github.wez.wezterm'],
    ['WarpTerminal', 'dev.warp.Warp-Stable'],
  ]

  for (const [program, bundle] of cases) {
    const t = oneWindow(
      { ...IN_GHOSTTY, terminal: program },
      { ghostty: TERMINALS, front: ['com.apple.finder'] },
    )

    expect(await t.run('jump', ...SESSION), program).toEqual(FOCUSED_RUN)
    expect(openRuns(t), program).toEqual([['open', '-b', bundle]])
    expect(
      t.screen.limits.filter(each => each.name === 'open'),
      program,
    ).toEqual([{ name: 'open', limitMs: LOOK_MS }])
    expect(
      t.screen.ran.filter(([name]) => name !== 'lsappinfo' && name !== 'open'),
      `${program}: no tmux, ps or Ghostty`,
    ).toEqual([])
    expect(t.screen.written, program).toEqual([])
    expect(t.waits, `${program}: no watch of the front`).toEqual([])
  }
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
    expect(t.screen.written).toEqual([])
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
  expect(runsOf(t, 'osascript').map(words => words[2])).toEqual([LIST, FIND_AND_FOCUS, LIST])
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

test('of two windows on one session, else, the jump goes to the one active last: by its state’s start, then by its attach', async () => {
  const cases: [string, Attached, Attached, string][] = [
    [
      'the later start, though attached first',
      { at: T0 + 30_000, state: stateOf('yourTurn', T0 + 40_000) },
      { at: T0, state: stateOf('working', T0 + 50_000) },
      SECONDS,
    ],
    [
      'the same start, so the later attach',
      { at: T0 + 30_000, state: stateOf('yourTurn', T0 + 40_000) },
      { at: T0, state: stateOf('working', T0 + 40_000) },
      FIRSTS,
    ],
    [
      'both stopped on Lee, so the later stop',
      { at: T0, state: stateOf('question', T0 + 50_000) },
      { at: T0 + 30_000, state: stateOf('permission', T0 + 40_000) },
      FIRSTS,
    ],
    [
      'one saying no state, as from a version before heartbeats said it: its attach stands for its start',
      { at: T0 + 30_000 },
      { at: T0, state: stateOf('working', T0 + 20_000) },
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
