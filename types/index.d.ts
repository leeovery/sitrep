/**
 * sitrep's values in `$.state`: the piece of work this window is attached
 * to, that work as its files fold, and the board as Claude last saw it.
 *
 * The engine takes only a self-contained contract, so the board's types
 * mirror core's (core/types.ts). hooks/state.ts converts a folded work to a
 * board and back, so the compiler holds each to the other.
 */

export type SitrepAskKind = 'review' | 'decide' | 'try' | 'do'

export type SitrepVerdict = 'yes' | 'choose' | 'comment' | 'ignore' | 'pickup'

export type SitrepDelivery = 'delivered' | 'waiting' | 'closed'

export type SitrepStatus = {
  name: string
  summary: string
  now: string[]
  next?: string
  at: number
  by: string
}

export type SitrepReply = {
  id: string
  item: string
  verdict: SitrepVerdict
  option?: string
  note?: string
  by: string
  at: number
  delivery: SitrepDelivery
  deliveredAt?: number
}

export type SitrepPosted = {
  id: string
  by: string
  at: number
  openedAt: number
  closedAt?: number
  editedAt?: number
  reason?: string
  ref?: string
}

export type SitrepAsk = SitrepPosted & {
  type: 'ask'
  kind: SitrepAskKind
  title: string
  where?: string
  options?: string[]
  state: 'waiting' | 'replied' | 'closed' | 'ignored'
  answer?: SitrepReply
  replies: SitrepReply[]
}

export type SitrepNote = SitrepPosted & {
  type: 'note'
  text: string
  detail?: string[]
  state: 'open' | 'closed'
}

export type SitrepParked = SitrepPosted & {
  type: 'park'
  title: string
  where?: string
  state: 'parked' | 'picked' | 'closed'
  answer?: SitrepReply
  replies: SitrepReply[]
}

export type SitrepItem = SitrepAsk | SitrepNote | SitrepParked

export type SitrepLogLine = {
  kind: 'note' | 'status' | 'pickup'
  at: number
  by: string
  text: string
  detail: string[]
  ref?: string
  id?: string
}

export type SitrepPresence = {
  writer: string
  attachedAt: number
  seenAt: number
  leftAt?: number
}

/** A folded work as plain data: core's `Work`, its map of items and set of ids as lists. */
export type SitrepBoard = {
  id: string
  project: string
  root: string
  created: number
  by: string
  status: SitrepStatus
  asks: SitrepAsk[]
  parked: SitrepParked[]
  /** Every item, in the order posted. */
  items: SitrepItem[]
  replies: SitrepReply[]
  log: SitrepLogLine[]
  presence: SitrepPresence[]
  isOpen: boolean
  deliverer?: string
  waiting: number
  ids: string[]
  updatedAt: number
}

/** The piece of work this window is attached to, and as whom. */
export type SitrepAttachment = {
  /** The project's key: the folder its works are under. */
  project: string
  work: string
  /** The session id the window attached as: its file and heartbeat in the work. */
  writer: string
  attachedAt: number
}

declare module 'claude-code' {
  interface PluginState {
    sitrep: {
      attachment: SitrepAttachment | null
      /** The attached work, folded; null with none attached. */
      board: SitrepBoard | null
      /** `boardText` as Claude last saw it: a start, a join, a read, its own post, or a turn's context. */
      seen: string | null
    }
  }
}
