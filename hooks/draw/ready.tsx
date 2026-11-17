/**
 * Ready to send, at the foot of every view while anything waits in it or
 * is on its way. Each send of Lee's on its way leads, a group of its own in
 * the order sent: the replies it carries, frozen, then the line saying where
 * it stands, with its take-back while the window holds it for its turn.
 * Under them, the replies still to send, grouped by where each goes, this
 * session first, a pick-up always to it whichever session of the project
 * parked its item, each hung from its item with its own ✕, then send and
 * cancel all, which reach only those, while any of them would go.
 *
 * Replies sent into another session's inbox stay in their group until Claude
 * has them, and a while after: the group says where they stand there, and
 * each reply whether it is on its way or when it was delivered. A reply that
 * will not go, or never went in, says why in its answer's place.
 *
 * Each of the box's lines takes one row, cut short rather than wrapped, so
 * its height follows from what it lists (`readyRows`): a docked board keeps
 * that many rows of its window for it, under its list. Given fewer rows
 * than it needs, it draws each send after the first as one row, its
 * take-back beside it, lists what fits and says how many more it holds.
 */
import type { RenderElement } from 'claude-code'
import {
  deliveryOf,
  type Ask,
  type Delivery,
  type Parked,
  type Reply,
  type ReplyFields,
  type Voided,
} from '../../core'
import type { SitrepInFlight, SitrepQueued } from '../../types'
import { agoWords, C, counted, GLYPH, wrapped } from '../look'
import { briefOf, filedAt, itemKey, sessionLabel } from '../places'
import {
  answered,
  destinations,
  goesTo,
  heldBack,
  isCarried,
  isCarriedBy,
  isShowing,
  queuedFor,
  sentIn,
  unsent,
  type HeldBack,
} from '../queue'
import type { Filed, Scene } from '../scene'
import { answeredByTheHook, drawReplyRow, drawRewrite, NOT_SENT, type Drawing } from './kit'

/** A send the window holds while Claude is mid-turn, which Lee can take back until it goes. */
const HELD = "⧗ Waiting for Claude's turn to end."

/** The first send held while Lee has stopped Claude's turn, Claude Code refusing the window's prompts until his input: Lee can send it now, or take it back. */
const STOPPED = '⧗ Interrupted: goes after your next message.'

/** A send held behind it, which no turn of Claude's holds. */
const BEHIND_STOP = '⧗ Goes after your next message.'

/** A send submitted, beyond taking back. */
const SENDING = '⧗ Sending.'

/** The take-back's label, whose cells a held send's line leaves it. */
const TAKE_BACK_LABEL = '↺ take back'

/** The label of the button sending now what the window holds while Lee has stopped Claude's turn. */
const SEND_NOW_LABEL = '↑ send now'

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

/**
 * The keys of the box's own buttons. A press on send is answered by the
 * `ui.press` hook, inside the press itself, where Claude Code takes the
 * submit though Lee stopped Claude's turn.
 */
export const SEND = 'send'
const CANCEL_ALL = 'cancel-all'
const UNREADY = 'unready:'

/** The key of the button stepping to the next held send the box has no row for. */
export const STEP_HELD = 'step-held'

/**
 * The key of the button sending now what the window holds while Lee has
 * stopped Claude's turn, beside the first send held: one at most. Its press
 * sends the first message in flight, answered by the `ui.press` hook inside
 * the press itself, where Claude Code takes the submit.
 */
export const SEND_NOW = 'send-now'

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
/** A send drawn brief: one row, under the send ahead of it. */
const BRIEF_ROWS = 1
/** The cells across the box keeps from its lines: its border and its padding, each side. */
const BOX_SIDES = 4
/** The row under the first send held while the window is stopped, holding its send now and take-back. */
const BUTTONS_ROWS = 1

/** A reply waiting for a send, or carried by one on its way, the item it answers, and what holds it back from a send, if anything does. */
type Queued = { item: Ask | Parked; queued: SitrepQueued; barred?: HeldBack }

/** A reply sent into its session's inbox, and the item it answers. */
type Sent = { item: Ask | Parked; sent: Reply }

type Listed = Queued | Sent

