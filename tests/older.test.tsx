/**
 * A window reloaded from a load of the mod before a piece of work was called
 * a session: `$.state` outlives the reload, so this load is handed what the
 * older one left there, in its names, and takes it up in today's.
 */
import type { On } from 'claude-code'
import { expect, test, tier, type Engine } from 'claude-code/testing'
import { metaText, sessionPaths, type SessionMeta } from '../core'
import { fromOlder } from '../hooks/older'
import type { SitrepInFlight, SitrepPane, SitrepProject } from '../types'
import { file, META, resolve, T0, W1, W2, yesAsk, type Line } from './support'
import { CONVERSATION, PROJECT, ROOT, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const NOW = T0 + 60_000

/** Another session of the project, open in another window. */
const LEDGER: SessionMeta = { ...META, id: 'sr-1edger', name: 'Request ledger', by: W2 }

/** The held session's asks: one waiting, and four Claude resolved, one more than RESOLVED folds to. */
const ASKS = file(
  [T0, yesAsk('k1', 'Review round 1')],
  ...['a1', 'a2', 'a3', 'a4'].flatMap((id, n): Line[] => [
    [T0, yesAsk(id, `Review round ${n + 2}`)],
    [T0 + n + 1, resolve(id, 'Approved in the chat')],
  ]),
)

/** The window's hold, as an older load left it: its session named as its work. */
const ATTACHED = { project: PROJECT.key, work: META.id, writer: W1, attachedAt: T0 }

/** What an older load left in a slot of `$.state`, read until this load first writes it. */
const leftBefore = (on: On, key: 'attachment' | 'queue' | 'pane', value: unknown) => {
  let isWritten = false

  on('state.get', { plugin: 'sitrep', key: [key] }, ($, e, next) =>
    isWritten ? next(e) : { value: { value, version: 0 } },
  )
  on('state.set', { plugin: 'sitrep', key: [key] }, ($, e, next) => {
    isWritten = true

    return next(e)
  })
}

/** The held session and the ledger on disk, and the window reloaded over the hold an older load left. */
const reloaded = async ($: Engine, w: World, on: On, pane?: object) => {
  const held = sessionPaths(ROOT, PROJECT.key, META.id)
  const ledger = sessionPaths(ROOT, PROJECT.key, LEDGER.id)

  w.put(held.meta, metaText(META))
  w.put(held.log(W1), ASKS)
  w.put(ledger.meta, metaText(LEDGER))
  w.put(ledger.log(W2), file([T0, yesAsk('k3', 'Keep the ledger forever?')]))
  leftBefore(on, 'attachment', ATTACHED)

  if (pane !== undefined) {
    leftBefore(on, 'pane', { isOpen: false, place: null, selected: null, placement: {}, ...pane })
  }

  await $.session.start(CONVERSATION)
}

test('a reload takes up the session an older load named as its work, and what it queued for it in Ready to send', async ($, on) => {
  const w = world($, on, { now: NOW })

  leftBefore(on, 'queue', [{ project: PROJECT.key, work: META.id, item: 'k1', verdict: 'yes' }])
  await reloaded($, w, on)

  expect(w.state.board?.id).toBe(META.id)
  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: META.id, writer: W1 })
  expect(w.state.attachment).not.toHaveProperty('work')

  const ui = await w.opened()

  expect(await ui.find({ type: 'Text', text: 'to this session' })).toBeDefined()
  expect(await ui.find({ key: `ready:${META.id}:k1` })).toBeDefined()
})

test('a reload keeps the session an older load left the board looking at', async ($, on) => {
  const w = world($, on, { now: NOW })

  await reloaded($, w, on, { place: { level: 'session', project: PROJECT.key, work: LEDGER.id } })

  const ui = await w.opened()

  expect(await ui.find({ key: `pick:${LEDGER.id}:k3` }), 'the ledger’s view').toBeDefined()
  expect(w.state.pane?.place).toEqual({
    level: 'session',
    project: PROJECT.key,
    session: LEDGER.id,
  })
})

test('a reload keeps RESOLVED shown in full as an older load left DONE, and the closed ask it had opened', async ($, on) => {
  const w = world($, on, { now: NOW })

  await reloaded($, w, on, { doneInFull: META.id, selected: `done:${META.id}:a1` })

  const ui = await w.opened()

  expect(await ui.find({ key: `earlier:${META.id}` })).toMatchObject({
    props: { label: 'show fewer' },
  })
  expect(await ui.find({ type: 'Text', text: /resolved by Claude: Approved/ })).toBeDefined()
  expect(w.state.pane).toMatchObject({
    resolvedInFull: META.id,
    selected: `resolved:${META.id}:a1`,
  })
  expect(w.state.pane).not.toHaveProperty('doneInFull')
})

test('every other slot an older load named otherwise reads in the names of today; one in them reads as it is', () => {
  const ref = { project: PROJECT.key, session: META.id }
  const older = { project: PROJECT.key, work: META.id }
  const brief = { id: META.id } as SitrepProject['sessions'][number]
  const project: SitrepProject = { key: PROJECT.key, sessions: [brief] }
  const inFlight = {
    source: 'send' as const,
    writer: W1,
    text: 'From the board',
    replies: [],
    claimedAt: T0,
    isHeld: false,
    isTaken: false,
  }
  const answering = {
    item: 'k1',
    as: 'answer' as const,
    title: 'Review',
    surface: 'terminal' as const,
  }
  const at = { level: 'session' as const, ...ref }
  const pane: SitrepPane = {
    isOpen: true,
    place: at,
    selected: null,
    resolvedInFull: null,
    placement: {},
  }

  expect(fromOlder.projects([{ key: PROJECT.key, works: [brief] } as never])).toEqual([project])
  expect(fromOlder.sent([{ ...older, replies: ['r1'] } as never])).toEqual([
    { ...ref, replies: ['r1'] },
  ])
  expect(fromOlder.inFlight({ ...older, ...inFlight } as never)).toEqual({ ...ref, ...inFlight })
  expect(fromOlder.scroll({ place: { level: 'session', ...older }, top: 4 } as never)).toEqual({
    place: at,
    top: 4,
  })
  expect(fromOlder.answering({ ...older, ...answering } as never)).toEqual({
    ...ref,
    ...answering,
  })
  expect(fromOlder.attachment(null)).toBeNull()
  expect(fromOlder.projects([project])).toEqual([project])
  expect(fromOlder.pane(pane)).toEqual(pane)
})

test('a message in flight an older load left, submitted as it was claimed, is held no more; one this load holds reads as it is', () => {
  const held: SitrepInFlight = {
    source: 'send',
    project: PROJECT.key,
    session: META.id,
    writer: W1,
    text: 'From the board',
    replies: [],
    claimedAt: T0,
    isHeld: true,
    isTaken: false,
  }
  const { isHeld: _, ...left } = held

  expect(fromOlder.inFlight(left as never)).toEqual({ ...held, isHeld: false })
  expect(fromOlder.inFlight(held)).toEqual(held)
})
