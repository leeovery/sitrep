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

export const META: SessionMeta = {
  id: 'sr-k3f9qa',
  name: 'Dashboard redesign',
  summary: 'Redesign the dashboard, area by area in Paper',
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by: W1,
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

export const park = (id: string, title: string): Body => ({ type: 'park', id, title })

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

/** Lee's snooze of an ask until `until`. */
export const snooze = (item: string, until: number): Body => ({ type: 'snooze', item, until })

/** Lee's waking of a snoozed ask now. */
export const wake = (item: string): Body => ({ type: 'wake', item })

/** Random bytes from a script: each draw takes the next list of bytes, the last list repeating. */
export const scripted = (...draws: number[][]): Random => {
  let next = 0

  return count => {
    const bytes = draws[Math.min(next++, draws.length - 1)] ?? [0]

    return Uint8Array.from({ length: count }, (_, i) => bytes[i % bytes.length] ?? 0)
  }
}
