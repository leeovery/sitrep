import { expect, test, tier, type Engine } from './kit'
import { parseEntries, parsePresence, sessionPaths } from '../core'
import { CANNOT_RIDE, ELSEWHERE, NOT_TAKEN } from '../hooks/answering'
import { QUIET_MS, RIDE_LOST } from '../hooks/deliver'
import { WATCH_MS } from '../hooks/window'
import {
  answering,
  at,
  entered,
  EXPORT,
  heldPaths,
  IMAGE,
  LIST,
  onLedgersAsks,
  onLedgersParked,
  OUTPUT,
  stateOf,
  writtenIn,
} from './answers'
import { rowsOf } from './drawn'
import {
  CLOSES,
  FRAMES,
  GO,
  LEAVES_OPEN,
  LEDGER,
  MIN,
  PROJECT,
  reviewRound,
  ROOT,
  T0,
  W1,
  W2,
  W3,
} from './data'
import { beat, delivered, file, note, reply } from './lines'
import { asked, CONVERSATION, lost, openAsk, pressYes, world, writeDoor, type World } from './world'

tier('user')

test('an answer with an image goes in at once as Lee’s own prompt, rewritten as the board’s words for it, the image with it, and is written down delivered', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  expect(
    (await entered(w, $, 'It prints this: [Image #1]', { attachments: [IMAGE] })).drop,
  ).toBeUndefined()
  expect(w.prompts).toEqual([
    {
      text: `From the board:\n- ${LIST.title} → ${OUTPUT}: “It prints this: [Image #1]”${CLOSES}`,
      context: undefined,
      origin: { kind: 'composer' },
      attachments: [IMAGE],
    },
  ])
  expect(writtenIn(w)).toEqual([{ item: id, verdict: 'answer', isDelivered: true }])
  expect(stateOf(w, id)).toBe('closed')
  expect(w.state.board?.waiting).toBe(0)
  expect(w.state.queue ?? []).toEqual([])
  expect(w.state.answering).toBeNull()
  expect(w.toasts).not.toContain(NOT_TAKEN)
})

test('an image with no words answers a words ask as the placeholder Claude Code leaves where it sits', async ($, on) => {
  const w = world($, on)

  await answering(w)
  await entered(w, $, '[Image #1]', { attachments: [IMAGE] })
  expect(w.prompts.map(each => each.text)).toEqual([
    `From the board:\n- ${LIST.title} → ${OUTPUT}: “[Image #1]”${CLOSES}`,
  ])
})

test('a comment with an image on an ask whose yes is queued goes in with the yes, as its note, and Ready to send loses the yes', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })
  await entered(w, $, 'After the copy pass [Image #1]', { attachments: [IMAGE] })
  expect(w.prompts.map(each => each.text)).toEqual([
    `From the board:\n- Give the ok for phase 3 → Go, with a comment: “After the copy pass [Image #1]”${CLOSES}`,
  ])
  expect(writtenIn(w)).toEqual([{ item: id, verdict: 'yes', isDelivered: true }])
  expect(stateOf(w, id)).toBe('closed')
  expect(w.state.queue).toEqual([])
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
})

test('a comment with an image on an ask with nothing queued goes in as a comment, leaving the ask open for Claude', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, FRAMES)
  const ui = await w.pane()

  await ui.press({ key: `comment:${w.item(id)}` })
  await entered(w, $, 'Frame 2 looks like this [Image #1]', { attachments: [IMAGE] })
  expect(w.prompts.map(each => each.text)).toEqual([
    `From the board:\n- ${FRAMES.title} → comment: “Frame 2 looks like this [Image #1]”${LEAVES_OPEN}`,
  ])
  expect(writtenIn(w)).toEqual([{ item: id, verdict: 'comment', isDelivered: true }])
  expect(stateOf(w, id)).toBe('replied')
})

