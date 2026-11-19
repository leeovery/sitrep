/**
 * Lee's drop of a parked item from the board (DESIGN.md, "Dropping a parked
 * item"): asked first, in place, and written at once in the session that
 * parked it, in this window's own file there, nothing sent to Claude, who
 * reads the item gone from the board.
 */
import { expect, test, tier, type Engine } from './kit'
import { CURRENT_MS, sessionPaths, type SessionMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import {
  CLOSES,
  ELSEWHERE,
  HOME,
  LEDGER,
  MIN,
  PROJECT,
  REVIEW,
  ROOT,
  SHIFTS,
  T0,
  W1,
  W2,
  W4,
} from './data'
import { rowsOf } from './drawn'
import { pane, sceneFrom } from './render'
import { delivered, drop, file, finish, moveTo, park, reply, resolve, type Line } from './lines'
import {
  asked,
  CONVERSATION,
  kindsIn,
  postedId,
  PROMPT,
  toProject,
  world,
  type Board,
  type World,
} from './world'

tier('user')

/** What this session parks. */
const BADGE = 'A priority badge across all tabs'

/** What the ledger, another session of Northwind's, parked. */
const EXPORT = 'Export the ledger as CSV'

/** What the drop asks in place of an item's buttons. */
const QUESTION = '  Drop it? It leaves Parked, and Claude no longer sees it.'

/** The drop's question's answers, as drawn. */
const ANSWERS = '  [ yes, drop it ] [ cancel ]'

/** An opened parked item's buttons, as drawn in a window of its project. */
const BUTTONS = '  [ pick it up ] [ ✎ with a comment ] [ ✕ drop ]'

/** What heads the board's text where it rides into a turn. */
const CHANGED = 'The sitrep board changed since you last saw it. It now reads:'

/** The press opening a project's picked up, which its own view and each of its sessions' draw. */
const PICKED_UP = `pickedup:project:${PROJECT.key}`

/** Long enough ago that a session idle since is past the views. */
const OLD = T0 - CURRENT_MS - MIN

/** The ledger's file this window writes. */
const LEDGER_LOG = sessionPaths(ROOT, PROJECT.key, LEDGER.id).log(W1)

/** The ledger's own file, which its window writes. */
const LEDGER_OWN = sessionPaths(ROOT, PROJECT.key, LEDGER.id).log(W2)

/** The ledger's inbox file this window writes. */
const LETTERS = sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W1)

/** The ledger's parked item, by its address. */
const LEDGERS = `${LEDGER.id}:p1`

/** The rows a parked item is drawn on, by its address. */
const parkedRows = async (ui: Board, key: string) => rowsOf(await ui.find({ key: `parked:${key}` }))

/** The rows an item taken off Parked is drawn on, opened, by its address, once the project's picked up is shown. */
const takenRows = async (ui: Board, key: string) => {
  await ui.press({ key: PICKED_UP })
  await ui.press({ key: `picked:${key}` })

  return rowsOf(await ui.find({ key: `taken:${key}` }))
}

/** Lee asks to drop the parked item at `key`, opening it first. */
const asking = async (ui: Board, key: string) => {
  await ui.press({ key: `ppick:${key}` })
  await ui.press({ key: `drop:${key}` })
}

/** Lee drops the parked item at `key`, opening it, then saying yes. */
const dropping = async (ui: Board, key: string) => {
  await asking(ui, key)
  await ui.press({ key: `drop-yes:${key}` })
}

/** The board's messages to Claude, as submitted. */
const fromTheBoard = (w: World) => w.submitted.filter(text => text.startsWith('From the board:'))

/** The context the next prompt takes, if any. */
const contextOf = async ($: Engine) => (await $.prompt.submit(PROMPT)).context?.[0]

/** This session begun, `titles` parked, and the board opened: the session, the parked items' ids, and the board. */
async function parked(w: World, ...titles: string[]) {
  const begun = await w.begin()
  const ids: string[] = []

  for (const title of titles) {
    ids.push(postedId(await w.call('park', { title })))
  }

  return { ...begun, ids, ui: await w.opened() }
}

