/**
 * Ready to send, at the foot of every view while anything waits in it or
 * is on its way. Each send of Lee's on its way leads, a group of its own in
 * the order sent: the replies it carries, frozen, then the line saying where
 * it stands, with its take-back while the window holds it for its turn.
 * Under them, the replies still to send, grouped by where each goes, this
 * session first, each hung from its item with its own ✕, then send and
 * cancel all, which reach only those.
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
import {
  answered,
  destinations,
  heldBack,
  isCarried,
  isCarriedBy,
  isShowing,
  queuedFor,
  sentIn,
  unsent,
} from '../queue'
import type { Filed, Scene } from '../scene'
import { drawReplyRow, drawRewrite, NOT_SENT, type Drawing } from './kit'

/** A send the window holds while Claude is mid-turn, which Lee can take back until it goes. */
const HELD = "⧗ Waiting for Claude's turn to end."

/** A send submitted, beyond taking back. */
const SENDING = '⧗ Sending.'

/** Why a sent reply never went in: its item changed under it, took another answer of Lee's first, or Claude closed it; or its session was finished. */
const NOT_DELIVERED: Record<Voided, string> = {
  changed: '· not delivered: it changed since',
  answered: '· not delivered: already answered',
  resolved: '· not delivered: Claude closed it',
  finished: '· not delivered: the session was finished',
}

/**
 * What a sent reply Claude has that settled nothing says after when it went
 * in: its item changed under it, or, void as its item closed, was reopened
 * before a mark said Claude has it.
 */
