/**
 * The board's nouns as data: what each line of a writer's file holds, and
 * what a session folds to once every writer's lines are read together.
 */

/**
 * What an ask wants back from Lee: a yes (a go, an approval, "it works"),
 * one of its options, or words (an answer, a command's output). It chooses
 * the ask's buttons and is never shown as a word.
 */
export type Wants = 'yes' | 'choice' | 'words'

/** What an ask said it was before asks said what they want back: lines written so still read, each as the shape it maps to. */
export type AskKind = 'review' | 'decide' | 'try' | 'do'

/**
 * Lee's answer: a yes, an option, words answering an ask that wants them,
 * a comment, an ignore, or a pick-up of a parked item.
 */
export type Verdict = 'yes' | 'choose' | 'answer' | 'comment' | 'ignore' | 'pickup'

/**
 * Where a reply stands: Claude has it; it goes in when its session's window
 * ends its turn; no window has the session, so it waits for one to join; or
 * it goes nowhere, void (`Voided` says why).
 */
export type Delivery = 'delivered' | 'waiting' | 'closed' | 'void'

/**
 * What keeps an item from taking a reply of Lee's: `answered`, Lee's
 * answer, on its way to it or delivered; `resolved`, Claude's closing it;
 * `dropped`, Lee's dropping a parked item.
 */
export type Barred = 'answered' | 'resolved' | 'dropped'

/**
 * Why a reply settles nothing: its item took it no more, as `Barred` says;
 * `changed`, its item changed under it so it fits no more; `finished`, its
 * session was finished before it went in.
 */
export type Voided = 'changed' | 'finished' | Barred

/** Who closed an item, and how: Lee's answer, Lee's ignore, Claude's resolve, or Lee's drop of a parked item. */
export type ClosedBy = 'answer' | 'ignore' | 'claude' | 'drop'

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
  wants: Wants
  /** A yes ask's button: the verb Lee gives, in Claude's words ("Go", "Approve"). */
  yes?: string
  title: string
  where?: string
  /** A choice ask's options. */
  options?: string[]
  /** The option of a choice ask Claude recommends, in its words. */
  recommended?: string
  /** What the words of a words ask are, in Claude's words: "the command's output". */
  needs?: string
  ref?: string
}

/** An ask's line as written before asks said what they want back: by its kind. */
export type KindAskBody = Omit<AskBody, 'wants' | 'yes'> & { kind: AskKind }

/**
 * A note's line, as Claude wrote one until notes went (17 November 2026),
 * read for its id alone: the id stays taken, so no new item is given it, and
 * its time and count still count; it posts nothing.
 */
export type NoteBody = { type: 'note'; id: string }

export type ParkBody = {
  type: 'park'
  id: string
  title: string
  where?: string
  ref?: string
}

/** The fields an edit may change; which of them apply depends on the item's type. */
export type Changes = {
  wants?: Wants
  yes?: string
  title?: string
  where?: string
  options?: string[]
  /** `''` clears it. */
  recommended?: string
  /** `''` clears it. */
  needs?: string
  ref?: string
}

/** Every type of item a session holds. */
export const ITEM_TYPES: readonly Item['type'][] = ['ask', 'park']

/** The fields an edit changes, by the type of item. */
export const EDITABLE: Record<Item['type'], readonly (keyof Changes)[]> = {
  ask: ['wants', 'yes', 'title', 'where', 'options', 'recommended', 'needs', 'ref'],
  park: ['title', 'where', 'ref'],
}

export type ResolveBody = { type: 'resolve'; item: string; reason?: string }
export type ReopenBody = { type: 'reopen'; item: string; reason?: string }
/** An edit's changes as a line holds them: one written before asks said what they want back may change an ask's kind. */
export type EditBody = {
  type: 'edit'
  item: string
  changes: Changes & { kind?: AskKind }
  reason?: string
}

export type ReplyBody = {
  type: 'reply'
  id: string
  item: string
  verdict: Verdict
  option?: string
  note?: string
  /** A pick-up's: the session it went to, by its id. None on a pick-up written before pick-ups said (17 November 2026). */
  to?: string
}

export type DeliveredBody = { type: 'delivered'; replies: string[] }

