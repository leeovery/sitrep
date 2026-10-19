/**
 * `$.state` as a load of the mod from before a piece of work was called a
 * session may have left it, read in today's names. `$.state` outlives a
 * reload, so a window that reloads mid-session hands this load values whose
 * session is still a `work`, a project's sessions its `works`, and RESOLVED
 * shown in full its `doneInFull`; read through these, the window keeps its
 * session, its place on the board, what waits in Ready to send and what is
 * on its way. Writes are in today's names only, so each value is read in the
 * old ones only until this load first writes it.
 */
import type {
  SitrepAnswering,
  SitrepAttachment,
  SitrepInFlight,
  SitrepPane,
  SitrepPlace,
  SitrepProject,
  SitrepQueued,
  SitrepScroll,
  SitrepSent,
  SitrepSessionRef,
} from '../types'
import { RESOLVED_KEY } from './draw/earlier'

/** What an older load named otherwise: a session as its `work`, a project's sessions as its `works`, RESOLVED in full as `doneInFull`. */
type Older = { work?: string; works?: SitrepProject['sessions']; doneInFull?: string | null }

/** What an older load opened a closed ask by, as DONE's, where this load has RESOLVED's. */
const DONE_KEY = 'done:'

const asOlder = (value: object) => value as Older

const sessionRef = <T extends SitrepSessionRef>(ref: T): T => {
  const { work, ...rest } = asOlder(ref)

  return 'session' in ref || work === undefined ? ref : ({ ...rest, session: work } as T)
}

const orNull =
  <T>(read: (value: T) => T) =>
  (value: T | null) =>
    value === null ? null : read(value)

const placeOf = (at: SitrepPlace): SitrepPlace => (at.level === 'session' ? sessionRef(at) : at)

const project = (read: SitrepProject): SitrepProject => {
  const { works, ...rest } = asOlder(read)

  return 'sessions' in read || works === undefined
    ? read
    : { ...(rest as SitrepProject), sessions: works }
}

const selected = (key: string | null) =>
  key?.startsWith(DONE_KEY) ? `${RESOLVED_KEY}${key.slice(DONE_KEY.length)}` : key

const pane = (kept: SitrepPane): SitrepPane => {
  const { doneInFull, ...rest } = asOlder(kept)
  const resolvedInFull = 'resolvedInFull' in kept ? kept.resolvedInFull : doneInFull

  return {
    ...(rest as SitrepPane),
    place: kept.place && placeOf(kept.place),
    selected: selected(kept.selected),
    ...(resolvedInFull === undefined ? {} : { resolvedInFull }),
  }
}

/** Each slot an older load named otherwise, read in today's names; any other slot reads as it is. */
export const fromOlder = {
  attachment: orNull<SitrepAttachment>(sessionRef),
  projects: (read: SitrepProject[]) => read.map(project),
  queue: (queued: SitrepQueued[]) => queued.map(sessionRef),
  sent: (sent: SitrepSent[]) => sent.map(sessionRef),
  inFlight: orNull<SitrepInFlight>(sessionRef),
  pane,
  scroll: orNull<SitrepScroll>(kept => ({ ...kept, place: placeOf(kept.place) })),
  answering: orNull<SitrepAnswering>(sessionRef),
}
