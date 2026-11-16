import { expect, test, tier } from './kit'
import { EXIT, main, WRITER } from '../cli/main'
import { parseEntries, type SessionMeta } from '../core'
import { WATCH_MS } from '../hooks/window'
import { CLOSES, GO, LEDGER, MIN, PLUGIN_VERSION, W1 } from './data'
import { file, reply, yesAsk } from './lines'
import { asked, CONVERSATION, PROMPT, world, type World } from './world'
import { manifestText, terminal } from './terminal'

tier('user')

/** The CLI on the mod's own files, at the mod's own time, from the plugin the windows run: one folder, one version. */
const besideWindows = (w: World) =>
  terminal({ files: w.files, now: () => w.clock.now(), manifest: manifestText(PLUGIN_VERSION) })

/** A session the mod started, and the CLI run on it. */
async function begun(w: World) {
  const { id, paths } = await w.begin()
  const t = besideWindows(w)

  return { id, paths, cli: (...words: string[]) => t.run(...words, '--session', id) }
}

test("what the CLI posts, the mod's watch folds: its note in the log, its ask waiting and counted on the band", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const noted = await cli('note', 'Round 3 drawn', '--detail', 'Frames 1–6')
  const posted = await cli(
    'ask',
    'Review round 3',
    '--wants',
    'yes',
    '--yes',
    'Approve',
    '--where',
    'In Paper: page "round 3"',
  )

  expect([noted.exit, posted.exit]).toEqual([EXIT.done, EXIT.done])

  await w.clock.advance(WATCH_MS)

  const board = w.state.board

  expect(board?.log.map(line => [line.kind, line.id, line.text, line.detail, line.by])).toEqual([
    ['note', noted.out.trim(), 'Round 3 drawn', ['Frames 1–6'], WRITER],
  ])
  expect(board?.asks.map(each => [each.id, each.title, each.state, each.by])).toEqual([
    [posted.out.trim(), 'Review round 3', 'waiting', WRITER],
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

/** Where Lee's reply to each of the session's asks stands, as `board --json` gives it: the open asks', and the resolved ones'. */
const replyIn = async (cli: (...words: string[]) => Run) => {
  const board = JSON.parse((await cli('board', '--json')).out) as {
    asks: { reply: unknown }[]
    resolved: { reply: unknown }[]
  }

  return {
    asks: board.asks.map(ask => ask.reply),
    resolved: board.resolved.map(ask => ask.reply),
  }
}

test("the CLI's answer goes in from the session's window as Lee's own message, once, and its mark closes the ask", async ($, on) => {
  const w = world($, on)
  const { paths, cli } = await begun(w)
  const posted = await asked(w, GO)

  await w.clock.advance(MIN)
  expect((await cli('answer', posted, 'Go')).exit).toBe(EXIT.done)
  expect(await replyIn(cli)).toMatchObject({ asks: [{ is: 'onItsWay' }], resolved: [] })

  await w.clock.advance(TAKE_IN)

  const lines = parseEntries(w.text(paths.log(W1)))
  const answered = parseEntries(w.text(paths.letters(WRITER))).map(line => 'id' in line && line.id)

  expect(w.prompts).toEqual([
    {
      text: `From the board:\n- Give the go for stage 3 → Go${CLOSES}`,
      origin: FROM_THE_BOARD,
      context: undefined,
    },
  ])
  expect(lines.map(line => line.type)).toEqual(['ask', 'delivered'])
  expect(lines.at(-1)).toMatchObject({ replies: answered })
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(await replyIn(cli)).toMatchObject({
    asks: [],
    resolved: [{ is: 'delivered', words: '→ Go', since: lines.at(-1)?.at }],
  })

  await w.clock.advance(4 * WATCH_MS)
  expect(w.prompts, 'nothing goes in twice').toHaveLength(1)
})

test("while the CLI's answer to the window's own ask goes in, the ask waits on Lee no more: the band counts none, and the ask shows it on its way", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const posted = await asked(w, {
    wants: 'choice',
    options: ['Keep it', 'Drop it'],
    title: 'Keep the sidebar?',
  })

  expect(await (await w.band()).find({ key: 'band:asks', text: '1 ask' })).toBeDefined()

  const turn = w.holdPrompts()

  await w.clock.advance(MIN)
  await cli('answer', posted, 'Drop it')
  await w.clock.advance(TAKE_IN)
  await turn.arrived

  expect(w.state.board?.waiting).toBe(0)
  expect(await (await w.band()).find({ key: 'band:asks', text: '0 asks' })).toBeDefined()

  const ui = await w.opened()

  await ui.press({ key: `pick:${w.item(posted)}` })
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()

  turn.end()
})

test('two answers the CLI writes at once to one ask both land, but the window gives Claude only the first, then and ever after', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const t = besideWindows(w)
  const posted = await asked(w, {
    wants: 'choice',
    options: ['Keep it', 'Drop it'],
    title: 'Keep the sidebar?',
  })

  await w.clock.advance(MIN)

  const held = t.holdAppends(2)
  const runs = Promise.all([
    main(['answer', posted, 'Keep it', '--session', id], t.io),
    main(['answer', posted, 'Drop it', '--session', id], t.io),
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
    `From the board:\n- Keep the sidebar? → Keep it${CLOSES}`,
  ])
  expect(parseEntries(w.text(paths.log(W1))).at(-1)).toMatchObject({
    type: 'delivered',
    replies: [first],
  })
  expect(w.state.board?.replies.find(reply => reply.id === second)?.delivery).toBe('void')
})

/** The window's own ask wanting a choice, and the board drawn. */
async function sidebarAsked(w: World) {
  const posted = await asked(w, {
    wants: 'choice',
    options: ['Keep it', 'Drop it'],
    title: 'Keep the sidebar?',
  })

  return { posted, ui: await w.pane() }
}

test("a reply queued to an ask the CLI's answer reached first is not carried: Claude has that answer only, and Ready to send says why", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const { posted, ui } = await sidebarAsked(w)
  const key = w.item(posted)

  await ui.press({ key: `choose:${key}:0` })
  expect(await ui.find({ key: `rewrite:${key}` })).toBeDefined()
  expect(await ui.find({ key: `readyrewrite:${key}` })).toBeDefined()

  await w.clock.advance(MIN)
  await cli('answer', posted, 'Drop it')
  await ui.press({ key: 'send' })

  expect(w.toasts).toContain(
    'Nothing to send: the items replied to are answered or closed already. Your replies are still on the board.',
  )
  expect(
    await ui.findAll({ type: 'Text', text: '· not sent: already answered' }),
    "under the ask's row and in Ready to send",
  ).toHaveLength(2)
  expect(await ui.find({ key: `rewrite:${key}` }), 'no comment to add to it').toBeUndefined()
  expect(await ui.find({ key: `readyrewrite:${key}` })).toBeUndefined()
  expect(await ui.find({ key: `unready:${key}` }), 'Lee can clear it').toBeDefined()

  await w.clock.advance(TAKE_IN)
  await ui.press({ key: 'send' })
  await w.clock.advance(4 * WATCH_MS)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    `From the board:\n- Keep the sidebar? → Drop it${CLOSES}`,
  ])
  expect(w.state.board?.asks[0]).toMatchObject({ state: 'closed', answer: { option: 'Drop it' } })
  expect(w.state.queue, 'left in Ready to send, unsent').toMatchObject([{ item: posted }])
  expect(await ui.find({ type: 'Text', text: '· not sent: already answered' })).toBeDefined()
})

