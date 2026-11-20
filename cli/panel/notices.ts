/**
 * The terminal notifications the panel posts, as the app's banners go
 * (Notices.swift's `newAsks` and `newAsk`): one for each ask new on the
 * board, never a permission prompt, a question or a stop, the oldest first,
 * a tie in board order. Its title is the ask's words, its body the row's
 * `Project · Session`, an away row's too.
 *
 * - The sequence is OSC 777, `ESC ] 777 ; notify ; <title> ; <body> BEL`.
 * - Both fields are cleaned as the board's words are, so no control
 *   character can end the sequence early, and a `;` in the title becomes
 *   `,`, since it would end the field.
 * - Inside tmux, `$TMUX` set, it goes in tmux's passthrough, each ESC in it
 *   doubled, which tmux passes on only with `allow-passthrough on`.
 *
 * Pure: the loop writes them.
 */
import type { Feed } from '../../core'
import { cleaned } from './view'

/** A notification's words: the ask's, and where it is. */
export type Notice = { title: string; place: string }

/** The environment the bytes depend on: tmux's, where the panel runs inside it. */
export type NoticeEnv = { TMUX?: string }

const ESC = '\x1b'

const BEL = '\x07'

/** The asks among `news`, the keys new on `feed`, as notices: the oldest first, a tie in board order. */
export const newAsks = (feed: Feed, news: readonly string[]): Notice[] => {
  const isNew = new Set(news)

  return (
    feed.rows
      .flatMap(row =>
        row.lines
          .filter(line => line.is === 'ask' && isNew.has(line.key))
          .map(line => ({ since: line.since, title: line.first.lead, place: `${row.projectName} · ${row.name}` })),
      )
      // A stable sort, so a tie keeps board order.
      .sort((a, b) => a.since - b.since)
      .map(({ title, place }) => ({ title, place }))
  )
}

/** The notice as OSC 777, its fields cleaned. */
export const osc777 = ({ title, place }: Notice) =>
  `${ESC}]777;notify;${cleaned(title).replaceAll(';', ',')};${cleaned(place)}${BEL}`

/** A sequence in tmux's passthrough. */
export const passedThrough = (sequence: string) => `${ESC}Ptmux;${sequence.replaceAll(ESC, ESC + ESC)}${ESC}\\`

const isInTmux = (env: NoticeEnv) => (env.TMUX ?? '') !== ''

/** The bytes that post the notice, wrapped for tmux where the panel runs inside it. */
export const noticeBytes = (notice: Notice, env: NoticeEnv) =>
  isInTmux(env) ? passedThrough(osc777(notice)) : osc777(notice)

/** The bytes for each ask new on the board, a write each, the oldest first. */
export const noticesOf = (feed: Feed, news: readonly string[], env: NoticeEnv) =>
  newAsks(feed, news).map(notice => noticeBytes(notice, env))
