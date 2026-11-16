/**
 * The message in flight, whatever its source, across what can come between
 * its submit and its lines: a reload, a quiet window, the conversation's end.
 *
 * The test kit cannot load a fresh copy of the mod, so a reload here runs
 * session.start again in the same module. What a reload must carry over
 * lives in `$.state`; each test sets the last load's submit as the engine
 * leaves it (settled live): after a `/reload-plugins` typed mid-turn it never
 * resolves, and the new load hears the message's turn start; after a
 * file-watch reload it resolved, and what the last load did next can be cut
 * short, left here as the message taken but not written down.
 */
import { expect, test, tier } from './kit'
import { HEARTBEAT_MS, parseEntries, parsePresence, sessionPaths, type SessionPaths } from '../core'
import { keptFlights, QUIET_MS } from '../hooks/deliver'
import { WATCH_MS } from '../hooks/window'
import type { SitrepInFlight, SitrepStoredFlights } from '../types'
import { CLOSES, file, MIN, reply, SENDER, SLOW, W1 } from './support'
import { postedId, PROJECT, CONVERSATION, ROOT, startedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Source = 'send' | 'inbox'

const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Orders & Invoices, round 1' }

const MESSAGE = `From the board:\n- Review Orders & Invoices, round 1 → Approve${CLOSES}`

/** Claude Code's refusal of every plugin's prompt once Lee has stopped Claude's turn, until he next types in the window (live, 2.1.318). */
const STOPPED = 'the session was stopped and nobody has sent input since'

/** What the window's own file holds once the message is written down, by its source. */
const WRITTEN: Record<Source, string[]> = {
  send: ['ask', 'reply', 'delivered'],
  inbox: ['ask', 'delivered'],
}

/** The kinds of line the window's own file holds, in order. */
const kindsIn = (w: World, paths: SessionPaths) =>
  parseEntries(w.text(paths.log(W1))).map(line => line.type)

/**
 * This session with a review asked and Lee's yes to it, a minute on: queued
 * on the board, or in the inbox from another session's window. `submit` sends
 * it: a press of send, or the looks that take the letter in.
 */
const replying: Record<Source, (w: World) => Promise<{ paths: SessionPaths; submit: () => void }>> =
  {
    send: async w => {
      const { paths } = await w.begin()
      const id = postedId(await w.call('ask', REVIEW))
      const ui = await w.pane()

      await w.clock.advance(MIN)
      await ui.press({ key: `yes:${w.item(id)}` })

      return { paths, submit: () => void ui.press({ key: 'send' }) }
    },
    inbox: async w => {
      const { paths } = await w.begin()
      const id = postedId(await w.call('ask', REVIEW))

      await w.clock.advance(MIN)
      w.put(paths.letters(SENDER), file([w.clock.now(), reply('r1', id, 'yes')]))

      return { paths, submit: () => void w.clock.advance(2 * WATCH_MS) }
    },
  }

/** Whether the session is as a message written down once leaves it: its lines, the ask closed, the queue empty. */
const expectWrittenOnce = (w: World, paths: SessionPaths, source: Source) => {
  expect(kindsIn(w, paths)).toEqual(WRITTEN[source])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.queue ?? []).toEqual([])
  expect(w.state.inFlight).toBeNull()
}

/** Turns the clock on past every look and quiet, a turn ending first. */
const longAfter = async (w: World) => {
  await w.turnEnds()
  await w.clock.advance(QUIET_MS + 4 * WATCH_MS)
}