test("an opened parked item's ✕ drop asks first, in place of its buttons, the item opened still; cancel goes back to the buttons, writing nothing", async ($, on) => {
  const w = world($, on)
  const { ids, paths, ui } = await parked(w, BADGE)
  const key = w.item(ids[0] ?? '')

  await ui.press({ key: `ppick:${key}` })
  expect((await parkedRows(ui, key)).at(-1)).toBe(BUTTONS)
  expect((await ui.find({ key: `drop:${key}` }))?.props.dimColor, 'dim after the pick-ups').toBe(
    true,
  )

  await ui.press({ key: `drop:${key}` })
  expect(await parkedRows(ui, key)).toEqual([
    expect.stringMatching(/^● A priority badge across all tabs/),
    QUESTION,
    ANSWERS,
  ])
  expect(
    await ui.find({ key: `pickup:${key}` }),
    'no pick-up beside the question',
  ).toBeUndefined()

  await ui.press({ key: `drop-no:${key}` })
  expect((await parkedRows(ui, key)).at(-1)).toBe(BUTTONS)
  expect(w.state.pane?.selected, 'opened still').toBe(key)
  expect(kindsIn(w, paths.log(W1))).toEqual(['park'])
})

test("the drop's question goes as Lee moves away, writing nothing: the item's title closes it, and opening another item, going elsewhere or closing the board ends it", async ($, on) => {
  const w = world($, on)
  const { ids, paths, ui } = await parked(w, BADGE, EXPORT)
  const [first, second] = ids.map(id => w.item(id))
  const isAsking = async () =>
    (await ui.find({ type: 'Text', text: QUESTION.trim() })) !== undefined

  await asking(ui, first ?? '')
  await ui.press({ key: `ppick:${first}` })
  expect(w.state.pane?.selected, 'the title closes the item').toBeNull()

  await asking(ui, first ?? '')
  await ui.press({ key: `ppick:${second}` })
  expect(w.state.pane?.selected, 'another item opened').toBe(second)
  expect(await isAsking()).toBe(false)

  await ui.press({ key: `drop:${second}` })
  await toProject(ui)
  await ui.press({ key: 'tab:session' })
  expect(await isAsking(), 'gone elsewhere and back').toBe(false)

  await asking(ui, second ?? '')
  await (await w.band()).press({ key: 'band:board' })
  expect(w.state.pane?.selected, 'the board closed').toBeNull()
  expect(kindsIn(w, paths.log(W1))).toEqual(['park', 'park'])
})

test("yes drops this session's own item at once, through the hold: it leaves Parked for its picked up, dropped by you, nothing goes to Claude or to Ready to send, and Claude's board reads it gone", async ($, on) => {
  const w = world($, on)
  const { ids, paths, ui } = await parked(w, BADGE)
  const key = w.item(ids[0] ?? '')

  await dropping(ui, key)

  expect(kindsIn(w, paths.log(W1))).toEqual(['park', 'drop'])
  expect(w.state.board?.items.find(each => each.id === ids[0])).toMatchObject({
    state: 'dropped',
    closedBy: 'drop',
  })
  expect(fromTheBoard(w), 'nothing to Claude').toEqual([])
  expect(w.state.queue ?? [], 'nothing in Ready to send').toEqual([])
  expect(w.state.pane?.selected).toBeNull()
  expect(await ui.find({ type: 'Text', text: 'nothing to come back to' })).toBeDefined()
  expect(await ui.find({ key: PICKED_UP, text: 'show picked up 1' })).toBeDefined()
  expect(await takenRows(ui, key)).toEqual([
    '✓ A priority badge across all tabs · dropped by now',
    '│ you',
    '└ nothing more was recorded',
  ])

  const context = await contextOf($)

  expect(context).toStartWith(CHANGED)
  expect(context).toContain('Parked:\n- none')
  expect(String((await w.call('board')).result)).not.toContain(BADGE)
})

/** A session of the project's, started long ago, its meta naming the project by its name. */
const longAgo = (session: SessionMeta): SessionMeta => ({
  ...session,
  project: PROJECT.name,
  created: OLD,
})

/** The ledger as it stands once it parked something: its lines, and whether a window holds it. */
type Standing = { lines: Line[]; isOpen: boolean }

