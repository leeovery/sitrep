/** Builders the core tests share: a session's files from its lines, and random bytes from a script. */
import {
  append,
  foldSession,
  metaText,
  presenceText,
  type AskKind,
  type Body,
  type Finisher,
  type Presence,
  type Random,
  type Verdict,
  type Session,
  type SessionFiles,
  type SessionMeta,
} from '../core'

/** The line under a reply to an ask in Lee's message saying it closed the ask. */
export const CLOSES = '\n  This closes the ask: nothing more to do with it.'

/** The line under a comment in Lee's message saying it left its ask open. */
export const LEAVES_OPEN = '\n  This leaves the ask open: act on it, then resolve it.'

export const MIN = 60_000

/** For a test that runs the clock through many of the watch's looks: past the default 5s on a loaded machine. */
export const SLOW = { timeoutMs: 20_000 }

/** When the session under test was started. */
export const T0 = 1_760_000_000_000

/** The window that started the session, a second window, two more on other sessions, and the CLI. */
export const W1 = 'b1c2d3e4-0000-4000-8000-000000000001'
export const W2 = 'b1c2d3e4-0000-4000-8000-000000000002'
export const W3 = 'b1c2d3e4-0000-4000-8000-000000000003'
export const W4 = 'b1c2d3e4-0000-4000-8000-000000000004'
export const CLI = 'cli'

/** A window on another session, sending replies into this one's inbox. */
export const SENDER = 'f0e1d2c3-0000-4000-8000-0000000000ff'

/** A subagent's loop. */
export const AGENT = 'a1b2c3d4'

export const META: SessionMeta = {
  id: 'sr-k3f9qa',
  name: 'Help desk redesign',
  summary: 'Redesign the help desk, page by page in Paper',
  project: 'northwind',
  root: '/Users/me/Code/northwind',
  created: T0,
  by: W1,
}

/**
 * A session of Northwind's as a build before 11 November 2026 left it, its
 * files byte for byte, nine days idle and finished: two items still parked,
 * a third picked up. What its files say is literal, so no builder of today's
 * can make it look newer than it is.
 */
export const PARKED_BEFORE = {
  id: 'sr-1edger',
  writer: W2,
  meta: '{"v":1,"id":"sr-1edger","name":"Invoice ledger","summary":"The invoice ledger, area by area","project":"northwind","root":"/Users/me/Code/northwind","created":1759136000000,"by":"b1c2d3e4-0000-4000-8000-000000000002"}\n',
  log: [
    '{"v":1,"at":1759136000000,"seq":1,"type":"status","name":"Invoice ledger","summary":"The invoice ledger, area by area","now":["Drawing the ledger schema"]}',
    '{"v":1,"at":1759136060000,"seq":2,"type":"park","title":"Export the ledger as CSV","ref":"PR #82","id":"p1"}',
    '{"v":1,"at":1759136120000,"seq":3,"type":"park","title":"Archive old invoices","where":"After the release","id":"p2"}',
    '{"v":1,"at":1759136180000,"seq":4,"type":"park","title":"Retry the export","id":"p3"}',
    '{"v":1,"at":1759222400000,"seq":5,"type":"reply","id":"r1","item":"p3","verdict":"pickup"}',
    '{"v":1,"at":1759222400000,"seq":6,"type":"delivered","replies":["r1"]}',
    '{"v":1,"at":1759222460000,"seq":7,"type":"finish","who":"claude","reason":"Shipped"}',
    '',
  ].join('\n'),
}

/** A line, and when it was written. */
export type Line = [at: number, body: Body]

/** A writer's file holding these lines, each stamped at its own time. */
export const file = (...lines: Line[]) =>
  lines.reduce((text, [at, body]) => append(text, [body], at).text, '')

/** A window's heartbeat file, as the window writes it. */
export const beat = (writer: string, times: Omit<Presence, 'writer'>) =>
  presenceText({ writer, ...times })

