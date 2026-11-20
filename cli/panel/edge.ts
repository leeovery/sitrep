/**
 * The CLI's one edge to programs, for a pick alone: it reads SitRep's saved
 * resume command, asks `ps` what runs on the window's device, and hands the
 * filled line to the user's login shell. It runs nothing else, never tmux
 * and never zmx.
 *
 * - The command is SitRep's setting (AppSettings.swift), JSON saved under
 *   `app` in SitRep's defaults: its `resume`, empty where the user cleared
 *   it; else the `resumeCommand` saved before `resume` had a key of its
 *   own, only where it holds a command; else the default. Defaults that
 *   can't be read are none saved.
 * - The command is typed before `ps` is asked, so one not fit to fill
 *   refuses in its own words, asking nothing.
 * - `ps -t <device>` lists what runs on the device, a terminal's device
 *   only, and one still there: a device gone runs nothing. A Claude Code
 *   is told by its program as `ps` gives it, its argv[0]: `claude`, or a
 *   file in a `claude/versions` folder, as Claude Code's own installer
 *   keeps each version. The app reads the path of the program itself
 *   (`Proc.isClaudeCode`), which no `ps` keyword gives: so a Claude started
 *   through a link of another name is missed here, and a program started
 *   as `claude` (`exec -a claude`) counted. It is stopped where its state
 *   starts `T`. `ps` exits 1 with nothing to say for a device no process
 *   is on; anything else, or nothing within PS_MS, is no answer.
 * - The line runs as `$SHELL -l -c <line>`, with the user's own PATH and
 *   environment, in a POSIX shell only, as each value is quoted for one: a
 *   `\'` in fish's single quotes is an escape. A command that ends non-zero
 *   within QUICK_MS leaves an answer saying so, as its own words went by
 *   too fast to read; one a signal ended leaves none, since a Ctrl-C the
 *   user pressed ends it so.
 */
import { isObject, type Checked } from '../../core'
import type { Io, Ran, Terminal } from '../io'
import { DEFAULT_COMMAND, typedOf } from './command'
import { dataIn } from './plist'
import { carriedOn, type ClaudeThere, type Resume } from './reach'

/** SitRep's defaults, under the home folder. */
export const DEFAULTS = 'Library/Preferences/com.leeovery.sitrep.plist'

/** The program asked what runs on a device: the system's own, never one the PATH puts first. */
export const PS = '/bin/ps'

/** How long `ps` has to answer. */
export const PS_MS = 2_000

/** How soon a command that fails ends for its failure to leave an answer. */
export const QUICK_MS = 2_000

/** The highest exit code of a program's own; above it, 128 and a signal's number, a signal ended it, as a Ctrl-C does. */
const HIGHEST_OWN_EXIT = 128

/** A process as `ps` lists it: its state, then its program, spaces and all. */
const PROCESS = /^\s*(\S+)\s+(.*\S)\s*$/

/** A terminal's device, as a window says it: the only kind `ps -t` is asked about. */
const DEVICE = /^\/dev\/tty[a-z0-9]+$/

/** The login shells whose single quotes a value is quoted for: POSIX shells, and zsh. */
const POSIX_SHELLS: ReadonlySet<string> = new Set(['sh', 'bash', 'zsh', 'dash', 'ksh'])

/** The JSON SitRep keeps under a key, as an object; an empty one where it holds no object, as SitRep reads its defaults. */
const settingsIn = (data: Uint8Array | undefined): Record<string, unknown> => {
  try {
    const settings: unknown = data === undefined ? undefined : JSON.parse(new TextDecoder().decode(data))

    return isObject(settings) ? settings : {}
  } catch {
    return {}
  }
}

/** The resume command saved in SitRep's defaults, as their bytes hold it; none where none is. */
export const commandIn = (defaults: Uint8Array): string | undefined => {
  const { resume, resumeCommand } = settingsIn(dataIn(defaults, 'app'))

  if (typeof resume === 'string') {
    return resume
  }

  return typeof resumeCommand === 'string' && resumeCommand !== '' ? resumeCommand : undefined
}

