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
import { CLIENTS, PANES, PS } from '../cli/screen'
import type { Where } from '../core'
import { META, MIN, T0, W2 } from './support'
import {
  ENV,
  ghosttyClient,
  NOW,
  phoneClient,
  SOCKET,
  sshClient,
  terminal,
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

/** The device of the Ghostty window attached to the work's session, and of Lee's phone. */
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

/** The work's tmux server: its session shown by the clients given, and another session beside it. */
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

const OFF_SCREEN = `sitrep: ${META.name} is not on screen: no Ghostty window shows it.\n`

const WORK = ['--work', META.id]

/** The knocks' markers, from the terminal's first random draw and its next. */
const MARKER = '/sitrep-knock/0102030401020304'
const NEXT_MARKER = '/sitrep-knock/0506070805060708'

/** The work's one window, `where` it is, with tmux and Ghostty as given. */
const oneWindow = (
  where: Where,
  options: Parameters<typeof terminal>[0] = { tmux: SHOWN, ghostty: TERMINALS },
) => {
  const t = terminal(options)

  t.seed(META, { seenAt: NOW, where })

  return t
}

test("jump focuses the Ghostty window on the work's tmux session, prints nothing, and puts the terminal's directory back exactly", async () => {
  const t = oneWindow(IN_TMUX)

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.done, out: '', err: '' })
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

  await t.run('jump', ...WORK)

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

  expect((await t.run('jump', ...WORK)).exit).toBe(EXIT.done)
  expect(t.screen.focused).toEqual(['KIT-TERMINAL'])
  expect(t.screen.directories()).toEqual(DIRECTORIES)
  expect(t.screen.ran.filter(([name]) => name !== 'lsappinfo').map(([name]) => name)).toEqual([
    'osascript',
    'osascript',
  ])
})

test('with no client on the work’s tmux server, the snapshot goes unused: ps failing then is no matter', async () => {
  const t = oneWindow(IN_TMUX, { tmux: serverShowing(), ghostty: TERMINALS, slow: ['ps'] })

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.refused, out: '', err: OFF_SCREEN })
})

test("a grouped session's Ghostty window counts only while it shows the pane's tmux window", async () => {
  const grouped = (window: string) =>
    oneWindow(IN_TMUX, {
      tmux: {
        [SOCKET]: {
          panes: [
            [PANE, CLAUDES],
            ['%149', BESIDE],
            [PANE, CLAUDES],
            ['%149', BESIDE],
          ],
          clients: [ghosttyClient(WINDOW, window)],
        },
      },
      ghostty: TERMINALS,
    })
  const elsewhere = grouped(BESIDE)
  const there = grouped(CLAUDES)

  expect((await elsewhere.run('jump', ...WORK)).err).toBe(OFF_SCREEN)
  expect((await there.run('jump', ...WORK)).exit).toBe(EXIT.done)
  expect(there.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test('a session the phone and a Ghostty window both show goes to the Ghostty window, and nothing is written to the phone', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(phoneClient(PHONE, CLAUDES), ghosttyClient(WINDOW, CLAUDES)),
    ghostty: [...TERMINALS, { id: 'NOT-THE-PHONE', device: PHONE, directory: HOME }],
  })

  expect((await t.run('jump', ...WORK)).exit).toBe(EXIT.done)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
  expect(t.screen.written.filter(each => each.device === PHONE)).toEqual([])
})

test('a work no Ghostty window shows is not on screen: nothing is written and nothing focused', async () => {
  const cases: [string, ReturnType<typeof terminal>][] = [
    [
      'a closed work, its window long gone',
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
      "a session of several windows, Claude's not the one showing",
      oneWindow(IN_TMUX, {
        tmux: {
          [SOCKET]: {
            panes: [
              [PANE, CLAUDES],
              ['%149', BESIDE],
            ],
            clients: [ghosttyClient(WINDOW, BESIDE)],
          },
        },
        ghostty: TERMINALS,
      }),
    ],
    [
      'a detached session',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(ghosttyClient('/dev/ttys041', KIT)),
        ghostty: TERMINALS,
      }),
    ],
    [
      'a session only the phone shows',
      oneWindow(IN_TMUX, { tmux: serverShowing(phoneClient(PHONE, CLAUDES)), ghostty: TERMINALS }),
    ],
    [
      'a session only a Ghostty on another Mac shows, over ssh',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(sshClient('/dev/ttys080', CLAUDES)),
        ghostty: [...TERMINALS, { id: 'LOOKALIKE', device: '/dev/ttys080', directory: HOME }],
      }),
    ],
    ['tmux gone', oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS })],
    ['Ghostty not running', oneWindow(IN_TMUX, { tmux: SHOWN })],
    ['Ghostty with no window open', oneWindow(IN_GHOSTTY, { ghostty: [] })],
    [
      'a window in another terminal',
      oneWindow({ ...IN_GHOSTTY, terminal: 'iTerm.app' }, { ghostty: TERMINALS }),
    ],
  ]

  for (const [why, t] of cases) {
    expect(await t.run('jump', ...WORK), why).toEqual({
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

    expect(await t.run('jump', ...WORK), why).toEqual({
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
    (await oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS }).run('jump', ...WORK)).err,
  ).toBe(OFF_SCREEN)
})

