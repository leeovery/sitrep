import { drained, expect, test } from './kit'
import type { Env, Io, Ran } from '../cli/io'
import { DEFAULT_COMMAND } from '../cli/panel/command'
import { claudeIn, claudeOn, commandIn, DEFAULTS, handed, PS_MS, QUICK_MS, readied, savedCommand } from '../cli/panel/edge'
import { dataIn } from '../cli/panel/plist'
import type { Resume } from '../cli/panel/reach'
import { HOME, T0, W1 } from './data'
import { defaultsOf, plistOf } from './plist'
import { ENV, terminal, tty } from './terminal'

/**
 * The CLI's one edge to programs: SitRep's saved resume command read from
 * its defaults, `ps` asked what runs on a device, and the line handed to
 * the login shell.
 */
const NAME = 'Invoice ledger'

const FOLDER = `${HOME}/Code/litware`

const SETTINGS = `${HOME}/${DEFAULTS}`

/**
 * SitRep's defaults as macOS's own encoder writes them (plutil), keys in
 * ASCII and one, `café`, in UTF-16: `app` holds its settings, the resume
 * command `attach {tty} {dir} {claude}` among them.
 */
const APPLE =
  'YnBsaXN0MDDVAQIDBAUGBwgJClNhcHBccGx1Z2luRm9sZGVyVGNhcmRZcGFuZWxTaG93ZABjAGEAZgDpTxB3eyJub3RpZmllc05ld0Fza3MiOmZhbHNlLCJwbGF5c1NvdW5kIjp0cnVlLCJzb3VuZCI6IkdsYXNzIiwidGVybWluYWwiOiJnaG9zdHR5IiwicmVzdW1lIjoiYXR0YWNoIHt0dHl9IHtkaXJ9IHtjbGF1ZGV9In1fECwvVXNlcnMvbWUvTGlicmFyeS9BcHBsaWNhdGlvbiBTdXBwb3J0L3NpdHJlcEd7IngiOjF9VXN0cmlwQnt9CBMXJCkzPLbl7fMAAAAAAAABAQAAAAAAAAALAAAAAAAAAAAAAAAAAAAA9g=='

const bytesOf = (base64: string) => Uint8Array.from(atob(base64), character => character.charCodeAt(0))

const textOf = (bytes: Uint8Array | undefined) => (bytes === undefined ? undefined : new TextDecoder().decode(bytes))

test("a binary property list as macOS writes it gives the data under a key of its top dictionary, a long one and one keyed in UTF-16 among them", () => {
  const apple = bytesOf(APPLE)

  expect(JSON.parse(textOf(dataIn(apple, 'app')) ?? '')).toEqual({
    notifiesNewAsks: false,
    playsSound: true,
    sound: 'Glass',
    terminal: 'ghostty',
    resume: 'attach {tty} {dir} {claude}',
  })
  expect(textOf(dataIn(apple, 'café'))).toBe('{}')
  expect(textOf(dataIn(apple, 'card'))).toBe('{"x":1}')
})

/** A list of the objects given, its top object the first, its offsets' table where given, each offset and reference a byte unless said, and the trailer's six spare bytes as given. */
const listOf = (objects: readonly number[], table: number, { spare = [], sizes = [1, 1] }: { spare?: readonly number[]; sizes?: readonly number[] } = {}) => {
  const trailer = new Uint8Array(32)
  const view = new DataView(trailer.buffer)

  trailer.set(spare)
  trailer.set(sizes, 6)
  view.setBigUint64(8, 1n)
  view.setBigUint64(24, BigInt(table))

  return Uint8Array.from([...new TextEncoder().encode('bplist00'), ...objects, ...trailer])
}

/** A dictionary at byte 8 claiming 2³¹ − 1 entries in an integer after its marker, the offsets' table a byte after it. */
const CLAIMING_OBJECTS = [0xdf, 0x13, 0, 0, 0, 0, 0x7f, 0xff, 0xff, 0xff, 8]

const CLAIMING = listOf(CLAIMING_OBJECTS, 18)

/**
 * A dictionary claiming ten entries, holding one: its key `app`, and the
 * data `x` as its value, whose reference is read past the references there
 * are, from the trailer's first spare byte.
 */
const PAST_TRAILER = listOf([0xda, 1, 0x53, 0x61, 0x70, 0x70, 0x41, 0x78, 8, 10, 14], 16, { spare: [2] })

test('a list claiming more than it holds is read no further, at once: the length of a dictionary is held to the bytes before the trailer', () => {
  expect(dataIn(CLAIMING, 'app')).toBeUndefined()
  expect(dataIn(PAST_TRAILER, 'app')).toBeUndefined()
})

