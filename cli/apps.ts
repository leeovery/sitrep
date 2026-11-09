/**
 * Which terminal app a window is in: one with a driver, else one brought
 * forward as an app, which shows the session but cannot pick out its window.
 * Outside a multiplexer it is told by the window's `$TERM_PROGRAM`; under
 * one, as tmux sets its own and zmx passes on the one its client started
 * with, by the client's ancestors in `ps`: the nearest that is a driver's
 * program, or inside an app bundle, or a known app's helper outside its
 * bundle.
 *
 * An app with no driver is brought forward by `open`, within the time limit,
 * and nothing more: no window of it picked out, and no select beyond the tmux
 * layer's. `open` launches an app not running, so it runs only for one
 * running. One told by its `$TERM_PROGRAM`, which a program started from
 * another terminal's shell inherits, or by a helper that outlives the app, as
 * iTerm2's server does, is asked of lsappinfo first; one told by its bundle's
 * path in `ps` is running, its program among the client's ancestors.
 */
import type { App, Driver } from './driver'
import { GHOSTTY } from './ghostty'
import type { Io } from './io'
import { look } from './look'

/** Every terminal app with a driver. */
export const DRIVERS: readonly Driver[] = [GHOSTTY]

/** An app with no driver known by its bundle id, the first of those given that is running: Warp's stable release or its preview. */
type Bundled = { name: string; bundles: readonly string[] }

/**
 * The terminal apps with no driver told by their `$TERM_PROGRAM`. kitty and
 * Alacritty set no `$TERM_PROGRAM`, so only their tmux clients are told, by
 * their app's path; VS Code's, which Cursor sets too, would name the wrong
 * app for one of them.
 */
export const BUNDLES: ReadonlyMap<string, Bundled> = new Map([
  ['Apple_Terminal', { name: 'Terminal', bundles: ['com.apple.Terminal'] }],
  ['iTerm.app', { name: 'iTerm2', bundles: ['com.googlecode.iterm2'] }],
  ['WezTerm', { name: 'WezTerm', bundles: ['com.github.wez.wezterm'] }],
  ['WarpTerminal', { name: 'Warp', bundles: ['dev.warp.Warp-Stable', 'dev.warp.Warp-Preview'] }],
])

/**
 * The programs of an app with no driver that run outside its bundle, by the
 * `$TERM_PROGRAM` of the app they are: iTerm2's shells, since 3.4, run under
 * `~/Library/Application Support/iTerm2/iTermServer-<version>` (unchecked on
 * this Mac, which has no iTerm2).
 */
const HELPERS: readonly [helper: RegExp, program: string][] = [
  [/\/Library\/Application Support\/iTerm2\/iTermServer-[^/]+$/, 'iTerm.app'],
]

/** The app bundle a program's path is inside, the outermost: `/Applications/Visual Studio Code.app` for its helpers too. */
const APP_PATH = /^(\/(?:.*?\/)?([^/]+)\.app)\//

/** lsappinfo's words finding a running app by its bundle id: it prints the app's ASN, or an empty line for none. */
export const findWords = (bundle: string) => ['lsappinfo', 'find', `bundleid=${bundle}`]

/** `open`'s words bringing an app forward. */
export const openWords = (app: { bundle: string } | { path: string }) =>
  'bundle' in app ? ['open', '-b', app.bundle] : ['open', '-a', app.path]

/** Forward once `open` ran well, else nothing answered. */
const openWith = async (io: Io, words: readonly string[]) =>
  (await look(io, words))?.exitCode === 0 ? 'forward' : undefined

const isRunning = async (io: Io, bundle: string) =>
  (await look(io, findWords(bundle)))?.stdout.trim().startsWith('ASN:') === true

/** The first of the bundle ids whose app is running; undefined for none, or lsappinfo not telling. */
const runningOf = async (io: Io, bundles: readonly string[]) => {
  for (const bundle of bundles) {
    if (await isRunning(io, bundle)) {
      return bundle
    }
  }

  return undefined
}

/** An app with no driver brought forward by its bundle id, once found running; one not running answers nothing. */
const byBundle = ({ name, bundles }: Bundled): App => ({
  name,
  start: io => async () => {
    const bundle = await runningOf(io, bundles)

    return bundle === undefined ? undefined : openWith(io, openWords({ bundle }))
  },
})

/** An app with no driver brought forward by its bundle's path, its program running as `ps` saw. */
const byPath = (name: string, path: string): App => ({
  name,
  start: io => () => openWith(io, openWords({ path })),
})

const bundledOf = (program: string | undefined) => {
  const known = program === undefined ? undefined : BUNDLES.get(program)

  return known === undefined ? undefined : byBundle(known)
}

/** Whether an app has a driver of its own. */
export const isDriver = (app: App): app is Driver => DRIVERS.some(driver => driver === app)

/** Whether a window in the app can be reached on the device: a driver needs one to find the window; an app with no driver is brought forward whole, so needs none. */
export const isReachable = (app: App, device: string | undefined) =>
  device !== undefined || !isDriver(app)

/** The app a window outside a multiplexer is in, by its `$TERM_PROGRAM`: its driver, else one in the table; undefined for any other. */
export const appOfProgram = (program: string | undefined): App | undefined =>
  DRIVERS.find(driver => driver.program === program) ?? bundledOf(program)

/**
 * Where a command line's arguments begin: at a space before an option or a
 * path (` -x`, ` /x`). A space before a lone dash is no argument's:
 * `/Applications/Visual Studio Code - Insiders.app` is one path.
 */
const ARGUMENT = / (?=\/|-\S)/

/**
 * A command line's program, as `ps -o comm` gives it but whole: the line up
 * to its first argument that is an option or a path, its own path's spaces
 * kept (`…/Code Helper (Plugin) --type=utility`). `ps` truncates every
 * column but the last, so the program and its arguments never come whole
 * together. A plain word after it stays on it (`…/ghostty launchd`).
 */
export const programOf = (args: string) => args.split(ARGUMENT)[0] ?? args

/** Whether a program is a driver's: the last part of its path is the driver's executable, a plain word after it left aside. */
const isDriversProgram = (program: string, driver: Driver) =>
  program.split('/').at(-1)?.split(' ')[0] === driver.executable

/**
 * The app a process is, by its command line's program: a driver's, a known
 * app's helper, else one inside an app bundle, the outermost; undefined for
 * one in none, a shell, `login`, mosh-server or sshd, and for an app a
 * program's arguments name.
 */
export const appOfCommand = (args: string): App | undefined => {
  const program = programOf(args)
  const helper = HELPERS.find(([pattern]) => pattern.test(program))
  const [, path, name = ''] = APP_PATH.exec(program) ?? []

  return (
    DRIVERS.find(driver => isDriversProgram(program, driver)) ??
    (helper === undefined ? undefined : bundledOf(helper[1])) ??
    (path === undefined ? undefined : byPath(name, path))
  )
}
