/**
 * Ready to send, at the foot of every view while anything waits in it:
 * the replies grouped by where each goes, each hung from its item with its
 * own ✕, then send and cancel all. Only this session's group exists yet.
 */
import { answerOf } from '../../core'
import type { SitrepQueued } from '../../types'
import { C, counted } from '../look'
import { answered, isSending } from '../queue'
import { hung, type Drawing } from './kit'

const SENDING = '⧗ Sending. If Claude is mid-turn it goes in as soon as that turn ends.'

const drawReply = (d: Drawing, reply: SitrepQueued) => {
  const { Box, Text, Button } = d.els
  const item = answered(d.scene.work, reply)

  if (item === undefined) {
    return null
  }

  return (
    <Box key={`ready:${reply.item}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1}>
          <Text wrap="truncate-end">{item.title}</Text>
        </Box>
        {!isSending(d.scene.sending, reply) && (
          <Button
            key={`unready:${reply.item}`}
            plain
            dimColor
            label="✕"
            onPress={() => d.act.unqueue(reply.work, reply.item)}
          />
        )}
      </Box>
      {hung(d, `readyanswer:${reply.item}`, answerOf(item, reply))}
    </Box>
  )
}

const drawControls = (d: Drawing) => {
  const { Box, Text, Button } = d.els

  if (d.scene.sending.length > 0) {
    return (
      <Box paddingTop={1}>
        <Text color={C.grey} italic wrap="wrap">
          {SENDING}
        </Text>
      </Box>
    )
  }

  return (
    <Box flexDirection="row" columnGap={1} paddingTop={1}>
      <Button key="send" variant="primary" label="send to Claude" onPress={() => d.act.send()} />
      <Button
        key="cancel-all"
        dimColor
        label="cancel all"
        onPress={() => d.act.cancelAll(d.scene.work.id)}
      />
    </Box>
  )
}

export const drawReady = (d: Drawing) => {
  const { Box, Text } = d.els
  const { work, queue } = d.scene

  if (queue.length === 0) {
    return null
  }

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={C.ok} paddingX={1}>
      <Box flexDirection="row" justifyContent="space-between">
        <Text color={C.ok} bold>
          READY TO SEND
        </Text>
        <Text color={C.grey}>{counted(queue.length, 'reply', 'replies')}</Text>
      </Box>
      <Box key={`group:${work.id}`} flexDirection="column" paddingTop={1}>
        <Text color={C.grey}>to this session</Text>
        {queue.map(reply => drawReply(d, reply))}
      </Box>
      {drawControls(d)}
    </Box>
  )
}
