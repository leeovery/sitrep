import { expect, test, tier } from './kit'
import { parseEntries, sessionPaths, SNOOZE_DEFAULTS, snoozeFile } from '../core'
import { AROUND_MS } from '../hooks/around'
import { isShowing, SENT_LINGER_MS } from '../hooks/queue'
import { readyRows, rowsOf } from './drawn'
import {
  CLI,
  CLOSES,
  keyed,
  LEDGER,
  META,
  MIN,
  PROJECT,
  REVIEW,
  ROOT,
  SENDER,
  T0,
  THEMES,
  W1,
  W3,
} from './data'
import { delivered, file, finish, fold, reopen, reply, resolve, unfinish, yesAsk } from './lines'
import {
  asked,
  INLINE,
  pressYes,
  toProject,
  world,
  type Board,
  type World,
} from './world'

tier('user')

/** The ledger's inbox file this window writes. */
const LETTERS = sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W1)

/** Themes' inbox file this window writes. */
const THEME_LETTERS = sessionPaths(ROOT, PROJECT.key, THEMES.id).letters(W1)

/**
 * This session with an ask, beside two others of its project: the ledger,
 * open in another window, and Themes, with no window; each with an ask.
 * A minute on, Lee opens the board: a reply is never written in the same
 * moment as the ask it answers.
 */
async function threeSessions(w: World) {
  const ledger = w.elsewhere(LEDGER)
  const themes = w.elsewhere(THEMES)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  themes.write(yesAsk('k4', 'Pick the dark palette', 'Done'))

  const { paths } = await w.begin()
  const posted = await asked(w, REVIEW)

  await w.clock.advance(MIN)
  ledger.beat()

  return { ledger, themes, paths, posted, ui: await w.opened() }
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
  const { posted, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })

  const groups = (await ui.findAll({ type: 'Text' }))
    .map(each => each.text)
    .filter(text => text.startsWith('to '))

  expect(groups).toEqual(['to this session', 'to Invoice ledger'])
  expect(await ui.find({ type: 'Text', text: /^\d+ repl/ })).toMatchObject({ text: '2 replies' })

  for (const way of ['tab:session', 'tab:all', `proj:${PROJECT.key}`]) {
    await ui.press({ key: way })

    const box = await readyRows(ui)
    const view = rowsOf(await ui.find({ type: 'Box' })).map(row => row.trim())

    expect(box[0], way).toMatch(/^READY TO SEND/)
    expect(view.slice(-box.length), `${way}: at the foot`).toEqual(box)
  }
})

test("send writes another session's replies into its inbox as this window's letters, and they leave the queue", async ($, on) => {
  const w = world($, on)
  const { posted, paths, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })
  await ui.press({ key: 'send' })

  const [letter] = repliesIn(w, LETTERS)

  expect(letter).toMatchObject({ item: 'k3', verdict: 'yes', seq: 1 })
  expect(w.state.queue).toEqual([])
  expect(w.state.sent).toEqual([
    { project: PROJECT.key, session: LEDGER.id, replies: [letter?.id] },
  ])
  expect(w.toasts).toContain('Sent 1 reply to Invoice ledger.')
  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
  ])
  expect(
    parseEntries(w.text(paths.log(W1))).map(line => line.type),
    'only this session’s reply is written to its own file',
  ).toEqual(['ask', 'reply', 'delivered'])
})

test('a send of replies to other sessions only closes an inline board, once they are in their inboxes', async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
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
  await answer(ui, LEDGER.id, 'k3')
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

  await answer(ui, LEDGER.id, 'k3')
  await answer(ui, THEMES.id, 'k4')
  await ui.press({ key: 'send' })

  expect(w.toasts).toContain('Sent 1 reply to Invoice ledger and 1 reply to Themes.')
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
  expect(await ui.find({ type: 'Text', text: 'to Invoice ledger' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: 'to Themes' })).toBeDefined()
  expect(w.state.sent?.map(each => each.session)).toEqual([THEMES.id])
})

