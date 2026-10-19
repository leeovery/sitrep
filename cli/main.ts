/**
 * The CLI, from its words to its exit code: the words read, then the files
 * and, where a command needs it, the screen, then the command's rules, then
 * a line appended or a window brought forward, and the answer printed.
 *
 * It writes as the writer `cli`, appending to `<session>/cli.jsonl` and never
 * rewriting it, and writes no delivered marks or heartbeats: it is never a
 * window on the session.
 */
import { append, checkJoin, rootOf, type Body, type Checked } from '../core'
import { parseWords, wantsHelp, type Fields } from './args'
import {
  commandNamed,
  type Command,
  type ProjectsCommand,
  type WindowCommand,
  type SessionCommand,
} from './commands'
import { findSession, readProjects, type Found } from './files'
import { commandHelp, HELP } from './help'
import type { Env, Io } from './io'
import { jump, sessionsOnScreen } from './jump'
import { windowsOf } from './screen'

/** How a run ends: done; a usage error, a refused input or a failure; or no such session. */
export const EXIT = { done: 0, refused: 1, noSession: 2 } as const

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

/** Appends the lines to a writer's file after the text it holds; never a rewrite, so runs at once both land. */
const post = async (io: Io, path: string, text: string, bodies: readonly Body[], now: number) => {
  if (bodies.length > 0) {
    await io.fs.append(path, append(text, bodies, now).added)
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

const onSession = async (io: Io, command: SessionCommand, input: Fields) => {
  const now = io.now()
  const found = await namedSession(io, input, now)

  if (typeof found === 'number') {
    return found
  }

  const acted = command.act(found, input, io.random)

  if (!acted.ok) {
    return fail(io, EXIT.refused, acted.error)
  }

  await post(io, found.paths.log(WRITER), found.files.logs[WRITER] ?? '', acted.value.post, now)
  print(io, acted.value.print)

  return EXIT.done
}

const onProjects = async (io: Io, command: ProjectsCommand, input: Fields) => {
  const now = io.now()
  const { projects, windows } = await readProjects(io, rootOf(io.env), now)
  const onScreen = command.looks(input) ? await sessionsOnScreen(io, windows) : new Set<string>()

  return told(io, command.act({ read: projects, cwd: io.cwd, now, onScreen }, input))
}

const onWindow = async (io: Io, command: WindowCommand, input: Fields) => {
  const now = io.now()
  const found = await namedSession(io, input, now)

  return typeof found === 'number'
    ? found
    : told(io, command.act(found, await jump(io, windowsOf(found.session, now))))
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
    case 'window':
      return onWindow(io, command, input.value)
  }
}

const answer = async (io: Io, words: readonly string[]): Promise<Exit> => {
  const [name, ...rest] = words

  if (name === undefined) {
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
    return fail(io, EXIT.refused, error instanceof Error ? error.message : String(error))
  }
}
