/**
 * A session's RESOLVED, at the foot of its view: the asks closed earlier, the
 * newest closed first, each opening to how it closed. It shows the latest
 * few, and a press opens it to every one.
 */
import { closingReply, listingOf, shownAnswerOf, type Ask, type Filed } from '../../core'
import { resolvedList } from '../lists'
import { C, GLYPH } from '../look'
import { itemKey } from '../places'
import { resolvedEarlier } from '../scene'
import { drawRow, heading, type Block, type Drawing } from './kit'
import { drawPast } from './past'

const MARK = { glyph: GLYPH.closed, color: C.ok }

/** What a closed ask is opened by, apart from the ask itself, which Asks opens: this, then its address. */
export const RESOLVED_KEY = 'resolved:'

const resolvedKey = (session: string, ask: Ask) => `${RESOLVED_KEY}${itemKey(session, ask.id)}`

/** How an ask closed: the reply of Lee's that closed it, or Claude's resolve, with why. */
const howClosed = (ask: Ask) => {
  const reply = closingReply(ask)

  if (reply !== undefined) {
    return shownAnswerOf(ask, reply)
  }

  return ask.reason === undefined ? 'resolved by Claude' : `resolved by Claude: ${ask.reason}`
}

/** A closed ask's row, as a block of its own. */
const drawClosed = (d: Drawing, session: string, ask: Ask): Block => {
  const key = resolvedKey(session, ask)
  const isOpen = d.scene.pane.selected === key
  const row = `closed:${itemKey(session, ask.id)}`

  return {
    key: row,
    element: drawRow(d, {
      key: row,
      mark: MARK,
      title: ask.title,
      at: ask.closedAt ?? ask.at,
      isOpen,
      press: { key, onPress: () => d.act.select(key) },
      branches: isOpen ? [howClosed(ask)] : [],
    }),
  }
}

/** RESOLVED's heading, the closed asks it shows, and its press; none while no ask has closed. */
export const drawResolved = (d: Drawing, { session }: Filed): Block[] => {
  const asks = resolvedEarlier(session, d.scene.now)

  if (asks.length === 0) {
    return []
  }

  return [
    { key: 'resolved', element: heading(d, 'RESOLVED', C.ok, `${asks.length} resolved`) },
    ...drawPast(d, {
      list: resolvedList(session.id),
      listing: listingOf(asks, true),
      draw: ask => drawClosed(d, session.id, ask),
      opens: ask => resolvedKey(session.id, ask),
    }),
  ]
}
