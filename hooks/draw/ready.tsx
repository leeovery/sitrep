/**
 * Ready to send, at the foot of every view while anything waits in it or
 * is on its way: the replies grouped by where each goes, this session
 * first, each hung from its item with its own ✕, then send and cancel all.
 *
 * Replies sent into another session's inbox stay in their group until Claude
 * has them, and a while after: the group says where they stand there, and
 * each reply whether it is on its way or when it was delivered. A reply that
 * will not go, or never went in, says why in its answer's place.
 *
 * Each of the box's lines takes one row, cut short rather than wrapped, so
 * its height follows from what it lists (`readyRows`): a docked board keeps
 * that many rows of its window for it, under its list. Given fewer rows
 * than it needs, it lists what fits and says how many more it holds.
 */
import type { RenderElement } from 'claude-code'
import {
  deliveryOf,
  type Ask,
  type Barred,
  type Delivery,
  type Parked,
  type Reply,
  type ReplyFields,
  type Voided,
} from '../../core'
import type { SitrepInFlight, SitrepQueued } from '../../types'
import { agoWords, C, counted, GLYPH, wrapped } from '../look'
import { filedAt, itemKey, sessionLabel } from '../places'
import { answered, destinations, heldBack, isCarried, isShowing, queuedFor, sentIn } from '../queue'
import type { Filed, Scene } from '../scene'
import { drawReplyRow, drawRewrite, NOT_SENT, type Drawing } from './kit'

const SENDING = '⧗ Sending. If Claude is mid-turn it goes in as soon as that turn ends.'

/** Why a sent reply never went in: its item changed under it, took another answer of Lee's first, or Claude closed it; or its session was finished. */
const NOT_DELIVERED: Record<Voided, string> = {
  changed: '· not delivered: it changed since',
  answered: '· not delivered: already answered',
  resolved: '· not delivered: Claude closed it',
  finished: '· not delivered: the session was finished',
}

/** Where a group's sent replies stand, as its line says it. */
const STANDING: Record<Delivery, { text: string; color: string }> = {
  delivered: { text: `${GLYPH.done} delivered`, color: C.ok },
  waiting: { text: '⧗ waiting for its turn to end', color: C.grey },
  closed: { text: '○ closed: goes in when it reopens', color: C.grey },
  void: { text: '✕ not delivered', color: C.grey },
}

/** The keys of the box's own buttons. */
const SEND = 'send'
const CANCEL_ALL = 'cancel-all'
const UNREADY = 'unready:'

/** The rows the box takes besides its lines: its border, top and bottom. */
const BORDER_ROWS = 2
/** The heading: the box's name and how many replies wait. */
const HEAD_ROWS = 1
/** The blank row above each group, and above send and cancel all or the line saying a send is on its way. */
const GAP_ROWS = 1
/** A group's rows before its replies: the blank row, and the line saying where they go. */
const GROUP_ROWS = GAP_ROWS + 1
/** A reply's rows: what it answers, and the answer hung under it. */
const REPLY_ROWS = 2
/** The line counting the replies left off for room. */
const MORE_ROWS = 1
/** The cells across the box keeps from its lines: its border and its padding, each side. */
const BOX_SIDES = 4

/** A reply waiting for a send, the item it answers, and what holds it back from one, if anything does. */
type Queued = { item: Ask | Parked; queued: SitrepQueued; barred?: Barred }

/** A reply sent into its session's inbox, and the item it answers. */
type Sent = { item: Ask | Parked; sent: Reply }

type Listed = Queued | Sent

/** One destination: the session, where the replies sent to it stand there, and the replies listed for it. */
type Group = { filed: Filed; standing?: Delivery; listed: Listed[] }

/** Ready to send as the box draws it. */
export type Ready = {
  groups: readonly Group[]
  /** How many replies wait for a send, any left off for room among them. */
  waiting: number
  /** How many replies are left off for room. */
  more: number
  /** While a send is on its way, the line saying so, as the rows it takes; else none. */
  sending: readonly string[]
}

/** A session's queued replies that fit their items, each with what holds it back from a send, if anything does. */
const queuedIn = (
  { session }: Filed,
  queue: readonly SitrepQueued[],
  inFlight: SitrepInFlight | null,
): Queued[] =>
  queuedFor(queue, session.id).flatMap(queued => {
    const item = answered(session, queued)

    return item === undefined ? [] : [{ item, queued, barred: heldBack(inFlight, item, queued) }]
  })

