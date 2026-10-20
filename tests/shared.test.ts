import { expect, test, tier } from 'claude-code/testing'
import { EXIT, main, WRITER } from '../cli/main'
import { parseEntries, type SessionMeta } from '../core'
import { WATCH_MS } from '../hooks/window'
import { MIN, T0, W1, W2, yesAsk } from './support'
import { terminal } from './terminal'
import { CONVERSATION, postedId, PROMPT, world } from './world'

tier('user')

type World = ReturnType<typeof world>

/** A session the mod started, and the CLI run on the mod's own files, at the mod's own time. */
async function begun(w: World) {
  const { id, paths } = await w.begin()
  const t = terminal({ files: w.files, now: () => w.clock.now() })

  return { id, paths, cli: (...words: string[]) => t.run(...words, '--session', id) }
}

test("what the CLI posts, the mod's watch folds: its note in the log, its ask waiting and counted on the band", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const noted = await cli('note', 'Round 3 drawn', '--detail', 'Frames 1–6')
  const asked = await cli(
    'ask',
    'Review round 3',
    '--wants',
    'yes',
    '--yes',
    'Approve',
    '--where',
    'In Paper: page "round 3"',
  )

  expect([noted.exit, asked.exit]).toEqual([EXIT.done, EXIT.done])

  await w.clock.advance(WATCH_MS)

  const board = w.state.board

  expect(board?.log.map(line => [line.kind, line.id, line.text, line.detail, line.by])).toEqual([
    ['note', noted.out.trim(), 'Round 3 drawn', ['Frames 1–6'], WRITER],
  ])
  expect(board?.asks.map(each => [each.id, each.title, each.state, each.by])).toEqual([
    [asked.out.trim(), 'Review round 3', 'waiting', WRITER],
  ])
  expect(board?.waiting).toBe(1)
  expect(
    w.toasts.some(toast => toast.includes('Review round 3')),
    'a toast names the ask',
  ).toBe(true)

  const band = await w.band()

  expect(await band.find({ key: 'band:asks', text: '1 ask' })).toBeDefined()
  expect(w.logs, 'no look failed').toEqual([])
})

test("the CLI's posts ride into Claude's next turn: Claude was not told them", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const noted = (await cli('note', 'Round 3 drawn')).out.trim()

  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain(`- ${noted}: Round 3 drawn`)
})

test('the CLI writes only its own file: no heartbeat, and the window’s file untouched', async ($, on) => {
  const w = world($, on)
  const { paths, cli } = await begun(w)
  const before = new Map([...w.files].map(([path, held]) => [path, held.text]))

  await cli('note', 'Round 3 drawn')
  await cli('status', '--now', 'Drawing round 4')

  const changed = [...w.files].filter(([path, held]) => before.get(path) !== held.text)

  expect(changed.map(([path]) => path)).toEqual([paths.log(WRITER)])
  expect([...w.files.keys()].filter(path => path.startsWith(`${paths.presence}/`))).toEqual([
    paths.heartbeat(W1),
  ])
})

const FROM_THE_BOARD = { kind: 'plugin', name: 'sitrep', asUser: true }

/** As long as the watch takes to fold a letter, and the next look to take it in. */
const TAKE_IN = 2 * WATCH_MS

type Run = ReturnType<ReturnType<typeof terminal>['run']>

/** Where Lee's answer to each of the session's asks stands, as `board --json` gives it: the open asks', and the resolved ones'. */
const answerIn = async (cli: (...words: string[]) => Run) => {
  const board = JSON.parse((await cli('board', '--json')).out) as {
    asks: { answer: unknown }[]
    resolved: { answer: unknown }[]
  }

  return {
    asks: board.asks.map(ask => ask.answer),
    resolved: board.resolved.map(ask => ask.answer),
  }
}

