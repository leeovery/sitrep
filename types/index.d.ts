/**
 * sitrep's values in `$.state`: the session this window is attached
 * to, that session as its files fold, the board as Claude last saw it, the
 * sessions around it as the board draws them, the window's own state as Lee
 * works the board, what Claude's calls named as they were answered, and
 * what the window is doing.
 *
 * The engine takes only a self-contained contract, so the board's types
 * mirror core's (core/types.ts, core/state.ts). hooks/board.ts converts a
 * folded session to a board and back, and hooks/activity.ts hands the
 * window's activity to core and back, so the compiler holds each to the
 * other.
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

/** Where a window is: core's `Where`. */
export type SitrepWhere = {
  device?: string
  terminal?: string
  tmux?: { socket: string; pane: string }
}

/** A tool as a row shows it: core's `ToolShown`. */
export type SitrepToolShown = { name: string; subject?: string }

/** A question as a row shows it: core's `QuestionShown`. */
export type SitrepQuestionShown = { text: string; count: number }

/** What a window is doing, and since when: core's `WindowState`. */
export type SitrepWindowState = {
  is: 'working' | 'permission' | 'question' | 'yourTurn'
  since: number
  tool?: SitrepToolShown
  question?: SitrepQuestionShown
}

export type SitrepPresence = {
  writer: string
  attachedAt: number
  seenAt: number
  leftAt?: number
  where?: SitrepWhere
  version?: string
  state?: SitrepWindowState
  loadedAt?: number
}

/** A call waiting on Lee: core's `Stop`. */
export type SitrepStop = { call: string; at: number; agentId?: string } & (
  { is: 'permission'; tool: SitrepToolShown } | { is: 'question'; question?: SitrepQuestionShown }
)

/** What this window has heard of its own doing, its heartbeat's state worked out from it: core's `Activity`, with when the load that kept it began. */
export type SitrepActivity = {
  loadedAt?: number
  turnAt?: number
  endedAt?: number
  tools: { call: string; tool: SitrepToolShown }[]
  asked: { call: string; tool: string; input: { [argument: string]: string }; agentId?: string }[]
  stops: SitrepStop[]
}

/** A finished session: core's `Finished`. */
export type SitrepFinished = {
  at: number
  by: string
  who: 'lee' | 'claude'
  reason?: string
}

/** A folded session as plain data: core's `Session`, its map of items and set of ids as lists. */
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

/** The session this window is attached to, and as whom. */
export type SitrepAttachment = {
  /** The project's key: the folder its sessions are under. */
  project: string
  session: string
  /** Claude Code's session id the window attached as: its file and heartbeat in the session. */
  writer: string
  attachedAt: number
}

/** A session as it is filed: its project's key, and its id. */
export type SitrepSessionRef = {
  project: string
  session: string
}

/** An item of a session's, wherever the board shows it. */
export type SitrepItemRef = SitrepSessionRef & { item: string }

/** A reply of Lee's waiting in Ready to send: the item it answers, and what it says. */
export type SitrepQueued = SitrepItemRef & {
  verdict: SitrepVerdict
  option?: string
  note?: string
}

/**
 * An item Lee is writing to in the prompt box: the next Enter there queues
 * what was written as an ask's answer or a comment on it, or as the note of
 * a parked item's pick-up, and nothing goes to Claude. The item's title, for
 * the band to name it wherever the item is.
 */
export type SitrepAnswering = SitrepItemRef & {
  /** What the words are: an ask's answer or a comment on it, or a pick-up's note. An older load's value is one of the first two. */
  as: 'answer' | 'comment' | 'pickup'
  title: string
  /** Where Lee began it, and the only surface whose Enter it takes: the terminal's prompt, or Claude's app's. */
  surface: 'terminal' | 'mobile'
  /** The words the mode put in the prompt box to be written again, if any. */
  filled?: string
}

