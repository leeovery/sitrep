import { expect, test, tier } from 'claude-code/testing'
import { EXIT } from '../cli/main'
import { parseEntries, sessionPaths, type SessionMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import { SENT_LINGER_MS } from '../hooks/queue'
import { rowsOf } from './drawn'
import { CLI, delivered, file, MIN, reply, resolve, SLOW, T0, W1, W2, W3, yesAsk } from './support'
import { terminal } from './terminal'
import { INLINE, postedId, PROJECT, ROOT, toProject, world } from './world'

tier('user')

type World = ReturnType<typeof world>
type Board = Awaited<ReturnType<World['opened']>>

const LEDGER = 'sr-1edger'
const THEMES = 'sr-themes'

const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Sessions & Runway, round 1' }

const meta = (id: string, name: string, by: string): SessionMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by,
})

/** The ledger's inbox file this window writes. */
const LETTERS = sessionPaths(ROOT, PROJECT.key, LEDGER).letters(W1)

/** Themes' inbox file this window writes. */
const THEME_LETTERS = sessionPaths(ROOT, PROJECT.key, THEMES).letters(W1)

/**
 * This session with an ask, beside two others of its project: the ledger,
 * open in another window, and Themes, with no window; each with an ask.
 * A minute on, Lee opens the board: a reply is never written in the same
 * moment as the ask it answers.
 */
async function threeSessions(w: World) {
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', W2))
  const themes = w.elsewhere(meta(THEMES, 'Themes', W3))

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  themes.write(yesAsk('k4', 'Pick the dark palette', 'Done'))

  const { paths } = await w.begin()
  const asked = postedId(await w.call('ask', REVIEW))

  await w.clock.advance(MIN)
  ledger.beat()

  return { ledger, themes, paths, asked, ui: await w.opened() }
}

/** Lee answers another session's ask from its view, then goes home. */
const answer = async (ui: Board, session: string, item: string) => {
  await toProject(ui)
  await ui.press({ key: `go:${session}` })
  await ui.press({ key: `pick:${session}:${item}` })
  await ui.press({ key: `yes:${session}:${item}` })
  await ui.press({ key: 'tab:session' })
}

/** The replies a file holds, by id. */
const repliesIn = (w: World, path: string) =>
  parseEntries(w.text(path)).flatMap(line => (line.type === 'reply' ? [line] : []))

test('Ready to send groups the replies by where each goes, this session first, at the foot of every view', async ($, on) => {
  const w = world($, on)
  const { asked, ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: `pick:${w.item(asked)}` })
  await ui.press({ key: `yes:${w.item(asked)}` })

  const groups = (await ui.findAll({ type: 'Text' }))
    .map(each => each.text)
    .filter(text => text.startsWith('to '))

  expect(groups).toEqual(['to this session', 'to Request ledger'])
  expect(await ui.find({ type: 'Text', text: '2 replies' })).toBeDefined()

  for (const way of ['tab:all', `proj:${PROJECT.key}`]) {
    await ui.press({ key: way })
    expect(await ui.find({ type: 'Text', text: /READY TO SEND/ }), way).toBeDefined()
  }
})

test("send writes another session's replies into its inbox as this window's letters, and they leave the queue", async ($, on) => {
  const w = world($, on)
  const { asked, paths, ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: `pick:${w.item(asked)}` })
  await ui.press({ key: `yes:${w.item(asked)}` })
  await ui.press({ key: 'send' })

  const [letter] = repliesIn(w, LETTERS)

  expect(letter).toMatchObject({ item: 'k3', verdict: 'yes', seq: 1 })
  expect(w.state.queue).toEqual([])
  expect(w.state.sent).toEqual([{ project: PROJECT.key, session: LEDGER, replies: [letter?.id] }])
  expect(w.toasts).toContain('Sent 1 reply to Request ledger.')
  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    'From the board:\n- Review Sessions & Runway, round 1 → Approve',
  ])
  expect(
    parseEntries(w.text(paths.log(W1))).map(line => line.type),
    'only this session’s reply is written to its own file',
  ).toEqual(['ask', 'reply', 'delivered'])
})

