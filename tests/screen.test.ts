import { expect, test } from 'claude-code/testing'
import { appOfCommand, appOfProgram, DRIVERS, openWords, programOf } from '../cli/apps'
import { GHOSTTY_BUNDLE, parseBundle } from '../cli/front'
import { GHOSTTY } from '../cli/ghostty'
import type { Place } from '../cli/multiplexer'
import {
  deviceOfNumbers,
  parseProcesses,
  seatOf,
  type Process,
  type Processes,
} from '../cli/processes'
import { placesShowing, reachOf, type Screen } from '../cli/screen'
import {
  parseClients,
  parsePanes,
  selectWords,
  socketsOf,
  tmuxReading,
  type Client,
  type Servers,
} from '../cli/tmux'
import { ZMX } from '../cli/zmx'
import type { Where } from '../core'

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

/** Every process, by id: `[id, parent, command line, device]`, on none unless given. */
const processes = (...each: [pid: number, parent: number, args: string, device?: string][]) =>
  new Map(
    each.map(([pid, parent, args, device]): [number, Process] => [
      pid,
      { parent, args, ...(device === undefined ? {} : { device }) },
    ]),
  )

/**
 * Four Ghostty windows (`tmux < zsh < login < ghostty`), the phone through
 * mosh-server, a Ghostty on another Mac over ssh, a Terminal window, and VS
 * Code's terminal, whose shell runs under a helper app inside VS Code's.
 * Each app's own child, and those under it, are on its window's device.
 */
const PROCESSES = processes(
  [1, 0, '/sbin/launchd'],
  [500, 1, GHOSTTY_APP],
  [501, 500, '/usr/bin/login', '/dev/ttys000'],
  [502, 501, '-zsh', '/dev/ttys000'],
  [503, 502, 'tmux', '/dev/ttys000'],
  [511, 500, '/usr/bin/login', '/dev/ttys055'],
  [512, 511, '-zsh', '/dev/ttys055'],
  [513, 512, 'tmux', '/dev/ttys055'],
  [521, 500, '/usr/bin/login', '/dev/ttys041'],
  [522, 521, '-zsh', '/dev/ttys041'],
  [523, 522, 'tmux', '/dev/ttys041'],
  [531, 500, '/usr/bin/login', '/dev/ttys056'],
  [532, 531, '-zsh', '/dev/ttys056'],
  [533, 532, 'tmux', '/dev/ttys056'],
  [600, 1, '/opt/homebrew/bin/mosh-server'],
  [601, 600, '-zsh', '/dev/ttys067'],
  [602, 601, 'tmux', '/dev/ttys067'],
  [700, 1, '/usr/sbin/sshd'],
  [701, 700, '/usr/libexec/sshd-session', '/dev/ttys080'],
  [702, 701, '-zsh', '/dev/ttys080'],
  [703, 702, 'tmux', '/dev/ttys080'],
  [800, 1, TERMINAL_APP],
  [801, 800, '/usr/bin/login', '/dev/ttys030'],
  [802, 801, '-zsh', '/dev/ttys030'],
  [803, 802, 'tmux', '/dev/ttys030'],
  [900, 1, '/Applications/Visual Studio Code.app/Contents/MacOS/Electron'],
  [
    901,
    900,
    '/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper',
  ],
  [902, 901, '-zsh', '/dev/ttys090'],
  [903, 902, 'tmux', '/dev/ttys090'],
)

/** A client on a device, its process, showing a window of the tmux session given, else of the one named for the window. */
const client = (device: string, pid: number, window: string, session = `$${window.slice(1)}`) => ({
  device,
  pid,
  window,
  session,
})

/** A pane in tmux's words: its tmux window, its tmux session, and its device, none unless given. */
type PaneLine = [pane: string, window: string, session: string, device?: string]

/** One server on the socket, with these panes and these clients. */
const serverOf = (panes: PaneLine[], clients: Client[]): Servers =>
  new Map([
    [
      SOCKET,
      {
        panes: parsePanes(
          panes.map(([pane, window, session, device = '']) =>
            [pane, window, session, device].join('\t'),
          ).join('\n'),
        ),
        clients,
      },
    ],
  ])

/** The screen tmux's servers give, read against the processes, and the sockets tmux gave no answer for. */
const screenWith = (
  servers: Servers,
  snapshot: Processes = PROCESSES,
  unansweredSockets: ReadonlySet<string> = new Set(),
): Screen => ({
  readings: [tmuxReading(servers, unansweredSockets)],
  processes: snapshot,
  unanswered: [],
})