/** The resume command SitRep has saved, or the default where none is. */
export const savedCommand = async (io: Io): Promise<string> => {
  const { HOME } = io.env
  const defaults = HOME === undefined ? undefined : await io.fs.bytes(`${HOME}/${DEFAULTS}`).catch(() => undefined)

  return (defaults === undefined ? undefined : commandIn(defaults)) ?? DEFAULT_COMMAND
}

/** Whether a program is Claude Code's, by its path: named `claude`, or in a `claude/versions` folder. */
const isClaudeCode = (program: string) => {
  const parts = program.split('/').filter(part => part !== '')

  return parts.at(-1) === 'claude' || parts.slice(-3, -1).join('/') === 'claude/versions'
}

/** What runs on a device, as `ps -o stat=,comm=` lists it: a Claude Code stopped, one running, or none. */
export const claudeIn = (listing: string): Exclude<ClaudeThere, 'unknown'> => {
  const states = listing.split('\n').flatMap(line => {
    const [, state = '', program = ''] = PROCESS.exec(line) ?? []

    return isClaudeCode(program) ? [state] : []
  })

  if (states.some(state => state.startsWith('T'))) {
    return 'stopped'
  }

  return states.length > 0 ? 'running' : 'none'
}

/** What `ps` listed, if it answered: all it ran on the device, or nothing, ending 1 with nothing to say, for a device no process is on. */
const listingOf = ({ exit, out, err }: Ran) => (exit === 0 || (exit === 1 && out.trim() === '' && err.trim() === '') ? out : undefined)

/** What runs on the device, by `ps`: none with no device to look on, or one gone; unknown where it is no terminal's, or `ps` gave no answer. */
export const claudeOn = async (io: Io, terminal: Terminal, device: string | undefined): Promise<ClaudeThere> => {
  if (device === undefined) {
    return 'none'
  }

  if (!DEVICE.test(device)) {
    return 'unknown'
  }

  try {
    if ((await io.fs.stat(device)) === undefined) {
      return 'none'
    }

    const listing = listingOf(await terminal.run([PS, '-t', device, '-o', 'stat=,comm='], PS_MS))

    return listing === undefined ? 'unknown' : claudeIn(listing)
  } catch {
    return 'unknown'
  }
}

/** Why no login shell ran the line, naming it. */
const unstarted = (shell: string) => `sitrep couldn't start your login shell, ${shell}.`

/** The login shell the line runs in, `$SHELL`; or why none can, unset or not a POSIX shell. */
const loginShellOf = (shell: string | undefined): Checked<string> => {
  if (shell === undefined || shell === '') {
    return { ok: false, error: "sitrep couldn't start your login shell: $SHELL is not set." }
  }

  const name = shell.split('/').at(-1) ?? shell

  return POSIX_SHELLS.has(name)
    ? { ok: true, value: shell }
    : { ok: false, error: `sitrep can run the resume command only in a POSIX shell; your login shell is ${name}.` }
}

/** The login shell's words for a pick, the resume command filled for the window it carries the session on from; or why it runs nothing. */
export const readied = async (io: Io, terminal: Terminal, resume: Resume): Promise<Checked<string[]>> => {
  const typed = typedOf(await savedCommand(io), resume.name)
  const shell = loginShellOf(io.env.SHELL)

  if (!typed.ok) {
    return typed
  }

  if (!shell.ok) {
    return shell
  }

  const line = carriedOn(resume, await claudeOn(io, terminal, resume.device), typed.value)

  return line.ok ? { ok: true, value: [shell.value, '-l', '-c', line.value] } : line
}

/** The terminal handed to the login shell until it ends: what the pick of the session named leaves to say once it has, if anything. */
export const handed = async (io: Io, terminal: Terminal, argv: readonly string[], name: string): Promise<string | undefined> => {
  const from = io.uptime()

  try {
    const exit = await terminal.hand(argv)

    return exit !== 0 && exit <= HIGHEST_OWN_EXIT && io.uptime() - from < QUICK_MS ? `The resume command ended with ${exit} for ${name}.` : undefined
  } catch {
    return unstarted(argv[0] ?? '')
  }
}
