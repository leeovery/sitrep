import type { On } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import { parseEntries, presenceText, type SessionMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import { file, META, MIN, note, seen, T0, W1, W2, W3, yesAsk } from './support'
import { CONVERSATION, ELSEWHERE, postedId, PROJECT, toProject, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const LEDGER: SessionMeta = { ...META, id: 'sr-1edger', name: 'Request ledger', by: W2 }

/** Every file the world holds under an old layout's folder. */
const underWorks = (w: World) => [...w.files.keys()].filter(path => path.includes('/works/'))

/** The mod finding, as a reload does, `kept` in `$.state`: the session the window held. */
const reloading = (on: On, kept: SitrepAttachment) => {
  let isReloaded = false

  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return { value: { value: kept, version: 1 } }
  })
}

test('a session started now is filed under sessions/, its meta session.json, and nothing under works/', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.call('note', { text: 'Drew round 1' })

  expect(w.files.has(paths.meta)).toBe(true)
  expect(paths.meta.endsWith(`/sessions/${paths.dir.split('/').at(-1)}/session.json`)).toBe(true)
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.type)).toEqual(['note'])
  expect(underWorks(w)).toEqual([])
})

test('a window joins a session filed under works/, reads every writer there, and writes under sessions/ alone', async ($, on) => {
  const w = world($, on)
  const paths = w.seedOld(LEDGER)
  const before = file([T0, yesAsk('k3', 'Review the ledger schema')])

  w.put(paths.old.log(W2), before)
  await $.session.start(CONVERSATION)

  const joined = String((await w.call('join', { session: LEDGER.id })).result)
  const noted = postedId(await w.call('note', { text: 'Read the schema' }))

  expect(joined).toContain('k3 wants a yes (Approve), waiting on Lee: Review the ledger schema')
  expect(w.state.board?.asks.map(ask => [ask.id, ask.by])).toEqual([['k3', W2]])
  expect(w.state.board?.log.map(line => line.id)).toEqual([noted])
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.type)).toEqual(['note'])
  expect(w.files.has(paths.heartbeat(W1))).toBe(true)
  expect(underWorks(w)).toEqual([paths.old.meta, paths.old.log(W2)])
  expect(w.text(paths.old.log(W2))).toBe(before)
})

test('after a reload into this version, the window takes up its session filed under works/, and its first write under sessions/ carries every line it had there', async ($, on) => {
  const w = world($, on, { now: T0 + MIN })
  const paths = w.seedOld(META)
  const before = file([T0, yesAsk('k1', 'Review round 1')], [T0, note('n1', 'Drew round 1')])

  reloading(on, { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 })
  w.put(paths.old.log(W1), before)
  w.put(paths.old.heartbeat(W1), presenceText({ writer: W1, attachedAt: T0, seenAt: T0 }))
  await $.session.start(CONVERSATION)

  expect(w.state.board?.asks.map(ask => ask.id)).toEqual(['k1'])

  await w.call('note', { text: 'Drew round 2' })

  expect(w.text(paths.log(W1)).startsWith(before)).toBe(true)
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.seq)).toEqual([1, 2, 3])
  expect(w.text(paths.old.log(W1)), 'the old file is left as it was').toBe(before)
  expect(w.state.board?.log.map(line => line.text)).toEqual(['Drew round 2', 'Drew round 1'])
})

test('a window that slept through the move and wrote its file under works/ again still reads whole: every line of both, each once, and its later heartbeat', async ($, on) => {
  const w = world($, on)
  const ledger = w.seedOld(LEDGER)
  const moved = file([T0, yesAsk('k3', 'Review the ledger schema')])
  const after = file(
    [T0, yesAsk('k3', 'Review the ledger schema')],
    [T0 + MIN, note('n4', 'Woke and wrote this')],
  )

  w.put(ledger.meta, w.text(ledger.old.meta))
  w.put(ledger.log(W2), moved)
  w.put(ledger.old.log(W2), after)
  w.put(ledger.heartbeat(W2), seen(W2, T0 - 10 * MIN))
  w.put(ledger.old.heartbeat(W2), seen(W2, T0))
  await w.begin()
  await w.call('join', { session: LEDGER.id })

  expect(w.state.board?.asks.map(ask => ask.id)).toEqual(['k3'])
  expect(w.state.board?.log.map(line => line.id)).toEqual(['n4'])
  expect(w.state.board?.presence.find(each => each.writer === W2)?.seenAt).toBe(T0)
  expect(w.state.board?.isOpen).toBe(true)
})

