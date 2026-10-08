/** A work's work.json: what it was started as, written once by whoever started it. */
import { VERSION } from './entries'

export type WorkMeta = {
  id: string
  name: string
  summary: string
  /** The project's name, for views that span projects. */
  project: string
  /** Where the work was started. */
  root: string
  created: number
  by: string
}

const TEXTS = ['id', 'name', 'summary', 'project', 'root', 'by'] as const

export const metaText = (meta: WorkMeta) => `${JSON.stringify({ v: VERSION, ...meta })}\n`

/** work.json's meta; undefined when the file is torn, bad or of another version. */
export const parseMeta = (text: string): WorkMeta | undefined => {
  let raw: { [key: string]: unknown }

  try {
    raw = JSON.parse(text) ?? {}
  } catch {
    return undefined
  }

  const isWhole =
    raw.v === VERSION &&
    typeof raw.created === 'number' &&
    TEXTS.every(key => typeof raw[key] === 'string')

  if (!isWhole) {
    return undefined
  }

  const { id, name, summary, project, root, created, by } = raw as WorkMeta

  return { id, name, summary, project, root, created, by }
}
