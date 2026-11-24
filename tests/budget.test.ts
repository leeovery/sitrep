import type { HookBudget } from 'claude-code'
import { expect, test, tier } from './kit'
import { HEARTBEAT_MS, parseEntries, type SessionPaths } from '../core'
import { AROUND_MS } from '../hooks/around'
import { WATCH_MS } from '../hooks/window'
import { HELP_DESK, HOME, LEDGER, REVIEW, W1 } from './data'
import { park, yesAsk } from './lines'
import { postedId, world, type World } from './world'

tier('user')

/** A whole hook's budget: past every call's deadline, whatever its hook began with. */
const PAST_THE_DEADLINE: HookBudget['ms'] = 10_000

const BUSY = 'The board was busy, so nothing was written: send it again.'

/** A wait the test ends: `held` until `open()`. */
const gate = () => {
  let open = () => {}
  const held = new Promise<void>(resolve => {
    open = resolve
  })

  return { held, open: () => open() }
}

/** The window's own file in the session, as it stands; undefined before its first line. */
const ownText = (w: World, paths: SessionPaths) => w.files.get(paths.log(W1))?.text

/** The ids of the asks the window's own file holds. */
const asksIn = (w: World, paths: SessionPaths) =>
  parseEntries(ownText(w, paths) ?? '').flatMap(line => (line.type === 'ask' ? [line.id] : []))

/** Whether a call has answered yet. */
const answering = (call: Promise<unknown>) => {
  const state = { isAnswered: false }
  const answered = () => {
    state.isAnswered = true
  }

  void call.then(answered, answered)

  return state
}

test('calls waiting their turn behind the watch past their deadline are refused, the board busy, a post or not; their turns, when they come, write nothing', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const watch = gate()
  const projectFile = () => w.files.get(paths.project.file)?.text
  const before = { own: ownText(w, paths), project: projectFile() }

  w.after('list', paths.presence, () => watch.held)
  await w.clock.advance(WATCH_MS)

  const status = w.call('status', { now: ['Drawing Inbox'] })
  const project = w.call('project', { directory: `${HOME}/Code/northwind-app` })

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)
  expect((await status).deny).toBe(BUSY)
  expect((await project).deny).toBe(BUSY)

  watch.open()
  await w.clock.settle()
  expect({ own: ownText(w, paths), project: projectFile() }, 'nothing written').toEqual(before)
  expect(w.logs).toEqual([])
})

test('a post whose check has not passed by its deadline, its fold held, is refused, the board busy, and writes nothing once it runs on', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const fold = gate()
  const before = ownText(w, paths)

  w.after('list', paths.presence, () => fold.held)

  const ask = w.call('ask', REVIEW)

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)
  expect((await ask).deny).toBe(BUSY)

  fold.open()
  await w.clock.settle()
  expect(ownText(w, paths), 'nothing written').toBe(before)
})

test('a post whose check passed by its deadline, its write held, is answered then as ever, and its line lands once written', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const disk = gate()

  w.beforeWrite(paths.log(W1), () => disk.held)

  const ask = w.call('ask', REVIEW)

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)

  const answer = await ask
  const id = postedId(answer)

  expect(answer.result).toBe(
    `Posted ask ${id}. Put it to the user in full after your last tool call.`,
  )
  expect(asksIn(w, paths), 'not written yet').toEqual([])

  disk.open()
  await w.clock.settle()
  expect(asksIn(w, paths)).toEqual([id])
  expect(w.logs).toEqual([])
})

test("a post answered at its deadline keeps its row's name once its write is done", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const disk = gate()
  const names = () => (w.state.named ?? []).map(each => each.name)

  w.beforeWrite(paths.log(W1), () => disk.held)

  const finish = w.call('finish', { reason: 'Shipped' })

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)
  expect((await finish).result).toBe(
    'Finished. This window stays attached; joining the session again reopens it.',
  )
  expect(names(), 'none kept before the write').toEqual([])

  disk.open()
  await w.clock.settle()
  expect(names()).toEqual([HELP_DESK.name])
})

