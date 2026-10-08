/**
 * Ready to send, at the foot of every view while anything waits in it or
 * is on its way: the replies grouped by where each goes, this session
 * first, each hung from its item with its own ✕, then send and cancel all.
 *
 * Replies sent into another work's inbox stay in their group until Claude
 * has them, and a while after: the group says where they stand there, and
 * each reply whether it is on its way or when it was delivered.
 */
import { answerOf, deliveryOf, type Delivery, type Reply } from '../../core'
import type { SitrepQueued, SitrepSent } from '../../types'
import { agoWords, C, counted, GLYPH } from '../look'
import { filedAt, workLabel } from '../places'
import { answered, destinations, isSending, isShowing, queuedFor, sentIn } from '../queue'
import type { Filed, Scene } from '../scene'
import { hung, type Drawing } from './kit'

const SENDING = '⧗ Sending. If Claude is mid-turn it goes in as soon as that turn ends.'

/** Where a group's sent replies stand, as its line says it. */
const STANDING: Record<Delivery, { text: string; color: string }> = {
  delivered: { text: `${GLYPH.done} delivered`, color: C.ok },
  waiting: { text: '⧗ waiting for its turn to end', color: C.grey },
  closed: { text: '○ closed: goes in when it reopens', color: C.grey },
}

/** One destination: the work, the replies waiting for it, and those sent to it Ready to send still shows. */
type Group = { filed: Filed; queued: SitrepQueued[]; sent?: SitrepSent }

/** Each destination, this session first, then as first queued, then those only sent to. */
const groupsOf = (scene: Scene): Group[] => {
  const held = scene.work.id
  const queued = [...queuedFor(scene.queue, held), ...scene.queue]

  return destinations([...queued, ...scene.sent]).flatMap(({ work }) => {
    const filed = filedAt(scene, work)
    const sent = scene.sent.find(each => each.work === work)

    if (filed === undefined) {
      return []
    }

    const group: Group = {
      filed,
      queued: queuedFor(scene.queue, work).filter(reply => answered(filed.work, reply)),
      sent: sent !== undefined && isShowing(filed.work, sent, scene.now) ? sent : undefined,
    }

    return group.queued.length > 0 || group.sent !== undefined ? [group] : []
  })
}

const drawReply = (d: Drawing, { work }: Filed, reply: SitrepQueued) => {
  const { Box, Text, Button } = d.els
  const item = answered(work, reply)

  if (item === undefined) {
    return null
  }

  return (
    <Box key={`ready:${reply.work}:${reply.item}`} flexDirection="column">
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

/** A reply sent into the work's inbox: what it answers, and whether Claude has it yet. */
const drawSent = (d: Drawing, { work }: Filed, reply: Reply) => {
  const { Box, Text } = d.els
  const item = work.items.get(reply.item)

  if (item === undefined || item.type === 'note') {
    return null
  }

  const standing =
    reply.deliveredAt === undefined
      ? '· on its way'
      : `· delivered ${agoWords(d.scene.now, reply.deliveredAt)}`

  return (
    <Box key={`sentreply:${reply.id}`} flexDirection="column">
      <Text wrap="truncate-end">{item.title}</Text>
      {hung(
        d,
        `sentanswer:${reply.id}`,
        answerOf(item, reply),
        <Text color={C.grey}>{standing}</Text>,
      )}
    </Box>
  )
}

const drawGroup = (d: Drawing, { filed, queued, sent }: Group) => {
  const { Box, Text } = d.els
  const label = filed.work === d.scene.work ? 'to this session' : `to ${workLabel(d.scene, filed)}`
  const standing = sent === undefined ? undefined : STANDING[deliveryOf(filed.work, sent.replies)]

  return (
    <Box key={`group:${filed.work.id}`} flexDirection="column" paddingTop={1}>
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1}>
          <Text color={C.grey} wrap="truncate-end">
            {label}
          </Text>
        </Box>
        {standing !== undefined && <Text color={standing.color}>{standing.text}</Text>}
      </Box>
      {queued.map(reply => drawReply(d, filed, reply))}
      {sent !== undefined && sentIn(filed.work, sent).map(reply => drawSent(d, filed, reply))}
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
      <Button key="cancel-all" dimColor label="cancel all" onPress={() => d.act.cancelAll()} />
    </Box>
  )
}

export const drawReady = (d: Drawing) => {
  const { Box, Text } = d.els
  const groups = groupsOf(d.scene)
  const waiting = groups.reduce((sum, group) => sum + group.queued.length, 0)

  if (groups.length === 0) {
    return null
  }

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={C.ok} paddingX={1}>
      <Box flexDirection="row" justifyContent="space-between">
        <Text color={C.ok} bold>
          READY TO SEND
        </Text>
        <Text color={C.grey}>{waiting > 0 ? counted(waiting, 'reply', 'replies') : 'sent'}</Text>
      </Box>
      {groups.map(group => drawGroup(d, group))}
      {waiting > 0 && drawControls(d)}
    </Box>
  )
}