/** A dictionary at byte 8 holding the key `app` and the data `x`, its length of 1 in an integer of `size` bytes after its marker. */
const lengthIn = (size: number) => {
  const dictionary = [0xdf, 0x10 | Math.log2(size), ...Array<number>(size - 1).fill(0), 1, 1, 2]
  const key = 8 + dictionary.length

  return listOf([...dictionary, 0x53, 0x61, 0x70, 0x70, 0x41, 0x78, 8, key, key + 4], key + 6)
}

test('a length comes in an integer of 8 bytes at most: a list claiming one of 16 holds nothing', () => {
  expect(textOf(dataIn(lengthIn(8), 'app'))).toBe('x')
  expect(dataIn(lengthIn(16), 'app')).toBeUndefined()
})

test('a list whose offsets or references take no bytes, or whose top object is no dictionary, holds nothing: one claiming 2³¹ − 1 references of no bytes each is not looked through', () => {
  const apple = bytesOf(APPLE)
  const sized = (at: number) => Uint8Array.from(apple, (byte, index) => (index === apple.length - 32 + at ? 0 : byte))

  expect([dataIn(sized(6), 'app'), dataIn(sized(7), 'app')]).toEqual([undefined, undefined])
  expect(dataIn(listOf(CLAIMING_OBJECTS, 18, { sizes: [1, 0] }), 'app')).toBeUndefined()
  expect(dataIn(listOf([0x5f, 0x10, 0x7f, 8], 11), 'app')).toBeUndefined()
  expect(dataIn(listOf([0x43, 0x61, 0x70, 0x70, 8], 12), 'app')).toBeUndefined()
})

test('a key not there, or holding no data, gives nothing; so do bytes that are no list, and a list cut short', () => {
  const apple = bytesOf(APPLE)

  expect([dataIn(apple, 'resume'), dataIn(apple, 'panelShow')]).toEqual([undefined, undefined])
  expect(dataIn(new TextEncoder().encode('{"app":{}}'), 'app')).toBeUndefined()
  expect(dataIn(apple.slice(0, 120), 'app')).toBeUndefined()
  expect(dataIn(apple.slice(0, 40), 'app')).toBeUndefined()
  expect(dataIn(new Uint8Array(), 'app')).toBeUndefined()
})

test("SitRep's resume command is its `resume` under `app`, empty where cleared; else the one saved before it had its own key, where it holds one", () => {
  expect(commandIn(bytesOf(APPLE))).toBe('attach {tty} {dir} {claude}')
  expect(commandIn(defaultsOf({ app: { resume: '', resumeCommand: 'old {claude}' } }))).toBe('')
  expect(commandIn(defaultsOf({ app: { resumeCommand: 'old {claude}' } }))).toBe('old {claude}')
  expect(commandIn(defaultsOf({ app: { resume: 7, resumeCommand: 'old {claude}' } }))).toBe('old {claude}')
})

test('defaults with no resume command saved, or none SitRep could read, hold none', () => {
  expect(commandIn(defaultsOf({ app: { resumeCommand: '' } }))).toBeUndefined()
  expect(commandIn(defaultsOf({ app: { sound: 'Glass' } }))).toBeUndefined()
  expect(commandIn(defaultsOf({ edge: { resume: 'edge {claude}' } }))).toBeUndefined()
  expect(commandIn(defaultsOf({ app: ['resume'] }))).toBeUndefined()
  expect(commandIn(plistOf({ app: new TextEncoder().encode('{"resume": ') }))).toBeUndefined()
  expect(commandIn(plistOf({ app: 'resume' }))).toBeUndefined()
})

test("the command is read from SitRep's defaults in the home folder; the default where none is saved, none is there, or no home is set", async () => {
  const saved = terminal()
  const none = terminal()
  const homeless = terminal({ env: { XDG_STATE_HOME: ENV.XDG_STATE_HOME } })

  saved.files.set(SETTINGS, { text: '', bytes: defaultsOf({ app: { resume: 'carry {claude}' } }), mtimeMs: T0 })
  homeless.files.set(SETTINGS, { text: '', bytes: defaultsOf({ app: { resume: 'carry {claude}' } }), mtimeMs: T0 })

  expect(DEFAULTS).toMatch(/^Library\/Preferences\/com\.[a-z]+\.sitrep\.plist$/)
  expect(await Promise.all([saved, none, homeless].map(each => savedCommand(each.io)))).toEqual(['carry {claude}', DEFAULT_COMMAND, DEFAULT_COMMAND])
})