test("the CLI's answer goes in from the session's window as Lee's own message, once, and its mark closes the ask", async ($, on) => {
  const w = world($, on)
  const { paths, cli } = await begun(w)
  const asked = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' }),
  )

  await w.clock.advance(MIN)
  expect((await cli('answer', asked, 'Go')).exit).toBe(EXIT.done)
  expect(await answerIn(cli)).toMatchObject({ asks: [{ is: 'onItsWay' }], resolved: [] })

  await w.clock.advance(TAKE_IN)

  const lines = parseEntries(w.text(paths.log(W1)))
  const answered = parseEntries(w.text(paths.letters(WRITER))).map(line => 'id' in line && line.id)

  expect(w.prompts).toEqual([
    {
      text: 'From the board:\n- Give the go for stage 3 → Go',
      origin: FROM_THE_BOARD,
      context: undefined,
    },
  ])
  expect(lines.map(line => line.type)).toEqual(['ask', 'delivered'])
  expect(lines.at(-1)).toMatchObject({ replies: answered })
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(await answerIn(cli)).toMatchObject({
    asks: [],
    resolved: [{ is: 'delivered', words: '→ Go', since: lines.at(-1)?.at }],
  })

  await w.clock.advance(4 * WATCH_MS)
  expect(w.prompts, 'nothing goes in twice').toHaveLength(1)
})

test("while the CLI's answer to the window's own ask goes in, the ask waits on Lee no more: the band counts none, and the ask shows it on its way", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const asked = postedId(
    await w.call('ask', {
      wants: 'choice',
      options: ['Keep it', 'Drop it'],
      title: 'Keep the sidebar?',
    }),
  )

  expect(await (await w.band()).find({ key: 'band:asks', text: '1 ask' })).toBeDefined()

  const turn = w.holdPrompts()

  await w.clock.advance(MIN)
  await cli('answer', asked, 'Drop it')
  await w.clock.advance(TAKE_IN)
  await turn.arrived

  expect(w.state.board?.waiting).toBe(0)
  expect(await (await w.band()).find({ key: 'band:asks', text: '0 asks' })).toBeDefined()

  const ui = await w.opened()

  await ui.press({ key: `pick:${w.item(asked)}` })
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()

  turn.end()
})

test('two answers the CLI writes at once to one ask both land, but the window gives Claude only the first, then and ever after', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const t = terminal({ files: w.files, now: () => w.clock.now() })
  const asked = postedId(
    await w.call('ask', {
      wants: 'choice',
      options: ['Keep it', 'Drop it'],
      title: 'Keep the sidebar?',
    }),
  )

  await w.clock.advance(MIN)

  const held = t.holdAppends(2)
  const runs = Promise.all([
    main(['answer', asked, 'Keep it', '--session', id], t.io),
    main(['answer', asked, 'Drop it', '--session', id], t.io),
  ])

  await held.arrived
  held.release()
  expect(await runs).toEqual([EXIT.done, EXIT.done])

  const [first, second] = parseEntries(w.text(paths.letters(WRITER))).map(
    line => 'id' in line && line.id,
  )

  await w.clock.advance(TAKE_IN)
  await w.clock.advance(4 * WATCH_MS)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    'From the board:\n- Keep the sidebar? → Keep it',
  ])
  expect(parseEntries(w.text(paths.log(W1))).at(-1)).toMatchObject({
    type: 'delivered',
    replies: [first],
  })
  expect(w.state.board?.replies.find(reply => reply.id === second)?.delivery).toBe('void')
})

/** A session no window holds, started by a window gone since, with an ask waiting on Lee. */
const LEDGER: SessionMeta = {
  id: 'sr-1edger',
  name: 'Request ledger',
  summary: 'Keep a ledger of requests',
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by: W2,
}

test('an answer to a session no window holds waits in its inbox, and goes in once a window takes the session up', async ($, on) => {
  const w = world($, on)
  const t = terminal({ files: w.files, now: () => w.clock.now() })
  const ledger = w.elsewhere(LEDGER)
  const cli = (...words: string[]) => t.run(...words, '--session', LEDGER.id)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  await $.session.start(CONVERSATION)
  expect((await cli('answer', 'k3', 'Approve')).exit).toBe(EXIT.done)
  await w.clock.advance(TAKE_IN)

  expect(w.prompts, 'no window holds it').toEqual([])
  expect(await answerIn(cli)).toMatchObject({ asks: [{ is: 'onItsWay' }] })

  await w.call('join', { session: LEDGER.id })
  await w.clock.advance(TAKE_IN)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    'From the board:\n- Review the ledger schema → Approve',
  ])
  expect(parseEntries(w.text(ledger.paths.log(W1))).at(-1)).toMatchObject({ type: 'delivered' })
  expect(await answerIn(cli)).toMatchObject({ asks: [], resolved: [{ is: 'delivered' }] })
})
