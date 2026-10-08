import { expect, test, tier } from 'claude-code/testing'
import { HEARTBEAT_MS, metaText, parseEntries, parsePresence, workPaths } from '../core'
import { boardOf, workOf } from '../hooks/board'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import { ask, file, fold, META, note, reply, SENDER, status, T0, W1, W2 } from './support'
import { DASHBOARD, PROJECT, ROOT, SESSION, postedId, world } from './world'

tier('user')

/** A /clear: the conversation ends, and the window goes on under another session id. */
const CLEARED = { reason: 'clear' as const, sessionId: W1, resume: { id: W1 } }

test('a work started in one window and joined by a second writer is one work to both', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const asked = postedId(await w.call('ask', { kind: 'review', title: 'Review round 1' }))

  await $.session.end(CLEARED)
  w.become({ session: W2 })
  await w.clock.advance(60_000)

  const joined = String((await w.call('join', { work: id })).result)
  const noted = postedId(await w.call('note', { text: 'Drew round 2' }))

  expect(joined).toContain(`- ${asked} review, waiting on Lee: Review round 1`)
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.type)).toEqual(['ask'])
  expect(parseEntries(w.text(paths.log(W2))).map(line => line.type)).toEqual(['note'])
  expect(w.state.board?.asks.map(item => item.id)).toEqual([asked])
  expect(w.state.board?.log.map(line => line.id)).toEqual([noted])
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.leftAt).toBe(T0)
  expect(parsePresence(w.text(paths.heartbeat(W2)), W2)?.leftAt).toBeUndefined()
  expect(w.state.board?.isOpen).toBe(true)
})

test('a window joining a work it wrote to before counts on from where its file left off', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()

  await w.call('note', { text: 'Drew round 1' })
  await w.call('note', { text: 'Drew round 2' })
  await w.call('start', { ...DASHBOARD, name: 'Lobby' })
  await w.call('join', { work: id })
  await w.call('note', { text: 'Drew round 3' })

  expect(
    parseEntries(w.text(paths.log(W1))).map(line => [line.seq, line.type === 'note' && line.text]),
  ).toEqual([
    [1, 'Drew round 1'],
    [2, 'Drew round 2'],
    [3, 'Drew round 3'],
  ])
})

test('after a reload, the window takes up the work $.state names, reads its file back and counts on', async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const paths = workPaths(ROOT, PROJECT.key, META.id)
  const kept: SitrepAttachment = {
    project: PROJECT.key,
    work: META.id,
    writer: W1,
    attachedAt: T0,
  }
  const before = file(
    [T0, status(['Drawing round 1'])],
    [T0, ask('k1', 'review', 'Review round 1')],
    [T0, note('n1', 'Drew round 1')],
  )
  let isReloaded = false

  // What a reload finds: nothing in the module, the attachment still in $.state.
  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return { value: { value: kept, version: 1 } }
  })

  w.put(paths.meta, metaText(META))
  w.put(paths.log(W1), before)
  await $.session.start(SESSION)
  await w.call('note', { text: 'Drew round 2' })

  const lines = parseEntries(w.text(paths.log(W1)))

  expect(w.text(paths.log(W1)).startsWith(before)).toBe(true)
  expect(lines.map(line => line.seq)).toEqual([1, 2, 3, 4])
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)).toEqual({
    writer: W1,
    attachedAt: T0,
    seenAt: T0 + 60_000,
  })
  expect(w.state.board?.asks.map(item => item.id)).toEqual(['k1'])
})

test('a hold another session left in $.state is dropped, not taken up', async ($, on) => {
  const w = world($, on)
  const paths = workPaths(ROOT, PROJECT.key, META.id)
  let isReloaded = false

  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return {
      value: {
        value: { project: PROJECT.key, work: META.id, writer: W2, attachedAt: T0 },
        version: 1,
      },
    }
  })

  w.put(paths.meta, metaText(META))
  await $.session.start(SESSION)

  expect(w.files.has(paths.heartbeat(W1))).toBe(false)
  expect(w.files.has(paths.heartbeat(W2))).toBe(false)
  expect(w.state.attachment).toBeNull()
})

test('the heartbeat is rewritten every 30 seconds while attached, and says when the window let go', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const beat = () => parsePresence(w.text(paths.heartbeat(W1)), W1)

  expect(beat()).toEqual({ writer: W1, attachedAt: T0, seenAt: T0 })

  await w.clock.advance(HEARTBEAT_MS)

  expect(beat()).toEqual({ writer: W1, attachedAt: T0, seenAt: T0 + HEARTBEAT_MS })

  await w.clock.advance(10_000)
  await $.session.end(CLEARED)

  expect(beat()?.leftAt).toBe(T0 + HEARTBEAT_MS + 10_000)

  await w.clock.advance(3 * HEARTBEAT_MS)

  expect(beat()?.seenAt).toBe(T0 + HEARTBEAT_MS)
})

test('the watch folds a line another writer added, and puts the board in $.state only when it changed', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const written = w.boards.length

  await w.clock.advance(4 * WATCH_MS)

  expect(w.boards.length, 'nothing changed, so nothing is put').toBe(written)

  w.put(paths.log(W2), file([w.clock.now(), ask('k9', 'try', 'Try it on the iPad')]))
  await w.clock.advance(WATCH_MS)

  expect(w.boards.length).toBe(written + 1)
  expect(w.state.board?.asks.map(item => [item.id, item.by])).toEqual([['k9', W2]])

  await w.clock.advance(4 * WATCH_MS)

  expect(w.boards.length).toBe(written + 1)
  expect(w.logs, 'no look failed').toEqual([])
})

test("the watch reads another window's heartbeat and the letters in the inbox too", async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const asked = postedId(await w.call('ask', { kind: 'review', title: 'Review round 1' }))

  await w.clock.advance(WATCH_MS)
  w.beat(id, { writer: W2, attachedAt: w.clock.now(), seenAt: w.clock.now() })
  w.put(paths.letters(SENDER), file([w.clock.now(), reply('r1', asked, 'yes')]))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.presence.map(each => each.writer)).toEqual([W1, W2])
  expect(w.state.board?.replies).toMatchObject([{ id: 'r1', item: asked, by: SENDER }])
})

test('a session that ends lets go: the board and the attachment leave $.state', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await $.session.end(CLEARED)

  expect(w.state.board).toBeNull()
  expect(w.state.attachment).toBeNull()
  expect((await w.call('board')).deny).toContain('No piece of work is attached')
})

test('the board in $.state is plain data, and rebuilds into the work core folds', () => {
  const work = fold({
    logs: {
      [W1]: file(
        [T0, ask('k1', 'decide', 'Keep it?', ['Keep it', 'Drop it'])],
        [T0, note('n1', 'Drew round 1')],
      ),
    },
  })
  const kept = JSON.parse(JSON.stringify(boardOf(work)))

  expect(kept).toEqual(boardOf(work))
  expect(workOf(kept)).toEqual(work)
  expect(workOf(kept).items.get('k1')?.type).toBe('ask')
})