test('the first message lists the sessions filed under works/ beside those under sessions/, in every project', async ($, on) => {
  const w = world($, on)

  w.seed({ ...META, id: 'sr-aaaaaa', name: 'Lobby' })
  w.seedOld({ ...META, id: 'sr-bbbbbb', name: 'Request ledger' })
  w.seedOld(
    { ...META, id: 'sr-cccccc', name: 'Standing orders', project: 'goosemates' },
    ELSEWHERE.key,
  )
  await $.session.start(CONVERSATION)

  const [listing] = (await $.prompt.context({ blocks: [] })).blocks

  for (const id of ['sr-aaaaaa', 'sr-bbbbbb', 'sr-cccccc']) {
    expect(listing?.text, id).toContain(id)
  }
})

test("the watch reads another writer's lines as they land under either layout", async ($, on) => {
  const w = world($, on)
  const ledger = w.seedOld(LEDGER)

  await $.session.start(CONVERSATION)
  await w.call('join', { session: LEDGER.id })
  w.put(ledger.old.log(W2), file([w.clock.now(), note('n1', 'From a window not yet reloaded')]))
  w.put(ledger.log(W3), file([w.clock.now(), note('n2', 'From a window on this version')]))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.log.map(line => [line.id, line.by])).toEqual([
    ['n2', W3],
    ['n1', W2],
  ])
  expect(w.logs, 'no look failed').toEqual([])
})

test('reading a board filed under both layouts lists no folder that is not there, under either', async ($, on) => {
  const w = world($, on)

  w.seedOld(LEDGER)
  w.seedOld({ ...META, id: 'sr-cccccc', name: 'Standing orders' }, ELSEWHERE.key)
  w.seed({ ...META, id: 'sr-dddddd', name: 'Themes' }, ELSEWHERE.key)
  await w.begin()
  await w.call('join', { session: LEDGER.id })
  await w.opened()
  await w.clock.advance(AROUND_MS)

  expect(w.unlisted.filter(path => /\/(sessions|works)(\/|$)/.test(path))).toEqual([])
})

test('finishing a session filed under works/ from its view writes under sessions/, after the lines this window had there', async ($, on) => {
  const w = world($, on)
  const themes = w.seedOld({ ...META, id: 'sr-themes', name: 'Themes', by: W3 })
  const mine = file([T0, note('n1', 'Looked in on the palette')])

  w.put(themes.old.log(W3), file([T0, yesAsk('k4', 'Pick the dark palette', 'Done')]))
  w.put(themes.old.log(W1), mine)
  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: 'go:sr-themes' })
  await ui.press({ key: 'finish:sr-themes' })
  await ui.press({ key: 'finish-yes:sr-themes' })

  expect(w.text(themes.log(W1)).startsWith(mine)).toBe(true)
  expect(parseEntries(w.text(themes.log(W1))).map(({ seq, type }) => [seq, type])).toEqual([
    [1, 'note'],
    [2, 'finish'],
  ])
  expect(w.text(themes.old.log(W1))).toBe(mine)
})

test('a reply to a session filed under works/ goes into its inbox under sessions/, after the letters this window had sent there', async ($, on) => {
  const w = world($, on)
  const ledger = w.seedOld(LEDGER)
  const sent = file([T0, { type: 'reply', id: 'r0', item: 'k0', verdict: 'yes' }])

  w.put(ledger.old.log(W2), file([T0, yesAsk('k3', 'Review the ledger schema')]))
  w.put(ledger.old.letters(W1), sent)
  await w.begin()
  await w.clock.advance(MIN)

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  await ui.press({ key: `yes:${LEDGER.id}:k3` })
  await ui.press({ key: 'send' })

  expect(w.text(ledger.letters(W1)).startsWith(sent)).toBe(true)
  expect(parseEntries(w.text(ledger.letters(W1))).map(({ seq, type }) => [seq, type])).toEqual([
    [1, 'reply'],
    [2, 'reply'],
  ])
  expect(w.text(ledger.old.letters(W1))).toBe(sent)
})