for (const source of ['send', 'inbox'] as const) {
  test(
    `${source}: after a /reload-plugins mid-turn the last submit never resolves; the turn its message starts writes it down once, and it never goes in again`,
    SLOW,
    async ($, on) => {
      const w = world($, on)
      const { paths, submit } = await replying[source](w)
      const turn = w.holdPrompts()

      submit()
      await turn.arrived
      turn.lose()
      await $.session.start(CONVERSATION)
      await w.clock.advance(4 * WATCH_MS)

      expect(kindsIn(w, paths)).toEqual(['ask'])
      expect(w.state.inFlight).toMatchObject({ source, text: MESSAGE, isTaken: false })

      await w.turnStarts(MESSAGE)
      expectWrittenOnce(w, paths, source)

      await longAfter(w)
      expect(w.submitted).toEqual([MESSAGE])
      expectWrittenOnce(w, paths, source)
    },
  )

  test(`${source}: after a file-watch reload the last submit resolved and its writing was cut short; the next load writes it down once`, async ($, on) => {
    const w = world($, on)
    const { paths, submit } = await replying[source](w)

    w.refuseWrites(path => path === paths.log(W1))
    submit()
    await w.clock.advance(WATCH_MS)

    expect(w.state.inFlight).toMatchObject({ source, isTaken: true })
    expect(kindsIn(w, paths)).toEqual(['ask'])

    w.refuseWrites()
    await $.session.start(CONVERSATION)
    expectWrittenOnce(w, paths, source)

    await longAfter(w)
    expect(w.submitted).toEqual([MESSAGE])
    expectWrittenOnce(w, paths, source)
  })

  test(`${source}: a load cut short once its lines were written writes nothing more; the next load ends the message`, async ($, on) => {
    const w = world($, on)
    let isCut = true

    on('state.set', { plugin: 'sitrep', key: 'inFlight' }, ($, e, next) =>
      isCut && e.value === null ? { deny: 'the load was cut short' } : next(e),
    )

    const { paths, submit } = await replying[source](w)

    submit()
    await w.clock.advance(WATCH_MS)
    expect(kindsIn(w, paths)).toEqual(WRITTEN[source])
    expect(w.logs.some(line => line.includes('the load was cut short'))).toBe(true)
    expect(w.state.flash ?? 0).toBe(0)
    expect(w.state.queue ?? [], 'a send its lines written is out of the queue').toEqual([])

    isCut = false
    await $.session.start(CONVERSATION)
    expectWrittenOnce(w, paths, source)
    expect(w.state.flash).toBe(source === 'inbox' ? 1 : 0)

    await longAfter(w)
    expect(w.submitted).toEqual([MESSAGE])
    expectWrittenOnce(w, paths, source)
  })

  test(
    `${source}: a message that never goes in is let go once the window has been quiet a while, and no sooner`,
    SLOW,
    async ($, on) => {
      const w = world($, on)
      const { paths, submit } = await replying[source](w)
      const turn = w.holdPrompts()

      submit()
      await turn.arrived
      turn.lose()
      await w.turnEnds()
      await w.clock.advance(QUIET_MS - 1)
      expect(w.state.inFlight).toMatchObject({ isTaken: false })

      await w.turnStarts('Carry on.')
      await w.clock.advance(QUIET_MS)
      expect(w.state.inFlight, 'a turn started: it could still carry the message').toMatchObject({
        isTaken: false,
      })

      await w.turnEnds()
      await w.clock.advance(QUIET_MS)
      expect(w.state.inFlight).toBeNull()
      expect(kindsIn(w, paths)).toEqual(['ask'])
      expect(w.state.board?.asks[0]?.state).toBe('waiting')
    },
  )

  test(`${source}: a message in flight as the conversation ends is written into its session if it goes in after, though the window holds none`, async ($, on) => {
    const w = world($, on)
    const { paths, submit } = await replying[source](w)
    const turn = w.holdPrompts()

    submit()
    await turn.arrived
    turn.lose()
    await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })
    await w.turnStarts(MESSAGE)

    expect(w.state.attachment ?? null).toBeNull()
    expect(kindsIn(w, paths)).toEqual(WRITTEN[source])
    expect(w.state.inFlight).toBeNull()
  })

  test(`${source}: refused as Lee stopped Claude's turn, the message is held and the window marked stopped; no look, quiet or reload submits it again or lets it go, and it goes once his turn ends`, SLOW, async ($, on) => {
    const w = world($, on)
    const { paths, submit } = await replying[source](w)

    w.dropPrompts(STOPPED)
    submit()
    await w.clock.advance(WATCH_MS)

    expect(w.submitted).toEqual([MESSAGE])
    expect(w.state.inFlight).toMatchObject({ source, isHeld: true })
    expect(w.state.stopped).toBe(true)

    await $.session.start(CONVERSATION)
    await w.clock.advance(QUIET_MS + 4 * WATCH_MS)

    expect(w.submitted).toEqual([MESSAGE])
    expect(w.state.inFlight).toMatchObject({ source, isHeld: true })
    expect(w.state.stopped).toBe(true)
    expect(w.toasts.filter(toast => toast.startsWith('Not sent'))).toEqual([])
    expect(w.logs.some(line => line.includes('were not taken'))).toBe(false)
    expect(kindsIn(w, paths)).toEqual(['ask'])

    w.dropPrompts()
    await w.turnStarts('Look at the failing test instead.')
    await w.turnEnds()
    await w.clock.settle()

    expect(w.submitted).toEqual([MESSAGE, MESSAGE])
    expectWrittenOnce(w, paths, source)
  })
}

test("send: let go, Lee's replies are back in Ready to send, and a toast says why", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', REVIEW))
  const ui = await w.pane()
  const turn = w.holdPrompts()

  await ui.press({ key: `yes:${w.item(id)}` })
  void ui.press({ key: 'send' })
  await turn.arrived
  turn.lose()
  await w.turnEnds()
  await w.clock.advance(QUIET_MS)

  expect(w.toasts).toContain(
    'Not sent: the message never went in. Your replies are still on the board.',
  )
  expect(w.state.queue).toHaveLength(1)
  expect(await ui.find({ key: 'send' })).toBeDefined()
})