/**
 * Lee's drop of a parked item, from the board: off Parked, with nothing
 * sent to Claude, who reads it gone from the board. Written in the session
 * that parked it, in the writer's own file there.
 */
export type DropBody = { type: 'drop'; item: string }

/** A reply a message in flight carries, its id fixed as the message was claimed: the fields its line will hold. */
export type SentReply = Omit<ReplyBody, 'type'>

/** Who finished a session: Lee, from the board, or Claude. */
export type Finisher = 'lee' | 'claude'

/** Finishes the session: Lee or Claude, with why. */
export type FinishBody = { type: 'finish'; who: Finisher; reason?: string }

/** Takes a finished session up again: a window joined it. */
export type UnfinishBody = { type: 'unfinish' }

/** Moves the session to another project, by its key: the session's folder stays where it was started. */
export type MoveBody = { type: 'move'; project: string }

/**
 * Lee's snooze of the session: everything it needs of Lee, the asks waiting
 * on him as it is written, by their ids (`asks`), and its turn, put off until
 * `until`, in place of any snooze before; with none, until it moves, as its
 * next turn ends. A new ask, Lee's reply to one it holds, or his own prompt
 * in its window wakes it sooner; its turn ending alone wakes only one until
 * it moves.
 */
export type SnoozeSessionBody = { type: 'snoozeSession'; until?: number; asks: string[] }

/** Lee's waking of the session now: from the app or the pane, by his own prompt in its window, or, for a snooze until it moves, by its next turn ending. */
export type WakeSessionBody = { type: 'wakeSession' }

/**
 * Lee's snooze of an ask, from before a snooze was the session's (23
 * October to 13 November 2026), which a window not reloaded still writes:
 * read as his snooze of the session until `until`, where it names an ask
 * waiting as posted.
 */
export type SnoozeBody = { type: 'snooze'; item: string; until: number }

/** Lee's waking of a snoozed ask, from before a snooze was the session's: read as his waking of the session. */
export type WakeBody = { type: 'wake'; item: string }

/**
 * Lee's snooze of the session's turn, the one that ended at `turn`, from
 * before a snooze was the session's (4 to 13 November 2026), read as it was
 * until it lapses: it waits in Snoozed until `until`, or with none until
 * the session takes another turn; in place of any snooze of a turn before.
 */
export type SnoozeTurnBody = { type: 'snoozeTurn'; turn: number; until?: number }

/** Lee's waking now of the session's turn that ended at `turn`, from before a snooze was the session's. */
export type WakeTurnBody = { type: 'wakeTurn'; turn: number }

/** What one line of a writer's file says. */
export type Body =
  | StatusBody
  | AskBody
  | KindAskBody
  | NoteBody
  | ParkBody
  | ResolveBody
  | ReopenBody
  | EditBody
  | ReplyBody
  | DeliveredBody
  | DropBody
  | FinishBody
  | UnfinishBody
  | MoveBody
  | SnoozeSessionBody
  | WakeSessionBody
  | SnoozeBody
  | WakeBody
  | SnoozeTurnBody
  | WakeTurnBody

/** A line as written: its body, stamped with the format's version, the time and the writer's own count. */
export type Entry = Body & { v: number; at: number; seq: number }

/** Where a session stands, as its latest status says, and who said it when. */
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
  /** A pick-up's: the session it went to, by its id; none where its line said none. */
  to?: string
  by: string
  at: number
  delivery: Delivery
  /** When a mark said Claude has it. */
  deliveredAt?: number
  /** When it went void, and why. One its item changed under may be delivered too: Claude has it, and it settles nothing. */
  voidedAt?: number
  voided?: Voided
  /** Settled, void or delivered, while its item stood closed, which has reopened since: history to the item as it now stands, which settles nothing and never comes back. */
  isHistory?: boolean
}