test('a device no Ghostty terminal answers on fails, saying which, and leaves no terminal on the marker', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: serverShowing(ghosttyClient('/dev/ttys099', CLAUDES)),
    ghostty: TERMINALS,
  })

  expect(await t.run('jump', ...WORK)).toEqual({
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

  expect((await t.run('jump', ...WORK)).exit).toBe(EXIT.refused)
  expect(t.screen.focused).toEqual([])
  expect(t.screen.written.map(each => each.device)).toEqual([WINDOW, WINDOW])
  expect(t.screen.directories()).toEqual({ [late.id]: ODD_FOLDER })
})

test('a terminal that reported no directory is put back to $HOME', async () => {
  const blank = { id: 'BLANK-TERMINAL', device: WINDOW, directory: '' }
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: [blank] })

  expect((await t.run('jump', ...WORK)).exit).toBe(EXIT.done)
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

  expect((await t.run('jump', ...WORK)).exit).toBe(EXIT.done)
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

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.done, out: '', err: '' })
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

  expect((await t.run('jump', ...WORK)).exit).toBe(EXIT.done)
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

  expect(await t.run('jump', ...WORK)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: "sitrep: Ghostty's windows kept opening or closing as they were listed. Try again.\n",
  })
  expect(t.screen.ran.filter(words => words[2] === LIST)).toHaveLength(3)
  expect(t.screen.written).toEqual([])
  expect(t.screen.focused).toEqual([])
})

test('the deliverer’s window is tried first, and another window when the deliverer’s is not on screen', async () => {
  const twoWindows = (tmux: Record<string, FakeServer>) => {
    const t = terminal({ tmux, ghostty: TERMINALS })
    const paths = t.seed(META, { seenAt: T0 + 30_000, where: IN_GHOSTTY })

    t.window(paths, W2, T0, IN_TMUX)

    return t
  }
  const both = twoWindows(SHOWN)
  const deliverersDetached = twoWindows(serverShowing())

  expect((await both.run('jump', ...WORK)).exit).toBe(EXIT.done)
  expect(both.screen.focused, 'the deliverer, attached first, though listed second').toEqual([
    'SWITCHBOARD-TERMINAL',
  ])
  expect((await deliverersDetached.run('jump', ...WORK)).exit).toBe(EXIT.done)
  expect(deliverersDetached.screen.focused).toEqual(['KIT-TERMINAL'])
})

const REFUSAL = '0:42: execution error: Not authorized to send Apple events to Ghostty. (-1743)'

test('macOS refusing control of Ghostty is told in osascript’s words, and nothing is written', async () => {
  const t = oneWindow(IN_GHOSTTY, { ghostty: TERMINALS, refused: () => REFUSAL })

  expect(await t.run('jump', ...WORK)).toEqual({
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

  expect(await t.run('jump', ...WORK)).toEqual({
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

  expect(await t.run('jump', ...WORK)).toEqual({
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

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.refused, out: '', err: NO_ANSWER })
  expect(t.screen.written).toEqual([])
  expect(t.screen.focused).toEqual([])
})

test('Ghostty not answering the find in time is refused in plain words, and the terminal put back', async () => {
  const t = oneWindow(IN_TMUX, {
    tmux: SHOWN,
    ghostty: TERMINALS,
    refused: run => ({ 2: TIMED_OUT })[run],
  })

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.refused, out: '', err: NO_ANSWER })
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

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.done, out: '', err: '' })
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

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.done, out: '', err: '' })
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

  expect((await t.run('jump', ...WORK)).err).toBe(
    `sitrep: ${META.name} shows on /dev/ttys097, /dev/ttys098 and /dev/ttys099, but no Ghostty window there answered.\n`,
  )
  expect(t.screen.directories()).toEqual(DIRECTORIES)
})