const OPEN: Standing = { lines: [[T0, park('p1', EXPORT)]], isOpen: true }

const STANDING: Record<string, Standing> = {
  'a session open in another window': OPEN,
  'a finished session': {
    lines: [
      [T0, park('p1', EXPORT)],
      [T0, finish('claude', 'Shipped')],
    ],
    isOpen: false,
  },
  'a session idle past the views': { lines: [[OLD, park('p1', EXPORT)]], isOpen: false },
}

/** This session beside the ledger, its lines `lines`, held by another window where `isOpen`: a minute on, Lee opens the board. */
async function besideLedger(w: World, { lines, isOpen }: Standing) {
  const ledger = w.elsewhere(longAgo(LEDGER))

  w.put(ledger.paths.log(W2), file(...lines))

  const { id, paths } = await w.begin()

  await w.clock.advance(MIN)

  if (isOpen) {
    ledger.beat()
  }

  return { id, paths, ui: await w.opened() }
}

/** The sessions the project's view lists, by their presses. */
const sessionsListed = async (ui: Board) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => String(each.key))
    .filter(key => key.startsWith('go:'))

for (const [standing, ledger] of Object.entries(STANDING)) {
  test(`a drop of what ${standing} parked is written in that session, in this window's own file there: nothing to Claude, nothing in its inbox, no session brought back, and Claude's board reads it gone`, async ($, on) => {
    const w = world($, on)
    const { id, paths, ui } = await besideLedger(w, ledger)

    expect(await contextOf($), 'Claude told of the item').toContain(
      'p1, parked by "Invoice ledger"',
    )

    await toProject(ui)
    await dropping(ui, LEDGERS)

    expect(kindsIn(w, LEDGER_LOG)).toEqual(['drop'])
    expect(w.files.has(LETTERS), 'nothing in its inbox').toBe(false)
    expect(w.files.has(paths.log(W1)), 'nothing written in this session').toBe(false)
    expect(fromTheBoard(w), 'nothing to Claude').toEqual([])
    expect(w.state.queue ?? []).toEqual([])
    expect(await ui.find({ type: 'Text', text: 'nothing to come back to' })).toBeDefined()
    expect(await takenRows(ui, LEDGERS)).toEqual([
      '✓ Invoice ledger: Export the ledger as CSV · now',
      '│ dropped by you',
      '└ nothing more was recorded',
    ])
    expect(await sessionsListed(ui), 'the drop brings no session back onto the board').toEqual(
      ledger.isOpen ? [`go:${id}`, `go:${LEDGER.id}`] : [`go:${id}`],
    )

    const context = await contextOf($)

    expect(context).toStartWith(CHANGED)
    expect(context).toContain('Parked:\n- none')
    expect(String((await w.call('board')).result)).not.toContain(EXPORT)
  })
}

test("this session's own view drops what another session parked, from under from other sessions, as the project's view does", async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)

  await dropping(ui, LEDGERS)

  expect(kindsIn(w, LEDGER_LOG)).toEqual(['drop'])
  expect(w.state.pane?.place ?? null, 'dropped from home').toBeNull()
  expect(await ui.find({ type: 'Text', text: 'from other sessions' })).toBeUndefined()
  expect(await ui.find({ key: PICKED_UP, text: 'show picked up 1' })).toBeDefined()
})

test("a drop of what a session moved here from another project parked is written in the folder it was started in, in this window's own file there", async ($, on) => {
  const w = world($, on)
  const shifts = w.elsewhere(SHIFTS, ELSEWHERE.key)
  const ledger = w.elsewhere(LEDGER)

  w.project(ELSEWHERE.key, {
    name: ELSEWHERE.name,
    directory: `${HOME}/Code/contoso`,
    created: T0,
    by: W4,
  })
  shifts.write(park('p9', 'Export the rota'))
  ledger.write(park('p1', EXPORT), moveTo(ELSEWHERE.key))
  await $.session.start(CONVERSATION)
  await w.call('start', { name: 'Rota', summary: 'The rota, week by week', project: 'Contoso' })
  await w.clock.advance(MIN)

  const ui = await w.opened()

  await dropping(ui, LEDGERS)

  const moved = (project: string) =>
    [...w.files.keys()].filter(path =>
      path.startsWith(`${ROOT}/projects/${project}/sessions/${LEDGER.id}/`),
    )

  expect(kindsIn(w, LEDGER_LOG), "in Northwind's folder, where it was started").toEqual(['drop'])
  expect(moved(ELSEWHERE.key), "nothing in Contoso's").toEqual([])
  expect(await ui.find({ key: `parked:${LEDGERS}` })).toBeUndefined()
  expect(await ui.find({ key: `parked:${SHIFTS.id}:p9` }), "the rest of Contoso's").toBeDefined()
})

