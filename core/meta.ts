/** A session's session.json: what it was started as, written once by whoever started it. */
import { parseVersioned } from './entries'
import { versionOf, type Upgrade } from './versions'

export type SessionMeta = {
  id: string
  name: string
  summary: string
  /** The project's name as the session was started in it; the project's own file names it since. */
  project: string
  /** Where the session was started. */
  root: string
  created: number
  by: string
}

/** How a session.json of each past version is brought to the next: none yet. */
const UPGRADES: readonly Upgrade[] = []

const TEXTS = ['id', 'name', 'summary', 'project', 'root', 'by'] as const

export const metaText = (meta: SessionMeta) =>
  `${JSON.stringify({ v: versionOf(UPGRADES), ...meta })}\n`

/** session.json's meta, in today's shape; undefined when the file is torn, bad or of a later version. */
export const parseMeta = (text: string): SessionMeta | undefined => {
  const raw = parseVersioned(text, UPGRADES) ?? {}
  const isWhole =
    typeof raw.created === 'number' && TEXTS.every(key => typeof raw[key] === 'string')

  if (!isWhole) {
    return undefined
  }

  const { id, name, summary, project, root, created, by } = raw as SessionMeta

  return { id, name, summary, project, root, created, by }
}
