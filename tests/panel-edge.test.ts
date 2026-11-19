import { drained, expect, test } from './kit'
import type { Io, Ran } from '../cli/io'
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

  expect(SETTINGS).toBe(`${HOME}/Library/Preferences/com.leeovery.sitrep.plist`)
  expect(await Promise.all([saved, none, homeless].map(each => savedCommand(each.io)))).toEqual(['carry {claude}', DEFAULT_COMMAND, DEFAULT_COMMAND])
})

test("a Claude Code on a device is told by its program, `claude` or a version in a `claude/versions` folder, stopped where its state starts T", () => {
  expect(claudeIn('Ss   -zsh\nS+   claude\n')).toBe('running')
  expect(claudeIn('S+   /Users/me/.local/share/claude/versions/2.1.322\n')).toBe('running')
  expect(claudeIn('S    /opt/homebrew/bin/claude\nT+   claude\n')).toBe('stopped')
  expect(claudeIn('T    -zsh\nS+   node\nS    /Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper\nS+   claude-helper\n')).toBe('none')
  expect(claudeIn('')).toBe('none')
})

/** A terminal whose `ps` answers as given. */
const psSaying = (ran: (argv: readonly string[]) => Promise<Ran>) => tty({ ran })

test("`ps` is the system's, asked of the device alone, within its time; it exits 1, listing nothing, for a device no process is on, or one gone", async () => {
  const listing = psSaying(async () => ({ exit: 0, out: 'S+   claude\n', err: '' }))
  const empty = psSaying(async () => ({ exit: 1, out: '', err: '' }))
  const gone = psSaying(async () => ({ exit: 1, out: '', err: 'ps: /dev/ttys041: No such file or directory\n' }))

  expect(await claudeOn(listing.terminal, '/dev/ttys041')).toBe('running')
  expect(listing.runs()).toEqual([{ argv: ['/bin/ps', '-t', '/dev/ttys041', '-o', 'stat=,comm='], ms: PS_MS }])
  expect(await claudeOn(empty.terminal, '/dev/ttys041')).toBe('none')
  expect(await claudeOn(gone.terminal, '/dev/ttys041')).toBe('none')
})

test('`ps` failing otherwise, not starting, or not answering in time, is no answer; with no device it is never asked', async () => {
  const failing = psSaying(async () => ({ exit: 2, out: '', err: 'ps: illegal option' }))
  const listingThenFailing = psSaying(async () => ({ exit: 1, out: 'S+   claude\n', err: '' }))
  const late = psSaying(async () => {
    throw new Error('/bin/ps gave no answer within 2000 ms')
  })
  const nowhere = psSaying(async () => ({ exit: 0, out: 'S+   claude\n', err: '' }))

  expect(await claudeOn(failing.terminal, '/dev/ttys041')).toBe('unknown')
  expect(await claudeOn(listingThenFailing.terminal, '/dev/ttys041')).toBe('unknown')
  expect(await claudeOn(late.terminal, '/dev/ttys041')).toBe('unknown')
  expect(await claudeOn(nowhere.terminal, undefined)).toBe('none')
  expect(nowhere.runs()).toEqual([])
})

const AWAY: Resume = { name: NAME, claude: W1, dir: FOLDER, device: '/dev/ttys041', isHeld: false, ownsDevice: true }

/** The memory world with SitRep's defaults saving `command`, where given, its login shell `shell`, and a terminal whose `ps` answers as given. */
const world = ({ command, shell = '/bin/zsh', ps = { exit: 1, out: '', err: '' } }: { command?: string; shell?: string; ps?: Ran } = {}) => {
  const screen = tty({ ran: async () => ps })
  const t = terminal({ env: { ...ENV, SHELL: shell }, terminal: screen.terminal })

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

test('a pick refused is readied as its words, with nothing handed; one with no login shell set says so', async () => {
  const running = world({ ps: { exit: 0, out: 'S+   claude\n', err: '' } })
  const unshelled = world({ shell: '' })
  const unset = terminal({ env: ENV })

  expect(await readied(running.t.io, running.screen.terminal, AWAY)).toEqual({
    ok: false,
    error: `${NAME}'s Claude is still running: set a resume command that can reach it, in SitRep's Settings.`,
  })
  expect(await readied(unshelled.t.io, unshelled.screen.terminal, AWAY)).toEqual({ ok: false, error: "sitrep couldn't start your login shell, $SHELL." })
  expect(await readied(unset.io, unshelled.screen.terminal, AWAY)).toEqual({ ok: false, error: "sitrep couldn't start your login shell, $SHELL." })
  expect([running.screen.handed(), unshelled.screen.handed()]).toEqual([[], []])
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