test("a Claude Code on a device is told by its program, `claude` or a version in a `claude/versions` folder, stopped where its state starts T", () => {
  expect(claudeIn('Ss   -zsh\nS+   claude\n')).toBe('running')
  expect(claudeIn('S+   /Users/me/.local/share/claude/versions/2.1.322\n')).toBe('running')
  expect(claudeIn('S    /opt/homebrew/bin/claude\nT+   claude\n')).toBe('stopped')
  expect(claudeIn('T    -zsh\nS+   node\nS    /Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper\nS+   claude-helper\n')).toBe('none')
  expect(claudeIn('')).toBe('none')
})

const DEVICE = '/dev/ttys041'

/** The memory world with a terminal whose `ps` answers as given, and the device there unless said. */
const psSaying = (ran: (argv: readonly string[]) => Promise<Ran>, { isThere = true }: { isThere?: boolean } = {}) => {
  const screen = tty({ ran })
  const t = terminal({ terminal: screen.terminal })

  if (isThere) {
    t.files.set(DEVICE, { text: '', mtimeMs: T0 })
  }

  return { on: (device: string | undefined) => claudeOn(t.io, screen.terminal, device), runs: screen.runs }
}

test("`ps` is the system's, asked of the device alone, within its time; it exits 1 with nothing to say for a device no process is on", async () => {
  const listing = psSaying(async () => ({ exit: 0, out: 'S+   claude\n', err: '' }))
  const empty = psSaying(async () => ({ exit: 1, out: '', err: '' }))

  expect(await listing.on(DEVICE)).toBe('running')
  expect(listing.runs()).toEqual([{ argv: ['/bin/ps', '-t', DEVICE, '-o', 'stat=,comm='], ms: PS_MS }])
  expect(await empty.on(DEVICE)).toBe('none')
})

test('a device gone runs nothing, and `ps` is not asked; neither is it for no device, nor for one no terminal has, which is no answer', async () => {
  const gone = psSaying(async () => ({ exit: 0, out: 'S+   claude\n', err: '' }), { isThere: false })
  const asked = psSaying(async () => ({ exit: 0, out: 'S+   claude\n', err: '' }))

  expect(await gone.on(DEVICE)).toBe('none')
  expect(await asked.on(undefined)).toBe('none')
  expect(await Promise.all(['/dev/disk0', '/dev/ttys041 -o pid', '-A', '/dev/../dev/ttys041', '/dev/TTYS041'].map(asked.on))).toEqual(Array(5).fill('unknown'))
  expect([gone.runs(), asked.runs()]).toEqual([[], []])
})

test('`ps` failing otherwise, saying why as it ends 1, not starting, or not answering in time, is no answer', async () => {
  const failing = [
    async () => ({ exit: 2, out: '', err: 'ps: illegal option' }),
    async () => ({ exit: 1, out: '', err: 'ps: /dev/ttys041: No such file or directory\n' }),
    async () => ({ exit: 1, out: 'S+   claude\n', err: '' }),
    async () => {
      throw new Error('/bin/ps gave no answer within 2000 ms')
    },
  ].map(ran => psSaying(ran))

  expect(await Promise.all(failing.map(each => each.on(DEVICE)))).toEqual(Array(4).fill('unknown'))
})

const AWAY: Resume = { name: NAME, claude: W1, dir: FOLDER, device: '/dev/ttys041', isHeld: false, ownsDevice: true }

/** The memory world with SitRep's defaults saving `command`, where given, its environment, the login shell zsh unless given, the device there, and a terminal whose `ps` answers as given. */
const world = ({ command, env = { ...ENV, SHELL: '/bin/zsh' }, ps = { exit: 1, out: '', err: '' } }: { command?: string; env?: Env; ps?: Ran } = {}) => {
  const screen = tty({ ran: async () => ps })
  const t = terminal({ env, terminal: screen.terminal })

  t.files.set(DEVICE, { text: '', mtimeMs: T0 })

  if (command !== undefined) {
    t.files.set(SETTINGS, { text: '', bytes: defaultsOf({ app: { resume: command } }), mtimeMs: T0 })
  }

  return { t, screen }
}

test('a pick readied hands the filled line to the login shell, `$SHELL -l -c <line>`, the saved command filled', async () => {
  const byDefault = world()
  const own = world({ command: 'attach {tty} {dir} {claude}', ps: { exit: 0, out: 'S+   claude\n', err: '' } })

  expect(await readied(byDefault.t.io, byDefault.screen.terminal, AWAY)).toEqual({
    ok: true,
    value: ['/bin/zsh', '-l', '-c', `cd '${FOLDER}' && claude --resume '${W1}'`],
  })
  expect(await readied(own.t.io, own.screen.terminal, AWAY)).toEqual({
    ok: true,
    value: ['/bin/zsh', '-l', '-c', `attach '/dev/ttys041' '${FOLDER}' '${W1}'`],
  })
})