/** A send of Lee's on its way, and the line saying where it stands, as the rows it takes: held, to be taken back, and sent now where it waits on Lee's next message; or submitted. */
type Going = { send: SitrepInFlight; rows: readonly string[]; isHeld: boolean; sendsNow: boolean }

/** Where the row standing for several held sends is: the one it shows, of how many, and the key of the one it steps to next. */
type Step = { at: number; of: number; next: string }

/**
 * A send of Lee's on its way, a group of its own: the replies it carries,
 * frozen, over its line. Brief, it is one row under the send ahead of it,
 * naming the first of them, where the box has no room for more; stepping,
 * that row stands for the sends the box has no row for, showing one at a
 * time. One to a session the board has not read lists none of them, its
 * line and its take-back showing all the same.
 */
type SendGroup = { going: Going; filed?: Filed; listed: Listed[]; isBrief: boolean; step?: Step }

/** One destination's replies still to send, and those sent into its inbox, with where they stand there. */
type ToSendGroup = { going?: undefined; filed: Filed; listed: Listed[]; standing?: Delivery }

type Group = SendGroup | ToSendGroup

/** Ready to send as the box draws it. */
export type Ready = {
  groups: readonly Group[]
  /** How many replies are not yet with Claude: those the sends on their way carry, and those still to send, any left off for room among them. */
  waiting: number
  /** How many replies a send would carry, any left off for room among them: none held back (`heldBack`). Send shows while any would go. */
  toSend: number
  /** How many replies are left off for room. */
  more: number
}

/** Queued replies that fit their items, each read in its own session where the board has that in full, with what holds it back from a send, if anything does. */
const queuedIn = (scene: Scene, queue: readonly SitrepQueued[]): Queued[] =>
  queue.flatMap(queued => {
    const filed = filedAt(scene, queued.session)
    const item = filed === undefined ? undefined : answered(filed.session, queued)

    return item === undefined ? [] : [{ item, queued, barred: heldBack(scene, item, queued) }]
  })

const sentTo = ({ session }: Filed, replies: readonly Reply[]): Sent[] =>
  replies.flatMap(sent => {
    const item = session.items.get(sent.item)

    return item === undefined ? [] : [{ item, sent }]
  })

/** What a held send waits on: Claude's turn; or, Lee having stopped Claude's turn, his input, as the first send, or behind it. */
type Holding = 'turn' | 'stop' | 'behindStop'

/**
 * Where a send on its way stands, as its line says it: held as the first
 * while the window is stopped, wrapped across the box, its send now and
 * take-back on a row under it; held otherwise, one row cut short beside its
 * take-back; submitted, wrapped.
 */
const goingOf = (send: SitrepInFlight, width: number, holding: Holding): Going => {
  if (!send.isHeld) {
    return { send, rows: wrapped(SENDING, width - BOX_SIDES), isHeld: false, sendsNow: false }
  }

  if (holding === 'stop') {
    // Never narrower than its longest word, which a board too narrow cuts short rather than splits.
    const across = width - BOX_SIDES
    const rows = wrapped(STOPPED, Math.max(across, ...STOPPED.split(' ').map(word => word.length)))

    return { send, rows, isHeld: true, sendsNow: true }
  }

  return { send, rows: [holding === 'turn' ? HELD : BEHIND_STOP], isHeld: true, sendsNow: false }
}

/**
 * What the send `at` in the order claimed waits on while held. An answer
 * that went in with Lee's prompt goes ahead of every held message, and
 * nothing is submitted until it has ended and its turn started, so no send
 * behind it can go now.
 */
const holdingOf = (scene: Scene, at: number): Holding => {
  if (!scene.isStopped) {
    return 'turn'
  }

  const isFirst = at === scene.inFlight.findIndex(isQueuedSend) && !scene.inFlight.some(isRide)

  return isFirst ? 'stop' : 'behindStop'
}

/** Whether a message in flight is an answer that went in with Lee's prompt, submitted already. */
const isRide = (flight: SitrepInFlight) => flight.ride !== undefined

/** Whether a message in flight is a send of Lee's from Ready to send: not the inbox's, nor an answer that went in with his prompt. */
const isQueuedSend = (flight: SitrepInFlight) => flight.source === 'send' && !isRide(flight)