test('a drop pressed on an item picked up a moment before, from another window, writes nothing, a toast saying why', async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)

  await toProject(ui)
  await asking(ui, LEDGERS)
  w.put(
    LEDGER_OWN,
    file(
      ...OPEN.lines,
      [w.clock.now(), reply('r1', 'p1', 'pickup', { to: LEDGER.id })],
      [w.clock.now(), delivered('r1')],
    ),
  )
  await ui.press({ key: `drop-yes:${LEDGERS}` })

  expect(w.toasts).toContain('Not dropped: it was picked up already.')
  expect(w.files.has(LEDGER_LOG), 'nothing written').toBe(false)
  expect(await takenRows(ui, LEDGERS)).toEqual([
    '✓ Invoice ledger: Export the ledger as CSV · now',
    '│ picked up by Invoice ledger',
    '└ nothing more was recorded',
  ])
})

test('a pick-up waiting in Ready to send of an item Lee dropped from another window stays there, saying so, with no send for it', async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)

  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGERS}` })
  await ui.press({ key: `pickup:${LEDGERS}` })
  w.put(LEDGER_OWN, file(...OPEN.lines, [w.clock.now(), drop('p1')]))
  await w.clock.advance(AROUND_MS)

  expect(rowsOf(await ui.find({ key: `readyanswer:${LEDGERS}` }))).toEqual([
    '└ pick it up · not sent: you dropped it',
  ])
  expect(await ui.find({ key: 'send' }), 'no send for it alone').toBeUndefined()
  expect(fromTheBoard(w), 'nothing to Claude').toEqual([])
})

test("Claude's resolve of an item Lee dropped passes quietly, writing nothing; its reopen brings the item back to Parked, where Claude's board lists it again", async ($, on) => {
  const w = world($, on)
  const { ids, paths, ui } = await parked(w, BADGE)
  const id = ids[0] ?? ''

  await dropping(ui, w.item(id))

  expect((await w.call('resolve', { item: id, reason: 'Done' })).result).toBe(
    `${id} was dropped already by the user: nothing to resolve.`,
  )
  expect(kindsIn(w, paths.log(W1))).toEqual(['park', 'drop'])

  expect((await w.call('reopen', { item: id, reason: 'The user wants it back' })).result).toBe(
    `Reopened ${id}.`,
  )
  expect(await parkedRows(ui, w.item(id))).toEqual([
    expect.stringMatching(/^● A priority badge across all tabs/),
  ])
  expect(await ui.find({ key: PICKED_UP })).toBeUndefined()
  expect(String((await w.call('board')).result)).toContain(`- ${id}: ${BADGE}`)
})

/** Lee picks up the ledger's parked item from the project's view, then goes home. */
const pickUpLedgers = async (ui: Board) => {
  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGERS}` })
  await ui.press({ key: `pickup:${LEDGERS}` })
  await ui.press({ key: 'tab:session' })
}

/** The ledger's export as Ready to send draws its pick-up. */
const readyExport = async (ui: Board) =>
  rowsOf(await ui.find({ key: `readyanswer:${LEDGERS}` }))