const sentTo = ({ session }: Filed, replies: readonly Reply[]): Sent[] =>
  replies.flatMap(sent => {
    const item = session.items.get(sent.item)

    return item === undefined || item.type === 'note' ? [] : [{ item, sent }]
  })

/** Each destination, this session first, then as first queued, then those only sent to. */
const groupsOf = (scene: Scene): Group[] => {
  const held = scene.session.id
  const queued = [...queuedFor(scene.queue, held), ...scene.queue]

  return destinations([...queued, ...scene.sent]).flatMap(({ session }): Group[] => {
    const filed = filedAt(scene, session)
    const sent = scene.sent.find(each => each.session === session)

    if (filed === undefined) {
      return []
    }

    const waiting = queuedIn(filed, scene.queue, scene.inFlight)

    if (sent === undefined || !isShowing(filed.session, sent, scene.now)) {
      return waiting.length > 0 ? [{ filed, listed: waiting }] : []
    }

    return [
      {
        filed,
        standing: deliveryOf(filed.session, sent.replies),
        listed: [...waiting, ...sentTo(filed, sentIn(filed.session, sent))],
      },
    ]
  })
}

const listedIn = (groups: readonly Group[]) =>
  groups.reduce((sum, group) => sum + group.listed.length, 0)

const groupRows = (groups: readonly Group[]) =>
  groups.length * GROUP_ROWS + listedIn(groups) * REPLY_ROWS

const controlsRows = ({ waiting, sending }: Ready) => {
  if (waiting === 0) {
    return 0
  }

  return GAP_ROWS + (sending.length > 0 ? sending.length : 1)
}

/** The rows the box takes: each of its lines one, and its border. */
export const readyRows = (ready: Ready) =>
  BORDER_ROWS +
  HEAD_ROWS +
  groupRows(ready.groups) +
  (ready.more > 0 ? MORE_ROWS : 0) +
  controlsRows(ready)

/**
 * The groups that fit in `room` rows: all of them, or those up to the first
 * that will not fit whole, it cut short, with a row kept for the count of
 * what was left off. A group listing replies shows with one of them at least.
 */
const fitted = (groups: readonly Group[], room: number) => {
  if (groupRows(groups) <= room) {
    return groups
  }

  const kept: Group[] = []
  let left = room - MORE_ROWS

  for (const group of groups) {
    const fits = Math.min(group.listed.length, Math.floor((left - GROUP_ROWS) / REPLY_ROWS))

    if (fits < Math.min(1, group.listed.length)) {
      break
    }

    kept.push({ ...group, listed: group.listed.slice(0, fits) })
    left -= GROUP_ROWS + fits * REPLY_ROWS

    if (fits < group.listed.length) {
      break
    }
  }

  return kept
}

/**
 * Ready to send as it draws `width` cells across in at most `rows` rows,
 * however few: its heading and buttons always show. Undefined while
 * nothing waits in it or is on its way.
 */
export const readyOf = (scene: Scene, width: number, rows = Infinity): Ready | undefined => {
  const groups = groupsOf(scene)

  if (groups.length === 0) {
    return undefined
  }

  const frame: Ready = {
    groups: [],
    waiting: groups.reduce(
      (sum, group) => sum + group.listed.filter(listed => 'queued' in listed).length,
      0,
    ),
    more: 0,
    sending: scene.inFlight?.source === 'send' ? wrapped(SENDING, width - BOX_SIDES) : [],
  }
  const kept = fitted(groups, rows - readyRows(frame))

  return { ...frame, groups: kept, more: listedIn(groups) - listedIn(kept) }
}

/** A line of the box, cut short at the edge. */
const line = ({ els }: Drawing, text: string, color?: string) => {
  const { Text } = els

  return (
    <Text color={color} wrap="truncate-end">
      {text}
    </Text>
  )
}

/** The answer hung from its reply's title by a `└`, on one row, and what goes after it there. */
const drawAnswer = (
  d: Drawing,
  key: string,
  item: Ask | Parked,
  reply: ReplyFields,
  after?: RenderElement,
) => {
  const { Box, Text } = d.els

  return (
    <Box key={key} flexDirection="row" gap={1}>
      <Text color={C.faint}>{GLYPH.last}</Text>
      {drawReplyRow(d, item, reply, after)}
    </Box>
  )
}

