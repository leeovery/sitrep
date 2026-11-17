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
} from '../core'
import { META, MIN, T0, type Asked } from './data'

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

/** An ask's line as the ask tool writes what Claude asked, given as the sample asks are (data.ts). */
export const askOf = (id: string, ask: Asked): Body => ({ type: 'ask', id, ...ask })

/** An ask's line as written before asks said what they want back: by its kind. */
export const kindAsk = (
  id: string,
  kind: AskKind,
  title: string,
  extra: { options?: string[]; needs?: string } = {},
): Body => ({ type: 'ask', id, kind, title, ...extra })

/** A note's line as Claude wrote one until notes went (17 November 2026), read now for its id alone. */
export const oldNote = (
  id: string,
  text: string,
  detail?: string[],
  extra: { ref?: string } = {},
): Body => ({ type: 'note', id, text, detail, ...extra }) as unknown as Body

/** An edit of a note's text and detail alone, as Claude wrote one until notes went. */
export const oldNoteEdit = (item: string, text: string, detail?: string[]): Body =>
  ({ type: 'edit', item, changes: { text, detail } }) as unknown as Body

export const park = (
  id: string,
  title: string,
  extra: { where?: string; ref?: string } = {},
): Body => ({ type: 'park', id, title, ...extra })

export const reply = (
  id: string,
  item: string,
  verdict: Verdict,
  extra: { option?: string; note?: string; to?: string } = {},
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
