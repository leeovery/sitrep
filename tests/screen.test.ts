import { expect, test } from 'claude-code/testing'
import { appOfCommand, appOfProgram, DRIVERS, openWords } from '../cli/apps'
import { GHOSTTY_BUNDLE, parseBundle } from '../cli/front'
import { GHOSTTY } from '../cli/ghostty'
import {
  clientApps,
  parseProcesses,
  placesShowing,
  reachOf,
  socketsOf,
  windowsOf,
  type Place,
  type Process,
  type Processes,
  type Screen,
} from '../cli/screen'
import { parseClients, parsePanes, selectWords, type Client } from '../cli/tmux'
import { attach, leave, presenceText, rowOf, type Where, type WindowState } from '../core'
import { fold, MIN, T0, W1, W2 } from './support'

const SOCKET = '/private/tmp/tmux-501/default'
const OTHER_SOCKET = '/private/tmp/tmux-501/session'
const GHOSTTY_APP = '/Applications/Ghostty.app/Contents/MacOS/ghostty'
const TERMINAL_APP = '/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal'

/** Claude's pane, the tmux window holding it, and its tmux session. */
const PANE = '%148'
const WINDOW = '@45'
const SESSION = '$45'

const IN_TMUX: Where = {
  device: '/dev/ttys043',
  terminal: 'tmux',
  tmux: { socket: SOCKET, pane: PANE },
}

const IN_GHOSTTY: Where = { device: '/dev/ttys041', terminal: 'ghostty' }

/** Every process, by id: `[id, parent, command]`. */
const processes = (...each: [pid: number, parent: number, command: string][]) =>
  new Map(each.map(([pid, parent, command]): [number, Process] => [pid, { parent, command }]))

/**
 * Four Ghostty windows (`tmux < zsh < login < ghostty`), the phone through
 * mosh-server, a Ghostty on another Mac over ssh, a Terminal window, and VS
 * Code's terminal, whose shell runs under a helper app inside VS Code's.
 */
const PROCESSES = processes(
  [1, 0, '/sbin/launchd'],
  [500, 1, GHOSTTY_APP],
  [501, 500, '/usr/bin/login'],
  [502, 501, '-zsh'],
  [503, 502, 'tmux'],
  [511, 500, '/usr/bin/login'],
  [512, 511, '-zsh'],
  [513, 512, 'tmux'],
  [521, 500, '/usr/bin/login'],
  [522, 521, '-zsh'],
  [523, 522, 'tmux'],
  [531, 500, '/usr/bin/login'],
  [532, 531, '-zsh'],
  [533, 532, 'tmux'],
  [600, 1, '/opt/homebrew/bin/mosh-server'],
  [601, 600, '-zsh'],
  [602, 601, 'tmux'],
  [700, 1, '/usr/sbin/sshd'],
  [701, 700, '/usr/libexec/sshd-session'],
  [702, 701, '-zsh'],
  [703, 702, 'tmux'],
  [800, 1, TERMINAL_APP],
  [801, 800, '/usr/bin/login'],
  [802, 801, '-zsh'],
  [803, 802, 'tmux'],
  [900, 1, '/Applications/Visual Studio Code.app/Contents/MacOS/Electron'],
  [
    901,
    900,
    '/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper',
  ],
  [902, 901, '-zsh'],
  [903, 902, 'tmux'],
)

/** A client on a device, its process, showing a window of the tmux session given, else of the one named for the window. */
const client = (device: string, pid: number, window: string, session = `$${window.slice(1)}`) => ({
  device,
  pid,
  window,
  session,
})

/** The screen one server with these panes, each in its tmux session, and these clients gives, read against the processes. */
const screenOf = (
  panes: [pane: string, window: string, session: string][],
  clients: Client[],
  snapshot: Processes = PROCESSES,
): Screen => {
  const servers = new Map([
    [SOCKET, { panes: parsePanes(panes.map(each => each.join('\t')).join('\n')), clients }],
  ])

  return {
    servers,
    apps: clientApps(servers, snapshot),
    unanswered: [],
    unansweredSockets: new Set(),
  }
}

/**
 * Claude's window shown by Ghostty windows, the phone and a Ghostty over
 * ssh; another of its tmux session by a Ghostty window; and a window of
 * another session by a Ghostty window.
 */
const SCREEN = screenOf(
  [
    [PANE, WINDOW, SESSION],
    ['%149', '@46', SESSION],
    ['%54', '@52', '$52'],
  ],
  [
    client('/dev/ttys067', 602, WINDOW),
    client('/dev/ttys000', 503, WINDOW),
    client('/dev/ttys041', 523, '@52'),
    client('/dev/ttys080', 703, WINDOW),
    client('/dev/ttys056', 533, '@46', SESSION),
    client('/dev/ttys055', 513, WINDOW),
  ],
)

