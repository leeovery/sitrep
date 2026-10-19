/**
 * Which terminal app a window is in: one with a driver, else one brought
 * forward as an app, which shows the session but cannot pick out its window.
 * Outside tmux it is told by the window's `$TERM_PROGRAM`; under tmux, which
 * sets its own, by the tmux client's ancestors in `ps`: the nearest that is a
 * driver's program, or inside an app bundle, or a known app's helper outside
 * its bundle.
 *
 * An app with no driver is brought forward by `open`, within the time limit,
 * and nothing more: no knock, and no select beyond the tmux layer's. `open`
 * launches an app not running, so it runs only for one running. One told by
 * its `$TERM_PROGRAM`, which a program started from another terminal's shell
 * inherits, or by a helper that outlives the app, as iTerm2's server does, is
 * asked of lsappinfo first; one told by its bundle's path in `ps` is running,
 * its program among the client's ancestors.
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

/** The app a window outside tmux is in, by its `$TERM_PROGRAM`: its driver, else one in the table; undefined for any other. */
export const appOfProgram = (program: string | undefined): App | undefined =>
  DRIVERS.find(driver => driver.program === program) ?? bundledOf(program)

/**
 * The app a process is, by its command as `ps` gives it: a driver's program,
 * a known app's helper, else a program inside an app bundle; undefined for
 * one in none, a shell, `login`, mosh-server or sshd.
 */
export const appOfCommand = (command: string): App | undefined => {
  const helper = HELPERS.find(([pattern]) => pattern.test(command))
  const [, path, name = ''] = APP_PATH.exec(command) ?? []

  return (
    DRIVERS.find(driver => command.split('/').at(-1) === driver.executable) ??
    (helper === undefined ? undefined : bundledOf(helper[1])) ??
    (path === undefined ? undefined : byPath(name, path))
  )
}
