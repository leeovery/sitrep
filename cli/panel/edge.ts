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
 * - `ps -t <device>` lists what runs on the device. A Claude Code is told by
 *   its program, as the app tells it (`Proc.isClaudeCode`): one named
 *   `claude`, or a file in a `claude/versions` folder, as Claude Code's own
 *   installer keeps each version. It is stopped where its state starts `T`.
 *   `ps` exits 1, listing nothing, for a device no process is on, or one
 *   gone; anything else, or nothing within PS_MS, is no answer.
 * - The line runs as `$SHELL -l -c <line>`, with the user's own PATH and
 *   environment. A command that ends non-zero within QUICK_MS leaves an
 *   answer saying so, as its own words went by too fast to read.
 */
import { isObject, type Checked } from '../../core'
import type { Io, Terminal } from '../io'
import { DEFAULT_COMMAND } from './command'
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

/** A process as `ps` lists it: its state, then its program, spaces and all. */
const PROCESS = /^\s*(\S+)\s+(.*\S)\s*$/

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

/** What runs on the device, by `ps`; none with no device to look on, and unknown where `ps` gave no answer. */
export const claudeOn = async (terminal: Terminal, device: string | undefined): Promise<ClaudeThere> => {
  if (device === undefined) {
    return 'none'
  }

  try {
    const { exit, out } = await terminal.run([PS, '-t', device, '-o', 'stat=,comm='], PS_MS)

    return exit === 0 || (exit === 1 && out.trim() === '') ? claudeIn(out) : 'unknown'
  } catch {
    return 'unknown'
  }
}

/** Why no login shell ran the line, naming it, or `$SHELL` where none is set. */
const unstarted = (shell: string) => `sitrep couldn't start your login shell, ${shell === '' ? '$SHELL' : shell}.`

/** The login shell's words for a pick, the resume command filled for the window it carries the session on from; or why it runs nothing. */
export const readied = async (io: Io, terminal: Terminal, resume: Resume): Promise<Checked<string[]>> => {
  const [command, there] = await Promise.all([savedCommand(io), claudeOn(terminal, resume.device)])
  const line = carriedOn(resume, there, command)
  const shell = io.env.SHELL ?? ''

  if (!line.ok) {
    return line
  }

  return shell === '' ? { ok: false, error: unstarted(shell) } : { ok: true, value: [shell, '-l', '-c', line.value] }
}

/** The terminal handed to the login shell until it ends: what the pick of the session named leaves to say once it has, if anything. */
export const handed = async (io: Io, terminal: Terminal, argv: readonly string[], name: string): Promise<string | undefined> => {
  const from = io.uptime()

  try {
    const exit = await terminal.hand(argv)

    return exit !== 0 && io.uptime() - from < QUICK_MS ? `The resume command ended with ${exit} for ${name}.` : undefined
  } catch {
    return unstarted(argv[0] ?? '')
  }
}