/** Each place as its device, its app's name, and the tmux session a select makes the pane's window current in, if any. */
const seen = (places: readonly Place[]) =>
  places.map(place => [place.device, place.app.name, place.select?.session])

test("tmux's panes read as each pane's tmux window and the tmux sessions it is in, a pane listed once for each", () => {
  expect(
    parsePanes(
      `${PANE}\t${WINDOW}\t$7\n%54\t@52\t$9\n${PANE}\t${WINDOW}\t$8\n${PANE}\t${WINDOW}\t$7\n\n`,
    ),
  ).toEqual(
    new Map([
      [PANE, { window: WINDOW, sessions: ['$7', '$8'] }],
      ['%54', { window: '@52', sessions: ['$9'] }],
    ]),
  )
})

test("tmux's clients read as each one's device, process, the tmux window it shows and the tmux session it is attached to; a line without its fields is skipped", () => {
  expect(
    parseClients(
      `/dev/ttys000\t503\t${WINDOW}\t$7\nnot a client\n/dev/ttys041\t523\t@52\n/dev/ttys067\t602\t@52\t$9\n`,
    ),
  ).toEqual([client('/dev/ttys000', 503, WINDOW, '$7'), client('/dev/ttys067', 602, '@52', '$9')])
})

test("tmux's select makes a window current in a tmux session by their ids, on the server's socket", () => {
  expect(selectWords({ socket: SOCKET, session: '$7', window: WINDOW })).toEqual([
    'tmux',
    '-u',
    '-S',
    SOCKET,
    'select-window',
    '-t',
    `$7:${WINDOW}`,
  ])
})

