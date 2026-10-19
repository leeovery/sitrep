import { expect, test } from 'claude-code/testing'
import { GHOSTTY_BUNDLE, parseBundle } from '../cli/front'
import { directoryAfter, MARKER_FOLDER, markerOf, parseListing, reportText } from '../cli/ghostty'
import { parseRemembered, rememberedText } from '../cli/remembered'
import {
  devicesShowing,
  ghosttyClients,
  parseClients,
  parsePanes,
  parseProcesses,
  socketsOf,
  windowsOf,
  type Client,
  type Process,
  type Processes,
  type Screen,
} from '../cli/screen'
import { attach, leave, presenceText, type Where } from '../core'
import { fold, MIN, scripted, T0, W1, W2 } from './support'

const SOCKET = '/private/tmp/tmux-501/default'
const OTHER_SOCKET = '/private/tmp/tmux-501/session'
const GHOSTTY_APP = '/Applications/Ghostty.app/Contents/MacOS/ghostty'

/** Claude's pane, and the tmux window holding it. */
const PANE = '%148'
const WINDOW = '@45'

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
 * mosh-server, and a Ghostty on another Mac over ssh.
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
)

/** The screen one server with these panes and clients gives, read against the processes. */
const screenOf = (
  panes: [pane: string, window: string][],
  clients: Client[],
  snapshot: Processes = PROCESSES,
): Screen => {
  const servers = new Map([[SOCKET, { panes: new Map(panes), clients }]])

  return { servers, ghostty: ghosttyClients(servers, snapshot), unanswered: [] }
}

/** Claude's window shown by Ghostty windows, the phone and a Ghostty over ssh; another by a Ghostty window; and one Ghostty window on a window of the same session that is not Claude's. */
const SCREEN = screenOf(
  [
    [PANE, WINDOW],
    ['%54', '@52'],
  ],
  [
    { device: '/dev/ttys067', pid: 602, window: WINDOW },
    { device: '/dev/ttys000', pid: 503, window: WINDOW },
    { device: '/dev/ttys041', pid: 523, window: '@52' },
    { device: '/dev/ttys080', pid: 703, window: WINDOW },
    { device: '/dev/ttys056', pid: 533, window: '@46' },
    { device: '/dev/ttys055', pid: 513, window: WINDOW },
  ],
)

test("tmux's panes read as each pane's tmux window, a pane listed once for each session its window is in", () => {
  expect(parsePanes(`${PANE}\t${WINDOW}\n%54\t@52\n${PANE}\t${WINDOW}\n\n`)).toEqual(
    new Map([
      [PANE, WINDOW],
      ['%54', '@52'],
    ]),
  )
})

