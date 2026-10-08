/**
 * The board's nouns as data: what each line of a writer's file holds, and
 * what a piece of work folds to once every writer's lines are read together.
 */

/** What an ask wants of Lee. It chooses the ask's first button and is never shown as a word. */
export type AskKind = 'review' | 'decide' | 'try' | 'do'

/**
 * Lee's answer: a yes (approve, it works, done), an option, a comment (an
 * answer, on a decide), an ignore, or a pick-up of a parked item.
 */
export type Verdict = 'yes' | 'choose' | 'comment' | 'ignore' | 'pickup'

/**
 * Where a reply stands: Claude has it; it goes in when its work's window
 * ends its turn; no window has the work, so it waits for one to join; or
 * its item changed under it before it went in, so it goes nowhere.
 */
export type Delivery = 'delivered' | 'waiting' | 'closed' | 'void'

export type StatusBody = {
  type: 'status'
  name: string
  summary: string
  now: string[]
  next?: string
}

export type AskBody = {
  type: 'ask'
  id: string
  kind: AskKind
  title: string
  where?: string
  options?: string[]
  ref?: string
}

export type NoteBody = {
  type: 'note'
  id: string
  text: string
  detail?: string[]
  ref?: string
}

export type ParkBody = {
  type: 'park'
  id: string
  title: string
  where?: string
  ref?: string
}

/** The fields an edit may change; which of them apply depends on the item's type. */
export type Changes = {
  kind?: AskKind
  title?: string
  where?: string
  options?: string[]
  ref?: string
  text?: string
  detail?: string[]
}

/** The fields an edit changes, by the type of item. */
export const EDITABLE: Record<Item['type'], readonly (keyof Changes)[]> = {
  ask: ['kind', 'title', 'where', 'options', 'ref'],
  note: ['text', 'detail', 'ref'],
  park: ['title', 'where', 'ref'],
}

export type ResolveBody = { type: 'resolve'; item: string; reason?: string }
export type ReopenBody = { type: 'reopen'; item: string; reason?: string }
export type EditBody = { type: 'edit'; item: string; changes: Changes; reason?: string }

export type ReplyBody = {
  type: 'reply'
  id: string
  item: string
  verdict: Verdict
  option?: string
  note?: string
}

export type DeliveredBody = { type: 'delivered'; replies: string[] }

/** What one line of a writer's file says. */
export type Body =
  | StatusBody
  | AskBody
  | NoteBody
  | ParkBody
  | ResolveBody
  | ReopenBody
  | EditBody
  | ReplyBody
  | DeliveredBody

/** A line as written: its body, stamped with the format's version, the time and the writer's own count. */
export type Entry = Body & { v: number; at: number; seq: number }

/** Where a piece of work stands, as its latest status says, and who said it when. */
export type Status = {
  name: string
  summary: string
  now: string[]
  next?: string
  at: number
  by: string
}

export type Reply = {
  id: string
  item: string
  verdict: Verdict
  option?: string
  note?: string
  by: string
  at: number
  delivery: Delivery
  deliveredAt?: number
  /** When the edit that left it fitting its item no more was made. */
  voidedAt?: number
}

/** What every posted item carries: who posted it when, and when it was last opened, closed or edited. */
type Posted = {
  id: string
  by: string
  at: number
  openedAt: number
  closedAt?: number
  editedAt?: number
  reason?: string
  ref?: string
}

/**
 * `waiting` on Lee; `replied`, a comment delivered and Claude to act on it;
 * `closed`; or `ignored`, closed by Lee's ignore.
 */
export type AskState = 'waiting' | 'replied' | 'closed' | 'ignored'

export type Ask = Posted & {
  type: 'ask'
  kind: AskKind
  title: string
  where?: string
  options?: string[]
  state: AskState
  /** The delivered reply that last moved it, since it was opened or reopened. */
  answer?: Reply
  replies: Reply[]
}

export type Note = Posted & {
  type: 'note'
  text: string
  detail?: string[]
  state: 'open' | 'closed'
}

export type Parked = Posted & {
  type: 'park'
  title: string
  where?: string
  state: 'parked' | 'picked' | 'closed'
  answer?: Reply
  replies: Reply[]
}

export type Item = Ask | Note | Parked

/** A line of the log: a note Claude wrote, or a status change or pick-up the board noticed. */
export type LogLine = {
  kind: 'note' | 'status' | 'pickup'
  at: number
  by: string
  text: string
  detail: string[]
  ref?: string
  /** The note's id; a line the board derived has none. */
  id?: string
}

/** A window's heartbeat on a piece of work; `leftAt` once it has let go. */
export type Presence = {
  writer: string
  attachedAt: number
  seenAt: number
  leftAt?: number
}

/** A piece of work as it stands, every writer's lines read together. */
export type Work = {
  id: string
  /** The project's name. */
  project: string
  root: string
  created: number
  by: string
  status: Status
  /** Every ask, oldest first. */
  asks: Ask[]
  /** What is still parked, oldest first. */
  parked: Parked[]
  items: ReadonlyMap<string, Item>
  /** Every reply that fitted its item as it was written, oldest first. */
  replies: Reply[]
  /** Newest first. */
  log: LogLine[]
  presence: Presence[]
  /** Whether a window is attached: a live presence. */
  isOpen: boolean
  /** The window that submits inbox replies: the oldest live presence. */
  deliverer?: string
  /** Asks waiting on Lee. */
  waiting: number
  /** Every id the work's lines use, items and replies alike. */
  ids: ReadonlySet<string>
  /** The latest line's time, or when the work was started. */
  updatedAt: number
}