test('jump names its work as every work command does, and an unknown one is no such work', async () => {
  const t = oneWindow(IN_TMUX)
  const named = terminal({ env: { ...ENV, SITREP_WORK: META.id }, ghostty: TERMINALS })

  named.seed(META, { seenAt: NOW, where: IN_GHOSTTY })

  expect((await t.run('jump')).exit).toBe(EXIT.refused)
  expect(await t.run('jump', '--work', 'sr-zzzzzz')).toEqual({
    exit: EXIT.noWork,
    out: '',
    err: 'sitrep: There is no piece of work sr-zzzzzz on the board, in any project.\n',
  })
  expect(t.screen.ran).toEqual([])
  expect((await named.run('jump')).exit, 'SITREP_WORK names it').toBe(EXIT.done)
  expect(named.screen.focused).toEqual(['KIT-TERMINAL'])
})

test("jump's help says what it does, and the help lists it", async () => {
  const t = terminal()

  expect((await t.run('jump', '--help')).out).toBe(
    [
      'Usage: sitrep jump [--work <id>]',
      '',
      'Bring the Ghostty window showing the piece of work to the front, on whatever Space it is. Prints nothing.',
      '',
      '  --work <id>  the piece of work: sr- and six characters; else $SITREP_WORK',
      '',
    ].join('\n'),
  )
  expect((await t.run('--help')).out).toContain('  sitrep jump\n')
})

/** Where a jump remembers each device's Ghostty terminal. */
const REMEMBERED = `${ROOT}/${REMEMBERED_FILE}`

/** The work's one window, in tmux, with these lines in the remembered file. */
const rememberedAs = (lines: string[], options?: Parameters<typeof terminal>[0]) => {
  const t = oneWindow(IN_TMUX, options)

  t.files.set(REMEMBERED, { text: lines.join(''), mtimeMs: NOW })

  return t
}

const FOCUSED_RUN = { exit: EXIT.done, out: '', err: '' }

test("a knock that answers remembers the device's terminal, and the next jump focuses it by its id: tmux and ps asked, nothing listed, nothing written", async () => {
  const t = oneWindow(IN_TMUX)

  expect(await t.run('jump', ...WORK)).toEqual(FOCUSED_RUN)
  expect(t.text(REMEMBERED)).toBe(rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL'))

  const first = t.screen.ran.length
  const written = t.screen.written.length

  expect(await t.run('jump', ...WORK)).toEqual(FOCUSED_RUN)
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

  expect(await t.run('jump', ...WORK)).toEqual(FOCUSED_RUN)
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

test("a remembered terminal's focus failing any way but a timeout falls back to the knock", async () => {
  const t = rememberedAs([rememberedText(WINDOW, 'SWITCHBOARD-TERMINAL')], {
    tmux: SHOWN,
    ghostty: TERMINALS,
    refused: run => (run === 1 ? REFUSAL : undefined),
  })

  expect(await t.run('jump', ...WORK)).toEqual(FOCUSED_RUN)
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

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.refused, out: '', err: NO_ANSWER })
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

  expect(await t.run('jump', ...WORK)).toEqual(FOCUSED_RUN)
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

  expect(await t.run('jump', ...WORK)).toEqual(FOCUSED_RUN)
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

  expect(await t.run('jump', ...WORK)).toEqual({ exit: EXIT.refused, out: '', err: OFF_SCREEN })
  expect(t.screen.written).toEqual([])
})

test('what the jump remembers sits beside the projects, and list never takes it for one', async () => {
  const t = oneWindow(IN_TMUX)
  const listed = await t.run('list')
  const listedJson = await t.run('list', '--json')

  await t.run('jump', ...WORK)

  expect(t.files.has(REMEMBERED)).toBe(true)
  expect(await t.run('list')).toEqual(listed)
  expect(await t.run('list', '--json')).toEqual(listedJson)
})

test("a jump sure to knock lists Ghostty's terminals while ps is still answering", async () => {
  const t = oneWindow(IN_TMUX)
  const ps = t.screen.hold('ps')
  const listing = t.screen.hold('osascript')
  const jumped = t.run('jump', ...WORK)

  await ps.arrived
  await listing.arrived

  expect(runsOf(t, 'osascript')).toEqual([['osascript', '-e', LIST]])

  ps.release()
  listing.release()

  expect(await jumped).toEqual(FOCUSED_RUN)
  expect(runsOf(t, 'osascript').filter(words => words[2] === LIST)).toHaveLength(1)
})

test('a jump whose work no Ghostty window shows lists nothing in Ghostty', async () => {
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
      'a detached session',
      oneWindow(IN_TMUX, {
        tmux: serverShowing(ghosttyClient('/dev/ttys041', KIT)),
        ghostty: TERMINALS,
      }),
    ],
    ['tmux gone', oneWindow(IN_TMUX, { tmux: {}, ghostty: TERMINALS })],
    [
      'a window in another terminal',
      oneWindow({ ...IN_GHOSTTY, terminal: 'iTerm.app' }, { ghostty: TERMINALS }),
    ],
  ]

  for (const [why, t] of cases) {
    expect((await t.run('jump', ...WORK)).err, why).toBe(OFF_SCREEN)
    expect(runsOf(t, 'osascript'), why).toEqual([])
  }
})