test('an answer with an image takes no board context, which waits for the next prompt', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  w.writer(heldPaths(w))(note('n9', 'Merged the band'))
  await entered(w, $, 'v1.2.3 [Image #1]', { attachments: [IMAGE] })
  await entered(w, $, 'Carry on.')
  expect(w.prompts.map(each => each.context?.length ?? 0)).toEqual([0, 1])
  expect(stateOf(w, id)).toBe('closed')
})

test("an answer with an image to another session's ask is kept: it can go only into this window's Claude", async ($, on) => {
  const w = world($, on)
  const ui = await onLedgersAsks(w)
  const there = w.item('k3', LEDGER.id)

  await ui.press({ key: `pick:${there}` })
  await ui.press({ key: `answer:${there}` })
  expect(await entered(w, $, 'id, at, by [Image #1]', { attachments: [IMAGE] })).toEqual({
    drop: NOT_TAKEN,
  })
  expect(w.toasts).toContain(ELSEWHERE)
  expect(w.prompts).toEqual([])
  expect(w.state.queue ?? []).toEqual([])
  expect(w.state.answering).toMatchObject({ session: LEDGER.id, item: 'k3' })
})

test('a comment with an image going with a queued yes the ask no longer fits is kept, a toast saying why', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })
  await w.call('edit', { item: id, wants: 'choice', options: ['Now', 'Later'] })
  expect(await entered(w, $, 'After the copy pass [Image #1]', { attachments: [IMAGE] })).toEqual({
    drop: NOT_TAKEN,
  })
  expect(w.toasts).toContain(CANNOT_RIDE.changed)
  expect(w.prompts).toEqual([])
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes' }])
  expect(w.state.answering).toMatchObject({ item: id })
})

test('a comment with an image going with a queued yes is kept once another answer is on its way to the ask, a toast saying why', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()
  const paths = heldPaths(w)

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })
  // Another window, attached first, delivers the session's inbox, so its yes stays on its way.
  w.put(paths.heartbeat(W2), beat(W2, { attachedAt: T0 - MIN, seenAt: w.clock.now() }))
  w.writer(paths)(reply('r9', id, 'yes'))
  await w.clock.advance(WATCH_MS)
  expect(w.state.answering, 'a comment barred by no answer').toMatchObject({ item: id })

  expect(await entered(w, $, 'After the copy pass [Image #1]', { attachments: [IMAGE] })).toEqual({
    drop: NOT_TAKEN,
  })
  expect(w.toasts).toContain(CANNOT_RIDE.answered)
  expect(w.prompts).toEqual([])
  expect(w.state.answering).toMatchObject({ item: id })
})

test('an answer with an image dropped beneath, by another plugin or Claude Code, writes nothing, puts back what was queued, and the mode stands', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })
  w.dropPrompts('Blocked by a hook')
  expect(await entered(w, $, 'After the copy pass [Image #1]', { attachments: [IMAGE] })).toEqual({
    drop: 'Blocked by a hook',
  })
  expect(writtenIn(w)).toEqual([])
  expect(w.flights()).toEqual([])
  expect(stateOf(w, id)).toBe('waiting')
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes' }])
  expect(w.state.answering).toMatchObject({ item: id, as: 'comment' })
  expect(w.toasts.filter(toast => toast.startsWith('Not sent'))).toEqual([])
})

/** Lee's comment with an image on the ask whose yes is queued, entered while every prompt waits beneath: the board, the ask's id, and Lee's prompt, still to settle. */
const ridingHeld = async (w: World, engine: Engine) => {
  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })

  const held = w.holdPrompts()
  const typed = entered(w, engine, 'After the copy pass [Image #1]', { attachments: [IMAGE] })

  await held.arrived

  return { id, ui, held, typed }
}

const RODE_WITH_GO = `From the board:\n- Give the ok for phase 3 → Go, with a comment: “After the copy pass [Image #1]”${CLOSES}`