test('replies sent into an inbox show where they went until the linger has passed since the last of them went in or went void, and not a moment longer', () => {
  const deliveredAt = T0 + 2 * MIN
  const settledAt = T0 + 3 * MIN
  const session = fold({
    logs: {
      [W1]: file(
        [T0, yesAsk('k1', 'Review round 1')],
        [T0, yesAsk('k2', 'Review round 2')],
        [deliveredAt, delivered('r1')],
        [settledAt, resolve('k2')],
      ),
    },
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, reply('r2', 'k2', 'yes')]),
    },
  })
  const sent = { project: keyed(META.project), session: META.id, replies: ['r1', 'r2'] }

  expect(session.replies.map(each => [each.delivery, each.deliveredAt ?? each.voidedAt])).toEqual([
    ['delivered', deliveredAt],
    ['void', settledAt],
  ])

  expect(isShowing(session, sent, settledAt + SENT_LINGER_MS - 1)).toBe(true)
  expect(isShowing(session, sent, settledAt + SENT_LINGER_MS)).toBe(false)
})

test("an ask whose reply went into its session's inbox waits on Lee no more: the band, the tab and the project count it nowhere", async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  expect(await (await w.band()).find({ key: 'band:elsewhere', text: '2 elsewhere' })).toBeDefined()

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })

  expect(await (await w.band()).find({ key: 'band:elsewhere', text: '1 elsewhere' })).toBeDefined()
  expect(rowsOf(await ui.find({ key: 'tab:all:box' }))).toEqual([' ≡ All projects 2'])

  await toProject(ui)

  expect(await ui.find({ type: 'Text', text: '2 waiting on you' })).toBeDefined()
  expect(
    await ui.find({
      key: `pick:${LEDGER.id}:k3`,
      text: 'Invoice ledger: Review the ledger schema',
    }),
    'its ask still shows',
  ).toBeDefined()
})

test("the destination's own view shows the ask's reply on its way, and offers no second answer", async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })
  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })

  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  expect(await ui.find({ key: `yes:${LEDGER.id}:k3` })).toBeUndefined()
})

test('a reply to another session whose item changed since is left in Ready to send, unsent', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  ledger.write({
    type: 'edit',
    item: 'k3',
    changes: { wants: 'choice', options: ['Now', 'Later'] },
  })
  await ui.press({ key: 'send' })

  expect(w.files.has(LETTERS)).toBe(false)
  expect(w.state.queue).toMatchObject([{ session: LEDGER.id, item: 'k3' }])
  expect(w.toasts).toContain(
    'Nothing to send: the items replied to have changed since. Your replies are still on the board.',
  )
})

test('two quick presses of send write each letter once', async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await Promise.all([ui.press({ key: 'send' }), ui.press({ key: 'send' })])

  expect(repliesIn(w, LETTERS)).toHaveLength(1)
  expect(w.state.sent).toMatchObject([
    { session: LEDGER.id, replies: [repliesIn(w, LETTERS)[0]?.id] },
  ])
  expect(w.toasts.filter(toast => toast.startsWith('Sent'))).toEqual([
    'Sent 1 reply to Invoice ledger.',
  ])
})

test('a sent reply whose item changed before it went in shows there as not delivered, offers its item again, and lingers out', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
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
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  expect(await ui.find({ key: `choose:${LEDGER.id}:k3:0` })).toBeDefined()

  await w.clock.advance(SENT_LINGER_MS)
  expect(await ui.find({ type: 'Text', text: 'to Invoice ledger' })).toBeUndefined()
  expect(w.state.sent).toEqual([])
})

test('a snooze.json whose time is no text still lets each look settle what was sent, the pane offering the defaults', async ($, on) => {
  const w = world($, on)

  w.put(snoozeFile(ROOT), '{"v":1,"tonight":{"on":true,"at":{"toString":0}}}')

  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })
  ledger.write({ type: 'edit', item: 'k3', changes: { wants: 'choice', options: ['Now', 'Later'] } })
  ledger.beat()
  await w.clock.advance(AROUND_MS)
  expect(w.state.sent).toHaveLength(1)

  await w.clock.advance(SENT_LINGER_MS)
  expect(w.state.sent).toEqual([])
  expect(w.state.snooze).toEqual(SNOOZE_DEFAULTS)
})