test('a send of replies to other sessions only closes an inline board, once they are in their inboxes', async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await ui.unmount()

  const inline = await w.pane('terminal', INLINE)

  await inline.press({ key: 'send' })

  expect(repliesIn(w, LETTERS)).toMatchObject([{ item: 'k3', verdict: 'yes' }])
  expect(w.prompts).toEqual([])
  expect(w.panes.has('sitrep')).toBe(false)
  expect(w.state.pane?.isOpen).toBe(false)
})

test('a letter after a reload adds to the inbox file as it stands, its count going on', async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  w.put(LETTERS, file([T0, reply('r0', 'k9', 'yes')]))
  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: 'send' })

  expect(
    parseEntries(w.text(LETTERS)).map(line => [line.seq, line.type === 'reply' && line.item]),
  ).toEqual([
    [1, 'k9'],
    [2, 'k3'],
  ])
})

test(
  'each destination says where its replies stand, and each reply whether Claude has it',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ledger, ui } = await threeSessions(w)

    await answer(ui, LEDGER, 'k3')
    await answer(ui, THEMES, 'k4')
    await ui.press({ key: 'send' })

    expect(w.toasts).toContain('Sent 1 reply to Request ledger and 1 reply to Themes.')
    expect(await ui.find({ type: 'Text', text: '⧗ waiting for its turn to end' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '○ closed: goes in when it reopens' })).toBeDefined()
    expect(await ui.findAll({ type: 'Text', text: '· on its way' })).toHaveLength(2)
    expect(await ui.find({ key: 'send' }), 'nothing waits to be sent').toBeUndefined()

    const [letter] = repliesIn(w, LETTERS)

    ledger.write(delivered(letter?.id ?? ''))
    ledger.beat()
    await w.clock.advance(AROUND_MS)
    expect(await ui.find({ type: 'Text', text: '✓ delivered' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '· delivered just now' })).toBeDefined()

    await w.clock.advance(2 * MIN)
    expect(await ui.find({ type: 'Text', text: '· delivered 2m ago' })).toBeDefined()

    await w.clock.advance(SENT_LINGER_MS)
    expect(await ui.find({ type: 'Text', text: 'to Request ledger' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: 'to Themes' })).toBeDefined()
    expect(w.state.sent?.map(each => each.session)).toEqual([THEMES])
  },
)

test("an ask whose reply went into its session's inbox waits on Lee no more: the band, the tab and the project count it nowhere", async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  expect(await (await w.band()).find({ key: 'band:elsewhere', text: '2 elsewhere' })).toBeDefined()

  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: 'send' })

  expect(await (await w.band()).find({ key: 'band:elsewhere', text: '1 elsewhere' })).toBeDefined()
  expect(rowsOf(await ui.find({ key: 'tab:all:box' }))).toEqual([' ≡ All projects 2'])

  await toProject(ui)

  expect(await ui.find({ type: 'Text', text: '2 waiting on you' })).toBeDefined()
  expect(
    await ui.find({ key: `pick:${LEDGER}:k3`, text: 'Request ledger: Review the ledger schema' }),
    'its ask still shows',
  ).toBeDefined()
})

test("the destination's own view shows the ask's reply on its way, and offers no second answer", async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: 'send' })
  await toProject(ui)
  await ui.press({ key: `go:${LEDGER}` })
  await ui.press({ key: `pick:${LEDGER}:k3` })

  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  expect(await ui.find({ key: `yes:${LEDGER}:k3` })).toBeUndefined()
})

test('a reply to another session whose item changed since is left in Ready to send, unsent', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  ledger.write({
    type: 'edit',
    item: 'k3',
    changes: { wants: 'choice', options: ['Now', 'Later'] },
  })
  await ui.press({ key: 'send' })

  expect(w.files.has(LETTERS)).toBe(false)
  expect(w.state.queue).toMatchObject([{ session: LEDGER, item: 'k3' }])
})

