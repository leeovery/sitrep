import { expect, test, tier } from 'claude-code/testing'
import { parseEntries, workPaths, type WorkMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import { SENT_LINGER_MS } from '../hooks/queue'
import { ask, delivered, file, MIN, reply, T0, W1, W2, W3 } from './support'
import { postedId, PROJECT, ROOT, world } from './world'

tier('user')

type World = ReturnType<typeof world>
type Board = Awaited<ReturnType<World['opened']>>

const LEDGER = 'sr-1edger'
const THEMES = 'sr-themes'

const REVIEW = { kind: 'review', title: 'Review Sessions & Runway, round 1' }

const meta = (id: string, name: string, by: string): WorkMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by,
})

/** The ledger's inbox file this window writes. */
const LETTERS = workPaths(ROOT, PROJECT.key, LEDGER).letters(W1)

/**
 * This session with an ask, beside two others of its project: the ledger,
 * open in another window, and Themes, with no window; each with an ask.
 * A minute on, Lee opens the board: a reply is never written in the same
 * moment as the ask it answers.
 */
async function threeSessions(w: World) {
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', W2))
  const themes = w.elsewhere(meta(THEMES, 'Themes', W3))

  ledger.write(ask('k3', 'review', 'Review the ledger schema'))
  themes.write(ask('k4', 'do', 'Pick the dark palette'))

  const { paths } = await w.begin()
  const asked = postedId(await w.call('ask', REVIEW))

  await w.clock.advance(MIN)
  ledger.beat()

  return { ledger, paths, asked, ui: await w.opened() }
}

/** Lee answers another session's ask from its view, then goes home. */
const answer = async (ui: Board, work: string, item: string) => {
  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${work}` })
  await ui.press({ key: `pick:${item}` })
  await ui.press({ key: `yes:${item}` })
  await ui.press({ key: 'home' })
}

/** The replies a file holds, by id. */
const repliesIn = (w: World, path: string) =>
  parseEntries(w.text(path)).flatMap(line => (line.type === 'reply' ? [line] : []))

test('Ready to send groups the replies by where each goes, this session first, at the foot of every view', async ($, on) => {
  const w = world($, on)
  const { asked, ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: `pick:${asked}` })
  await ui.press({ key: `yes:${asked}` })

  const groups = (await ui.findAll({ type: 'Text' }))
    .map(each => each.text)
    .filter(text => text.startsWith('to '))

  expect(groups).toEqual(['to this session', 'to Request ledger'])
  expect(await ui.find({ type: 'Text', text: '2 replies' })).toBeDefined()

  for (const tab of ['tab:project', 'tab:all']) {
    await ui.press({ key: tab })
    expect(await ui.find({ type: 'Text', text: /READY TO SEND/ }), tab).toBeDefined()
  }
})

test("send writes another work's replies into its inbox as this window's letters, and they leave the queue", async ($, on) => {
  const w = world($, on)
  const { asked, paths, ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: `pick:${asked}` })
  await ui.press({ key: `yes:${asked}` })
  await ui.press({ key: 'send' })

  const [letter] = repliesIn(w, LETTERS)

  expect(letter).toMatchObject({ item: 'k3', verdict: 'yes', seq: 1 })
  expect(w.state.queue).toEqual([])
  expect(w.state.sent).toEqual([{ project: PROJECT.key, work: LEDGER, replies: [letter?.id] }])
  expect(w.toasts).toContain('Sent 1 reply to Request ledger.')
  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    'From the board:\n- Review Sessions & Runway, round 1 → approved',
  ])
  expect(
    parseEntries(w.text(paths.log(W1))).map(line => line.type),
    'only this session’s reply is written to its own file',
  ).toEqual(['ask', 'reply', 'delivered'])
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

test('each destination says where its replies stand, and each reply whether Claude has it', async ($, on) => {
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
  expect(w.state.sent?.map(each => each.work)).toEqual([THEMES])
})

test("the destination's own view shows the ask's reply on its way, and offers no second answer", async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  await ui.press({ key: 'send' })
  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${LEDGER}` })
  await ui.press({ key: 'pick:k3' })

  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  expect(await ui.find({ key: 'yes:k3' })).toBeUndefined()
})

test('a reply to another work whose item changed since is left in Ready to send, unsent', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER, 'k3')
  ledger.write({ type: 'edit', item: 'k3', changes: { kind: 'decide', options: ['Now', 'Later'] } })
  await ui.press({ key: 'send' })

  expect(w.files.has(LETTERS)).toBe(false)
  expect(w.state.queue).toMatchObject([{ work: LEDGER, item: 'k3' }])
})