/** Replies this window wrote into another session's inbox, by their ids: shown in Ready to send until Claude has them. */
export type SitrepSent = SitrepSessionRef & { replies: string[] }

/** A reply as a line of a session's file: core's `ReplyBody`. */
export type SitrepReplyBody = {
  type: 'reply'
  id: string
  item: string
  verdict: SitrepVerdict
  option?: string
  note?: string
}

/** Whose replies a message carries: Lee's send from this window's board, or what other sessions left in its inbox. */
export type SitrepSource = 'send' | 'inbox'

/**
 * Lee's replies submitted as Lee's own message, one message at a time
 * whatever its source: on their way until Claude Code has taken it and its
 * lines are written into the session it went to.
 */
export type SitrepInFlight = SitrepSessionRef & {
  source: SitrepSource
  /** The window's writer as it claimed the message: whose file in the session records it. */
  writer: string
  /** The message, exactly as submitted: the text the turn it starts carries. */
  text: string
  /** The replies the message carries, their ids fixed as it was claimed. */
  replies: SitrepReplyBody[]
  /**
   * When it was claimed, which tells this claim from a later one of the same
   * text: for a send, taken before it read the board, the time its replies
   * are written as of.
   */
  claimedAt: number
  /** Whether Claude Code has taken the message, its lines still to write. */
  isTaken: boolean
}

/** A session in brief: core's `SessionSummary`. */
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
  asked: number
  parked: number
  updatedAt: number
}

/** A session as views beyond its own draw it: core's `SessionBrief`. */
export type SitrepBrief = SitrepSummary & {
  log: SitrepLogLine[]
  parkedItems: SitrepParked[]
  asks: SitrepAsk[]
}

/** A project as last read: its key, and its current sessions other than the held one, in brief. */
export type SitrepProject = {
  key: string
  sessions: SitrepBrief[]
}

/** Another session the board draws in full, and the project it is filed under. */
export type SitrepOther = {
  project: string
  board: SitrepBoard
}

/** Where the board is looking: a session, a project's sessions, or every project. */
export type SitrepPlace =
  | ({ level: 'session' } & SitrepSessionRef)
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
  /** The session whose RESOLVED shows every closed ask, not only the latest; null for none. A pane an older load saved lacks it, and is read as none. */
  resolvedInFull: string | null
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

/** What a call's row names, as the call was answered: the call's id, and the item's title or the session's name. */
export type SitrepNamed = {
  call: string
  name: string
}

declare module 'claude-code' {
  interface PluginState {
    sitrep: {
      attachment: SitrepAttachment | null
      /** The attached session, folded; null with none attached. */
      board: SitrepBoard | null
      /** `boardText` as Claude last saw it: a start, a join, a read, its own post, or a turn's context. */
      seen: string | null
      /** Every project holding a current session, and the held session's, as last read. */
      projects: SitrepProject[]
      /** The other sessions the board draws in full: the session it looks at, and those replies wait for or went to. */
      others: SitrepOther[]
      /** Ready to send, in the order queued. */
      queue: SitrepQueued[]
      /** Where replies written into other sessions' inboxes went, until Claude has them. */
      sent: SitrepSent[]
      /** The message on its way to Claude, or null. */
      inFlight: SitrepInFlight | null
      pane: SitrepPane
      /** How far down the docked board's list stands, or null at its top. */
      scroll: SitrepScroll | null
      /** The item the next Enter in the prompt box writes to, or null. */
      answering: SitrepAnswering | null
      pulse: SitrepPulse
      /** How many replies from the board the band is flashing as just taken in; 0 for none. */
      flash: number
      /** What the latest naming calls' rows name, the latest last. */
      named: SitrepNamed[]
      /** A count moved on as time passes, so what the board draws from the time is drawn again. */
      tick: number
      /** What this window has heard of its own doing, held or not: its turn, the tools it runs, the calls put to Lee, and what waits on Lee. */
      activity: SitrepActivity
    }
  }
}
