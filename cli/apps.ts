/**
 * Which terminal app a window is in: one with a driver, else one brought
 * forward as an app, which shows the session but cannot pick out its window.
 * Outside tmux it is told by the window's `$TERM_PROGRAM`; under tmux, which
 * sets its own, by the tmux client's ancestors in `ps`: the nearest that is a
 * driver's program, or inside an app bundle.
 *
 * An app with no driver is brought forward by `open`, within the time limit,
 * and nothing more: no knock, and no select beyond the tmux layer's. `open`
 * launches an app not running and sends a running one the reopen event,
 * which makes an app with no window open one; neither happens here, as a
 * live window of the session is in the app.
 */
import type { App, Driver } from './driver'
import { GHOSTTY } from './ghostty'
import { look } from './look'

/** Every terminal app with a driver. */
export const DRIVERS: readonly Driver[] = [GHOSTTY]

/**
 * The terminal apps with no driver told by their `$TERM_PROGRAM`, each with
 * its name and its bundle id. kitty and Alacritty set no `$TERM_PROGRAM`, so
 * only their tmux clients are told, by their app's path; VS Code's, which
 * Cursor sets too, would name the wrong app for one of them.
 */
export const BUNDLES: ReadonlyMap<string, { name: string; bundle: string }> = new Map([
  ['Apple_Terminal', { name: 'Terminal', bundle: 'com.apple.Terminal' }],
  ['iTerm.app', { name: 'iTerm2', bundle: 'com.googlecode.iterm2' }],
  ['WezTerm', { name: 'WezTerm', bundle: 'com.github.wez.wezterm' }],
  ['WarpTerminal', { name: 'Warp', bundle: 'dev.warp.Warp-Stable' }],
])

/** The app bundle a program's path is inside, the outermost: `/Applications/Visual Studio Code.app` for its helpers too. */
const APP_PATH = /^(\/(?:.*?\/)?([^/]+)\.app)\//

/** `open`'s words bringing an app forward. */
export const openWords = (app: { bundle: string } | { path: string }) =>
  'bundle' in app ? ['open', '-b', app.bundle] : ['open', '-a', app.path]

/** An app with no driver, brought forward by `open`: forward once `open` ran well, else nothing answered. */
const opened = (name: string, words: readonly string[]): App => ({
  name,
  start: io => async () => ((await look(io, words))?.exitCode === 0 ? 'forward' : undefined),
})

/** The app a window outside tmux is in, by its `$TERM_PROGRAM`: its driver, else one in the table; undefined for any other. */
export const appOfProgram = (program: string | undefined): App | undefined => {
  const known = program === undefined ? undefined : BUNDLES.get(program)

  return (
    DRIVERS.find(driver => driver.program === program) ??
    (known === undefined ? undefined : opened(known.name, openWords(known)))
  )
}

/** The app a process is, by its command as `ps` gives it: a driver's program, else a program inside an app bundle; undefined for one in none, a shell, `login`, mosh-server or sshd. */
export const appOfCommand = (command: string): App | undefined => {
  const [, path, name = ''] = APP_PATH.exec(command) ?? []

  return (
    DRIVERS.find(driver => command.split('/').at(-1) === driver.executable) ??
    (path === undefined ? undefined : opened(name, openWords({ path })))
  )
}
