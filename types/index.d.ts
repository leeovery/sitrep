/**
 * sitrep's values in `$.state`: the piece of work this window is attached
 * to, that work as its files fold, the board as Claude last saw it, the
 * works around it as the board draws them, and the window's own state as
 * Lee works the board.
 *
 * The engine takes only a self-contained contract, so the board's types
 * mirror core's (core/types.ts). hooks/board.ts converts a folded work to a
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

/** A piece of work as it is filed: its project's key, and its id. */
export type SitrepWorkRef = {
  project: string
  work: string
}

/** An item of a piece of work's, wherever the board shows it. */
export type SitrepItemRef = SitrepWorkRef & { item: string }

/** A reply of Lee's waiting in Ready to send: the item it answers, and what it says. */
export type SitrepQueued = SitrepItemRef & {
  verdict: SitrepVerdict
  option?: string
  note?: string
}

/** Replies this window wrote into another work's inbox, by their ids: shown in Ready to send until Claude has them. */
export type SitrepSent = SitrepWorkRef & { replies: string[] }

/** Inbox replies this window submitted as Lee's message: on their way until the delivered mark is written. */
export type SitrepDelivering = {
  work: string
  replies: string[]
  /** The message, as a turn it starts carries it. */
  text: string
  /** Whether Claude Code has taken the message, its mark still to write. */
  isTaken: boolean
}

/** A piece of work in brief: core's `WorkSummary`. */
export type SitrepSummary = {
  id: string
  name: string
  summary: string
  project: string
  now: string[]
  next?: string
  isOpen: boolean
  waiting: number
  parked: number
  updatedAt: number
}

/** A piece of work as views beyond its own draw it: core's `WorkBrief`. */
export type SitrepBrief = SitrepSummary & {
  log: SitrepLogLine[]
  parkedItems: SitrepParked[]
}

/** A project as last read: its key, and its current works other than the held one, in brief. */
export type SitrepProject = {
  key: string
  works: SitrepBrief[]
}

/** Another piece of work the board draws in full, and the project it is filed under. */
export type SitrepOther = {
  project: string
  board: SitrepBoard
}

/** Where the board is looking: a piece of work, a project's works, or every project. */
export type SitrepPlace =
  | ({ level: 'session' } & SitrepWorkRef)
  | { level: 'project'; project: string }
  | { level: 'all' }

/** What the board shows where it is looking: its view of the place, or what the place parked. */
export type SitrepView = 'board' | 'parked'

/** The board full, or collapsed to the glance. */
export type SitrepMode = 'full' | 'glance'

/** The board pane as the window keeps it. */
export type SitrepPane = {
  /** Whether the pane is open and drawn, which the band's button follows. */
  isOpen: boolean
  mode: SitrepMode
  /** Null at home: this session. */
  place: SitrepPlace | null
  view: SitrepView
  /** The item (or log line) opened under its line. */
  selected: string | null
  /** The ask whose comment field is open. */
  commenting: SitrepItemRef | null
}

/** New asks pulsing, and how many frames of the pulse are left. */
export type SitrepPulse = {
  asks: string[]
  frames: number
}

declare module 'claude-code' {
  interface PluginState {
    sitrep: {
      attachment: SitrepAttachment | null
      /** The attached work, folded; null with none attached. */
      board: SitrepBoard | null
      /** `boardText` as Claude last saw it: a start, a join, a read, its own post, or a turn's context. */
      seen: string | null
      /** The projects last read: the held work's, and while the board is open those it looks at. */
      projects: SitrepProject[]
      /** The other works the board draws in full: the session it looks at, and those replies wait for or went to. */
      others: SitrepOther[]
      /** Ready to send, in the order queued. */
      queue: SitrepQueued[]
      /** The replies of a send Claude Code has not taken yet: frozen in the queue until it does. */
      sending: SitrepQueued[]
      /** Where replies written into other works' inboxes went, until Claude has them. */
      sent: SitrepSent[]
      /** The inbox delivery on its way to Claude, or null. */
      delivering: SitrepDelivering | null
      pane: SitrepPane
      /** What has been typed in the open comment field. */
      draft: string
      pulse: SitrepPulse
      /** How many replies from the board the band is flashing as just taken in; 0 for none. */
      flash: number
      /** A count moved on as time passes, so what the board draws from the time is drawn again. */
      tick: number
    }
  }
}
