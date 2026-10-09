/**
 * A session's DONE, at the foot of its view: the asks closed earlier, the
 * newest closed first, each opening to how it closed. It shows the latest
 * few, and a press opens it to every one.
 */
import { answerOf, closingReply, type Ask } from '../../core'
import { C, GLYPH } from '../look'
import { doneEarlier, type Filed } from '../scene'
import { drawRow, heading, type Drawing } from './kit'

/** How many closed asks DONE shows until it is opened to them all. */
const LATEST = 3

const MARK = { glyph: GLYPH.done, color: C.ok }

/** What a closed ask is opened by, apart from the ask itself, which For you opens. */
const doneKey = (ask: Ask) => `done:${ask.id}`

/** How an ask closed: the reply of Lee's that closed it, or Claude's resolve, with why. */
const howClosed = (ask: Ask) => {
  const reply = closingReply(ask)

  if (reply !== undefined) {
    return answerOf(ask, reply)
  }

  return ask.reason === undefined ? 'resolved by Claude' : `resolved by Claude: ${ask.reason}`
}

const drawClosed = (d: Drawing, ask: Ask) => {
  const key = doneKey(ask)
  const isOpen = d.scene.pane.selected === key

  return drawRow(d, {
    key: `closed:${ask.id}`,
    mark: MARK,
    title: ask.title,
    at: ask.closedAt ?? ask.at,
    isOpen,
    press: { key, onPress: () => d.act.select(key) },
    branches: isOpen ? [howClosed(ask)] : [],
  })
}

/**
 * What has DONE opened to every one, if anything: its own toggle, or an
 * ask past the latest few, opened there, which must not fold away under
 * the press that opened it.
 */
const openedToAllBy = (asks: readonly Ask[], toggle: string, selected: string | null) =>
  [toggle, ...asks.slice(LATEST).map(doneKey)].find(key => key === selected)

export const drawDone = (d: Drawing, { work }: Filed) => {
  const { Box, Button } = d.els
  const asks = doneEarlier(work, d.scene.now)
  const key = `earlier:${work.id}`
  const allBy = openedToAllBy(asks, key, d.scene.pane.selected)

  if (asks.length === 0) {
    return null
  }

  return (
    <Box flexDirection="column">
      {heading(d, 'DONE', C.ok, `${asks.length} closed`)}
      {(allBy === undefined ? asks.slice(0, LATEST) : asks).map(ask => drawClosed(d, ask))}
      {asks.length > LATEST && (
        <Button
          key={key}
          plain
          label={allBy === undefined ? `show all ${asks.length}` : 'show fewer'}
          onPress={() => d.act.select(allBy ?? key)}
        />
      )}
    </Box>
  )
}
