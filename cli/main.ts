/**
 * The CLI, from its words to its exit code: the words read, then the files,
 * then the command's rules, then a line appended (acts.ts), and the answer
 * printed.
 *
 * It writes no delivered marks or heartbeats: it is never a window on the
 * session. `watch` runs on, printing the board as it changes, until it is
 * to end. With no words, or only flags, on a terminal, it is the panel, the
 * board drawn in the terminal until it is left; off one, the help.
 */
import { rootOf, type Checked } from '../core'
import { actOn } from './acts'
import { parseWords, wantsHelp, type Fields } from './args'
import {
  commandNamed,
  type Command,
  type ProjectsCommand,
  type SessionCommand,
} from './commands'
import { readProjects } from './files'
import { commandHelp, HELP } from './help'
import type { Io, Terminal } from './io'
import { panel } from './panel/panel'
import { watch } from './watch'

export { WRITER } from './acts'

/**
 * How a run ends: done; a usage error, a refused input or a failure; no
 * such session; or, the panel's, by a signal, 128 and its number: its
 * terminal hung up (SIGHUP), it was interrupted (SIGINT), told to quit
 * (SIGQUIT) or told to end (SIGTERM).
 */
export const EXIT = { done: 0, refused: 1, noSession: 2, hungUp: 129, interrupted: 130, quit: 131, terminated: 143 } as const

export type Exit = (typeof EXIT)[keyof typeof EXIT]

const HELP_WORDS = ['help', '--help', '-h']

/** The panel's one flag of its own: no notification for a new ask. */
const NO_NOTIFY = '--no-notify'

const fail = (io: Io, exit: Exit, error: string) => {
  io.err(`sitrep: ${error}\n`)

  return exit
}

const messageOf = (error: unknown) => (error instanceof Error ? error.message : String(error))

const print = (io: Io, text: string) => {
  if (text !== '') {
    io.out(`${text}\n`)
  }
}

const unknown = (io: Io, name: string) =>
  fail(io, EXIT.refused, `There is no command ${name}. sitrep --help lists them.`)

/** The help, or a command's when one is named. */
const help = (io: Io, name?: string) => {
  const command = name === undefined ? undefined : commandNamed(name)

  if (name !== undefined && command === undefined) {
    return unknown(io, name)
  }

  print(io, command === undefined ? HELP : commandHelp(command))

  return EXIT.done
}

/** A command's answer printed, or its refusal told. */
const told = (io: Io, acted: Checked<string>) => {
  if (!acted.ok) {
    return fail(io, EXIT.refused, acted.error)
  }

  print(io, acted.value)

  return EXIT.done
}

/** A command on a session, acted (acts.ts): what it prints printed, or why not told. */
const onSession = async (io: Io, command: SessionCommand, input: Fields) => {
  const acted = await actOn(io, command, input)

  if (!acted.ok) {
    return fail(io, EXIT[acted.ending], acted.error)
  }

  print(io, acted.value)

  return EXIT.done
}

const onProjects = async (io: Io, command: ProjectsCommand, input: Fields) => {
  const now = io.now()
  const read = await readProjects(io, rootOf(io.env), now)

  return told(io, command.act({ read, cwd: io.cwd, now }, input))
}

/** A command on the rest of its words: its help, or its run once they read. */
const runCommand = async (io: Io, command: Command, words: readonly string[]) => {
  if (wantsHelp(words)) {
    return help(io, command.name)
  }

  const input = parseWords(command.grammar, words)

  if (!input.ok) {
    return fail(io, EXIT.refused, `${input.error} sitrep ${command.name} --help says more.`)
  }

  switch (command.on) {
    case 'session':
      return onSession(io, command, input.value)
    case 'projects':
      return onProjects(io, command, input.value)
    case 'feed':
      await watch(io)

      return EXIT.done
  }
}

/** The terminal the panel opens on: standard input and output both one, and `TERM` not `dumb`. */
const panelTerminal = ({ terminal, env }: Io): Terminal | undefined =>
  env.TERM === 'dumb' ? undefined : terminal

/** A word that reads as a flag of bare `sitrep`'s: a dash and more; never a command's name. */
const isBareFlag = (word: string) => word.length > 1 && word.startsWith('-')

/**
 * Bare `sitrep`, given only flags: one it doesn't take answered as an
 * unknown command is, as before it took any; the help where they ask for
 * it; else the panel on a terminal, and the help on standard error off one.
 */
const bare = async (io: Io, flags: readonly string[]): Promise<Exit> => {
  const stray = flags.find(flag => flag !== NO_NOTIFY && !HELP_WORDS.includes(flag))

  if (stray !== undefined) {
    return unknown(io, stray)
  }

  if (flags.some(flag => HELP_WORDS.includes(flag))) {
    return help(io)
  }

  const terminal = panelTerminal(io)

  if (terminal === undefined) {
    io.err(`${HELP}\n`)

    return EXIT.refused
  }

  return EXIT[await panel(io, terminal, { isNotifying: !flags.includes(NO_NOTIFY) })]
}

const answer = async (io: Io, words: readonly string[]): Promise<Exit> => {
  const [name, ...rest] = words

  if (name === undefined || words.every(isBareFlag)) {
    return bare(io, words)
  }

  if (HELP_WORDS.includes(name)) {
    return help(io, rest[0])
  }

  const command = commandNamed(name)

  return command === undefined ? unknown(io, name) : runCommand(io, command, rest)
}

/** Runs the CLI on its words; a failure the files or the world threw is told, and ends it as refused. */
export const main = async (words: readonly string[], io: Io): Promise<Exit> => {
  try {
    return await answer(io, words)
  } catch (error) {
    return fail(io, EXIT.refused, messageOf(error))
  }
}