/** What follows a queued reply's answer: why it will not go, where something holds it back; else its edit, unless a send carries it. */
const afterQueued = (d: Drawing, key: string, { item, queued, barred }: Queued) => {
  if (barred !== undefined) {
    return line(d, NOT_SENT[barred], C.grey)
  }

  return isCarried(d.scene.inFlight, queued)
    ? undefined
    : drawRewrite(d, `readyrewrite:${key}`, item, queued)
}

/** A reply waiting for a send, as the box lists it: what it answers, its ✕, and the answer under it. */
const drawQueuedEntry = (d: Drawing, entry: Queued) => {
  const { item, queued } = entry
  const { Box, Button } = d.els
  const key = itemKey(queued.session, queued.item)

  return (
    <Box key={`ready:${key}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1}>
          {line(d, item.title)}
        </Box>
        {!isCarried(d.scene.inFlight, queued) && (
          <Button
            key={`${UNREADY}${key}`}
            plain
            dimColor
            label="✕"
            onPress={() => d.act.unqueue(queued.session, queued.item)}
          />
        )}
      </Box>
      {drawAnswer(d, `readyanswer:${key}`, item, queued, afterQueued(d, key, entry))}
    </Box>
  )
}

/** A reply sent into the session's inbox, as the box lists it: what it answers, and whether Claude has it yet. */
const drawSentEntry = (d: Drawing, { item, sent }: Sent) => {
  const { Box } = d.els
  const standing =
    sent.voided !== undefined
      ? NOT_DELIVERED[sent.voided]
      : sent.deliveredAt === undefined
        ? '· on its way'
        : `· delivered ${agoWords(d.scene.now, sent.deliveredAt)}`

  return (
    <Box key={`sentreply:${sent.id}`} flexDirection="column">
      {line(d, item.title)}
      {drawAnswer(d, `sentanswer:${sent.id}`, item, sent, line(d, standing, C.grey))}
    </Box>
  )
}

const drawGroup = (d: Drawing, { filed, standing, listed }: Group) => {
  const { Box } = d.els
  const label =
    filed.session === d.scene.session ? 'to this session' : `to ${sessionLabel(d.scene, filed)}`
  const stands = standing === undefined ? undefined : STANDING[standing]

  return (
    <Box key={`group:${filed.session.id}`} flexDirection="column" paddingTop={GAP_ROWS}>
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1}>
          {line(d, label, C.grey)}
        </Box>
        {stands !== undefined && line(d, stands.text, stands.color)}
      </Box>
      {listed.map(each => ('queued' in each ? drawQueuedEntry(d, each) : drawSentEntry(d, each)))}
    </Box>
  )
}

const drawControls = (d: Drawing, { sending }: Ready) => {
  const { Box, Text, Button } = d.els

  if (sending.length > 0) {
    return (
      <Box flexDirection="column" paddingTop={GAP_ROWS}>
        {sending.map((row, i) => (
          <Text key={`sending:${i}`} color={C.grey} italic wrap="truncate-end">
            {row}
          </Text>
        ))}
      </Box>
    )
  }

  return (
    <Box flexDirection="row" columnGap={1} paddingTop={GAP_ROWS}>
      <Button
        key={SEND}
        variant="primary"
        label="send to Claude"
        onPress={() => d.act.send(d.isDock)}
      />
      <Button key={CANCEL_ALL} dimColor label="cancel all" onPress={() => d.act.cancelAll()} />
    </Box>
  )
}

/** The box, `readyRows(ready)` rows tall. */
export const drawReady = (d: Drawing, ready: Ready) => {
  const { Box, Text } = d.els
  const { groups, waiting, more } = ready

  return (
    <Box key="ready" flexDirection="column" borderStyle="round" borderColor={C.ok} paddingX={1}>
      <Box flexDirection="row" justifyContent="space-between">
        <Text color={C.ok} bold wrap="truncate-end">
          READY TO SEND
        </Text>
        {line(d, waiting > 0 ? counted(waiting, 'reply', 'replies') : 'sent', C.grey)}
      </Box>
      {groups.map(group => drawGroup(d, group))}
      {more > 0 && line(d, `… ${more} more`, C.grey)}
      {waiting > 0 && drawControls(d, ready)}
    </Box>
  )
}
