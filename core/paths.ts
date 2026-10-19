/**
 * Where sitrep's files live. Core names the paths; the front ends read and
 * write them.
 *
 *   <root>/projects/<project key>/
 *     project.json              the project's name and directory
 *     works/<session id>/
 *       work.json               the session as it was started
 *       <writer>.jsonl          one file per writer
 *       inbox/<sender>.jsonl    replies from other sessions, one file per sender
 *       presence/<writer>.json  each attached window's heartbeat
 */

/** The folder under the state home. */
const FOLDER = 'sitrep'

/** The state home when `XDG_STATE_HOME` names none, under `HOME`. */
const STATE_HOME = '.local/state'

export const PROJECT_FILE = 'project.json'
export const META_FILE = 'work.json'
export const LOG_SUFFIX = '.jsonl'
export const PRESENCE_SUFFIX = '.json'

/** What a project key, session id or writer may be, so none of them can climb out of its folder. */
const SAFE_NAME = /^[A-Za-z0-9_-]+$/

/** A project's folder, and its file there. */
export type ProjectPaths = { dir: string; file: string }

export type SessionPaths = {
  dir: string
  /** The project the session is filed under. */
  project: ProjectPaths
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

export const sessionsDir = (root: string, project: string) =>
  `${projectPaths(root, project).dir}/works`

export const sessionPaths = (root: string, project: string, id: string): SessionPaths => {
  const dir = `${sessionsDir(root, project)}/${safe(id)}`
  const inbox = `${dir}/inbox`
  const presence = `${dir}/presence`

  return {
    dir,
    project: projectPaths(root, project),
    meta: `${dir}/${META_FILE}`,
    inbox,
    presence,
    log: writer => `${dir}/${safe(writer)}${LOG_SUFFIX}`,
    letters: sender => `${inbox}/${safe(sender)}${LOG_SUFFIX}`,
    heartbeat: writer => `${presence}/${safe(writer)}${PRESENCE_SUFFIX}`,
  }
}

/** Whether a listed folder's name is one sitrep files under: a project key, a session id, a writer. */
export const isSafeName = (name: string) => SAFE_NAME.test(name)

/** The writer a listed file belongs to, given its folder's suffix; undefined for any other file. */
export const writerOf = (fileName: string, suffix: string) => {
  const writer = fileName.slice(0, -suffix.length)

  return fileName.endsWith(suffix) && SAFE_NAME.test(writer) ? writer : undefined
}