test("while the window's send waits out Claude's turn, the CLI reads its answer on its way from the claim: `board --json` says so, `list` counts nothing waiting, and a second answer is refused", async ($, on) => {
  const w = world($, on)
  const { cli } = await begun(w)
  const { posted, ui } = await sidebarAsked(w)

  await ui.press({ key: `choose:${w.item(posted)}:0` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await w.clock.advance(MIN)
  expect(await replyIn(cli)).toMatchObject({
    asks: [{ is: 'onItsWay', isAnswer: true, words: '→ Keep it' }],
    resolved: [],
  })
  expect(JSON.parse((await besideWindows(w).run('list', '--json')).out)).toMatchObject({
    projects: [{ waiting: 0, sessions: [{ waiting: 0 }] }],
  })

  const second = await cli('answer', posted, 'Drop it')

  expect(second.exit).toBe(EXIT.refused)
  expect(second.err).toContain(`An answer to ${posted} is on its way already.`)
  expect(w.prompts, 'held for the turn to end').toEqual([])

  await w.turnEnds()
  await w.clock.advance(4 * WATCH_MS)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    `From the board:\n- Keep the sidebar? → Keep it${CLOSES}`,
  ])
  expect(await replyIn(cli)).toMatchObject({
    asks: [],
    resolved: [{ is: 'delivered', words: '→ Keep it' }],
  })
})