test('an answer with an image is on its way from the moment it goes: frozen in Ready to send, with no take-back, and a send meanwhile carries none of it', async ($, on) => {
  const w = world($, on)
  const { id, ui, held, typed } = await ridingHeld(w, $)

  await w.clock.settle()
  expect(rowsOf(await ui.find({ key: 'ready' })).map(row => row.trim())).toContain('⧗ Sending.')
  expect(await ui.find({ key: w.takeBack() })).toBeUndefined()
  expect(
    parsePresence(w.text(heldPaths(w).heartbeat(W1)), W1)?.sending?.map(each =>
      each.replies.map(reply => reply.item),
    ),
  ).toEqual([[id]])
  expect(w.state.answering).toBeNull()

  const other = await asked(w, reviewRound(1))

  await ui.press({ key: `yes:${w.item(other)}` })
  await ui.press({ key: 'send' })
  held.end()
  await typed
  await w.turnStarts(RODE_WITH_GO)
  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([
    RODE_WITH_GO,
    `From the board:\n- Review round 1 → Approve${CLOSES}`,
  ])
  expect(writtenIn(w)).toEqual([
    { item: id, verdict: 'yes', isDelivered: true },
    { item: other, verdict: 'yes', isDelivered: true },
  ])
  expect(w.state.queue).toEqual([])
})

test('✎ on another ask while the answer with an image goes in begins the mode for it, which stands once it has gone', async ($, on) => {
  const w = world($, on)
  const { ui, held, typed } = await ridingHeld(w, $)
  const list = await asked(w, LIST)

  w.box.text = ''
  await ui.press({ key: `answer:${w.item(list)}` })
  held.end()
  await typed

  expect(w.state.answering).toMatchObject({ item: list, as: 'answer' })
})

test('an answer with an image whose writing failed is written down once, by the next load', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  w.refuseWrites(path => path === heldPaths(w).log(W1))
  await entered(w, $, 'v1.2.3 [Image #1]', { attachments: [IMAGE] })
  expect(writtenIn(w)).toEqual([])
  expect(w.flights()).toMatchObject([{ isTaken: true }])

  w.refuseWrites()
  await $.session.start(CONVERSATION)
  await w.clock.advance(4 * WATCH_MS)

  expect(writtenIn(w)).toEqual([{ item: id, verdict: 'answer', isDelivered: true }])
  expect(w.flights()).toEqual([])
  expect(w.prompts).toHaveLength(1)
})

test('an answer with an image whose prompt fails beneath is let go, what was queued put back, and nothing waits on it', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })
  w.failPrompts('a hook timed out')
  await entered(w, $, 'After the copy pass [Image #1]', { attachments: [IMAGE] }).catch(() => {})

  expect(w.flights()).toEqual([])
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes' }])
  expect(writtenIn(w)).toEqual([])
  expect(stateOf(w, id)).toBe('waiting')
})

test('an answer with an image is never let go as never taken while its hook waits on Claude Code, however long, nor after a turn ends', async ($, on) => {
  const w = world($, on)
  const { id, held, typed } = await ridingHeld(w, $)

  await w.turnEnds()
  await w.clock.advance(3 * QUIET_MS)

  expect(w.flights()).toMatchObject([{ isHeld: false, isTaken: false }])
  expect(w.toasts).not.toContain(RIDE_LOST)

  held.end()
  await typed

  expect(writtenIn(w)).toEqual([{ item: id, verdict: 'yes', isDelivered: true }])
  expect(w.flights()).toEqual([])
})

/** Lee's comment with an image let in, its hook then gone with the load a reload replaced: the ask's id. */
const leftByReload = async (w: World, engine: Engine) => {
  const { id, held, typed } = await ridingHeld(w, engine)

  held.lose()
  lost(typed)
  await engine.session.start(CONVERSATION)

  return id
}

test('an answer with an image a reload left waiting on its hook is let go once the window has gone quiet without it: what was queued put back, and a toast saying to write it again', async ($, on) => {
  const w = world($, on)
  const id = await leftByReload(w, $)

  await w.clock.advance(QUIET_MS + WATCH_MS)

  expect(w.flights()).toEqual([])
  expect(w.toasts).toContain(RIDE_LOST)
  expect(w.toasts.filter(toast => toast.startsWith('Not sent'))).toEqual([])
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes' }])
  expect(writtenIn(w)).toEqual([])
})