/** What every posted item carries: who posted it when, and when it was last opened, closed or edited. */
type Posted = {
  id: string
  by: string
  at: number
  openedAt: number
  closedAt?: number
  /** Who closed it, as the event that closed it says; none while it is open. */
  closedBy?: ClosedBy
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
  wants: Wants
  /** The yes button's words; on an ask read from its kind, the words its yes was given in. */
  yes?: string
  /** The kind of an ask read from it, as its line or an edit written before asks said what they want back gave it: its replies keep the meaning they had. */
  kind?: AskKind
  title: string
  where?: string
  options?: string[]
  /** One of its options, while it is a choice that has it. */
  recommended?: string
  needs?: string
  state: AskState
  /** The delivered reply that last moved it, since it was opened or reopened. */
  answer?: Reply
  /** Lee's answer on its way to it, which bars another: at most one, as a second starts void. A comment on its way is no answer. */
  answerOnItsWay?: Reply
  /** Lee's replies to it, oldest first, those on their way in a live window's message, not written down yet, among them at their claim's time. */
  replies: Reply[]
  /** When Lee's snooze of its session wakes, while that is still to come at the fold's moment, `UNTIL_IT_MOVES` for one with no time; only on one waiting as posted. */
  snoozedUntil?: number
  /** When Lee's snooze of its session ran out, once it has, until a later line ends it; only on one waiting as posted. */
  wokeAt?: number
}

export type Parked = Posted & {
  type: 'park'
  title: string
  where?: string
  /** Still parked; picked up by Lee; closed by Claude; or dropped by Lee. */
  state: 'parked' | 'picked' | 'closed' | 'dropped'
  answer?: Reply
  /** Lee's pick-up on its way to it, its answer, as an ask's is. */
  answerOnItsWay?: Reply
  replies: Reply[]
}

export type Item = Ask | Parked

/** A change of a session's status, as the board noticed it, comparing a status with the one before: who changed it when, its headline, and the detail it opens to. */
export type StatusLine = {
  at: number
  by: string
  text: string
  detail: string[]
}

/** A finished session: when, by which writer, and whether Lee or Claude, with why. */
export type Finished = {
  at: number
  by: string
  who: Finisher
  reason?: string
}

/** Where a window is: the terminal device Claude Code is on, the terminal program, its tmux pane when it runs in tmux, and its zmx session when it runs in zmx. */
export type Where = {
  /** `/dev/ttys043` */
  device?: string
  /** `$TERM_PROGRAM` as given: `ghostty`, `tmux`, `iTerm.app`. */
  terminal?: string
  /** The tmux server's socket (`/private/tmp/tmux-501/default`) and the pane (`%148`). */
  tmux?: { socket: string; pane: string }
  /** The zmx session's name, `$ZMX_SESSION` as given: `sitrep-Xq4mR2`, `kit · restore-card`. */
  zmx?: { session: string }
}

/** A tool as a row shows it: its name, and what it acts on (a file's path, Bash's command), where the tool has one. */
export type ToolShown = { name: string; subject?: string }

/** A question Claude put to Lee as a row shows it: the first question's text, and how many it asked. */
export type QuestionShown = { text: string; count: number }

/**
 * What a window is doing: running a turn, stopped on Lee at a permission
 * prompt or a question, its turn over but on its own work, which will wake
 * it, or waiting for Lee's message.
 */
export type StateKind = 'working' | 'permission' | 'question' | 'onItsWork' | 'yourTurn'

/** Tasks of one kind a turn left running: how many, and the first, as its line says it. */
export type Tasks = { count: number; first: string }

/**
 * What a turn left pending that will wake its window, as its Stop listed
 * it, in summary: its tasks by kind, each kind's first as its line says it
 * (an agent's, a monitor's or another task's description, a workflow's name,
 * a shell's command), and its one-off wakes, with the soonest's time where
 * its schedule reads.
 */
export type Work = {
  agents?: Tasks
  workflows?: Tasks
  shells?: Tasks
  monitors?: Tasks
  others?: Tasks
  wakes?: { count: number; at?: number }
}

/**
 * A window's state, and since when: the turn's start while working, the
 * prompt's or the question's showing while stopped, the turn's end (or the
 * attach, before any turn) on its own work and on your turn. Working
 * carries the tool running, a permission prompt the tool it asks for, a
 * question the question, on its own work what is pending.
 */
export type WindowState = {
  is: StateKind
  since: number
  tool?: ToolShown
  question?: QuestionShown
  work?: Work
}