/** The screen one server with these panes and these clients gives, read against the processes. */
const screenOf = (
  panes: PaneLine[],
  clients: Client[],
  snapshot: Processes = PROCESSES,
): Screen => screenWith(serverOf(panes, clients), snapshot)

/**
 * Claude's window shown by Ghostty windows, the phone and a Ghostty over
 * ssh; another of its tmux session by a Ghostty window; and a window of
 * another session by a Ghostty window.
 */
const SERVERS = serverOf(
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

const SCREEN = screenWith(SERVERS)

/** Each place as its device, its app's name, and the tmux session a select makes the pane's window current in, if any. */
const seen = (places: readonly Place[]) =>
  places.map(place => [place.device, place.app.name, place.select?.session])

test("tmux's panes read as each pane's tmux window, the tmux sessions it is in, a pane listed once for each, and its device", () => {
  expect(
    parsePanes(
      [
        `${PANE}\t${WINDOW}\t$7\t/dev/ttys043`,
        '%54\t@52\t$9\t/dev/ttys044',
        `${PANE}\t${WINDOW}\t$8\t/dev/ttys043`,
        `${PANE}\t${WINDOW}\t$7\t/dev/ttys043`,
        '%55\t@53\t$9',
        '',
      ].join('\n'),
    ),
  ).toEqual(
    new Map([
      [PANE, { window: WINDOW, sessions: ['$7', '$8'], device: '/dev/ttys043' }],
      ['%54', { window: '@52', sessions: ['$9'], device: '/dev/ttys044' }],
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

test("ps's snapshot reads as each process's parent, its device by its numbers, none for `??`, and its command line, spaces kept", () => {
  expect(
    parseProcesses(
      [
        '    1     0    ?? /sbin/launchd',
        ' 4168     1    ?? /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --flag',
        '11796 11681 16/32 /opt/homebrew/bin/zmx attach kit · restore-card',
        '  700     1  16/7 /bin/zsh',
        '  800     1   3/2 /bin/cat',
        'not a process',
        '   12     1    ?? ',
        '',
      ].join('\n'),
    ),
  ).toEqual(
    processes(
      [1, 0, '/sbin/launchd'],
      [4168, 1, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --flag'],
      [11796, 11681, '/opt/homebrew/bin/zmx attach kit · restore-card', '/dev/ttys032'],
      [700, 1, '/bin/zsh', '/dev/ttys007'],
      [800, 1, '/bin/cat'],
    ),
  )
})

test("a terminal's numbers name a pty, major 16, as /dev/ttys and its minor to three places; anything else names none", () => {
  expect(deviceOfNumbers('16/32')).toBe('/dev/ttys032')
  expect(deviceOfNumbers('16/7')).toBe('/dev/ttys007')
  expect(deviceOfNumbers('16/1024')).toBe('/dev/ttys1024')

  for (const tdev of ['??', '3/2', '16/', '16/x', '116/32', '']) {
    expect(deviceOfNumbers(tdev), tdev).toBeUndefined()
  }
})

test("a command line's program is its first word, up to the first argument that is an option or a path, its own path's spaces and lone dashes kept", () => {
  const INSIDERS =
    '/Applications/Visual Studio Code - Insiders.app/Contents/Frameworks/Code - Insiders Helper (Plugin).app/Contents/MacOS/Code - Insiders Helper (Plugin)'

  expect(programOf(GHOSTTY_APP)).toBe(GHOSTTY_APP)
  expect(programOf('/usr/bin/login -flp lee /bin/bash --noprofile')).toBe('/usr/bin/login')
  expect(programOf('-/bin/zsh')).toBe('-/bin/zsh')
  expect(
    programOf(
      '/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin) --type=utility',
    ),
  ).toBe(
    '/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)',
  )
  expect(programOf(`${INSIDERS} --type=utility`)).toBe(INSIDERS)
  expect(
    programOf('/Users/lee/Library/Application Support/iTerm2/iTermServer-3.5.4 /Users/lee/s.socket'),
  ).toBe('/Users/lee/Library/Application Support/iTerm2/iTermServer-3.5.4')
})

test("the app a command line runs is told by its program: a driver's though a plain word follows it, an app by its outermost bundle though its name holds a dash, and none for an app only its arguments name", () => {
  expect(appOfCommand(`${GHOSTTY_APP} launchd`)).toBe(GHOSTTY)
  expect(appOfCommand(`${GHOSTTY_APP} --config-default-files=false`)).toBe(GHOSTTY)
  expect(
    appOfCommand(
      '/Applications/Visual Studio Code - Insiders.app/Contents/Frameworks/Code - Insiders Helper (Plugin).app/Contents/MacOS/Code - Insiders Helper (Plugin) --type=utility',
    )?.name,
  ).toBe('Visual Studio Code - Insiders')
  expect(
    appOfCommand('/Users/lee/Library/Application Support/iTerm2/iTermServer-3.5.4 /Users/lee/s.socket')
      ?.name,
  ).toBe('iTerm2')

  for (const args of [
    '/bin/zsh -c open /Applications/Foo.app/Contents/MacOS/foo',
    '/usr/bin/foo --path=/Applications/Foo.app/Contents/MacOS/foo',
    '/usr/bin/login -flp lee /bin/bash --noprofile --norc -c exec -l /bin/zsh',
  ]) {
    expect(appOfCommand(args), args).toBeUndefined()
  }
})

test("each client's terminal app is the nearest app it descends from: Ghostty's driver for Ghostty's, an app by its outermost bundle for another's, and none for the phone's or a Ghostty's over ssh", () => {
  const apps = Object.fromEntries(
    [503, 513, 523, 533, 602, 703, 803, 903].map(pid => [
      pid,
      seatOf(PROCESSES, pid, `/dev/ttys${pid}`)?.app.name,
    ]),
  )

  expect(apps).toEqual({
    503: 'Ghostty',
    513: 'Ghostty',
    523: 'Ghostty',
    533: 'Ghostty',
    602: undefined,
    703: undefined,
    803: 'Terminal',
    903: 'Visual Studio Code',
  })
  expect(seatOf(PROCESSES, 503, '/dev/ttys503')?.app).toBe(GHOSTTY)
})

test("a client's device is the tty of its terminal app's own child, through any relaying pty; that child on none, the client's own; the client on none of its own, none", () => {
  const inGhostty = (...above: [pid: number, parent: number, args: string, device?: string][]) =>
    processes([1, 0, '/sbin/launchd'], [500, 1, GHOSTTY_APP], ...above)
  const direct = inGhostty(
    [501, 500, '/usr/bin/login', '/dev/ttys036'],
    [502, 501, '-zsh', '/dev/ttys036'],
    [600, 502, 'tmux', '/dev/ttys036'],
  )
  const relayed = inGhostty(
    [501, 500, '/usr/bin/login', '/dev/ttys036'],
    [502, 501, '-zsh', '/dev/ttys036'],
    [503, 502, 'portal open /sit', '/dev/ttys036'],
    [600, 503, '/opt/homebrew/bin/zmx attach kit', '/dev/ttys032'],
  )
  const unseated = inGhostty(
    [501, 500, '/usr/bin/login'],
    [502, 501, '-zsh'],
    [600, 502, 'tmux', '/dev/ttys040'],
  )

  expect(seatOf(direct, 600, '/dev/ttys036')).toEqual({ app: GHOSTTY, device: '/dev/ttys036' })
  expect(seatOf(relayed, 600, '/dev/ttys032')).toEqual({ app: GHOSTTY, device: '/dev/ttys036' })
  expect(seatOf(unseated, 600, '/dev/ttys040'), "the app's child on no tty").toEqual({
    app: GHOSTTY,
    device: '/dev/ttys040',
  })
  expect(seatOf(relayed, 600, ''), 'a control-mode client, on no tty').toBeUndefined()
  expect(seatOf(relayed, 999, '/dev/ttys032'), 'a client the snapshot lacks').toBeUndefined()
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
  const gone = screenWith(new Map([[OTHER_SOCKET, undefined]]))

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
  const silent = (...sockets: string[]) =>
    screenWith(new Map([[SOCKET, undefined]]), PROCESSES, new Set(sockets))

  expect(reachOf([IN_TMUX], silent(SOCKET))).toEqual({ is: 'unknown', unanswered: ['tmux'] })
  expect(reachOf([IN_TMUX], silent(OTHER_SOCKET))).toEqual({ is: 'off screen' })
  expect(
    reachOf([IN_TMUX], screenWith(SERVERS, PROCESSES, new Set([OTHER_SOCKET]))).is,
    'a place found stands, whatever else gave no answer',
  ).toBe('on screen')
})

test("where nothing shows the windows, ps giving no answer makes them unknown where a server they run under has clients, whose apps it tells; off screen where it has none", () => {
  const clients = [client('/dev/ttys000', 503, WINDOW)]

  const unsnapped = (each: Client[]): Screen => ({
    ...screenOf([[PANE, WINDOW, SESSION]], each),
    processes: undefined,
  })

  expect(reachOf([IN_TMUX], unsnapped(clients))).toEqual({ is: 'unknown', unanswered: ['ps'] })
  expect(reachOf([IN_TMUX], unsnapped([]))).toEqual({ is: 'off screen' })
})

test('a window outside tmux is never unknown: neither tmux nor ps is asked of it', () => {
  const silent: Screen = {
    ...screenWith(new Map(), PROCESSES, new Set([SOCKET])),
    processes: undefined,
  }

  expect(reachOf([IN_GHOSTTY], silent).is).toBe('on screen')
  expect(reachOf([{ ...IN_GHOSTTY, terminal: 'Unknown' }], silent)).toEqual({ is: 'off screen' })
})

test('the sockets the windows run under are each named once', () => {
  expect(
    socketsOf([IN_TMUX, IN_GHOSTTY, IN_TMUX, { tmux: { socket: OTHER_SOCKET, pane: '%1' } }]),
  ).toEqual([SOCKET, OTHER_SOCKET])
})

test("lsappinfo's bundle id line reads as the id; an app gone, or nothing, as none", () => {
  expect(parseBundle('"CFBundleIdentifier"="com.mitchellh.ghostty"\n')).toBe(GHOSTTY_BUNDLE)
  expect(parseBundle('"CFBundleIdentifier"=[ NULL ] \n')).toBeUndefined()
  expect(parseBundle('')).toBeUndefined()
})

/** The zmx session `kit`'s clients beside the fixture's: one in a Ghostty window, and one over pipes in a Terminal window's shell, on no tty of its own. */
const WITH_ZMX: Processes = new Map([
  ...PROCESSES,
  ...processes(
    [541, 500, '/usr/bin/login', '/dev/ttys060'],
    [542, 541, '-zsh', '/dev/ttys060'],
    [543, 542, '/opt/homebrew/bin/zmx attach kit', '/dev/ttys060'],
    [804, 802, 'zmx attach kit'],
  ),
])

/** The screen tmux's server and zmx give, read against the processes with zmx's clients. */
const nestedScreen = async (paneDevice: string): Promise<Screen> => ({
  readings: [
    tmuxReading(
      serverOf([[PANE, WINDOW, SESSION, paneDevice]], [client('/dev/ttys000', 503, WINDOW)]),
      new Set(),
    ),
    await ZMX.read(undefined as never, []),
  ],
  processes: WITH_ZMX,
  unanswered: [],
})

test('a zmx client counts only on a tty of its own: one over pipes is no place, though its app needs no device', async () => {
  const screen = await nestedScreen('')

  expect(seen(placesShowing([{ terminal: 'ghostty', zmx: { session: 'kit' } }], screen))).toEqual([
    ['/dev/ttys060', 'Ghostty', undefined],
  ])
})

test('a window recording tmux and zmx, one run inside the other, is in the innermost: tmux where its pane is on the window’s device, else zmx; both, tmux first, where tmux cannot tell', async () => {
  const nested = (device: string): Where => ({
    device,
    terminal: 'tmux',
    tmux: { socket: SOCKET, pane: PANE },
    zmx: { session: 'kit' },
  })
  const tmuxInZmx = await nestedScreen('/dev/ttys043')

  expect(seen(placesShowing([nested('/dev/ttys043')], tmuxInZmx)), 'tmux inside zmx').toEqual([
    ['/dev/ttys000', 'Ghostty', undefined],
  ])
  expect(seen(placesShowing([nested('/dev/ttys087')], tmuxInZmx)), 'zmx inside tmux').toEqual([
    ['/dev/ttys060', 'Ghostty', undefined],
  ])
  expect(
    seen(placesShowing([nested('/dev/ttys087')], await nestedScreen(''))),
    'the pane saying no device',
  ).toEqual([
    ['/dev/ttys000', 'Ghostty', undefined],
    ['/dev/ttys060', 'Ghostty', undefined],
  ])
})
