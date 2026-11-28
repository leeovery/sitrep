/**
 * A command on a session, acted: the session read, the command's rules,
 * then its lines appended, and what it prints, printing nothing itself.
 * `main` runs every command on a session through it, and the panel its
 * snoozes, its wake and its answers, from the words `sitrep` would be
 * given, so each writes the line the command writes.
 *
 * It writes as the writer `cli`, appending to `<session>/cli.jsonl` and
 * never rewriting it, and an answer to its letters in the session's inbox,
 * `<session>/inbox/cli.jsonl`, the same way; each file's count goes on from
 * that file.
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
import { parseWords, type Fields } from './args'
import type { SessionCommand } from './commands'
import { findSession, readBoardAt, textAt, type Found } from './files'
import type { Env, Io } from './io'

/** The writer the CLI writes as, whichever script or tool runs it. */
export const WRITER = 'cli'

/** What acting came to: what to print; or why not, and whether it was refused or found no such session. */
export type Acted = { ok: true; value: string } | { ok: false; error: string; ending: 'refused' | 'noSession' }

const NAME_THE_SESSION =
  'Name the session: --session sr-xxxxxx, or SITREP_SESSION in the environment.'

const refused = (error: string): Acted => ({ ok: false, error, ending: 'refused' })

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

/** A command on a session, on its fields: the session read as it stands now, its checks, and its lines appended, dated as they are written. */
export const actOn = async (io: Io, command: SessionCommand, input: Fields): Promise<Acted> => {
  const now = io.now()
  const id = sessionIdOf(input, io.env)

  if (!id.ok) {
    return refused(id.error)
  }

  const found = await findSession(io, rootOf(io.env), id.value, now)

  if (found === undefined) {
    return { ok: false, error: `There is no session ${id.value} on the board, in any project.`, ending: 'noSession' }
  }

  const version = manifestVersion((await textAt(io, io.manifest)) ?? '')
  const board = await boardFor(io, command, found, now)
  const acted = command.act(found, input, { random: io.random, version, now, ...board })

  if (!acted.ok) {
    return refused(acted.error)
  }

  await post(io, fileFor(found, command), acted.value.post, io.now())

  return { ok: true, value: acted.value.print }
}

/** A command on a session, on the words `sitrep` would be given after its name. */
export const actOnWords = async (io: Io, command: SessionCommand, words: readonly string[]): Promise<Acted> => {
  const input = parseWords(command.grammar, words)

  return input.ok ? actOn(io, command, input.value) : refused(`${input.error} sitrep ${command.name} --help says more.`)
}