test('two quick presses of send write each letter once', async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await Promise.all([ui.press({ key: 'send' }), ui.press({ key: 'send' })])

  expect(repliesIn(w, LETTERS)).toHaveLength(1)
  expect(w.state.sent).toMatchObject([{ session: LEDGER, replies: [repliesIn(w, LETTERS)[0]?.id] }])
  expect(w.toasts.filter(toast => toast.startsWith('Sent'))).toEqual([
    'Sent 1 reply to Request ledger.',
  ])
})

test(
  'a sent reply whose item changed before it went in shows there as not delivered, offers its item again, and lingers out',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ledger, ui } = await threeSessions(w)

    await answer(ui, LEDGER, 'k3')
    await ui.press({ key: 'send' })
    await w.clock.advance(MIN)
    ledger.write({
      type: 'edit',
      item: 'k3',
      changes: { wants: 'choice', options: ['Now', 'Later'] },
    })
    ledger.beat()
    await w.clock.advance(AROUND_MS)

    expect(await ui.find({ type: 'Text', text: '✕ not delivered' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '· not delivered: it changed since' })).toBeDefined()

    await toProject(ui)
    await ui.press({ key: `go:${LEDGER}` })
    await ui.press({ key: `pick:${LEDGER}:k3` })
    expect(await ui.find({ key: `choose:${LEDGER}:k3:0` })).toBeDefined()

    await w.clock.advance(SENT_LINGER_MS)
    expect(await ui.find({ type: 'Text', text: 'to Request ledger' })).toBeUndefined()
    expect(w.state.sent).toEqual([])
  },
)

test("a reply queued to another session's ask that Lee answered from elsewhere first, or that Claude closed, is not sent: Ready to send keeps it, saying why", async ($, on) => {
  const w = world($, on)
  const { themes, ui } = await threeSessions(w)
  const t = terminal({ files: w.files, now: () => w.clock.now() })

  await answer(ui, LEDGER, 'k3')
  await answer(ui, THEMES, 'k4')
  expect((await t.run('answer', 'k3', 'Approve', '--session', LEDGER)).exit).toBe(EXIT.done)
  themes.write(resolve('k4'))
  await w.clock.advance(AROUND_MS)

  expect(await ui.find({ type: 'Text', text: '· not sent: already answered' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· not sent: Claude closed it' })).toBeDefined()

  await ui.press({ key: 'send' })

  expect(w.files.has(LETTERS)).toBe(false)
  expect(w.files.has(THEME_LETTERS)).toBe(false)
  expect(w.state.queue).toMatchObject([
    { session: LEDGER, item: 'k3' },
    { session: THEMES, item: 'k4' },
  ])
})

test(
  "a sent reply that reached its ask after another of Lee's answers, or after Claude closed it, shows there as not delivered, saying which",
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ui } = await threeSessions(w)

    await answer(ui, LEDGER, 'k3')
    await answer(ui, THEMES, 'k4')
    await ui.press({ key: 'send' })

    const [ours] = repliesIn(w, LETTERS)
    const before = (ours?.at ?? 0) - 1

    w.put(
      sessionPaths(ROOT, PROJECT.key, LEDGER).letters(W3),
      file([before, reply('r9', 'k3', 'yes', { note: 'From the other window' })]),
    )
    w.put(sessionPaths(ROOT, PROJECT.key, THEMES).log(CLI), file([before, resolve('k4')]))
    await w.clock.advance(AROUND_MS)

    expect(await ui.findAll({ type: 'Text', text: '✕ not delivered' })).toHaveLength(2)
    expect(await ui.find({ type: 'Text', text: '· not delivered: already answered' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '· not delivered: Claude closed it' })).toBeDefined()
  },
)