test('inbox: let go, its replies are taken in at a later look', async ($, on) => {
  const w = world($, on)
  const { paths, submit } = await replying.inbox(w)
  const turn = w.holdPrompts()

  submit()
  await turn.arrived
  turn.lose()
  await w.turnEnds()
  await w.clock.advance(QUIET_MS + WATCH_MS)

  expect(w.submitted).toEqual([MESSAGE, MESSAGE])
  expect(kindsIn(w, paths)).toEqual(['ask', 'delivered'])
})

test('a message whose writing a reload cut short is written into its own session, though the window holds another by then', async ($, on) => {
  const w = world($, on)
  const { paths, submit } = await replying.send(w)

  w.refuseWrites(path => path === paths.log(W1))
  submit()
  await w.clock.advance(WATCH_MS)
  w.refuseWrites()

  const themes = await w.call('start', {
    name: 'Themes',
    summary: 'The dark palette',
    project: PROJECT.name,
  })

  await $.session.start(CONVERSATION)

  expect(kindsIn(w, paths)).toEqual(WRITTEN.send)
  expect(w.state.attachment?.session).toBe(startedId(themes))
  expect(w.state.board?.replies).toEqual([])
  expect(w.state.inFlight).toBeNull()
})

/** What the window's heartbeat says it sends its session. */
const sendingIn = (w: World, paths: SessionPaths) =>
  parsePresence(w.text(paths.heartbeat(W1)), W1)?.sending

/** The band's count of what waits on Lee in this session, where it says `text`. */
const asksOnBand = async (w: World, text: string) =>
  (await w.band()).find({ key: 'band:asks', text })

/** This session with a review asked, Lee's yes to it queued a minute on, and send pressed while Claude is mid-turn, the window holding the message for the turn to end. */
const sentHeld = async (w: World) => {
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))
  const ui = await w.pane()

  await w.clock.advance(MIN)
  await ui.press({ key: `yes:${w.item(id)}` })
  await w.turnStarts('Carry on.')

  const claimedAt = w.clock.now()

  await ui.press({ key: 'send' })
  await w.clock.advance(WATCH_MS)

  return { paths, id, ui, claimedAt }
}

test("send: from its claim the heartbeat says the yes it carries, and the ask needs Lee no more; taken and written down, the heartbeat drops it and the session's lines carry it", async ($, on) => {
  const w = world($, on)
  const { paths, id, claimedAt } = await sentHeld(w)
  const [carried] = keptFlights(w.state.inFlight ?? null)[0]?.replies ?? []

  expect(sendingIn(w, paths)).toEqual([
    { at: claimedAt, replies: [{ id: carried?.id, item: id, verdict: 'yes' }] },
  ])
  expect(w.state.board?.waiting).toBe(0)
  expect(await asksOnBand(w, '0 asks')).toBeDefined()

  await w.turnEnds()
  await w.clock.advance(WATCH_MS)

  expect(sendingIn(w, paths)).toBeUndefined()
  expectWrittenOnce(w, paths, 'send')
  expect(w.state.board?.waiting).toBe(0)
})

test('send refused: the heartbeat keeps no claim, and the ask waits on Lee again', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))
  const ui = await w.pane()

  w.dropPrompts('the session is closing')
  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })
  await w.clock.advance(WATCH_MS)

  expect(sendingIn(w, paths)).toBeUndefined()
  expect(w.state.board?.waiting).toBe(1)
  expect(await asksOnBand(w, '1 ask')).toBeDefined()
})

test('a claim a load from before held messages left, saying no isHeld, is let go once the window was quiet a while', async ($, on) => {
  let isOlder = false

  // What such a load left in $.state: its message submitted as claimed, saying no hold.
  on('state.get', { plugin: 'sitrep', key: ['inFlight'] }, async ($, e, next) => {
    const got = (await next(e)) as { value?: { value: { isHeld?: boolean } | null } }
    const kept = got.value?.value

    if (!isOlder || kept === null || kept === undefined) {
      return got as never
    }

    const { isHeld: _, ...older } = kept

    return { value: { ...got.value, value: older } } as never
  })

  const w = world($, on)
  const { submit } = await replying.send(w)
  const turn = w.holdPrompts()

  submit()
  await turn.arrived
  turn.lose()
  isOlder = true
  await $.session.start(CONVERSATION)
  // A turn of another message, so no wait this module began before the reload stands;
  // and a beat, reading the claim afresh, as a fresh load's first read would.
  await w.turnStarts('Carry on.')
  await w.clock.advance(HEARTBEAT_MS)
  await w.turnEnds()
  await w.clock.advance(QUIET_MS + WATCH_MS)

  expect(w.state.inFlight).toBeNull()
  expect(w.toasts).toContain(
    'Not sent: the message never went in. Your replies are still on the board.',
  )
  expect(w.state.queue).toHaveLength(1)
})