test("an answer reaching the inbox while the window's send waits out Claude's turn never goes in: Claude has the send's answer, its mark the record of it, and the inbox's goes void", async ($, on) => {
  const w = world($, on)
  const { paths, cli } = await begun(w)
  const { posted, ui } = await sidebarAsked(w)

  await ui.press({ key: `choose:${w.item(posted)}:0` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await w.clock.advance(MIN)
  w.put(
    paths.letters(WRITER),
    file([w.clock.now(), reply('r9', posted, 'choose', { option: 'Drop it' })]),
  )
  await w.clock.advance(TAKE_IN)
  expect(
    await ui.find({ type: 'Text', text: /not sent/ }),
    'the reply the send carries is going',
  ).toBeUndefined()

  await w.turnEnds()
  await w.clock.advance(4 * WATCH_MS)

  const [letter] = parseEntries(w.text(paths.letters(WRITER))).map(line => 'id' in line && line.id)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    `From the board:\n- Keep the sidebar? → Keep it${CLOSES}`,
  ])
  expect(w.state.board?.replies.find(reply => reply.id === letter)).toMatchObject({
    delivery: 'void',
    voided: 'answered',
  })
  expect(await replyIn(cli)).toMatchObject({
    resolved: [{ is: 'delivered', words: '→ Keep it' }],
  })
})

test("an answer landing as the window's send reads the board, unseen by it, goes void once the send is written down: Claude has the send's answer only", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const { posted, ui } = await sidebarAsked(w)

  await ui.press({ key: `choose:${w.item(posted)}:0` })
  await w.clock.advance(MIN)

  const claimed = w.clock.now()

  // The send's read lists the session's folder twice, before its heartbeats
  // and after them: the letter lands once the second has taken its view.
  w.after('list', paths.dir, () => {})
  w.after('list', paths.dir, async () => {
    await w.clock.set(claimed + 2)
    w.put(
      paths.letters(WRITER),
      file([claimed + 1, reply('r9', posted, 'choose', { option: 'Drop it' })]),
    )
  })
  await ui.press({ key: 'send' })
  await w.clock.advance(4 * WATCH_MS)

  expect(w.state.inFlight).toBeNull()
  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    `From the board:\n- Keep the sidebar? → Keep it${CLOSES}`,
  ])
  expect(w.state.board?.replies.find(each => each.id === 'r9')).toMatchObject({
    delivery: 'void',
    voided: 'answered',
  })
})

/** A session no window holds, started by a window gone since, with an ask waiting on Lee. */
const INVOICES: SessionMeta = { ...LEDGER, summary: 'Keep a ledger of invoices' }

test('an answer to a session no window holds waits in its inbox, and goes in once a window takes the session up', async ($, on) => {
  const w = world($, on)
  const t = besideWindows(w)
  const ledger = w.elsewhere(INVOICES)
  const cli = (...words: string[]) => t.run(...words, '--session', INVOICES.id)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  await $.session.start(CONVERSATION)
  expect((await cli('answer', 'k3', 'Approve')).exit).toBe(EXIT.done)
  await w.clock.advance(TAKE_IN)

  expect(w.prompts, 'no window holds it').toEqual([])
  expect(await replyIn(cli)).toMatchObject({ asks: [{ is: 'onItsWay' }] })

  await w.call('join', { session: INVOICES.id })
  await w.clock.advance(TAKE_IN)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    `From the board:\n- Review the ledger schema → Approve${CLOSES}`,
  ])
  expect(parseEntries(w.text(ledger.paths.log(W1))).at(-1)).toMatchObject({ type: 'delivered' })
  expect(await replyIn(cli)).toMatchObject({ asks: [], resolved: [{ is: 'delivered' }] })
})
