/**
 * A session's RESOLVED, at the foot of its view: the asks closed earlier, the
 * newest closed first, each opening to how it closed. It shows the latest
 * few, and a press opens it to every one.
 */
import { answerOf, closingReply, type Ask } from '../../core'
import { C, GLYPH } from '../look'
import { itemKey } from '../places'
import { resolvedEarlier, type Filed } from '../scene'
import { drawRow, heading, type Block, type Drawing } from './kit'

/** How many closed asks RESOLVED shows until it is opened to them all. */
const LATEST = 3

const MARK = { glyph: GLYPH.done, color: C.ok }

/** What a closed ask is opened by, apart from the ask itself, which Asks opens: this, then its address. */
export const RESOLVED_KEY = 'resolved:'

const resolvedKey = (session: string, ask: Ask) => `${RESOLVED_KEY}${itemKey(session, ask.id)}`

/** How an ask closed: the reply of Lee's that closed it, or Claude's resolve, with why. */
const howClosed = (ask: Ask) => {
  const reply = closingReply(ask)

  if (reply !== undefined) {
    return answerOf(ask, reply)
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

/**
 * The press opening RESOLVED to every closed ask, or folding it back to the
 * latest, dim; none with no more than those. Dim rather than a grey Text
 * child: Claude Code 2.1.294 refuses a Button with a label and children,
 * and the refusal blanks the whole board (seen live).
 */
const drawToggle = (d: Drawing, session: string, asks: readonly Ask[], isInFull: boolean) => {
  const { Button } = d.els
  const key = `earlier:${session}`
  const label = isInFull ? 'show fewer' : `show all ${asks.length}`
  const hidden = asks.slice(LATEST).map(ask => resolvedKey(session, ask))

  return asks.length > LATEST
    ? [
        {
          key,
          element: (
            <Button
              key={key}
              plain
              dimColor
              label={label}
              onPress={() => d.act.toggleResolved(session, hidden)}
            />
          ),
        },
      ]
    : []
}

/** RESOLVED's heading, the closed asks it shows, and its toggle; none while no ask has closed. */
export const drawResolved = (d: Drawing, { session }: Filed): Block[] => {
  const asks = resolvedEarlier(session, d.scene.now)
  const isInFull = d.scene.pane.resolvedInFull === session.id

  if (asks.length === 0) {
    return []
  }

  return [
    { key: 'resolved', element: heading(d, 'RESOLVED', C.ok, `${asks.length} resolved`) },
    ...(isInFull ? asks : asks.slice(0, LATEST)).map(ask => drawClosed(d, session.id, ask)),
    ...drawToggle(d, session.id, asks, isInFull),
  ]
}