test('send never taken: let go once the window was quiet a while, the heartbeat drops it, and the ask waits on Lee again', async ($, on) => {
  const w = world($, on)
  const { paths } = await sentHeld(w)

  expect(sendingIn(w, paths)).toBeDefined()

  const turn = w.holdPrompts()

  void w.turnEnds()
  await turn.arrived
  turn.lose()
  await w.clock.advance(QUIET_MS + WATCH_MS)

  expect(w.state.inFlight).toBeNull()
  expect(sendingIn(w, paths)).toBeUndefined()
  expect(w.state.board?.waiting).toBe(1)
})

test("inbox: the heartbeat says nothing of the inbox's message, its replies on their way in the inbox already", async ($, on) => {
  const w = world($, on)
  const { paths, submit } = await replying.inbox(w)
  const turn = w.holdPrompts()

  submit()
  await turn.arrived
  await w.clock.advance(WATCH_MS)

  expect(w.state.inFlight).toMatchObject({ source: 'inbox', isTaken: false })
  expect(sendingIn(w, paths)).toBeUndefined()
  expect(w.state.board?.waiting).toBe(0)

  turn.end()
})

test('a send whose window has moved to another session is said in neither heartbeat', async ($, on) => {
  const w = world($, on)
  const { paths } = await sentHeld(w)
  const themes = await w.call('start', {
    name: 'Themes',
    summary: 'The dark palette',
    project: PROJECT.name,
  })

  await w.clock.advance(WATCH_MS)

  expect(w.state.inFlight).toMatchObject({ source: 'send', isTaken: false })
  expect(sendingIn(w, paths)).toBeUndefined()
  expect(sendingIn(w, sessionPaths(ROOT, PROJECT.key, startedId(themes)))).toBeUndefined()
})

test('a load whose read of $.state predates a send claimed since keeps the newer claim in the heartbeat', async ($, on) => {
  let isStale = false

  // session.start reads $.state as it stood when its dispatch began: before the send.
  on('state.get', { plugin: 'sitrep', key: ['inFlight'] }, ($, e, next) =>
    isStale ? { value: { value: null, version: 0 } } : next(e),
  )

  const w = world($, on)
  const { paths, id, claimedAt } = await sentHeld(w)
  const [carried] = keptFlights(w.state.inFlight ?? null)[0]?.replies ?? []

  isStale = true
  await $.session.start(CONVERSATION)
  isStale = false
  await w.clock.advance(WATCH_MS)

  expect(sendingIn(w, paths)).toEqual([
    { at: claimedAt, replies: [{ id: carried?.id, item: id, verdict: 'yes' }] },
  ])
  expect(w.state.board?.waiting).toBe(0)
})

test('a claim another load ended leaves the heartbeat at its next beat, though this load still held it, and the ask waits on Lee again', async ($, on) => {
  let isEnded = false

  // A load a reload left running lets go of the claim in $.state: this load never hears it.
  on('state.get', { plugin: 'sitrep', key: ['inFlight'] }, ($, e, next) =>
    isEnded ? { value: { value: null, version: 0 } } : next(e),
  )

  const w = world($, on)
  const { paths } = await sentHeld(w)

  expect(sendingIn(w, paths)).toBeDefined()

  isEnded = true
  await w.clock.advance(HEARTBEAT_MS + WATCH_MS)

  expect(sendingIn(w, paths)).toBeUndefined()
  expect(w.state.board?.waiting).toBe(1)
})

/** A send of one reply, claimed at `claimedAt` and held. */
const claimAt = (claimedAt: number): SitrepInFlight => ({
  source: 'send',
  project: PROJECT.key,
  session: 'sr-k3p9xw',
  writer: W1,
  text: MESSAGE,
  replies: [{ type: 'reply', id: `r${claimedAt}`, item: 'k1', verdict: 'yes' }],
  claimedAt,
  isHeld: true,
  isTaken: false,
})

test("keptFlights: the claims $.state kept, none, one alone or a list, in the order claimed; the object a build before several sends made of a list, spreading it, is read as no claim, nor as those inside it", () => {
  const first = claimAt(1)
  const second = claimAt(2)
  const older = { ...claimAt(3), isHeld: undefined } as unknown as SitrepInFlight
  const spread = { ...[first, second], isHeld: false } as unknown as SitrepStoredFlights

  expect(keptFlights(null)).toEqual([])
  expect(keptFlights(first)).toEqual([first])
  expect(keptFlights([first, second])).toEqual([first, second])
  expect(keptFlights(older), 'kept before the window held messages: submitted as claimed').toEqual([
    { ...claimAt(3), isHeld: false },
  ])
  expect(keptFlights(spread)).toEqual([])
})
