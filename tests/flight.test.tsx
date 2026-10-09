/**
 * The message in flight, whatever its source, across what can come between
 * its submit and its lines: a reload, a quiet session, the conversation's end.
 *
 * The test kit cannot load a fresh copy of the mod, so a reload here runs
 * session.start again in the same module. What a reload must carry over
 * lives in `$.state`; each test sets the last load's submit as the engine
 * leaves it (settled live): after a `/reload-plugins` typed mid-turn it never
 * resolves, and the new load hears the message's turn start; after a
 * file-watch reload it resolved, and what the last load did next can be cut
 * short, left here as the message taken but not written down.
 */
import { expect, test, tier } from 'claude-code/testing'
import { parseEntries, type WorkPaths } from '../core'
import { QUIET_MS } from '../hooks/deliver'
import { WATCH_MS } from '../hooks/window'
import { file, MIN, reply, SENDER, SLOW, W1 } from './support'
import { postedId, PROJECT, SESSION, startedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Source = 'send' | 'inbox'

const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Sessions & Runway, round 1' }

const MESSAGE = 'From the board:\n- Review Sessions & Runway, round 1 → Approve'

/** What the window's own file holds once the message is written down, by its source. */
const WRITTEN: Record<Source, string[]> = {
  send: ['ask', 'reply', 'delivered'],
  inbox: ['ask', 'delivered'],
}

/** The kinds of line the window's own file holds, in order. */
const kindsIn = (w: World, paths: WorkPaths) =>
  parseEntries(w.text(paths.log(W1))).map(line => line.type)

/**
 * This session with a review asked and Lee's yes to it, a minute on: queued
 * on the board, or in the inbox from another work's window. `submit` sends
 * it: a press of send, or the looks that take the letter in.
 */
const replying: Record<Source, (w: World) => Promise<{ paths: WorkPaths; submit: () => void }>> = {
  send: async w => {
    const { paths } = await w.begin()
    const id = postedId(await w.call('ask', REVIEW))
    const ui = await w.pane()

    await w.clock.advance(MIN)
    await ui.press({ key: `yes:${id}` })

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

/** Whether the work is as a message written down once leaves it: its lines, the ask closed, the queue empty. */
const expectWrittenOnce = (w: World, paths: WorkPaths, source: Source) => {
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
      await $.session.start(SESSION)
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
    await $.session.start(SESSION)
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
    expect(w.state.queue ?? []).toHaveLength(source === 'send' ? 1 : 0)

    isCut = false
    await $.session.start(SESSION)
    expectWrittenOnce(w, paths, source)
    expect(w.state.flash).toBe(source === 'inbox' ? 1 : 0)

    await longAfter(w)
    expect(w.submitted).toEqual([MESSAGE])
    expectWrittenOnce(w, paths, source)
  })

  test(
    `${source}: a message that never goes in is let go once the session has been quiet a while, and no sooner`,
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

  test(`${source}: a message in flight as the conversation ends is written into its work if it goes in after, though the window holds none`, async ($, on) => {
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
}

test("send: let go, Lee's replies are back in Ready to send, and a toast says why", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', REVIEW))
  const ui = await w.pane()
  const turn = w.holdPrompts()

  await ui.press({ key: `yes:${id}` })
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

test('a message whose writing a reload cut short is written into its own work, though the window holds another by then', async ($, on) => {
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

  await $.session.start(SESSION)

  expect(kindsIn(w, paths)).toEqual(WRITTEN.send)
  expect(w.state.attachment?.work).toBe(startedId(themes))
  expect(w.state.board?.replies).toEqual([])
  expect(w.state.inFlight).toBeNull()
})
