/**
 * The engine beneath the mod, for its tests: a file system in memory, a
 * repository git knows, the session, the environment and the clock, and a
 * record of what the mod puts in `$.state`. Nothing touches a real folder.
 */
import type { On } from 'claude-code'
import { mock, type Engine } from 'claude-code/testing'
import { metaText, presenceText, projectOf, workPaths, type Presence, type WorkMeta } from '../core'
import type { SitrepAttachment, SitrepBoard } from '../types'
import { T0, W1 } from './support'

export const STATE_HOME = '/state'
export const ROOT = `${STATE_HOME}/sitrep`

/** The repository the session works in, a worktree of it, and a folder outside git. */
export const REPO = '/Users/lee/Code/switchboard'
export const WORKTREE = '/Users/lee/Code/switchboard-wt'
export const LOOSE = '/Users/lee/notes'

export const PROJECT = projectOf(`${REPO}/.git`)

/** Another project, with a work of its own. */
export const ELSEWHERE = projectOf('/Users/lee/Code/goosemates/.git')

export const SESSION = { cwd: REPO, surface: 'terminal' as const, isInteractive: true }

export const DASHBOARD = {
  name: 'Dashboard redesign',
  summary: 'Redesign the dashboard, area by area',
}

export const PROMPT = { text: 'Carry on.', wait: false, origin: { kind: 'composer' as const } }

/** What a test calls a tool with: its short name and its arguments. */
type Args = { [key: string]: unknown }

type File = { text: string; mtimeMs: number }

const MISSING = (path: string) => ({ deny: `ENOENT: no such file or directory, ${path}` })

const isUnder = (dir: string, path: string) => path.startsWith(`${dir}/`)

export function world(engine: Engine, on: On, options: { now?: number; cwd?: string } = {}) {
  const clock = mock.clock(on, { now: options.now ?? T0 })
  const files = new Map<string, File>()
  const state: {
    attachment?: SitrepAttachment | null
    board?: SitrepBoard | null
    seen?: string | null
  } = {}
  const boards: (SitrepBoard | null)[] = []
  const logs: string[] = []
  const registered: { name: string; isDeferred?: boolean }[] = []
  let session = W1
  let cwd = options.cwd ?? REPO
  let dropping: string | undefined

  mock.env(on, { XDG_STATE_HOME: STATE_HOME, HOME: '/Users/lee' })

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('prompt.submit', ($, e) =>
    dropping === undefined
      ? { text: e.text, context: e.context, origin: e.origin }
      : { drop: dropping },
  )
  on('session.id', () => ({ value: session }))
  on('session.cwd', () => ({ value: cwd }))

  on('tool.register', ($, e) => {
    registered.push({ name: e.name, isDeferred: e.isDeferred })

    return { value: { tool: `mcp__sitrep__${e.name}` } }
  })

  on('ui.log', ($, e) => {
    logs.push(e.text)

    return { value: undefined }
  })

  on('process.run', ($, e) => {
    const where = e.init?.cwd ?? cwd
    const isRepo = where === REPO || where === WORKTREE

    return {
      value: {
        exitCode: isRepo ? 0 : 128,
        stdout: isRepo ? `${REPO}/.git\n` : '',
        stderr: isRepo ? '' : 'fatal: not a git repository',
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }
  })

  on('state.set', ($, e, next) => {
    Object.assign(state, { [e.key]: e.value })

    if (e.key === 'board') {
      boards.push(e.value as SitrepBoard | null)
    }

    return next(e)
  })

  on('fs.read', ($, e) => {
    const file = files.get(e.path)

    return file === undefined ? MISSING(e.path) : { value: file.text }
  })

  on('fs.write', ($, e) => {
    files.set(e.path, { text: e.text, mtimeMs: clock.now() })

    return { value: undefined }
  })

  on('fs.exists', ($, e) => ({
    value: files.has(e.path) || [...files.keys()].some(path => isUnder(e.path, path)),
  }))

  on('fs.list', ($, e) => {
    const under = [...files.entries()].filter(([path]) => isUnder(e.path, path))

    if (under.length === 0) {
      return MISSING(e.path)
    }

    const entries = new Map<string, { kind: 'file' | 'dir'; size: number; mtimeMs: number }>()

    for (const [path, file] of under) {
      const [name = '', ...deeper] = path.slice(e.path.length + 1).split('/')

      entries.set(
        name,
        deeper.length > 0
          ? { kind: 'dir', size: 0, mtimeMs: 0 }
          : {
              kind: 'file',
              size: new TextEncoder().encode(file.text).length,
              mtimeMs: file.mtimeMs,
            },
      )
    }

    return { value: [...entries].map(([name, entry]) => ({ name, ...entry, isLink: false })) }
  })

  /** Writes a file as another writer would: a window elsewhere, the CLI, Lee's board. */
  const put = (path: string, text: string) => files.set(path, { text, mtimeMs: clock.now() })

  /** The text of a file, failing the test when it is not there. */
  const text = (path: string) => {
    const file = files.get(path)

    if (file === undefined) {
      throw new Error(`no file at ${path}`)
    }

    return file.text
  }

  /** A work started by another window, filed under `project`. */
  const seed = (meta: WorkMeta, project = PROJECT.key) =>
    put(workPaths(ROOT, project, meta.id).meta, metaText(meta))

  /** Another window's heartbeat on a work. */
  const beat = (id: string, presence: Presence, project = PROJECT.key) =>
    put(workPaths(ROOT, project, id).heartbeat(presence.writer), presenceText(presence))

  /** Calls one of sitrep's tools from the main conversation, or from a subagent given its id. */
  const call = (name: string, args: Args = {}, agentId?: string) =>
    engine.tool.call({
      tool: `mcp__sitrep__${name}`,
      ...args,
      ...(agentId === undefined ? {} : { agentId }),
    } as never) as Promise<{ result?: unknown; deny?: string }>

  /** The session started, and a piece of work started in it: its id and its folder's paths. */
  const begin = async () => {
    await engine.session.start(SESSION)

    const id = startedId(await call('start', DASHBOARD))

    return { id, paths: workPaths(ROOT, PROJECT.key, id) }
  }

  /** The session from here on: another id, as after a /clear, or another folder. */
  const become = (next: { session?: string; cwd?: string }) => {
    session = next.session ?? session
    cwd = next.cwd ?? cwd
  }

  /** Prompts from here on do not enter, for that reason; or, given none, they enter again. */
  const dropPrompts = (reason?: string) => {
    dropping = reason
  }

  return {
    clock,
    files,
    state,
    boards,
    logs,
    registered,
    put,
    text,
    seed,
    beat,
    call,
    begin,
    become,
    dropPrompts,
  }
}

/** The work id a start's answer names. */
export const startedId = (answer: { result?: unknown }) => {
  const id = String(answer.result).match(/\bsr-[0-9a-z]+/)?.[0]

  if (id === undefined) {
    throw new Error(`no work id in ${String(answer.result)}`)
  }

  return id
}

/** The item id an answer names, after the words given. */
export const postedId = (answer: { result?: unknown }) => {
  const id = String(answer.result).match(/ ([0-9a-z]{4,})\.$/)?.[1]

  if (id === undefined) {
    throw new Error(`no item id in ${String(answer.result)}`)
  }

  return id
}