test("a reply queued to another session's ask that Lee answered from elsewhere first, or that Claude closed, is not sent: Ready to send keeps it, saying why, and offers no send while nothing would go", async ($, on) => {
  const w = world($, on)
  const { themes, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await answer(ui, THEMES.id, 'k4')
  w.put(
    sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(CLI),
    file([w.clock.now(), reply('r9', 'k3', 'yes')]),
  )
  themes.write(resolve('k4'))
  await w.clock.advance(AROUND_MS)

  expect(await ui.find({ type: 'Text', text: '· not sent: already answered' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· not sent: Claude closed it' })).toBeDefined()

  expect(await ui.find({ key: 'send' })).toBeUndefined()
  expect(w.state.queue).toMatchObject([
    { session: LEDGER.id, item: 'k3' },
    { session: THEMES.id, item: 'k4' },
  ])
})

test("another window's comment on its way to an ask takes it off Lee's counts but bars no answer: the ask still offers its buttons, and Lee's yes to it is sent", async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)

  w.put(
    sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W3),
    file([w.clock.now(), reply('r9', 'k3', 'comment', { note: 'Tighten the schema first' })]),
  )
  await w.clock.advance(AROUND_MS)

  expect(await (await w.band()).find({ key: 'band:elsewhere', text: '1 elsewhere' })).toBeDefined()
  expect(rowsOf(await ui.find({ key: 'tab:all:box' }))).toEqual([' ≡ All projects 2'])

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })

  expect(await ui.find({ type: 'Text', text: '· on its way' }), 'the comment').toBeDefined()
  expect(await ui.find({ key: `yes:${LEDGER.id}:k3` })).toBeDefined()

  await answer(ui, LEDGER.id, 'k3')

  expect(await ui.find({ type: 'Text', text: /not sent:/ })).toBeUndefined()

  await ui.press({ key: 'send' })

  expect(repliesIn(w, LETTERS)).toMatchObject([{ item: 'k3', verdict: 'yes' }])
  expect(w.state.queue).toEqual([])
})

test("a comment queued to another session's ask is sent though Lee's answer to it from elsewhere is on its way: an answer bars no comment", async ($, on) => {
  const w = world($, on)
  const { ui } = await threeSessions(w)
  const words = 'Tighten the schema first'

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  await ui.press({ key: `comment:${LEDGER.id}:k3` })
  w.box.text = words
  await $.prompt.submit({ text: words, wait: false, origin: { kind: 'composer' } })
  w.put(
    sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(CLI),
    file([w.clock.now(), reply('r9', 'k3', 'yes')]),
  )
  await w.clock.advance(AROUND_MS)

  expect(await ui.find({ type: 'Text', text: /not sent:/ })).toBeUndefined()

  await ui.press({ key: 'send' })

  expect(repliesIn(w, LETTERS)).toMatchObject([{ item: 'k3', verdict: 'comment', note: words }])
})

test('a sent reply whose session was finished before it went in shows there as not delivered, saying so', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })
  await w.clock.advance(MIN)
  ledger.write(finish('lee'))
  await w.clock.advance(AROUND_MS)

  expect(
    await ui.find({ type: 'Text', text: '· not delivered: the session was finished' }),
  ).toBeDefined()
})

test('a sent reply Claude was given though its ask changed under it first shows there as delivered, saying it changed since', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })

  const [letter] = repliesIn(w, LETTERS)

  ledger.write({
    type: 'edit',
    item: 'k3',
    changes: { wants: 'choice', options: ['Now', 'Later'] },
  })
  ledger.write(delivered(letter?.id ?? ''))
  await w.clock.advance(AROUND_MS)

  expect(await ui.find({ type: 'Text', text: '✓ delivered' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: '· delivered just now, but it changed since' }),
  ).toBeDefined()
})

