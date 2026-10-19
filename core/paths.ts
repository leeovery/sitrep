/**
 * Where sitrep's files live. Core names the paths; the front ends read and
 * write them.
 *
 *   <root>/projects/<project key>/
 *     project.json              the project's name and directory
 *     sessions/<session id>/
 *       session.json            the session as it was started
 *       <writer>.jsonl          one file per writer
 *       inbox/<sender>.jsonl    replies from other sessions, one file per sender
 *       presence/<writer>.json  each attached window's heartbeat
 *     works/<session id>/       the old layout, the same but for its meta:
 *       work.json               read beside today's, never written, and
 *                               moved into it by the CLI
 */

/** The folder under the state home. */
const FOLDER = 'sitrep'

/** The state home when `XDG_STATE_HOME` names none, under `HOME`. */
const STATE_HOME = '.local/state'

export const PROJECT_FILE = 'project.json'
export const LOG_SUFFIX = '.jsonl'
export const PRESENCE_SUFFIX = '.json'

/** How a project files its sessions: the folder they sit in, and the name of each one's meta. */
type Layout = { sessions: string; meta: string }

/** Today's layout, the only one written. */
const LAYOUT: Layout = { sessions: 'sessions', meta: 'session.json' }

/**
 * The old layout, which windows not yet reloaded still write: read beside
 * today's until the CLI moves it, once no window runs a version that does.
 */
const OLD_LAYOUT: Layout = { sessions: 'works', meta: 'work.json' }

/** What a project key, session id or writer may be, so none of them can climb out of its folder. */
const SAFE_NAME = /^[A-Za-z0-9_-]+$/

/** A project's folder, and its file there. */
export type ProjectPaths = { dir: string; file: string }

/** A session's folder and its files, under one layout. */
export type SessionFolder = {
  /** The folder the project files its sessions in, under this layout. */
  sessions: string
  dir: string
  meta: string
  inbox: string
  presence: string
  /** A writer's own file in the session. */
  log: (writer: string) => string
  /** A sender's file in the session's inbox. */
  letters: (sender: string) => string
  /** A window's heartbeat on the session. */
  heartbeat: (writer: string) => string
}

/**
 * A session's paths: its folder under today's layout, where everything is
 * written, the project it is filed under, and its folder under the old
 * layout, read beside today's.
 */
export type SessionPaths = SessionFolder & {
  project: ProjectPaths
  old: SessionFolder
}

const safe = (name: string) => {
  if (!SAFE_NAME.test(name)) {
    throw new Error(`Not a name sitrep files under: ${JSON.stringify(name)}`)
  }

  return name
}

/** sitrep's folder: `$XDG_STATE_HOME/sitrep`, else `$HOME/.local/state/sitrep`. */
export const rootOf = (env: { XDG_STATE_HOME?: string; HOME?: string }) => {
  const { XDG_STATE_HOME: state, HOME: home } = env

  // The XDG spec has a relative or empty value ignored.
  if (state?.startsWith('/')) {
    return `${state.replace(/\/+$/, '')}/${FOLDER}`
  }

  if (home?.startsWith('/')) {
    return `${home.replace(/\/+$/, '')}/${STATE_HOME}/${FOLDER}`
  }

  throw new Error('sitrep needs HOME or XDG_STATE_HOME to place its folder')
}

export const projectsDir = (root: string) => `${root}/projects`

export const projectPaths = (root: string, project: string): ProjectPaths => {
  const dir = `${projectsDir(root)}/${safe(project)}`

  return { dir, file: `${dir}/${PROJECT_FILE}` }
}

const sessionsUnder = (root: string, project: string, layout: Layout) =>
  `${projectPaths(root, project).dir}/${layout.sessions}`

/** The folder a project files its sessions in. */
export const sessionsDir = (root: string, project: string) => sessionsUnder(root, project, LAYOUT)

/** The folder a project filed its sessions in under the old layout. */
export const oldSessionsDir = (root: string, project: string) =>
  sessionsUnder(root, project, OLD_LAYOUT)

const folderOf = (root: string, project: string, id: string, layout: Layout): SessionFolder => {
  const sessions = sessionsUnder(root, project, layout)
  const dir = `${sessions}/${safe(id)}`
  const inbox = `${dir}/inbox`
  const presence = `${dir}/presence`

  return {
    sessions,
    dir,
    meta: `${dir}/${layout.meta}`,
    inbox,
    presence,
    log: writer => `${dir}/${safe(writer)}${LOG_SUFFIX}`,
    letters: sender => `${inbox}/${safe(sender)}${LOG_SUFFIX}`,
    heartbeat: writer => `${presence}/${safe(writer)}${PRESENCE_SUFFIX}`,
  }
}

export const sessionPaths = (root: string, project: string, id: string): SessionPaths => ({
  ...folderOf(root, project, id, LAYOUT),
  project: projectPaths(root, project),
  old: folderOf(root, project, id, OLD_LAYOUT),
})

/** Where a file of a session's old folder goes in today's: the same place, its meta named anew. */
export const movedTo = (paths: SessionPaths, path: string) =>
  path === paths.old.meta ? paths.meta : `${paths.dir}${path.slice(paths.old.dir.length)}`

/** Whether a listed folder's name is one sitrep files under: a project key, a session id, a writer. */
export const isSafeName = (name: string) => SAFE_NAME.test(name)

/** The writer a listed file belongs to, given its folder's suffix; undefined for any other file. */
export const writerOf = (fileName: string, suffix: string) => {
  const writer = fileName.slice(0, -suffix.length)

  return fileName.endsWith(suffix) && SAFE_NAME.test(writer) ? writer : undefined
}
