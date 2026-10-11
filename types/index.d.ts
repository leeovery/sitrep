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

export type SitrepWants = 'yes' | 'choice' | 'words'

export type SitrepAskKind = 'review' | 'decide' | 'try' | 'do'

export type SitrepVerdict = 'yes' | 'choose' | 'answer' | 'comment' | 'ignore' | 'pickup'

export type SitrepDelivery = 'delivered' | 'waiting' | 'closed' | 'void'

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
  voidedAt?: number
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
  wants: SitrepWants
  yes?: string
  kind?: SitrepAskKind
  title: string
  where?: string
  options?: string[]
  needs?: string
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

/** A piece of work marked done: core's `Finished`. */
export type SitrepFinished = {
  at: number
  by: string
  who: 'lee' | 'claude'
  reason?: string
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
  finished?: SitrepFinished
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

/**
 * An ask Lee is answering in the prompt box: the next Enter there queues
 * what was written as its answer, or as a comment, and nothing goes to
 * Claude. The ask's title, for the band to name it wherever the ask is.
 */
export type SitrepAnswering = SitrepItemRef & {
  as: 'answer' | 'comment'
  title: string
  /** Where Lee began it, and the only surface whose Enter it takes: the terminal's prompt, or Claude's app's. */
  surface: 'terminal' | 'mobile'
  /** The words the mode put in the prompt box to be written again, if any. */
  filled?: string
}

/** Replies this window wrote into another work's inbox, by their ids: shown in Ready to send until Claude has them. */
export type SitrepSent = SitrepWorkRef & { replies: string[] }

/** A reply as a line of a work's file: core's `ReplyBody`. */
export type SitrepReplyBody = {
  type: 'reply'
  id: string
  item: string
  verdict: SitrepVerdict
  option?: string
  note?: string
}

/** Whose replies a message carries: Lee's send from this window's board, or what other works left in its inbox. */
export type SitrepSource = 'send' | 'inbox'

/**
 * Lee's replies submitted as Lee's own message, one message at a time
 * whatever its source: on their way until Claude Code has taken it and its
 * lines are written into the work it went to.
 */
export type SitrepInFlight = SitrepWorkRef & {
  source: SitrepSource
  /** The window's writer as it claimed the message: whose file in the work records it. */
  writer: string
  /** The message, exactly as submitted: the text the turn it starts carries. */
  text: string
  /** The replies the message carries, their ids fixed as it was claimed. */
  replies: SitrepReplyBody[]
  /** When it was claimed, which tells this claim from a later one of the same text. */
  claimedAt: number
  /** Whether Claude Code has taken the message, its lines still to write. */
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
  isFinished: boolean
  waiting: number
  parked: number
  updatedAt: number
}

/** A piece of work as views beyond its own draw it: core's `WorkBrief`. */
export type SitrepBrief = SitrepSummary & {
  log: SitrepLogLine[]
  parkedItems: SitrepParked[]
  asks: SitrepAsk[]
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

/** Where Claude Code seated the board: docked beside the transcript, or inline above the prompt. */
export type SitrepPlacement = 'dock' | 'inline'

/** The board pane as the window keeps it. */
export type SitrepPane = {
  /** Whether the pane is open and drawn, which the band's button follows. */
  isOpen: boolean
  /** Null at home: this session. */
  place: SitrepPlace | null
  /** The item (or log line) opened under its line. */
  selected: string | null
  /** The work whose DONE shows every closed ask, not only the latest; null for none. A pane an older load saved lacks it, and is read as none. */
  doneInFull: string | null
  /** Where Claude Code last seated the board on each surface, as the board drawn there said; kept across closes. A surface whose board never said is missing, as is the whole from a pane an older load saved. */
  placement: Partial<Record<string, SitrepPlacement>>
}

/** How far down the docked board's list stands: the place it was moved at, and the list's first row showing there. */
export type SitrepScroll = {
  place: SitrepPlace
  top: number
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
      /** Every project holding a current work, and the held work's, as last read. */
      projects: SitrepProject[]
      /** The other works the board draws in full: the session it looks at, and those replies wait for or went to. */
      others: SitrepOther[]
      /** Ready to send, in the order queued. */
      queue: SitrepQueued[]
      /** Where replies written into other works' inboxes went, until Claude has them. */
      sent: SitrepSent[]
      /** The message on its way to Claude, or null. */
      inFlight: SitrepInFlight | null
      pane: SitrepPane
      /** How far down the docked board's list stands, or null at its top. */
      scroll: SitrepScroll | null
      /** The ask the next Enter in the prompt box answers, or null. */
      answering: SitrepAnswering | null
      pulse: SitrepPulse
      /** How many replies from the board the band is flashing as just taken in; 0 for none. */
      flash: number
      /** A count moved on as time passes, so what the board draws from the time is drawn again. */
      tick: number
    }
  }
}
