/**
 * A project's identity. A git repository is one project however many
 * worktrees it has, so it is known by its common dir; a folder outside git
 * is known by its own path.
 */

export type Project = {
  /** Folder-safe and collision-resistant: the name's slug and a hash of the path. */
  key: string
  /** The repository's folder name. */
  name: string
}

const FNV_OFFSET = 0x811c9dc5
const FNV_PRIME = 0x01000193

/** The longest slug a key keeps; the hash after it does the telling apart. */
const SLUG_LENGTH = 32

/** The slug for a name with no letters or digits in it. */
const NAMELESS = 'project'

/** FNV-1a, 32 bits, over the text's UTF-8 bytes. */
export const fnv1a = (text: string) => {
  let hash = FNV_OFFSET

  for (const byte of new TextEncoder().encode(text)) {
    hash = Math.imul(hash ^ byte, FNV_PRIME) >>> 0
  }

  return hash
}

const slug = (name: string) =>
  name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .slice(0, SLUG_LENGTH)
    .replace(/^-+|-+$/g, '') || NAMELESS

/** The repository's folder: the common dir's parent, or a bare repository's own folder less `.git`. */
const nameOf = (path: string) => {
  const parts = path.split('/')
  const last = parts.at(-1) ?? ''

  return last === '.git' ? (parts.at(-2) ?? '') : last.replace(/\.git$/, '')
}

/** The project a git common dir (or, outside git, a folder) belongs to. The path is absolute. */
export const projectOf = (dir: string): Project => {
  const path = dir.replace(/\/+$/, '') || '/'
  const name = nameOf(path) || path

  return { key: `${slug(name)}-${fnv1a(path).toString(16).padStart(8, '0')}`, name }
}

/**
 * What a front end asks git, in the folder it works in, for the project's
 * identity: the repository's common dir, spelled the same however the
 * folder was reached.
 */
export const COMMON_DIR = [
  'git',
  'rev-parse',
  '--path-format=absolute',
  '--git-common-dir',
] as const

/**
 * What a folder's project is known by, from git's answer to `COMMON_DIR`
 * there; outside git, or with no answer, the folder itself.
 */
export const identityOf = (cwd: string, git?: { exitCode: number; stdout: string }) =>
  (git?.exitCode === 0 ? git.stdout.trim() : '') || cwd
