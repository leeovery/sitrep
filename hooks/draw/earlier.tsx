/**
 * A session's DONE, at the foot of its view: the asks closed earlier, the
 * newest closed first, each hung with how it closed and when. It shows the
 * latest few, and a press opens it to every one.
 */
import { answerOf, closingReply, type Ask } from '../../core'
import { agoWords, C, GLYPH } from '../look'
import { doneEarlier, type Filed } from '../scene'
import { drawMark, heading, replyLine, tree, type Drawing } from './kit'

/** How many closed asks DONE shows until it is opened to them all. */
const LATEST = 3

/** The mark of an ask that closed a while ago. */
const CLOSED = { glyph: GLYPH.done, color: C.faint }

/** How an ask closed: the reply of Lee's that closed it, or Claude's resolve, with why. */
const howClosed = (ask: Ask) => {
  const reply = closingReply(ask)

  if (reply !== undefined) {
    return answerOf(ask, reply)
  }

  return ask.reason === undefined ? 'resolved by Claude' : `resolved by Claude: ${ask.reason}`
}

const drawClosed = (d: Drawing, ask: Ask) => {
  const { Box, Text } = d.els
  const age = <Text color={C.grey}>{`· ${agoWords(d.scene.now, ask.closedAt ?? ask.at)}`}</Text>

  return (
    <Box key={`closed:${ask.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        {drawMark(d, CLOSED, 1, true)}
        <Box flexGrow={1} flexShrink={1}>
          <Text color={C.faint} wrap="truncate-end">
            {ask.title}
          </Text>
        </Box>
      </Box>
      {tree(d, `how:${ask.id}`, [replyLine(d, howClosed(ask), age)])}
    </Box>
  )
}

export const drawDone = (d: Drawing, { work }: Filed) => {
  const { Box, Button } = d.els
  const asks = doneEarlier(work, d.scene.now)
  const key = `earlier:${work.id}`
  const isAll = d.scene.pane.selected === key

  if (asks.length === 0) {
    return null
  }

  return (
    <Box flexDirection="column">
      {heading(d, 'DONE', C.ok, `${asks.length} closed`)}
      <Box flexDirection="column" rowGap={1}>
        {(isAll ? asks : asks.slice(0, LATEST)).map(ask => drawClosed(d, ask))}
        {asks.length > LATEST && (
          <Button
            key={key}
            plain
            label={isAll ? 'show fewer' : `show all ${asks.length}`}
            onPress={() => d.act.select(key)}
          />
        )}
      </Box>
    </Box>
  )
}
