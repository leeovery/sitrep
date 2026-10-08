/**
 * For you's history: how many asks closed earlier, as the press that opens
 * the list of them, the newest closed first, each hung with how it closed
 * and when.
 */
import { answerOf, closingReply, type Ask } from '../../core'
import { agoWords, C, GLYPH } from '../look'
import { doneEarlier, type Filed } from '../scene'
import { drawMark, replyLine, tree, type Drawing } from './kit'

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

export const drawEarlier = (d: Drawing, { work }: Filed) => {
  const { Box, Button } = d.els
  const asks = doneEarlier(work, d.scene.now)
  const key = `earlier:${work.id}`

  if (asks.length === 0) {
    return null
  }

  return (
    <Box flexDirection="column" rowGap={1}>
      <Button
        key={key}
        plain
        label={`${GLYPH.done} ${asks.length} done earlier`}
        onPress={() => d.act.select(key)}
      />
      {d.scene.pane.selected === key && asks.map(ask => drawClosed(d, ask))}
    </Box>
  )
}