test('a pick refused is readied as its words, with nothing handed', async () => {
  const running = world({ ps: { exit: 0, out: 'S+   claude\n', err: '' } })

  expect(await readied(running.t.io, running.screen.terminal, AWAY)).toEqual({
    ok: false,
    error: `${NAME}'s Claude is still running: set a resume command that can reach it, in SitRep's Settings.`,
  })
  expect(running.screen.handed()).toEqual([])
})

test('a command not fit to fill refuses in its own words before `ps` is asked: empty, unknown, with a placeholder in quotes, or past plain syntax', async () => {
  const commands = ['', 'seat open -s {session}', 'cd "{dir}"', 'cd `pwd` {dir}']
  const worlds = commands.map(command => world({ command, ps: { exit: 0, out: 'T+   claude\n', err: '' } }))
  const answers = await Promise.all(worlds.map(({ t, screen }) => readied(t.io, screen.terminal, AWAY)))

  expect(answers.map(answer => !answer.ok && answer.error)).toEqual([
    `The resume command in Settings is empty. To carry ${NAME} on, set one, or restore the default.`,
    "The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}.",
    'The resume command in Settings puts {dir} in quotes. Remove them: SitRep quotes each value itself.',
    "The resume command in Settings uses a backtick, which sitrep can't check. Put that part in a script and pass it {claude}, {dir} or {tty}, as in ~/bin/resume {claude} {dir}.",
  ])
  expect(worlds.flatMap(({ screen }) => screen.runs())).toEqual([])
})

test('the line runs only in a POSIX login shell, as each value is quoted for one: any other, or none set, refuses before `ps` is asked', async () => {
  const shells = ['/bin/sh', '/bin/bash', '/opt/homebrew/bin/zsh', '/bin/dash', '/bin/ksh']
  const posix = await Promise.all(shells.map(shell => world({ env: { ...ENV, SHELL: shell } })).map(({ t, screen }) => readied(t.io, screen.terminal, AWAY)))
  const others = [...['/opt/homebrew/bin/fish', '/bin/tcsh', '/usr/local/bin/nu', ''].map(shell => ({ ...ENV, SHELL: shell })), ENV].map(env => world({ env }))
  const refusals = await Promise.all(others.map(({ t, screen }) => readied(t.io, screen.terminal, AWAY)))

  expect(posix.map(answer => answer.ok && answer.value[0])).toEqual(shells)
  expect(refusals.map(answer => !answer.ok && answer.error)).toEqual([
    'sitrep can run the resume command only in a POSIX shell; your login shell is fish.',
    'sitrep can run the resume command only in a POSIX shell; your login shell is tcsh.',
    'sitrep can run the resume command only in a POSIX shell; your login shell is nu.',
    "sitrep couldn't start your login shell: $SHELL is not set.",
    "sitrep couldn't start your login shell: $SHELL is not set.",
  ])
  expect(others.flatMap(({ screen }) => screen.runs())).toEqual([])
})

/** The world with a clock the test moves while the program has the terminal. */
const clocked = () => {
  const { t, screen } = world()
  let clock = 0
  const io: Io = { ...t.io, uptime: () => clock }

  return { io, screen, after: (ms: number) => (clock += ms) }
}

/** The terminal handed over, the program ending after `ms` with `exit`: what the pick leaves to say. */
const handedFor = async (ms: number, exit: number) => {
  const { io, screen, after } = clocked()
  const said = handed(io, screen.terminal, ['/bin/zsh', '-l', '-c', 'carry'], NAME)

  await drained()
  after(ms)
  screen.end(exit)

  return { said: await said, handed: screen.handed() }
}

test('a command that ends non-zero within 2 seconds leaves an answer with its exit code; one ending well, or later, leaves none', async () => {
  expect(await handedFor(QUICK_MS - 1, 1)).toEqual({
    said: `The resume command ended with 1 for ${NAME}.`,
    handed: [['/bin/zsh', '-l', '-c', 'carry']],
  })
  expect((await handedFor(0, 127)).said).toBe(`The resume command ended with 127 for ${NAME}.`)
  expect((await handedFor(QUICK_MS, 1)).said).toBeUndefined()
  expect((await handedFor(10, 0)).said).toBeUndefined()
})

test('a login shell that cannot start leaves its own answer, naming it', async () => {
  const { io, screen } = clocked()
  const said = handed(io, screen.terminal, ['/bin/zshh', '-l', '-c', 'carry'], NAME)

  await drained()
  screen.unstarted(new Error("ENOENT: no such file or directory, posix_spawn '/bin/zshh'"))

  expect(await said).toBe("sitrep couldn't start your login shell, /bin/zshh.")
})
