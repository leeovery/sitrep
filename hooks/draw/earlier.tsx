/**
 * A session's DONE, at the foot of its view: the asks closed earlier, the
 * newest closed first, each opening to how it closed. It shows the latest
 * few, and a press opens it to every one.
 */
import { answerOf, closingReply, type Ask } from '../../core'
import { C, GLYPH } from '../look'
import { itemKey } from '../places'
import { doneEarlier, type Filed } from '../scene'
import { drawRow, heading, type Block, type Drawing } from './kit'

/** How many closed asks DONE shows until it is opened to them all. */
const LATEST = 3

const MARK = { glyph: GLYPH.done, color: C.ok }

/** What a closed ask is opened by, apart from the ask itself, which For you opens. */
const doneKey = (work: string, ask: Ask) => `done:${itemKey(work, ask.id)}`

/** How an ask closed: the reply of Lee's that closed it, or Claude's resolve, with why. */
const howClosed = (ask: Ask) => {
  const reply = closingReply(ask)

  if (reply !== undefined) {
    return answerOf(ask, reply)
  }

  return ask.reason === undefined ? 'resolved by Claude' : `resolved by Claude: ${ask.reason}`
}

/** A closed ask's row, as a block of its own. */
const drawClosed = (d: Drawing, work: string, ask: Ask): Block => {
  const key = doneKey(work, ask)
  const isOpen = d.scene.pane.selected === key
  const row = `closed:${itemKey(work, ask.id)}`

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

/** The press opening DONE to every closed ask, or folding it back to the latest, in grey; none with no more than those. */
const drawToggle = (d: Drawing, work: string, asks: readonly Ask[], isInFull: boolean) => {
  const { Button, Text } = d.els
  const key = `earlier:${work}`
  const label = isInFull ? 'show fewer' : `show all ${asks.length}`
  const hidden = asks.slice(LATEST).map(ask => doneKey(work, ask))

  return asks.length > LATEST
    ? [
        {
          key,
          element: (
            <Button key={key} plain label={label} onPress={() => d.act.toggleDone(work, hidden)}>
              <Text color={C.grey}>{label}</Text>
            </Button>
          ),
        },
      ]
    : []
}

/** DONE's heading, the closed asks it shows, and its toggle; none while no ask has closed. */
export const drawDone = (d: Drawing, { work }: Filed): Block[] => {
  const asks = doneEarlier(work, d.scene.now)
  const isInFull = d.scene.pane.doneInFull === work.id

  if (asks.length === 0) {
    return []
  }

  return [
    { key: 'done', element: heading(d, 'DONE', C.ok, `${asks.length} closed`) },
    ...(isInFull ? asks : asks.slice(0, LATEST)).map(ask => drawClosed(d, work.id, ask)),
    ...drawToggle(d, work.id, asks, isInFull),
  ]
}