test("a send held for Claude's turn goes without a pick-up of another session's item Lee dropped meanwhile, from another window: Ready to send keeps it, saying so, and Claude has the rest", async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)
  const posted = await asked(w, REVIEW)

  await pickUpLedgers(ui)
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  w.put(LEDGER_OWN, file(...OPEN.lines, [w.clock.now(), drop('p1')]))
  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([
    `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
  ])
  expect(w.files.has(LEDGER_LOG), 'no pick-up written down').toBe(false)
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER.id, item: 'p1', verdict: 'pickup' },
  ])
  await w.clock.advance(AROUND_MS)
  expect(await readyExport(ui), 'at the next look').toEqual([
    '└ pick it up · not sent: you dropped it',
  ])
})

test("a send held for Claude's turn carrying only a pick-up whose item Claude closed meanwhile is let go, nothing submitted: Ready to send keeps it, saying so", async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)

  await pickUpLedgers(ui)
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  w.put(LEDGER_OWN, file(...OPEN.lines, [w.clock.now(), resolve('p1', 'Done elsewhere')]))
  await w.turnEnds()
  await w.clock.settle()

  expect(fromTheBoard(w), 'nothing to Claude').toEqual([])
  expect(w.state.inFlight ?? [], 'let go').toEqual([])
  expect(w.files.has(LEDGER_LOG)).toBe(false)
  await w.clock.advance(AROUND_MS)
  expect(await readyExport(ui), 'at the next look').toEqual([
    '└ pick it up · not sent: Claude closed it',
  ])
})

test('a send pressed as a pick-up\'s item is dropped from another window, before the look reads it, carries nothing, and says why', async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)

  await pickUpLedgers(ui)
  w.put(LEDGER_OWN, file(...OPEN.lines, [w.clock.now(), drop('p1')]))
  await ui.press({ key: 'send' })

  expect(fromTheBoard(w), 'nothing to Claude').toEqual([])
  expect(w.toasts).toContain(
    'Nothing to send: the items replied to are answered or closed already. Your replies are still on the board.',
  )
})

test("a reply sent into a session's inbox, from an older build, whose item Lee dropped before it went in, shows in Ready to send as not delivered, saying so", async () => {
  const ui = pane(
    sceneFrom({
      now: T0 + 3 * MIN,
      around: [
        {
          meta: LEDGER,
          lines: [
            [T0, park('p1', EXPORT)],
            [T0 + MIN, reply('r1', 'p1', 'pickup')],
            [T0 + 2 * MIN, drop('p1')],
          ],
        },
      ],
      sent: [{ project: PROJECT.key, session: LEDGER.id, replies: ['r1'] }],
    }),
  )

  expect(await ui.find({ type: 'Text', text: '· not delivered: you dropped it' })).toBeDefined()
})

test("a held send let go, its only pick-up's item dropped meanwhile, gives its place to the send held behind it, which goes as the same turn ends", async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)
  const posted = await asked(w, REVIEW)

  await pickUpLedgers(ui)
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })
  await ui.press({ key: 'send' })
  expect(w.flights().map(each => each.isHeld), 'both held').toEqual([true, true])

  w.put(LEDGER_OWN, file(...OPEN.lines, [w.clock.now(), drop('p1')]))
  await w.turnEnds()

  expect(w.submitted).toEqual([
    `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
  ])
  expect(w.flights().map(each => each.isHeld), 'the second, on its way').toEqual([false])
})

test("a send held for Claude's turn goes without a pick-up whose item another window picked up meanwhile", async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)

  await pickUpLedgers(ui)
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  w.put(
    sessionPaths(ROOT, PROJECT.key, LEDGER.id).log(W4),
    file([w.clock.now(), reply('r9', 'p1', 'pickup')], [w.clock.now(), delivered('r9')]),
  )
  await w.turnEnds()
  await w.clock.settle()

  expect(fromTheBoard(w), 'nothing to Claude').toEqual([])
  expect(w.flights(), 'let go').toEqual([])
  expect(w.files.has(LEDGER_LOG)).toBe(false)
})

test("a send held for Claude's turn goes without a pick-up of the held session's own item Claude closed meanwhile, as of another session's", async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await parked(w, BADGE)
  const id = ids[0] ?? ''

  await ui.press({ key: `ppick:${w.item(id)}` })
  await ui.press({ key: `pickup:${w.item(id)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await w.call('resolve', { item: id, reason: 'Done already' })
  await w.turnEnds()
  await w.clock.settle()

  expect(fromTheBoard(w), 'nothing to Claude').toEqual([])
  expect(w.flights(), 'let go').toEqual([])
})