test('an answer with an image a reload left waiting is written down once its turn starts after all', async ($, on) => {
  const w = world($, on)
  const id = await leftByReload(w, $)

  await w.turnStarts(RODE_WITH_GO)

  expect(writtenIn(w)).toEqual([{ item: id, verdict: 'yes', isDelivered: true }])
  expect(w.flights()).toEqual([])
})

test("an answer with an image a reload left, let go with the inbox's replies held behind it, says only that the answer didn't go in", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const id = await asked(w, GO)
  const other = await asked(w, reviewRound(1))
  const ui = await w.pane()

  await w.clock.advance(MIN)
  await w.turnStarts('Carry on.')
  w.put(paths.letters(W3), file([w.clock.now(), reply('r9', other, 'yes')]))
  await w.clock.advance(2 * WATCH_MS)
  expect(w.flights()).toMatchObject([{ source: 'inbox', isHeld: true }])

  await openAsk(w, ui, w.item(id))
  await pressYes(ui, w.item(id))
  await ui.press({ key: `rewrite:${w.item(id)}` })

  const held = w.holdPrompts()
  const typed = entered(w, $, 'After the copy pass [Image #1]', { attachments: [IMAGE] })

  await held.arrived
  expect(w.flights()).toMatchObject([{ source: 'send', isHeld: false }, { source: 'inbox' }])

  held.lose()
  lost(typed)
  await $.session.start(CONVERSATION)
  await w.turnEnds()
  await w.clock.advance(QUIET_MS + WATCH_MS)

  expect(w.toasts).toContain(RIDE_LOST)
  expect(w.toasts.filter(toast => toast.startsWith('Not sent'))).toEqual([])
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes' }])
})

test('an answer with an image whose ask a send claims first goes to Claude as any prompt does, and the send carries the yes alone', async ($, on) => {
  const w = world($, on)
  const riding = writeDoor(on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })

  riding.hold(flights => flights.some(each => each.ride !== undefined))

  const typed = entered(w, $, 'After the copy pass [Image #1]', { attachments: [IMAGE] })

  await riding.arrived

  const held = w.holdPrompts()

  await ui.press({ key: 'send' })
  await held.arrived
  riding.open()
  await w.clock.settle()
  expect(
    w.flights().map(each => each.ride !== undefined),
    "the send alone in flight, the ride's claim refused",
  ).toEqual([false])

  held.end()
  await typed
  await w.clock.settle()

  expect(w.submitted).toEqual([
    `From the board:\n- Give the ok for phase 3 → Go${CLOSES}`,
    'After the copy pass [Image #1]',
  ])
  expect(w.prompts[1]?.attachments).toEqual([IMAGE])
  expect(writtenIn(w)).toEqual([{ item: id, verdict: 'yes', isDelivered: true }])
  expect(w.state.answering).toBeNull()
})

test("a pick-up with an image of another session's parked item goes in to this window's Claude, naming whose it was, and is written down in that session", async ($, on) => {
  const w = world($, on)

  await onLedgersParked(w)
  expect(
    (await entered(w, $, 'Like this [Image #1]', { attachments: [IMAGE] })).drop,
  ).toBeUndefined()
  expect(w.prompts.map(each => [each.text, each.attachments])).toEqual([
    [
      `From the board:\n- Pick up from parked, ${LEDGER.name}'s: ${EXPORT}. Like this [Image #1]`,
      [IMAGE],
    ],
  ])

  const ledger = parseEntries(w.text(sessionPaths(ROOT, PROJECT.key, LEDGER.id).log(W1)))

  expect(ledger.map(line => line.type)).toEqual(['reply', 'delivered'])
  expect(ledger[0]).toMatchObject({ item: 'p3', verdict: 'pickup', note: 'Like this [Image #1]' })
  expect(w.toasts).not.toContain(ELSEWHERE)
  expect(w.state.queue ?? []).toEqual([])
})
