import type { On } from 'claude-code'
import { expect, test, tier } from './kit'
import { metaText, parseEntries, presenceText, type SessionMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import { file, META, MIN, note, T0, W1, W2, W3, yesAsk } from './support'
import { CONVERSATION, ELSEWHERE, postedId, PROJECT, toProject, world } from './world'

tier('user')

const LEDGER: SessionMeta = { ...META, id: 'sr-1edger', name: 'Invoice ledger', by: W2 }

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

test('a session started now is filed under sessions/, its meta session.json', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.call('note', { text: 'Drew round 1' })

  expect(w.files.has(paths.meta)).toBe(true)
  expect(paths.meta.endsWith(`/sessions/${paths.dir.split('/').at(-1)}/session.json`)).toBe(true)
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.type)).toEqual(['note'])
})

test('a window joins a session another window started, reads every writer there, and writes its own file alone', async ($, on) => {
  const w = world($, on)
  const paths = w.seed(LEDGER)
  const before = file([T0, yesAsk('k3', 'Review the ledger schema')])

  w.put(paths.log(W2), before)
  await $.session.start(CONVERSATION)

  const joined = String((await w.call('join', { session: LEDGER.id })).result)
  const noted = postedId(await w.call('note', { text: 'Read the schema' }))

  expect(joined).toContain('k3 wants a yes (Approve), waiting on Lee: Review the ledger schema')
  expect(w.state.board?.asks.map(ask => [ask.id, ask.by])).toEqual([['k3', W2]])
  expect(w.state.board?.log.map(line => line.id)).toEqual([noted])
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.type)).toEqual(['note'])
  expect(w.files.has(paths.heartbeat(W1))).toBe(true)
  expect(w.text(paths.log(W2))).toBe(before)
})

test('after a reload, the window takes up its session, and its first write carries every line it had', async ($, on) => {
  const w = world($, on, { now: T0 + MIN })
  const paths = w.seed(META)
  const before = file([T0, yesAsk('k1', 'Review round 1')], [T0, note('n1', 'Drew round 1')])

  reloading(on, { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 })
  w.put(paths.log(W1), before)
  w.put(paths.heartbeat(W1), presenceText({ writer: W1, attachedAt: T0, seenAt: T0 }))
  await $.session.start(CONVERSATION)

  expect(w.state.board?.asks.map(ask => ask.id)).toEqual(['k1'])

  await w.call('note', { text: 'Drew round 2' })

  expect(w.text(paths.log(W1)).startsWith(before)).toBe(true)
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.seq)).toEqual([1, 2, 3])
  expect(w.state.board?.log.map(line => line.text)).toEqual(['Drew round 2', 'Drew round 1'])
})

test('the first message lists the sessions filed in every project', async ($, on) => {
  const w = world($, on)

  w.seed({ ...META, id: 'sr-aaaaaa', name: 'Lobby' })
  w.seed({ ...META, id: 'sr-bbbbbb', name: 'Invoice ledger' })
  w.seed(
    { ...META, id: 'sr-cccccc', name: 'Shift schedules', project: 'contoso' },
    ELSEWHERE.key,
  )
  await $.session.start(CONVERSATION)

  const [listing] = (await $.prompt.context({ blocks: [] })).blocks

  for (const id of ['sr-aaaaaa', 'sr-bbbbbb', 'sr-cccccc']) {
    expect(listing?.text, id).toContain(id)
  }
})

test('a folder under sessions/ not named as a session id is never listed as a session', async ($, on) => {
  const w = world($, on)
  const lobby = w.seed({ ...META, id: 'sr-aaaaaa', name: 'Lobby' })

  w.put(
    `${lobby.sessions}/undefined/session.json`,
    metaText({ ...META, id: 'sr-zzzzzz', name: 'Not a session' }),
  )
  await $.session.start(CONVERSATION)

  const [listing] = (await $.prompt.context({ blocks: [] })).blocks

  expect(listing?.text).toContain('Lobby')
  expect(listing?.text).not.toContain('Not a session')
})

test("the watch reads another writer's lines as they land", async ($, on) => {
  const w = world($, on)
  const ledger = w.seed(LEDGER)

  await $.session.start(CONVERSATION)
  await w.call('join', { session: LEDGER.id })
  w.put(ledger.log(W2), file([w.clock.now(), note('n1', 'From one window')]))
  w.put(ledger.log(W3), file([w.clock.now(), note('n2', 'From another')]))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.log.map(line => [line.id, line.by])).toEqual([
    ['n2', W3],
    ['n1', W2],
  ])
  expect(w.logs, 'no look failed').toEqual([])
})

test('reading a board lists no folder that is not there: a session with no inbox or heartbeats, a project with no sessions', async ($, on) => {
  const w = world($, on)

  w.seed(LEDGER)
  w.seed({ ...META, id: 'sr-cccccc', name: 'Shift schedules' }, ELSEWHERE.key)
  w.project('contoso', { name: 'Contoso', created: T0, by: W2 })
  await w.begin()
  await w.call('join', { session: LEDGER.id })
  await w.opened()
  await w.clock.advance(AROUND_MS)

  expect(w.unlisted.filter(path => /\/sessions(\/|$)/.test(path))).toEqual([])
})

test("finishing another window's session from its view writes after the lines this window had there", async ($, on) => {
  const w = world($, on)
  const themes = w.seed({ ...META, id: 'sr-themes', name: 'Themes', by: W3 })
  const mine = file([T0, note('n1', 'Looked in on the palette')])

  w.put(themes.log(W3), file([T0, yesAsk('k4', 'Pick the dark palette', 'Done')]))
  w.put(themes.log(W1), mine)
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
})

test("a reply to another window's session goes into its inbox after the letters this window had sent there", async ($, on) => {
  const w = world($, on)
  const ledger = w.seed(LEDGER)
  const sent = file([T0, { type: 'reply', id: 'r0', item: 'k0', verdict: 'yes' }])

  w.put(ledger.log(W2), file([T0, yesAsk('k3', 'Review the ledger schema')]))
  w.put(ledger.letters(W1), sent)
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
})
