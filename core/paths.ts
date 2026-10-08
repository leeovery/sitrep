/**
 * Where sitrep's files live. Core names the paths; the front ends read and
 * write them.
 *
 *   <root>/projects/<project key>/works/<work id>/
 *     work.json               the work as it was started
 *     <writer>.jsonl          one file per writer
 *     inbox/<sender>.jsonl    replies sent from other works, one file per sender
 *     presence/<writer>.json  each attached window's heartbeat
 */

/** The folder under the state home. */
const FOLDER = 'sitrep'

/** The state home when `XDG_STATE_HOME` names none, under `HOME`. */
const STATE_HOME = '.local/state'

export const META_FILE = 'work.json'
export const LOG_SUFFIX = '.jsonl'
export const PRESENCE_SUFFIX = '.json'

/** What a project key, work id or writer may be, so none of them can climb out of its folder. */
const SAFE_NAME = /^[A-Za-z0-9_-]+$/

export type WorkPaths = {
  dir: string
  meta: string
  inbox: string
  presence: string
  /** A writer's own file in the work. */
  log: (writer: string) => string
  /** A sender's file in the work's inbox. */
  letters: (sender: string) => string
  /** A window's heartbeat on the work. */
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

export const worksDir = (root: string, project: string) =>
  `${projectsDir(root)}/${safe(project)}/works`

export const workPaths = (root: string, project: string, id: string): WorkPaths => {
  const dir = `${worksDir(root, project)}/${safe(id)}`
  const inbox = `${dir}/inbox`
  const presence = `${dir}/presence`

  return {
    dir,
    meta: `${dir}/${META_FILE}`,
    inbox,
    presence,
    log: writer => `${dir}/${safe(writer)}${LOG_SUFFIX}`,
    letters: sender => `${inbox}/${safe(sender)}${LOG_SUFFIX}`,
    heartbeat: writer => `${presence}/${safe(writer)}${PRESENCE_SUFFIX}`,
  }
}

/** Whether a listed folder's name is one sitrep files under: a project key, a work id, a writer. */
export const isSafeName = (name: string) => SAFE_NAME.test(name)

/**
 * The projects to look in, of the folders listed under `projects/`: `here`
 * first, listed or not, then every other. A work id is looked up in this
 * order, so the project a front end works in wins.
 */
export const projectKeys = (here: string, listed: readonly string[]) => [
  here,
  ...listed.filter(key => key !== here && isSafeName(key)),
]

/** The writer a listed file belongs to, given its folder's suffix; undefined for any other file. */
export const writerOf = (fileName: string, suffix: string) => {
  const writer = fileName.slice(0, -suffix.length)

  return fileName.endsWith(suffix) && SAFE_NAME.test(writer) ? writer : undefined
}