/**
 * A send of Lee's on its way as a group of its own, `at` in the order
 * claimed: the replies it carries, and its line. None for the inbox's
 * message, whose replies Lee sent from elsewhere.
 */
const goingGroup = (scene: Scene, send: SitrepInFlight, at: number, width: number): SendGroup[] => {
  if (send.source !== 'send') {
    return []
  }

  const filed = filedAt(scene, send.session)
  const listed = queuedIn(
    scene,
    scene.queue.filter(queued => isCarriedBy(send, queued)),
  )

  return [{ going: goingOf(send, width, holdingOf(scene, at)), filed, listed, isBrief: false }]
}

/** Each destination of the replies still to send, this session first, then as first queued, then those only sent to. */
const unsentGroups = (scene: Scene): ToSendGroup[] => {
  const queue = unsent(scene.queue, scene.inFlight)
  const held = { project: scene.here, session: scene.session.id }
  const to = queue.flatMap(reply => goesTo(held, reply) ?? [])
  const here = to.filter(each => each.session === held.session)

  return destinations([...here, ...to, ...scene.sent]).flatMap(({ session }): ToSendGroup[] => {
    const filed = filedAt(scene, session)
    const sent = scene.sent.find(each => each.session === session)

    if (filed === undefined) {
      return []
    }

    const waiting = queuedIn(scene, queuedFor(queue, held, session))

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
  ...scene.inFlight.flatMap((send, at) => goingGroup(scene, send, at, width)),
  ...unsentGroups(scene),
]

const listedIn = (groups: readonly Group[]) =>
  groups.reduce((sum, group) => sum + group.listed.length, 0)

const isSend = (group: Group): group is SendGroup => group.going !== undefined

/** How many replies a group holds that are not yet with Claude: all a send carries, listed or not; of the rest, those queued, not sent into an inbox. */
const waitingIn = (group: Group) =>
  isSend(group)
    ? group.going.send.replies.length
    : group.listed.filter(listed => 'queued' in listed).length

const countWaiting = (groups: readonly Group[]) =>
  groups.reduce((sum, group) => sum + waitingIn(group), 0)

/** Whether a reply listed is queued, and nothing holds it back from a send. */
const isSendable = (listed: Listed) => 'queued' in listed && listed.barred === undefined

/** How many replies of the groups still to send a send could carry. */
const countToSend = (groups: readonly Group[]) =>
  groups
    .filter(group => !isSend(group))
    .reduce((sum, group) => sum + group.listed.filter(isSendable).length, 0)

/** The rows a send's line takes, and the row of its buttons under it where it has one. */
const goingRows = (going: Going) => going.rows.length + (going.sendsNow ? BUTTONS_ROWS : 0)

/** The rows a group takes: its heading's, its replies' and a send's line; a brief send's one row. */
const rowsOf = (group: Group) => {
  if (isSend(group) && group.isBrief) {
    return BRIEF_ROWS
  }

  return GROUP_ROWS + group.listed.length * REPLY_ROWS + (isSend(group) ? goingRows(group.going) : 0)
}

const groupRows = (groups: readonly Group[]) =>
  groups.reduce((sum, group) => sum + rowsOf(group), 0)

const controlsRows = ({ toSend }: Ready) => (toSend === 0 ? 0 : GAP_ROWS + 1)

/** The rows the box takes: each of its lines one, and its border. */
export const readyRows = (ready: Ready) =>
  BORDER_ROWS +
  HEAD_ROWS +
  groupRows(ready.groups) +
  (ready.more > 0 ? MORE_ROWS : 0) +
  controlsRows(ready)

/**
 * What fits of the groups' replies in `room` rows, in order. A send shows
 * with what fits of its replies, its heading and its line counted already;
 * a group still to send shows with its heading and one of its replies at
 * least, where it lists any, or neither it nor any after it does.
 */
const filled = (groups: readonly Group[], room: number) => {
  const kept: Group[] = []
  let left = room
  let isFull = false

  for (const group of groups) {
    const headingRows = isSend(group) ? 0 : GROUP_ROWS
    const share = isFull ? 0 : Math.floor((left - headingRows) / REPLY_ROWS)
    const fits = Math.max(0, Math.min(group.listed.length, share))
    const isShut = isFull || headingRows > left || fits < Math.min(1, group.listed.length)

    if (!isSend(group) && isShut) {
      break
    }

    kept.push({ ...group, listed: group.listed.slice(0, fits) })
    left -= headingRows + fits * REPLY_ROWS
    isFull = isFull || fits < group.listed.length
  }

  return kept
}

/**
 * The sends after the first, each a row of its own, in `rows` rows: all of
 * them where they fit; else as many as fit but one, then one row standing
 * for the rest, which shows the one `shown` names, or the first of them,
 * and steps through them. That row shows however few rows there are, so
 * each held send's take-back is always within reach.
 */
const briefed = (later: readonly SendGroup[], rows: number, shown: string | null) => {
  const brief = (send: SendGroup): SendGroup => ({ ...send, isBrief: true })

  if (later.length <= Math.max(1, rows)) {
    return later.map(brief)
  }

  const kept = Math.max(0, rows - 1)
  const rest = later.slice(kept)
  const at = Math.max(0, rest.findIndex(send => sendKey(send.going.send) === shown))
  const stepping = rest.flatMap((send, i) => {
    const next = rest[(i + 1) % rest.length]

    return i === at && next !== undefined
      ? [{ ...brief(send), step: { at, of: rest.length, next: sendKey(next.going.send) } }]
      : []
  })

  return [...later.slice(0, kept).map(brief), ...stepping]
}

/**
 * The groups that fit in `room` rows: all of them; or else the first send's
 * heading and line, and so its take-back, then a row for each send after it
 * (`briefed`), then what fits of the replies in order, a row kept for the
 * count of what was left off. The sends' rows come before any reply, the
 * first send's own among them.
 */
const fitted = (groups: readonly Group[], room: number, shown: string | null): Group[] => {
  if (groupRows(groups) <= room) {
    return [...groups]
  }

  const [first, ...rest] = groups.filter(isSend)
  const toSend = groups.filter(group => !isSend(group))

  if (first === undefined) {
    return filled(toSend, room - MORE_ROWS)
  }

  // An answer that went in with Lee's prompt is submitted already, with no
  // take-back to keep in reach: it shows whole, as the first send does.
  const leading = [first, ...rest.filter(send => !isQueuedSend(send.going.send))]
  const later = rest.filter(send => isQueuedSend(send.going.send))
  const left = leading.reduce(
    (rows, send) => rows - GROUP_ROWS - goingRows(send.going),
    room - MORE_ROWS,
  )
  const briefs = briefed(later, left, shown)
  // A brief send's replies count as shown, not as left off: its row names
  // them. Those of the sends a stepping row has yet to show count as left off.
  const kept = filled([...leading, ...toSend], left - briefs.length * BRIEF_ROWS)

  return [...kept.slice(0, leading.length), ...briefs, ...kept.slice(leading.length)]
}

/**
 * Ready to send as it draws `width` cells across in at most `rows` rows,
 * however few: its heading, the first send's line and the buttons always
 * show. Undefined while nothing waits in it or is on its way.
 */
export const readyOf = (scene: Scene, width: number, rows = Infinity): Ready | undefined => {
  const groups = groupsOf(scene, width)

  if (groups.length === 0) {
    return undefined
  }

  const frame: Ready = {
    groups: [],
    waiting: countWaiting(groups),
    toSend: countToSend(groups),
    more: 0,
  }
  const kept = fitted(groups, rows - readyRows(frame), scene.pane.heldShown)

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

/** The button stepping a row standing for several held sends to the next of them. */
const drawStep = (d: Drawing, { next }: Step) => {
  const { Button } = d.els

  return (
    <Button key={STEP_HELD} plain dimColor label="› next" onPress={() => d.act.showHeld(next)} />
  )
}

/**
 * The line saying where a send on its way stands, under its replies; held,
 * its take-back beside it, after the step to the next held send where the
 * row stands for several; held as the first while the window is stopped,
 * its send now and take-back on a row of their own under it, at the right
 * as every take-back is.
 */
const drawGoing = (d: Drawing, { send, rows, isHeld, sendsNow }: Going, step?: Step) => {
  const { Box, Text, Button } = d.els
  const lines = rows.map((row, i) => (
    <Text key={`going:${i}`} color={C.grey} italic wrap="truncate-end">
      {row}
    </Text>
  ))
  const takeBack = (
    <Button
      key={takeBackKey(send)}
      plain
      dimColor
      label={TAKE_BACK_LABEL}
      onPress={() => d.act.takeBack(send)}
    />
  )

  if (!isHeld) {
    return <Box flexDirection="column">{lines}</Box>
  }

  if (sendsNow) {
    return (
      <Box flexDirection="column">
        {lines}
        <Box flexDirection="row" columnGap={1} justifyContent="flex-end">
          <Button
            key={SEND_NOW}
            plain
            dimColor
            label={SEND_NOW_LABEL}
            onPress={answeredByTheHook}
          />
          {takeBack}
        </Box>
      </Box>
    )
  }

  return (
    <Box flexDirection="row" columnGap={1}>
      <Box flexDirection="column" flexGrow={1} flexShrink={1}>
        {lines}
      </Box>
      {step !== undefined && drawStep(d, step)}
      {takeBack}
    </Box>
  )
}

const drawEntry = (d: Drawing, entry: Listed) =>
  'queued' in entry ? drawQueuedEntry(d, entry) : drawSentEntry(d, entry)

/** Where a group's replies go, as its heading says it: this session, or the one named. */
const toWhere = (d: Drawing, filed: Filed) =>
  filed.session === d.scene.session ? 'to this session' : `to ${sessionLabel(d.scene, filed)}`

/** Where a send goes: as `toWhere` says it; one to a session the board has not read, by its name in its project's briefs, where they hold it. */
const sendWhere = (d: Drawing, { going, filed }: SendGroup) => {
  if (filed !== undefined) {
    return toWhere(d, filed)
  }

  const brief = briefOf(d.scene, going.send.session)

  return brief === undefined ? 'to another session' : `to ${brief.name}`
}

/**
 * The row a brief send takes for its heading, replies and line: where it
 * goes, unless to this session, the first reply it carries and how many
 * more; standing for several held sends, which of them it shows.
 */
const briefLine = (d: Drawing, group: SendGroup) => {
  const { going, filed, listed, step } = group
  const lead =
    filed?.session === d.scene.session ? '⧗ Then:' : `⧗ Then, ${sendWhere(d, group)}:`
  const count = going.send.replies.length
  const [first] = listed
  const carried =
    first === undefined
      ? counted(count, 'reply', 'replies')
      : `${first.item.title}${count > 1 ? ` +${count - 1}` : ''}`
  const of = step === undefined ? '' : ` · ${step.at + 1} of ${step.of}`

  return `${lead} ${carried}${of}`
}

const drawSendGroup = (d: Drawing, group: SendGroup) => {
  const { Box } = d.els
  const { going, listed, isBrief, step } = group
  const key = `going:${sendKey(going.send)}`

  if (isBrief) {
    return (
      <Box key={key} flexDirection="column">
        {drawGoing(d, { ...going, rows: [briefLine(d, group)] }, step)}
      </Box>
    )
  }

  return (
    <Box key={key} flexDirection="column" paddingTop={GAP_ROWS}>
      {line(d, `on its way ${sendWhere(d, group)}`, C.grey)}
      {listed.map(each => drawEntry(d, each))}
      {drawGoing(d, going)}
    </Box>
  )
}

const drawToSendGroup = (d: Drawing, { filed, standing, listed }: ToSendGroup) => {
  const { Box } = d.els
  const stands = standing === undefined ? undefined : STANDING[standing]

  return (
    <Box key={`group:${filed.session.id}`} flexDirection="column" paddingTop={GAP_ROWS}>
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1}>
          {line(d, toWhere(d, filed), C.grey)}
        </Box>
        {stands !== undefined && line(d, stands.text, stands.color)}
      </Box>
      {listed.map(each => drawEntry(d, each))}
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
        onPress={answeredByTheHook}
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
      {groups.map(group => (isSend(group) ? drawSendGroup(d, group) : drawToSendGroup(d, group)))}
      {more > 0 && line(d, `… ${more} more`, C.grey)}
      {toSend > 0 && drawControls(d)}
    </Box>
  )
}