/** The heartbeat of a window attached at `at` and seen then. */
export const seen = (writer: string, at: number) => beat(writer, { attachedAt: at, seenAt: at })

/** The session folded from these files at `now`; it fails the test when the session does not fold. */
export const fold = (files: Partial<SessionFiles>, now = T0 + 60 * MIN): Session => {
  const session = foldSession({ meta: metaText(META), logs: {}, ...files }, now)

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

export const status = (
  now: string[],
  extra: { name?: string; summary?: string; next?: string } = {},
): Body => ({
  type: 'status',
  name: extra.name ?? META.name,
  summary: extra.summary ?? META.summary,
  now,
  next: extra.next,
})

/** An ask wanting a yes, its button's words `yes`. */
export const yesAsk = (id: string, title: string, yes = 'Approve'): Body => ({
  type: 'ask',
  id,
  wants: 'yes',
  yes,
  title,
})

/** An ask wanting one of `options`. */
export const choiceAsk = (id: string, title: string, options: string[]): Body => ({
  type: 'ask',
  id,
  wants: 'choice',
  title,
  options,
})

/** An ask wanting words, which `needs` says what they are. */
export const wordsAsk = (id: string, title: string, needs?: string): Body => ({
  type: 'ask',
  id,
  wants: 'words',
  title,
  needs,
})

/** An ask's line as written before asks said what they want back: by its kind. */
export const kindAsk = (
  id: string,
  kind: AskKind,
  title: string,
  extra: { options?: string[]; needs?: string } = {},
): Body => ({ type: 'ask', id, kind, title, ...extra })

export const note = (id: string, text: string, detail?: string[]): Body => ({
  type: 'note',
  id,
  text,
  detail,
})

export const park = (
  id: string,
  title: string,
  extra: { where?: string; ref?: string } = {},
): Body => ({ type: 'park', id, title, ...extra })

export const reply = (
  id: string,
  item: string,
  verdict: Verdict,
  extra: { option?: string; note?: string } = {},
): Body => ({ type: 'reply', id, item, verdict, ...extra })

export const delivered = (...replies: string[]): Body => ({ type: 'delivered', replies })

export const resolve = (item: string, reason?: string): Body => ({ type: 'resolve', item, reason })

export const reopen = (item: string, reason?: string): Body => ({ type: 'reopen', item, reason })

export const finish = (who: Finisher, reason?: string): Body => ({ type: 'finish', who, reason })

export const unfinish = (): Body => ({ type: 'unfinish' })

/** Lee's snooze of the session until `until`, none until it moves, holding `asks` and its turn. */
export const snoozeSession = (until: number | undefined, ...asks: string[]): Body =>
  until === undefined ? { type: 'snoozeSession', asks } : { type: 'snoozeSession', until, asks }

/** Lee's waking of the session now. */
export const wakeSession = (): Body => ({ type: 'wakeSession' })

/** An old line: Lee's snooze of an ask until `until`. */
export const snooze = (item: string, until: number): Body => ({ type: 'snooze', item, until })

/** An old line: Lee's waking of a snoozed ask now. */
export const wake = (item: string): Body => ({ type: 'wake', item })

/** An old line: Lee's snooze of the session's turn that ended at `turn`, until `until`, or with none until it moves. */
export const snoozeTurn = (turn: number, until?: number): Body =>
  until === undefined ? { type: 'snoozeTurn', turn } : { type: 'snoozeTurn', turn, until }

/** Lee's waking now of the session's turn that ended at `turn`. */
export const wakeTurn = (turn: number): Body => ({ type: 'wakeTurn', turn })

/** Random bytes from a script: each draw takes the next list of bytes, the last list repeating. */
export const scripted = (...draws: number[][]): Random => {
  let next = 0

  return count => {
    const bytes = draws[Math.min(next++, draws.length - 1)] ?? [0]

    return Uint8Array.from({ length: count }, (_, i) => bytes[i % bytes.length] ?? 0)
  }
}