/** A window's heartbeat on a session; `leftAt` once it has let go, and `where` the window is, as far as it is known. */
export type Presence = {
  writer: string
  attachedAt: number
  seenAt: number
  leftAt?: number
  /** Set as the window let go because its conversation ended while its Claude lives on, into the next (a `/clear`, or a `/resume` in the same process): the window is that conversation's no longer. */
  livesOn?: true
  where?: Where
  /** The folder its Claude runs in, absolute: the process's own, which entering a worktree moves and a shell's `cd` does not; none from a window on a version before heartbeats said it. */
  directory?: string
  /** The sitrep version the window runs, as its plugin's manifest gives it; none from a window on a version before heartbeats said it. */
  version?: string
  /** What the window is doing; none from a window on a version before heartbeats said it, nor from one that let go. */
  state?: WindowState
  /** When the load of the mod that wrote it began, so a load a reload superseded writes no heartbeat over a newer one's; none where the clock failed, or before heartbeats said it. */
  loadedAt?: number
  /** Lee's replies the window's messages in flight carry to this session, each message's from its claim until it ends, in the order claimed; none while it sends none, nor from a window that let go. */
  sending?: Sending[]
}

/**
 * Lee's replies a window sends its own session as one message of Lee's,
 * published in its heartbeat from the claim until the message ends, written
 * down or let go: on their way from the claim, as an inbox reply is. `at` is
 * when the message was claimed.
 */
export type Sending = { at: number; replies: SentReply[] }

/** Lee's latest snooze of a session: when it wakes, `UNTIL_IT_MOVES` for one with no time; when Lee wrote it; and the asks it holds, those waiting on Lee then. */
export type SessionSnooze = { until: number; at: number; asks: readonly string[] }

/**
 * The time a snooze with none wakes at, as the fold reads it: never by the
 * clock, until a line wakes it. Past any time a `Date` holds, so it sorts
 * after every one and no line can carry it, and whole, so it keeps in the
 * JSON `$.state` holds, as Infinity would not.
 */
export const UNTIL_IT_MOVES = Number.MAX_SAFE_INTEGER

/** Lee's latest snooze of a session's turn, from an old line: the turn it holds, by its end; when it wakes, none until the turn moves; and when Lee wrote it. */
export type TurnSnooze = { turn: number; until?: number; at: number }

/** A session as it stands, every writer's lines read together. */
export type Session = {
  id: string
  /** The project's name, as its file has it, else as the session recorded it, first letter a capital. */
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
  /** Every change of its status, the newest first. */
  history: StatusLine[]
  presence: Presence[]
  /** Whether a window is attached: a live presence. */
  isOpen: boolean
  /** The window that submits inbox replies: the oldest live presence. */
  deliverer?: string
  /** Asks waiting on Lee, those Lee snoozed aside; none once the session is finished. */
  waiting: number
  /** Set once the session is finished, until a window joins it again. */
  finished?: Finished
  /** The project its latest move names, by key; none for one never moved. Whether it is filed there is filing.ts's to say. */
  movedTo?: string
  /** Lee's latest snooze of the session, until a line wakes it, and none while an ask it does not hold waits on Lee: it holds while its time is to come (`snoozedUntilOf`). */
  snooze?: SessionSnooze
  /** When Lee's latest snooze of the session runs out, while an ask it does not hold waits on Lee and sets it aside: then it stands again, run out, its asks woken. `UNTIL_IT_MOVES` for one with no time, which never runs out. */
  asideUntil?: number
  /** Lee's latest snooze of its turn, from an old line, until a line wakes it: whether it holds at a moment is the rows' to say. */
  turnSnooze?: TurnSnooze
  /** From old lines' snoozes of asks, holding every ask waiting on Lee: when the first of them wakes, the turn with it; none once one has woken or ended. */
  turnWithAsks?: number
  /** Every id the session's lines use, items and replies alike. */
  ids: ReadonlySet<string>
  /** The latest line's time, Lee's snoozes and wakes of a session or a turn aside, which Claude is never told of, and lines about a parked item but its park, which is its project's; or when the session was started. */
  updatedAt: number
}
