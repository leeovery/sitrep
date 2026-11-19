/**
 * The CLI, from its words to its exit code: the words read, then the files,
 * then the command's rules, then a line appended, and the answer printed.
 *
 * It writes as the writer `cli`, appending to `<session>/cli.jsonl` and
 * never rewriting it, and an answer to its letters in the session's inbox,
 * `<session>/inbox/cli.jsonl`, the same way; each file's count goes on from
 * that file. It writes no delivered marks or heartbeats: it is never a
 * window on the session. `watch` runs on, printing the board as it changes,
 * until it is to end. With no words, on a terminal, it is the panel, the
 * board drawn in the terminal until it is left; off one, the help.
 */
import {
  addition,
  checkJoin,
  manifestVersion,
  parkedBy,
  projectParked,
  rootOf,
  stamp,
  type Body,
  type Checked,
} from '../core'
import { parseWords, wantsHelp, type Fields } from './args'
import {
  commandNamed,
  type Command,
  type ProjectsCommand,
  type SessionCommand,
} from './commands'
import { findSession, readBoardAt, readProjects, textAt, type Found } from './files'
import { commandHelp, HELP } from './help'
import type { Env, Io, Terminal } from './io'
import { panel } from './panel/panel'
import { watch } from './watch'

/**
 * How a run ends: done; a usage error, a refused input or a failure; no
 * such session; or, the panel's, by a signal, 128 and its number: its
 * terminal hung up (SIGHUP), it was interrupted (SIGINT), told to quit
 * (SIGQUIT) or told to end (SIGTERM).
 */
export const EXIT = { done: 0, refused: 1, noSession: 2, hungUp: 129, interrupted: 130, quit: 131, terminated: 143 } as const

export type Exit = (typeof EXIT)[keyof typeof EXIT]

/** The writer the CLI writes as, whichever script or tool runs it. */
export const WRITER = 'cli'

const HELP_WORDS = ['help', '--help', '-h']

const NAME_THE_SESSION =
  'Name the session: --session sr-xxxxxx, or SITREP_SESSION in the environment.'

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

/** The session a command names: `--session`, else `SITREP_SESSION`, checked as join checks it. */
const sessionIdOf = (input: Fields, env: Env): Checked<string> => {
  const given = input.session ?? (env.SITREP_SESSION || undefined)

  if (given === undefined) {
    return { ok: false, error: NAME_THE_SESSION }
  }

  const checked = checkJoin({ session: given })

  return checked.ok ? { ok: true, value: checked.value.session } : checked
}

/**
 * Appends the lines to a writer's file, their count going on from the file
 * as it stands, a torn last line ended first; never a rewrite, so runs at
 * once both land.
 */
const post = async (io: Io, path: string, bodies: readonly Body[], now: number) => {
  if (bodies.length > 0) {
    const text = (await textAt(io, path)) ?? ''

    await io.fs.append(path, addition(text, stamp(text, bodies, now)))
  }
}

/** The session the words name, as it stands at `now`; else how the run ends, told. */
const namedSession = async (io: Io, input: Fields, now: number): Promise<Found | Exit> => {
  const id = sessionIdOf(input, io.env)

  if (!id.ok) {
    return fail(io, EXIT.refused, id.error)
  }

  const found = await findSession(io, rootOf(io.env), id.value, now)

  return (
    found ??
    fail(io, EXIT.noSession, `There is no session ${id.value} on the board, in any project.`)
  )
}

/** A command's answer printed, or its refusal told. */
const told = (io: Io, acted: Checked<string>) => {
  if (!acted.ok) {
    return fail(io, EXIT.refused, acted.error)
  }

  print(io, acted.value)

  return EXIT.done
}

/** The file a command's lines go to: the CLI's own, or its letters in the session's inbox. */
const fileFor = ({ paths }: Found, command: SessionCommand) =>
  command.into === 'inbox' ? paths.letters(WRITER) : paths.log(WRITER)

/** What a command that reads the board is given of it: what every session filed under the found session's project parked, and the projects on it; none for any other. */
const boardFor = async (io: Io, command: SessionCommand, { project }: Found, now: number) => {
  if (command.readsBoard !== true) {
    return { parked: [], projects: [] }
  }

  const read = await readBoardAt(io, rootOf(io.env), now)
  const sessions = read.find(each => each.project.key === project)?.sessions ?? []

  return {
    parked: projectParked(sessions.flatMap(parkedBy)),
    projects: read.map(each => each.project),
  }
}

/** A command on a session: the session read, its checks, and its lines appended, dated as they are written. */
const onSession = async (io: Io, command: SessionCommand, input: Fields) => {
  const now = io.now()
  const found = await namedSession(io, input, now)

  if (typeof found === 'number') {
    return found
  }

  const version = manifestVersion((await textAt(io, io.manifest)) ?? '')
  const board = await boardFor(io, command, found, now)
  const acted = command.act(found, input, { random: io.random, version, now, ...board })

  if (!acted.ok) {
    return fail(io, EXIT.refused, acted.error)
  }

  await post(io, fileFor(found, command), acted.value.post, io.now())
  print(io, acted.value.print)

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

const answer = async (io: Io, words: readonly string[]): Promise<Exit> => {
  const [name, ...rest] = words

  if (name === undefined) {
    const terminal = panelTerminal(io)

    if (terminal !== undefined) {
      return EXIT[await panel(io, terminal)]
    }

    io.err(`${HELP}\n`)

    return EXIT.refused
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