const UNSETTLED: Record<Voided, string> = {
  changed: ', but it changed since',
  answered: ', but it was reopened since',
  resolved: ', but it was reopened since',
  finished: ', but it was reopened since',
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

/** What tells one send on its way from another in the box, as two claimed in one millisecond would not be told by their time: the ids of the replies it carries, fixed at its claim. */
const sendKey = (send: SitrepInFlight) => send.replies.map(reply => reply.id).join(',')

/** The key of a held send's take-back. */
export const takeBackKey = (send: SitrepInFlight) => `take-back:${sendKey(send)}`

/** The rows the box takes besides its lines: its border, top and bottom. */
const BORDER_ROWS = 2
/** The heading: the box's name and how many replies wait. */
const HEAD_ROWS = 1
/** The blank row above each group, and above send and cancel all. */
const GAP_ROWS = 1
/** A group's rows before its replies: the blank row, and the line saying where they go. */
const GROUP_ROWS = GAP_ROWS + 1
/** A reply's rows: what it answers, and the answer hung under it. */
const REPLY_ROWS = 2
/** The line counting the replies left off for room. */
const MORE_ROWS = 1
/** The cells across the box keeps from its lines: its border and its padding, each side. */
const BOX_SIDES = 4

/** A reply waiting for a send, or carried by one on its way, the item it answers, and what holds it back from a send, if anything does. */
type Queued = { item: Ask | Parked; queued: SitrepQueued; barred?: Barred }

/** A reply sent into its session's inbox, and the item it answers. */
type Sent = { item: Ask | Parked; sent: Reply }

type Listed = Queued | Sent

/** A send of Lee's on its way, and the line saying where it stands, as the rows it takes: held for its turn, to be taken back, or submitted. */
type Going = { send: SitrepInFlight; rows: readonly string[]; isHeld: boolean }

/**
 * One group of the box: the replies a send on its way carries, over its
 * line; or one destination's replies still to send, with where those sent
 * into its inbox stand there.
 */
type Group = { filed: Filed; listed: Listed[]; standing?: Delivery; going?: Going }

/** Ready to send as the box draws it. */
export type Ready = {
  groups: readonly Group[]
  /** How many replies are not yet with Claude: those the sends on their way carry, and those still to send, any left off for room among them. */
  waiting: number
  /** How many replies wait for a send, any left off for room among them. */
  toSend: number
  /** How many replies are left off for room. */
  more: number
}

/** A session's queued replies that fit their items, each with what holds it back from a send, if anything does. */
const queuedIn = (
  { session }: Filed,
  queue: readonly SitrepQueued[],
  flights: readonly SitrepInFlight[],
): Queued[] =>
  queuedFor(queue, session.id).flatMap(queued => {
    const item = answered(session, queued)

    return item === undefined ? [] : [{ item, queued, barred: heldBack(flights, item, queued) }]
  })

const sentTo = ({ session }: Filed, replies: readonly Reply[]): Sent[] =>
  replies.flatMap(sent => {
    const item = session.items.get(sent.item)

    return item === undefined || item.type === 'note' ? [] : [{ item, sent }]
  })

/** Where a send on its way stands, as its line says it: held, one row cut short beside its take-back; submitted, wrapped. */
const goingOf = (send: SitrepInFlight, width: number): Going =>
  send.isHeld
    ? { send, rows: [HELD], isHeld: true }
    : { send, rows: wrapped(SENDING, width - BOX_SIDES), isHeld: false }

/** A send of Lee's on its way as a group of its own: the replies it carries, and its line. None for the inbox's message, whose replies Lee sent from elsewhere. */
const goingGroup = (scene: Scene, send: SitrepInFlight, width: number): Group[] => {
  const filed = send.source === 'send' ? filedAt(scene, send.session) : undefined

  if (filed === undefined) {
    return []
  }

  const carried = scene.queue.filter(queued => isCarriedBy(send, queued))

  return [{ filed, listed: queuedIn(filed, carried, scene.inFlight), going: goingOf(send, width) }]
}

/** Each destination of the replies still to send, this session first, then as first queued, then those only sent to. */
const unsentGroups = (scene: Scene): Group[] => {
  const queue = unsent(scene.queue, scene.inFlight)
  const queued = [...queuedFor(queue, scene.session.id), ...queue]

  return destinations([...queued, ...scene.sent]).flatMap(({ session }): Group[] => {
    const filed = filedAt(scene, session)
    const sent = scene.sent.find(each => each.session === session)

    if (filed === undefined) {
      return []
    }

    const waiting = queuedIn(filed, queue, scene.inFlight)

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

/** The box's groups: each send on its way, in the order sent, then the replies still to send. */
const groupsOf = (scene: Scene, width: number): Group[] => [
  ...scene.inFlight.flatMap(send => goingGroup(scene, send, width)),
  ...unsentGroups(scene),
]

const listedIn = (groups: readonly Group[]) =>
  groups.reduce((sum, group) => sum + group.listed.length, 0)

/** How many replies the groups list that are not yet with Claude: queued, not sent into an inbox. */
const countQueued = (groups: readonly Group[]) =>
  groups.reduce((sum, group) => sum + group.listed.filter(listed => 'queued' in listed).length, 0)

/** The rows of a send's line: none for a group still to send. */
const goingRows = ({ going }: Group) => going?.rows.length ?? 0

/** The rows a group always takes, however few it is given: a send's heading and line; none for one still to send, which shows with a reply or not at all. */
const fixedRows = (group: Group) => (group.going === undefined ? 0 : GROUP_ROWS + goingRows(group))

const groupRows = (groups: readonly Group[]) =>
  groups.reduce(
    (sum, group) => sum + GROUP_ROWS + group.listed.length * REPLY_ROWS + goingRows(group),
    0,
  )

const controlsRows = ({ toSend }: Ready) => (toSend === 0 ? 0 : GAP_ROWS + 1)

/** The rows the box takes: each of its lines one, and its border. */
export const readyRows = (ready: Ready) =>
  BORDER_ROWS +
  HEAD_ROWS +
  groupRows(ready.groups) +
  (ready.more > 0 ? MORE_ROWS : 0) +
  controlsRows(ready)

/**
 * The groups that fit in `room` rows: all of them, or what fits of them in
 * order, a row kept for the count of what was left off. A send's group
 * always shows, its heading and its line, and so its take-back, with what
 * fits of its replies; a group still to send shows with one of its replies
 * at least, or neither it nor any after it does.
 */
const fitted = (groups: readonly Group[], room: number) => {
  if (groupRows(groups) <= room) {
    return groups
  }

  const kept: Group[] = []
  let left = room - MORE_ROWS - groups.reduce((sum, group) => sum + fixedRows(group), 0)
  let isFull = false

  for (const group of groups) {
    // A send's heading is kept already, with its line.
    const headingRows = group.going === undefined ? GROUP_ROWS : 0
    const share = isFull ? 0 : Math.floor((left - headingRows) / REPLY_ROWS)
    const fits = Math.max(0, Math.min(group.listed.length, share))

    if (group.going === undefined && fits === 0) {
      break
    }

    kept.push({ ...group, listed: group.listed.slice(0, fits) })
    left -= headingRows + fits * REPLY_ROWS
    isFull = isFull || fits < group.listed.length
  }

  return kept
}

/**
 * Ready to send as it draws `width` cells across in at most `rows` rows,
 * however few: its heading, each send's line and the buttons always show.
 * Undefined while nothing waits in it or is on its way.
 */
export const readyOf = (scene: Scene, width: number, rows = Infinity): Ready | undefined => {
  const groups = groupsOf(scene, width)

  if (groups.length === 0) {
    return undefined
  }

  const frame: Ready = {
    groups: [],
    waiting: countQueued(groups),
    toSend: countQueued(groups.filter(group => group.going === undefined)),
    more: 0,
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

/** Whether Claude has a sent reply, and since when; one that settled nothing says why. */
const sentWords = (now: number, sent: Reply) => {
  if (sent.deliveredAt === undefined) {
    return sent.voided === undefined ? '· on its way' : NOT_DELIVERED[sent.voided]
  }

  const unsettled = sent.voided === undefined ? '' : UNSETTLED[sent.voided]

  return `· delivered ${agoWords(now, sent.deliveredAt)}${unsettled}`
}

/** A reply sent into the session's inbox, as the box lists it: what it answers, and whether Claude has it yet. */
const drawSentEntry = (d: Drawing, { item, sent }: Sent) => {
  const { Box } = d.els
  const standing = sentWords(d.scene.now, sent)

  return (
    <Box key={`sentreply:${sent.id}`} flexDirection="column">
      {line(d, item.title)}
      {drawAnswer(d, `sentanswer:${sent.id}`, item, sent, line(d, standing, C.grey))}
    </Box>
  )
}

/** The line saying where a send on its way stands, under its replies; held, its take-back beside it. */
const drawGoing = (d: Drawing, { send, rows, isHeld }: Going) => {
  const { Box, Text, Button } = d.els
  const lines = rows.map((row, i) => (
    <Text key={`going:${i}`} color={C.grey} italic wrap="truncate-end">
      {row}
    </Text>
  ))

  if (!isHeld) {
    return <Box flexDirection="column">{lines}</Box>
  }

  return (
    <Box flexDirection="row" columnGap={1}>
      <Box flexGrow={1} flexShrink={1}>
        {lines}
      </Box>
      <Button
        key={takeBackKey(send)}
        plain
        dimColor
        label="↺ take back"
        onPress={() => d.act.takeBack(send)}
      />
    </Box>
  )
}

/** Where a group's replies go, as its heading says it: on their way there, for a send's. */
const headingOf = (d: Drawing, { filed, going }: Group) => {
  const to =
    filed.session === d.scene.session ? 'to this session' : `to ${sessionLabel(d.scene, filed)}`

  return going === undefined ? to : `on its way ${to}`
}

const drawGroup = (d: Drawing, group: Group) => {
  const { Box } = d.els
  const { filed, standing, listed, going } = group
  const stands = standing === undefined ? undefined : STANDING[standing]
  const key = going === undefined ? `group:${filed.session.id}` : `going:${sendKey(going.send)}`

  return (
    <Box key={key} flexDirection="column" paddingTop={GAP_ROWS}>
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1}>
          {line(d, headingOf(d, group), C.grey)}
        </Box>
        {stands !== undefined && line(d, stands.text, stands.color)}
      </Box>
      {listed.map(each => ('queued' in each ? drawQueuedEntry(d, each) : drawSentEntry(d, each)))}
      {going !== undefined && drawGoing(d, going)}
    </Box>
  )
}

/** Send and cancel all, for the replies still to send. */
const drawControls = (d: Drawing) => {
  const { Box, Button } = d.els

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
  const { groups, waiting, toSend, more } = ready

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
      {toSend > 0 && drawControls(d)}
    </Box>
  )
}