test("tmux's clients read as each one's device, process and the tmux window it shows; a line without its fields is skipped", () => {
  expect(
    parseClients(`/dev/ttys000\t503\t${WINDOW}\nnot a client\n/dev/ttys067\t602\t@52\n`),
  ).toEqual([
    { device: '/dev/ttys000', pid: 503, window: WINDOW },
    { device: '/dev/ttys067', pid: 602, window: '@52' },
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

test("the clients descending from Ghostty are found once for the screen: never the phone's, nor a Ghostty's over ssh", () => {
  expect(SCREEN.ghostty).toEqual(new Set([503, 523, 533, 513]))
})

test("a window in tmux shows on the Ghostty clients on its pane's tmux window, in tmux's order; one on another window of the session does not count", () => {
  expect(devicesShowing([IN_TMUX], SCREEN)).toEqual(['/dev/ttys000', '/dev/ttys055'])
})

test("a grouped session's client counts only while it shows the pane's window", () => {
  const grouped = (window: string) =>
    devicesShowing(
      [IN_TMUX],
      screenOf(
        [
          [PANE, WINDOW],
          ['%149', '@46'],
          [PANE, WINDOW],
          ['%149', '@46'],
        ],
        [{ device: '/dev/ttys000', pid: 503, window }],
      ),
    )

  expect(grouped('@46'), 'the other session of the group on another window').toEqual([])
  expect(grouped(WINDOW)).toEqual(['/dev/ttys000'])
})

test('a client whose process the snapshot lacks, or whose ancestry loops, shows nothing', () => {
  const clients = [
    { device: '/dev/ttys000', pid: 503, window: WINDOW },
    { device: '/dev/ttys099', pid: 10, window: WINDOW },
  ]

  expect(devicesShowing([IN_TMUX], screenOf([[PANE, WINDOW]], clients, new Map()))).toEqual([])
  expect(
    devicesShowing(
      [IN_TMUX],
      screenOf(
        [[PANE, WINDOW]],
        clients,
        processes([10, 11, 'tmux'], [11, 12, '-zsh'], [12, 11, '/usr/bin/login']),
      ),
    ),
  ).toEqual([])
})

test('a window in tmux shows nowhere when its pane, or its server, is gone', () => {
  const gone: Screen = { ...SCREEN, servers: new Map([[OTHER_SOCKET, undefined]]) }

  expect(devicesShowing([{ ...IN_TMUX, tmux: { socket: SOCKET, pane: '%9' } }], SCREEN)).toEqual([])
  expect(
    devicesShowing([{ ...IN_TMUX, tmux: { socket: OTHER_SOCKET, pane: PANE } }], gone),
  ).toEqual([])
  expect(
    devicesShowing([{ ...IN_TMUX, tmux: { socket: '/tmp/never-asked', pane: PANE } }], SCREEN),
  ).toEqual([])
})

test('a window outside tmux shows on its own device in Ghostty, and nowhere in another terminal or without a device', () => {
  expect(devicesShowing([IN_GHOSTTY], SCREEN)).toEqual(['/dev/ttys041'])
  expect(devicesShowing([{ ...IN_GHOSTTY, terminal: 'iTerm.app' }], SCREEN)).toEqual([])
  expect(devicesShowing([{ terminal: 'ghostty' }], SCREEN)).toEqual([])
})

test("several windows show on each one's devices, the first window's first", () => {
  expect(devicesShowing([IN_GHOSTTY, IN_TMUX], SCREEN)).toEqual([
    '/dev/ttys041',
    '/dev/ttys000',
    '/dev/ttys055',
  ])
})

test('a device showing two windows, two panes of one tmux window, is given once', () => {
  const OTHER_PANE: Where = { ...IN_TMUX, tmux: { socket: SOCKET, pane: '%149' } }
  const screen = screenOf(
    [
      [PANE, WINDOW],
      ['%149', WINDOW],
    ],
    [{ device: '/dev/ttys000', pid: 503, window: WINDOW }],
  )

  expect(devicesShowing([IN_TMUX, OTHER_PANE, IN_GHOSTTY, IN_TMUX], screen)).toEqual([
    '/dev/ttys000',
    '/dev/ttys041',
  ])
})

test('the sockets the windows run under are each named once', () => {
  expect(
    socketsOf([IN_TMUX, IN_GHOSTTY, IN_TMUX, { tmux: { socket: OTHER_SOCKET, pane: '%1' } }]),
  ).toEqual([SOCKET, OTHER_SOCKET])
})

test("a session's windows are its live presences' whereabouts, the deliverer's first; a window gone, stale or not saying where is left out", () => {
  const now = T0 + MIN
  const session = fold(
    {
      presence: {
        [W1]: presenceText(attach(W1, T0 + 30_000, IN_GHOSTTY)),
        [W2]: presenceText(attach(W2, T0, IN_TMUX)),
        gone: presenceText(leave(attach('gone', T0, IN_GHOSTTY), T0 + 40_000)),
        stale: presenceText(attach('stale', T0 - 10 * MIN, IN_GHOSTTY)),
        unsaid: presenceText(attach('unsaid', T0 + 50_000)),
      },
    },
    now,
  )

  expect(session.deliverer).toBe(W2)
  expect(windowsOf(session, now)).toEqual([IN_TMUX, IN_GHOSTTY])
})

test('a report names its path at localhost, every character but / percent-encoded', () => {
  expect(reportText('/Users/lee/Code/kit')).toBe('\x1b]7;file://localhost/Users/lee/Code/kit\x07')
  expect(reportText('/tmp/a b%20é')).toBe('\x1b]7;file://localhost/tmp/a%20b%2520%C3%A9\x07')
})

test("a marker is a fresh path in the markers' folder, its random bytes in hex", () => {
  expect(MARKER_FOLDER).toBe('/sitrep-knock')
  expect(markerOf(scripted([0, 15, 16, 255]))).toBe('/sitrep-knock/000f10ff000f10ff')
})

test('a terminal goes back to the directory it reported, or home for none, or for a marker another knock left', () => {
  expect(directoryAfter('/Users/lee/Code/a b', '/Users/lee')).toBe('/Users/lee/Code/a b')
  expect(directoryAfter('', '/Users/lee')).toBe('/Users/lee')
  expect(directoryAfter(undefined, '/Users/lee')).toBe('/Users/lee')
  expect(directoryAfter('/sitrep-knock/0102030401020304', '/Users/lee')).toBe('/Users/lee')
  expect(directoryAfter('/sitrep-knockout', '/Users/lee')).toBe('/sitrep-knockout')
})

test("Ghostty's listing reads as its terminals, one reporting no directory kept though its line is the last", () => {
  expect(parseListing('31C806B1\tA1C829FD\n31C806B1\t/Users/lee/Code/a b\nA1C829FD\t\n')).toEqual([
    { id: '31C806B1', directory: '/Users/lee/Code/a b' },
    { id: 'A1C829FD', directory: '' },
  ])
  expect(parseListing('\n\n'), 'no terminals, or Ghostty not running').toEqual([])
})

test("a listing whose ids read last differ from its pairs' is no listing: a terminal opened or closed as it read", () => {
  expect(parseListing('31C806B1\tNEW\n31C806B1\t/Users/lee\nA1C829FD\t/tmp\n')).toBeUndefined()
  expect(parseListing('31C806B1\tA1C829FD\n\n'), 'the counts differed, so no pairs').toBeUndefined()
})

test("each device's remembered terminal reads from its file, the last line for a device winning", () => {
  const text = [
    rememberedText('/dev/ttys000', 'OLD-TERMINAL'),
    rememberedText('/dev/ttys041', 'KIT-TERMINAL'),
    rememberedText('/dev/ttys000', 'NEW-TERMINAL'),
  ].join('')

  expect(parseRemembered(text)).toEqual(
    new Map([
      ['/dev/ttys000', 'NEW-TERMINAL'],
      ['/dev/ttys041', 'KIT-TERMINAL'],
    ]),
  )
  expect(rememberedText('/dev/ttys000', 'NEW-TERMINAL')).toBe(
    '{"device":"/dev/ttys000","terminal":"NEW-TERMINAL"}\n',
  )
})

test('a remembered line torn, broken or not a pair is skipped, and the lines around it stand', () => {
  const text = [
    'not json\n',
    '[1,2]\n',
    '"/dev/ttys000"\n',
    rememberedText('/dev/ttys000', 'GOOD-TERMINAL'),
    '{"device":"/dev/ttys000"}\n',
    '{"device":"/dev/ttys000","terminal":""}\n',
    '{"device":"/dev/ttys000","terminal":7}\n',
    '{"device":"","terminal":"NO-DEVICE"}\n',
    rememberedText('/dev/ttys041', 'KIT-TERMINAL'),
    '{"device":"/dev/ttys000","termi',
  ].join('')

  expect(parseRemembered(text)).toEqual(
    new Map([
      ['/dev/ttys000', 'GOOD-TERMINAL'],
      ['/dev/ttys041', 'KIT-TERMINAL'],
    ]),
  )
  expect(parseRemembered('')).toEqual(new Map())
})

test("lsappinfo's bundle id line reads as the id; an app gone, or nothing, as none", () => {
  expect(parseBundle('"CFBundleIdentifier"="com.mitchellh.ghostty"\n')).toBe(GHOSTTY_BUNDLE)
  expect(parseBundle('"CFBundleIdentifier"=[ NULL ] \n')).toBeUndefined()
  expect(parseBundle('')).toBeUndefined()
})
