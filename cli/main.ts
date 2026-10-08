/**
 * The CLI, from its words to its exit code: the words read, then the files,
 * then core's rules, then a line appended and the answer printed.
 *
 * It writes as the writer `cli`, appending to `<work>/cli.jsonl` and never
 * rewriting it, and writes no delivered marks or heartbeats: it is never a
 * window on the work.
 */
import { append, checkJoin, type Body, type Checked } from '../core'
import { parseWords, wantsHelp, type Fields } from './args'
import { commandNamed, type Command, type ProjectsCommand, type WorkCommand } from './commands'
import { findWork, placeOf, readProjects } from './files'
import { commandHelp, HELP } from './help'
import type { Env, Io } from './io'
import { listed } from './output'

/** How a run ends: done; a usage error, a refused input or a failure; or no such piece of work. */
export const EXIT = { done: 0, refused: 1, noWork: 2 } as const

export type Exit = (typeof EXIT)[keyof typeof EXIT]

/** The writer the CLI writes as, whichever script or tool runs it. */
export const WRITER = 'cli'

const HELP_WORDS = ['help', '--help', '-h']

const NAME_THE_WORK = 'Name the piece of work: --work sr-xxxxxx, or SITREP_WORK in the environment.'

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

/** The work a command names: `--work`, else `SITREP_WORK`, checked as join checks it. */
const workIdOf = (input: Fields, env: Env): Checked<string> => {
  const given = input.work ?? (env.SITREP_WORK || undefined)

  if (given === undefined) {
    return { ok: false, error: NAME_THE_WORK }
  }

  const checked = checkJoin({ work: given })

  return checked.ok ? { ok: true, value: checked.value.work } : checked
}

/** Appends the lines to a writer's file after the text it holds; never a rewrite, so runs at once both land. */
const post = async (io: Io, path: string, text: string, bodies: readonly Body[], now: number) => {
  if (bodies.length > 0) {
    await io.fs.append(path, append(text, bodies, now).added)
  }
}

const onWork = async (io: Io, command: WorkCommand, input: Fields) => {
  const id = workIdOf(input, io.env)

  if (!id.ok) {
    return fail(io, EXIT.refused, id.error)
  }

  const now = io.now()
  const found = await findWork(io, await placeOf(io), id.value, now)

  if (found === undefined) {
    return fail(
      io,
      EXIT.noWork,
      `There is no piece of work ${id.value} on the board, in this project or any other.`,
    )
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
  const place = await placeOf(io)
  const now = io.now()
  const read = await readProjects(io, place, input.all === true, now)

  print(io, command.act(listed(read, place.here, now), place.here, input))

  return EXIT.done
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

  return command.on === 'work'
    ? onWork(io, command, input.value)
    : onProjects(io, command, input.value)
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