const FINDER = 'com.apple.finder'

/** How many times the watch looks when nothing ends it early. */
const LOOKS = WATCH_MS / LOOK_EVERY_MS

/** A jump with Finder in front as it begins, and the app in front at each look after as given. */
const fromFinder = async (front: string[], options: Parameters<typeof terminal>[0] = {}) => {
  const t = oneWindow(IN_TMUX, { tmux: SHOWN, ghostty: TERMINALS, front, ...options })

  return { t, run: await t.run('jump', ...WORK) }
}

const isFront = (words: readonly string[]) => words.join(' ') === FRONT.join(' ')

const broughtForward = (t: ReturnType<typeof terminal>) =>
  t.screen.ran.filter(words => words.join(' ') === BRING_FORWARD.join(' '))

test('with Ghostty in front as the jump begins, nothing watches the front after it', async () => {
  const t = oneWindow(IN_TMUX)

  expect(await t.run('jump', ...WORK)).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.filter(isFront)).toHaveLength(1)
  expect(t.waits).toEqual([])
  expect(broughtForward(t)).toEqual([])
})

test('which app is in front is read as the jump begins, before tmux answers', async () => {
  const t = oneWindow(IN_TMUX)
  const tmux = t.screen.hold('tmux')
  const jumped = t.run('jump', ...WORK)

  await tmux.arrived

  expect(t.screen.ran.filter(isFront)).toHaveLength(1)

  tmux.release()

  expect(await jumped).toEqual(FOCUSED_RUN)
})

test('another app taking the front back after Ghostty came forward brings Ghostty forward once, at that look', async () => {
  const { t, run } = await fromFinder([FINDER, FINDER, GHOSTTY_BUNDLE, GHOSTTY_BUNDLE, FINDER])

  expect(run).toEqual(FOCUSED_RUN)
  expect(
    t.screen.ran.filter(isFront),
    'the look as the jump began, and four after the focus',
  ).toHaveLength(5)
  expect(t.waits).toEqual([LOOK_EVERY_MS, LOOK_EVERY_MS, LOOK_EVERY_MS, LOOK_EVERY_MS])
  expect(broughtForward(t)).toHaveLength(1)
  expect(t.screen.ran.at(-1)).toEqual(BRING_FORWARD)
  expect(t.screen.focused).toEqual(['SWITCHBOARD-TERMINAL'])
})

test('Ghostty never coming forward is brought forward once, as the watch ends, by `open` within the time limit', async () => {
  const { t, run } = await fromFinder([FINDER])

  expect(run).toEqual(FOCUSED_RUN)
  expect(t.screen.ran.filter(isFront)).toHaveLength(1 + LOOKS)
  expect(t.waits.reduce((sum, ms) => sum + ms, 0)).toBe(WATCH_MS)
  expect(broughtForward(t)).toHaveLength(1)
  expect(t.screen.ran.at(-1)).toEqual(BRING_FORWARD)
  expect(t.screen.limits.at(-1)).toEqual({ name: 'open', limitMs: LOOK_MS })
  expect(BRING_FORWARD).toEqual(['open', '-b', GHOSTTY_BUNDLE])
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

    expect(await t.run('jump', ...WORK), why).toEqual(FOCUSED_RUN)
    expect(t.waits, why).toEqual([])
    expect(broughtForward(t), why).toEqual([])
  }

  for (const options of [{ missing: ['open'] }, { slow: ['open'] }]) {
    const { t, run } = await fromFinder([FINDER], options)

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

  expect((await offScreen.run('jump', ...WORK)).exit).toBe(EXIT.refused)
  expect((await unanswered.run('jump', ...WORK)).exit).toBe(EXIT.refused)

  for (const t of [offScreen, unanswered]) {
    expect(t.waits).toEqual([])
    expect(broughtForward(t)).toEqual([])
  }
})
