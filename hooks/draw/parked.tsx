/**
 * The parked view: what this work raised and put off, each to pick up.
 * A pick-up queues in Ready to send like any reply.
 */
import type { Parked } from '../../core'
import { ago, C, clip, GLYPH } from '../look'
import { queuedOn } from '../queue'
import { drawQueued, heading, type Drawing } from './kit'

const ABOUT = "What we said we'd come back to. Each stays until you pick it up and Claude has it."

/** Where to look, and the button that picks it up. */
const drawOpened = (d: Drawing, parked: Parked) => {
  const { Box, Text, Button } = d.els
  const work = d.scene.work.id

  return (
    <Box flexDirection="column">
      {parked.where !== undefined && (
        <Text color={C.soft} wrap="wrap">
          {parked.where}
        </Text>
      )}
      <Box flexDirection="row">
        <Button
          key={`pickup:${parked.id}`}
          label="pick it up"
          onPress={() => d.act.reply({ work, item: parked.id, verdict: 'pickup' })}
        />
      </Box>
    </Box>
  )
}

const drawItem = (d: Drawing, parked: Parked) => {
  const { Box, Text, Button } = d.els
  const { work, queue, pane, now } = d.scene
  const queued = queuedOn(queue, work.id, parked.id)

  return (
    <Box key={`parked:${parked.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Text color={C.parked}>{GLYPH.parked}</Text>
        <Box flexGrow={1} flexShrink={1}>
          <Button
            key={`ppick:${parked.id}`}
            plain
            label={clip(parked.title, d.width - 8)}
            onPress={() => d.act.select(parked.id)}
          />
        </Box>
        <Text color={C.grey}>{ago(now, parked.at)}</Text>
      </Box>
      <Box paddingLeft={2} flexDirection="column">
        {queued !== undefined
          ? drawQueued(d, parked, queued)
          : pane.selected === parked.id && drawOpened(d, parked)}
      </Box>
    </Box>
  )
}

export const drawParkedView = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const { parked } = d.scene.work

  return (
    <Box flexDirection="column" gap={1}>
      <Button
        key="back"
        plain
        dimColor
        label="← back to the board"
        onPress={() => d.act.show('session')}
      />
      <Box flexDirection="column">
        {heading(d, 'PARKED IN THIS SESSION', C.parked, `${parked.length}`)}
        <Text color={C.grey} italic wrap="wrap">
          {ABOUT}
        </Text>
      </Box>
      <Box flexDirection="column" rowGap={1}>
        {parked.length === 0 && <Text color={C.grey}>Nothing parked.</Text>}
        {parked.map(each => drawItem(d, each))}
      </Box>
    </Box>
  )
}