test('a sent reply Claude was given only after its ask was closed and reopened shows there as delivered, saying it was reopened since', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })

  const [letter] = repliesIn(w, LETTERS)

  await w.clock.advance(MIN)
  ledger.write(resolve('k3'))
  await w.clock.advance(MIN)
  ledger.write(reopen('k3'))
  ledger.write(delivered(letter?.id ?? ''))
  await w.clock.advance(AROUND_MS)

  expect(await ui.find({ type: 'Text', text: '✓ delivered' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: '· delivered just now, but it was reopened since' }),
  ).toBeDefined()
})

test("a sent reply void as Lee's other answer went in first, marked only once its ask reopened, says it was reopened since", async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })

  const [ours] = repliesIn(w, LETTERS)

  w.put(
    sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W3),
    file([(ours?.at ?? 0) - 1, reply('r9', 'k3', 'yes')]),
  )
  ledger.write(delivered('r9'))
  ledger.write(reopen('k3'))
  ledger.write(delivered(ours?.id ?? ''))
  await w.clock.advance(AROUND_MS)

  expect(
    await ui.find({ type: 'Text', text: '· delivered just now, but it was reopened since' }),
  ).toBeDefined()
})

test('a sent reply void as its session was finished, marked only once its ask was closed and reopened, says it was reopened since', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })

  const [ours] = repliesIn(w, LETTERS)

  ledger.write(finish('lee'))
  ledger.write(unfinish())
  ledger.write(resolve('k3'))
  ledger.write(reopen('k3'))
  ledger.write(delivered(ours?.id ?? ''))
  await w.clock.advance(AROUND_MS)

  expect(
    await ui.find({ type: 'Text', text: '· delivered just now, but it was reopened since' }),
  ).toBeDefined()
})

test('a send that carries nothing, some of its replies changed under them and others answered first, says both', async ($, on) => {
  const w = world($, on)
  const { ledger, themes, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await answer(ui, THEMES.id, 'k4')
  ledger.write({
    type: 'edit',
    item: 'k3',
    changes: { wants: 'choice', options: ['Now', 'Later'] },
  })
  themes.write(resolve('k4'))
  await ui.press({ key: 'send' })

  expect(w.toasts).toContain(
    'Nothing to send: the items replied to have changed since, or are answered or closed already. Your replies are still on the board.',
  )
})

test("a sent reply that reached its ask after another of Lee's answers, or whose ask Claude closed before it went in, shows there as not delivered, saying which", async ($, on) => {
  const w = world($, on)
  const { themes, ui } = await threeSessions(w)

  await answer(ui, LEDGER.id, 'k3')
  await answer(ui, THEMES.id, 'k4')
  await ui.press({ key: 'send' })

  const [ours] = repliesIn(w, LETTERS)

  w.put(
    sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W3),
    file([(ours?.at ?? 0) - 1, reply('r9', 'k3', 'yes', { note: 'From the other window' })]),
  )
  await w.clock.advance(MIN)
  themes.write(resolve('k4'))
  await w.clock.advance(AROUND_MS)

  expect(await ui.findAll({ type: 'Text', text: '✕ not delivered' })).toHaveLength(2)
  expect(await ui.find({ type: 'Text', text: '· not delivered: already answered' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· not delivered: Claude closed it' })).toBeDefined()
})

test("a send of letters alone, pressed while Lee has stopped Claude's turn, carries the send held for this session on from the press", async ($, on) => {
  const w = world($, on)
  const { posted, paths, ui } = await threeSessions(w)
  const own = `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`

  await pressYes(ui, w.item(posted))
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  w.dropPrompts('the session was stopped and nobody has sent input since')
  await w.turnEnds({ isAborted: true })
  await w.clock.settle()

  expect(w.state.stopped).toBe(true)

  w.dropPrompts()
  await answer(ui, LEDGER.id, 'k3')
  await ui.press({ key: 'send' })
  await w.clock.settle()

  expect(repliesIn(w, LETTERS)).toMatchObject([{ item: 'k3', verdict: 'yes' }])
  expect(w.submitted).toEqual([own, own])
  expect(w.state.stopped).toBe(false)
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.type)).toEqual([
    'ask',
    'reply',
    'delivered',
  ])
})