test("ps's snapshot reads as each process's parent and command, a command's spaces kept", () => {
  expect(
    parseProcesses(
      [
        '    1     0 /sbin/launchd',
        ' 4168     1 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        'not a process',
        '',
      ].join('\n'),
    ),
  ).toEqual(
    processes(
      [1, 0, '/sbin/launchd'],
      [4168, 1, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'],
    ),
  )
})

test("each client's terminal app is the nearest app it descends from: Ghostty's driver for Ghostty's, an app by its outermost bundle for another's, and none for the phone's or a Ghostty's over ssh", () => {
  const apps = clientApps(
    new Map([
      [
        SOCKET,
        {
          panes: new Map(),
          clients: [503, 513, 523, 533, 602, 703, 803, 903].map(pid =>
            client(`/dev/ttys${pid}`, pid, WINDOW),
          ),
        },
      ],
    ]),
    PROCESSES,
  )

  expect(Object.fromEntries([...apps].map(([pid, app]) => [pid, app.name]))).toEqual({
    503: 'Ghostty',
    513: 'Ghostty',
    523: 'Ghostty',
    533: 'Ghostty',
    803: 'Terminal',
    903: 'Visual Studio Code',
  })
  expect(apps.get(503)).toBe(GHOSTTY)
})

test("Ghostty's driver is told by its program, `ghostty`, outside tmux and in ps, and declares nothing beyond bringing a window forward", () => {
  expect(DRIVERS).toEqual([GHOSTTY])
  expect(appOfProgram('ghostty')).toBe(GHOSTTY)
  expect(appOfCommand(GHOSTTY_APP)).toBe(GHOSTTY)
  expect(GHOSTTY.can).toEqual([])
})

test('a terminal app with no driver is told by its `$TERM_PROGRAM` in the table, or its program inside an app bundle; anything else is none', () => {
  expect(appOfProgram('iTerm.app')?.name).toBe('iTerm2')
  expect(appOfProgram('Apple_Terminal')?.name).toBe('Terminal')

  for (const program of ['tmux', 'Unknown', '', undefined]) {
    expect(appOfProgram(program), String(program)).toBeUndefined()
  }

  expect(appOfCommand('/Foo.app/Contents/MacOS/foo')?.name).toBe('Foo')
  expect(
    appOfCommand('/Users/lee/Library/Application Support/iTerm2/iTermServer-3.5.4')?.name,
    "iTerm2's server, outside its bundle",
  ).toBe('iTerm2')

  for (const command of ['-zsh', '/usr/bin/login', '/opt/homebrew/bin/mosh-server', 'tmux']) {
    expect(appOfCommand(command), command).toBeUndefined()
  }
})

test('an app with no driver is opened by its bundle id, or by its path', () => {
  expect(openWords({ bundle: 'com.googlecode.iterm2' })).toEqual([
    'open',
    '-b',
    'com.googlecode.iterm2',
  ])
  expect(openWords({ path: '/Applications/Foo.app' })).toEqual([
    'open',
    '-a',
    '/Applications/Foo.app',
  ])
})

test("a window in tmux shows on the clients in a terminal app on its pane's tmux window, in tmux's order; one on another window of its session is selected for nothing", () => {
  expect(seen(placesShowing([IN_TMUX], SCREEN))).toEqual([
    ['/dev/ttys000', 'Ghostty', undefined],
    ['/dev/ttys055', 'Ghostty', undefined],
  ])
})

test("a pane's window no client shows is shown by a select, in each tmux session holding it that a client in a terminal app is attached to, never one only the phone is", () => {
  const screen = screenOf(
    [
      [PANE, WINDOW, '$7'],
      ['%149', '@46', '$7'],
      [PANE, WINDOW, '$8'],
      ['%149', '@46', '$8'],
      ['%54', '@52', '$9'],
    ],
    [
      client('/dev/ttys067', 602, '@46', '$7'),
      client('/dev/ttys000', 503, '@46', '$8'),
      client('/dev/ttys041', 523, '@52', '$9'),
      client('/dev/ttys030', 803, '@46', '$7'),
    ],
  )

  expect(placesShowing([IN_TMUX], screen)).toEqual([
    {
      app: GHOSTTY,
      device: '/dev/ttys000',
      select: { socket: SOCKET, session: '$8', window: WINDOW },
    },
    {
      app: expect.objectContaining({ name: 'Terminal' }),
      device: '/dev/ttys030',
      select: { socket: SOCKET, session: '$7', window: WINDOW },
    },
  ])
})

test('the phone showing the pane does not stop a select for a Ghostty window: only a client a jump can reach counts as showing it', () => {
  const screen = screenOf(
    [
      [PANE, WINDOW, '$7'],
      ['%149', '@46', '$7'],
    ],
    [client('/dev/ttys067', 602, WINDOW, '$7'), client('/dev/ttys000', 503, '@46', '$7')],
  )

  expect(seen(placesShowing([IN_TMUX], screen))).toEqual([['/dev/ttys000', 'Ghostty', '$7']])
})

test('a client whose process the snapshot lacks, or whose ancestry loops, shows nothing', () => {
  const clients = [client('/dev/ttys000', 503, WINDOW), client('/dev/ttys099', 10, WINDOW)]

  expect(placesShowing([IN_TMUX], screenOf([[PANE, WINDOW, SESSION]], clients, new Map()))).toEqual(
    [],
  )
  expect(
    placesShowing(
      [IN_TMUX],
      screenOf(
        [[PANE, WINDOW, SESSION]],
        clients,
        processes([10, 11, 'tmux'], [11, 12, '-zsh'], [12, 11, '/usr/bin/login']),
      ),
    ),
  ).toEqual([])
})

test('a window in tmux shows nowhere when its pane, or its server, is gone', () => {
  const gone: Screen = { ...SCREEN, servers: new Map([[OTHER_SOCKET, undefined]]) }

  expect(placesShowing([{ ...IN_TMUX, tmux: { socket: SOCKET, pane: '%9' } }], SCREEN)).toEqual([])
  expect(placesShowing([{ ...IN_TMUX, tmux: { socket: OTHER_SOCKET, pane: PANE } }], gone)).toEqual(
    [],
  )
  expect(
    placesShowing([{ ...IN_TMUX, tmux: { socket: '/tmp/never-asked', pane: PANE } }], SCREEN),
  ).toEqual([])
})

test('a window outside tmux shows on its own device, in Ghostty or an app its `$TERM_PROGRAM` names, which needs no device; nowhere in another terminal, nor in Ghostty without a device', () => {
  expect(seen(placesShowing([IN_GHOSTTY], SCREEN))).toEqual([
    ['/dev/ttys041', 'Ghostty', undefined],
  ])
  expect(seen(placesShowing([{ ...IN_GHOSTTY, terminal: 'iTerm.app' }], SCREEN))).toEqual([
    ['/dev/ttys041', 'iTerm2', undefined],
  ])
  expect(placesShowing([{ ...IN_GHOSTTY, terminal: 'Unknown' }], SCREEN)).toEqual([])
  expect(placesShowing([{ terminal: 'ghostty' }], SCREEN)).toEqual([])
  expect(seen(placesShowing([{ terminal: 'iTerm.app' }], SCREEN))).toEqual([
    [undefined, 'iTerm2', undefined],
  ])
  expect(
    seen(placesShowing([{ terminal: 'iTerm.app' }, { terminal: 'Apple_Terminal' }], SCREEN)),
    'two apps without a device are two places',
  ).toEqual([
    [undefined, 'iTerm2', undefined],
    [undefined, 'Terminal', undefined],
  ])
})

test("several windows show on each one's devices, the first window's first", () => {
  expect(seen(placesShowing([IN_GHOSTTY, IN_TMUX], SCREEN)).map(([device]) => device)).toEqual([
    '/dev/ttys041',
    '/dev/ttys000',
    '/dev/ttys055',
  ])
})

test('a device showing two windows, two panes of one tmux window, is given once', () => {
  const OTHER_PANE: Where = { ...IN_TMUX, tmux: { socket: SOCKET, pane: '%149' } }
  const screen = screenOf(
    [
      [PANE, WINDOW, SESSION],
      ['%149', WINDOW, SESSION],
    ],
    [client('/dev/ttys000', 503, WINDOW)],
  )

  expect(
    seen(placesShowing([IN_TMUX, OTHER_PANE, IN_GHOSTTY, IN_TMUX], screen)).map(
      ([device]) => device,
    ),
  ).toEqual(['/dev/ttys000', '/dev/ttys041'])
})

test('a jump reaches windows a place shows, the places with it; none where nothing shows them and every program asked of them answered', () => {
  expect(reachOf([IN_TMUX], SCREEN)).toEqual({
    is: 'on screen',
    places: placesShowing([IN_TMUX], SCREEN),
  })
  expect(reachOf([IN_GHOSTTY], SCREEN).is).toBe('on screen')
  expect(reachOf([{ ...IN_TMUX, tmux: { socket: SOCKET, pane: '%9' } }], SCREEN)).toEqual({
    is: 'off screen',
  })
  expect(reachOf([], SCREEN)).toEqual({ is: 'off screen' })
})

test('where nothing shows the windows, tmux giving no answer for a socket one runs under makes it unknown, never off screen; for another socket only, off screen', () => {
  const silent = (...sockets: string[]): Screen => ({
    ...SCREEN,
    servers: new Map([[SOCKET, undefined]]),
    unanswered: ['tmux'],
    unansweredSockets: new Set(sockets),
  })

  expect(reachOf([IN_TMUX], silent(SOCKET))).toEqual({ is: 'unknown', unanswered: ['tmux'] })
  expect(reachOf([IN_TMUX], silent(OTHER_SOCKET))).toEqual({ is: 'off screen' })
  expect(
    reachOf([IN_TMUX], { ...silent(OTHER_SOCKET), servers: SCREEN.servers }).is,
    'a place found stands, whatever else gave no answer',
  ).toBe('on screen')
})

test("where nothing shows the windows, ps giving no answer makes them unknown where a server they run under has clients, whose apps it tells; off screen where it has none", () => {
  const clients = [client('/dev/ttys000', 503, WINDOW)]
  const unsnapped = screenOf([[PANE, WINDOW, SESSION]], clients, new Map())

  expect(reachOf([IN_TMUX], { ...unsnapped, unanswered: ['ps'] })).toEqual({
    is: 'unknown',
    unanswered: ['ps'],
  })
  expect(
    reachOf([IN_TMUX], { ...screenOf([[PANE, WINDOW, SESSION]], []), unanswered: ['ps'] }),
  ).toEqual({ is: 'off screen' })
})

test('a window outside tmux is never unknown: neither tmux nor ps is asked of it', () => {
  const silent: Screen = {
    servers: new Map(),
    apps: new Map(),
    unanswered: ['tmux', 'ps'],
    unansweredSockets: new Set([SOCKET]),
  }

  expect(reachOf([IN_GHOSTTY], silent).is).toBe('on screen')
  expect(reachOf([{ ...IN_GHOSTTY, terminal: 'Unknown' }], silent)).toEqual({ is: 'off screen' })
})

test('the sockets the windows run under are each named once', () => {
  expect(
    socketsOf([IN_TMUX, IN_GHOSTTY, IN_TMUX, { tmux: { socket: OTHER_SOCKET, pane: '%1' } }]),
  ).toEqual([SOCKET, OTHER_SOCKET])
})

/** A window's whereabouts, by its writer: a device of its own. */
const whereOf = (writer: string): Where => ({ device: `/dev/tty${writer}`, terminal: 'ghostty' })

type Window = [writer: string, at: number, state?: WindowState]

/** When the windows below are looked at: a minute on. */
const LOOKED = T0 + MIN

/** A session of these live windows, each attached at its time and in its state, if any. */
const sessionAt = (...windows: Window[]) =>
  fold(
    {
      presence: Object.fromEntries(
        windows.map(([writer, at, state]) => [
          writer,
          presenceText(attach(writer, at, { where: whereOf(writer), state })),
        ]),
      ),
    },
    LOOKED,
  )

/** The windows a session of these live windows is in, by writer, in the order a jump tries them. */
const windowsAt = (...windows: Window[]) =>
  windowsOf(sessionAt(...windows), LOOKED).map(where => where.device?.slice('/dev/tty'.length))

test("a session's windows are its live presences' whereabouts; a window gone, stale or not saying where is left out", () => {
  const now = T0 + MIN
  const session = fold(
    {
      presence: {
        [W1]: presenceText(attach(W1, T0 + 30_000, { where: IN_GHOSTTY })),
        [W2]: presenceText(attach(W2, T0, { where: IN_TMUX })),
        gone: presenceText(leave(attach('gone', T0, { where: IN_GHOSTTY }), T0 + 40_000)),
        stale: presenceText(attach('stale', T0 - 10 * MIN, { where: IN_GHOSTTY })),
        unsaid: presenceText(attach('unsaid', T0 + 50_000)),
      },
    },
    now,
  )

  expect(session.deliverer, 'the deliverer, attached first, is not first').toBe(W2)
  expect(windowsOf(session, now)).toEqual([IN_GHOSTTY, IN_TMUX])
})

test("a session's windows go the one stopped on Lee first, at a permission prompt or a question, then those working, then the rest; within each, the latest state's start, then the latest attach", () => {
  const at = (is: WindowState['is'], since: number): WindowState => ({ is, since })

  expect(
    windowsAt(
      ['a', T0 + 30_000, at('working', T0 + 50_000)],
      ['b', T0, at('permission', T0 + 10_000)],
    ),
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(
      ['a', T0 + 30_000, at('yourTurn', T0 + 50_000)],
      ['b', T0, at('question', T0 + 10_000)],
    ),
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0, at('yourTurn', T0 + 50_000)], ['b', T0, at('working', T0 + 10_000)]),
    'working, however long ago its turn began',
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0, at('working', T0 + 20_000)], ['b', T0, at('working', T0 + 40_000)]),
    'of two working, the turn begun last',
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0, at('yourTurn', T0 + 20_000)], ['b', T0, at('yourTurn', T0 + 40_000)]),
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(
      ['a', T0, at('yourTurn', T0 + 40_000)],
      ['b', T0 + 10_000, at('yourTurn', T0 + 40_000)],
    ),
    'the same start, so the later attach',
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(
      ['a', T0, at('question', T0 + 20_000)],
      ['b', T0, at('permission', T0 + 30_000)],
      ['c', T0, at('working', T0 + 50_000)],
    ),
    'of two stopped on Lee, the later stop',
  ).toEqual(['b', 'a', 'c'])
  expect(
    windowsAt(['a', T0, at('yourTurn', T0 + 20_000)], ['b', T0 + 30_000]),
    "a window saying no state goes by its attach, as a state's start before any turn is, among those on their turn",
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0 + 30_000], ['b', T0, at('working', T0 + 5_000)]),
    'and below one working',
  ).toEqual(['b', 'a'])
})

test("a window on its own work goes below one working and above one on its turn, though that turn ended later: the window the session's row describes", () => {
  const work = { agents: { count: 1, first: 'Review the diff' } }
  const waiting: Window = ['a', T0, { is: 'onItsWork', since: T0 + 10_000, work }]
  const turn: Window = ['b', T0, { is: 'yourTurn', since: T0 + 40_000 }]
  const row = rowOf({ key: 'kit', name: 'Kit' }, sessionAt(waiting, turn), LOOKED)

  expect(row?.lines[0]?.writer).toBe('a')
  expect(windowsAt(waiting, turn)).toEqual(['a', 'b'])
  expect(windowsAt(waiting, ['b', T0, { is: 'working', since: T0 + 5_000 }])).toEqual(['b', 'a'])
})

test("lsappinfo's bundle id line reads as the id; an app gone, or nothing, as none", () => {
  expect(parseBundle('"CFBundleIdentifier"="com.mitchellh.ghostty"\n')).toBe(GHOSTTY_BUNDLE)
  expect(parseBundle('"CFBundleIdentifier"=[ NULL ] \n')).toBeUndefined()
  expect(parseBundle('')).toBeUndefined()
})