test('a post answered at its deadline whose write then fails says so in the debug log', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const disk = gate()

  w.beforeWrite(paths.log(W1), () => disk.held)
  w.refuseWrites(path => path === paths.log(W1))

  const status = w.call('status', { now: ['Drawing Inbox'] })

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)
  expect((await status).result).toBe('Status set.')

  disk.open()
  await w.clock.settle()
  expect(w.logs.filter(line => line.includes('the status call answered at its deadline'))).toEqual([
    expect.stringContaining('EIO'),
  ])
})

test('a call begun that is no post, such as board, is not refused at its deadline: it answers once its work is done', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const fold = gate()

  w.after('list', paths.presence, () => fold.held)

  const board = w.call('board')
  const call = answering(board)

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)
  expect(call.isAnswered, 'answered at the deadline').toBe(false)

  fold.open()
  expect((await board).result).toContain(HELP_DESK.name)
})

test("resolve on the attached session's item is a post, refused at its deadline before its check; on a parked item of another session, it is not", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(park('p1', 'Look at the ledger export'))

  const { paths } = await w.begin()
  const ask = postedId(await w.call('ask', REVIEW))
  const own = gate()

  w.after('list', paths.presence, () => own.held)

  const here = w.call('resolve', { item: ask })

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)
  expect((await here).deny, 'its own').toBe(BUSY)
  own.open()
  await w.clock.settle()

  const there = gate()

  w.after('list', ledger.paths.dir, () => there.held)

  const elsewhere = w.call('resolve', { item: 'p1', session: LEDGER.id })
  const call = answering(elsewhere)

  await w.clock.settle()
  await w.clock.advance(PAST_THE_DEADLINE)
  expect(call.isAnswered, 'answered at the deadline').toBe(false)

  there.open()
  expect((await elsewhere).result).toBe('Resolved p1.')
})

test('the watch skips a tick while its last refresh is still under way: held over several, it queues no more', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const fold = gate()
  const folds = () => w.listed.filter(path => path === paths.presence).length

  w.after('list', paths.presence, () => fold.held)
  await w.clock.advance(WATCH_MS)

  const held = folds()

  await w.clock.advance(3 * WATCH_MS)
  fold.open()
  await w.clock.settle()
  expect(folds(), 'no tick queued behind the held one').toBe(held)

  await w.clock.advance(WATCH_MS)
  expect(folds(), 'the next tick, once it is done').toBe(held + 1)
})

test('the heartbeat skips a beat while its last is still under way: held over several, it queues no more', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const disk = gate()
  const beats = () => w.written.filter(path => path === paths.heartbeat(W1)).length

  // The start's own rewrites of the heartbeat, for its call starting and ending, done first.
  await w.clock.advance(WATCH_MS)
  w.beforeWrite(paths.heartbeat(W1), () => disk.held)
  await w.clock.advance(HEARTBEAT_MS)

  const before = beats()

  await w.clock.advance(2 * HEARTBEAT_MS)
  disk.open()
  await w.clock.settle()
  expect(beats(), 'the held beat alone').toBe(before + 1)

  await w.clock.advance(HEARTBEAT_MS)
  expect(beats(), 'the next beat, once it is done').toBe(before + 2)
})

test('the look around skips a tick while its last look is still under way: held over several, it queues no more', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  await w.begin()

  const look = gate()
  const looks = () => w.listed.filter(path => path === ledger.paths.dir).length

  w.after('list', ledger.paths.dir, () => look.held)
  await w.clock.advance(AROUND_MS)

  const held = looks()

  await w.clock.advance(3 * AROUND_MS)
  look.open()
  await w.clock.settle()
  expect(looks(), 'no tick queued behind the held one').toBe(held)

  await w.clock.advance(AROUND_MS)
  expect(looks(), 'the next tick, once it is done').toBe(held + 1)
})
