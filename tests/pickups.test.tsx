import { expect, test, tier, type Engine } from './kit'
import {
  CURRENT_MS,
  parseEntries,
  parsePresence,
  sessionPaths,
  sessionsDir,
  type SessionMeta,
} from '../core'
import type { SitrepInFlight } from '../types'
import { WATCH_MS } from '../hooks/window'
import {
  CLOSES,
  ELSEWHERE,
  LEDGER,
  MIN,
  PROJECT,
  REVIEW,
  ROOT,
  SHIFTS,
  T0,
  THEMES,
  W1,
  W2,
  W3,
} from './data'
import { delivered, file, finish, park, reply, yesAsk, type Line } from './lines'
import { rowsOf } from './drawn'
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

/** The parked items, and the note each is picked up with, if any. */
const PARKED = [
  { title: 'A priority badge across all tabs' },
  { title: 'Thumbnails inline in the gallery', note: 'Before the release' },
  { title: 'Sign-in without the redirect', note: 'After the API fixes' },
]

/** A session parking each item, the board opened docked, and each picked up, its note written in the prompt: the parked ids and the board. */
async function pickedUp(w: World, $: Engine) {
  await w.begin()

  const ids: string[] = []

  for (const { title } of PARKED) {
    ids.push(postedId(await w.call('park', { title })))
  }

  const ui = await w.opened()

  for (const [i, id] of ids.entries()) {
    const note = PARKED[i]?.note

    await ui.press({ key: `ppick:${w.item(id)}` })

    if (note === undefined) {
      await ui.press({ key: `pickup:${w.item(id)}` })
    } else {
      await ui.press({ key: `pickup:${w.item(id)}` })
      await ui.press({ key: `rewrite:${w.item(id)}` })
      await $.prompt.submit({ text: note, wait: false, origin: { kind: 'composer' } })
    }
  }

  return { ids, ui }
}

/** The keys Parked's picked up opens its items by, in order, once it is opened. */
const pickUpRows = async (ui: Board) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => String(each.key))
    .filter(key => key.startsWith('picked:'))

/** The press opening a project's picked up, which its own view and each of its sessions' draw. */
const PICKED_UP = `pickedup:project:${PROJECT.key}`

test('a send of several pick-ups, some with notes, draws the docked board before, during and after the turn', async ($, on) => {
  const w = world($, on)
  const { ui } = await pickedUp(w, $)

  await expect(ui.drawn(), 'the pick-ups waiting').resolves.toBeDefined()

  await ui.press({ key: 'send' })

  await expect(ui.drawn(), 'sent').resolves.toBeDefined()
  await ui.press({ key: PICKED_UP })
  expect(new Set(await pickUpRows(ui)).size).toBe(PARKED.length)

  await w.turnStarts(w.prompts.at(-1)?.text ?? '')
  await expect(ui.drawn(), "during Claude's turn").resolves.toBeDefined()

  await w.turnEnds()
  await expect(ui.drawn(), 'after the turn').resolves.toBeDefined()
  expect(await ui.find({ key: 'tab:session' }), 'the header with the rest').toBeDefined()
  expect(new Set(await pickUpRows(ui)).size).toBe(PARKED.length)
})

test('opening one item a send picked up opens only that one', async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await pickedUp(w, $)

  await ui.press({ key: 'send' })
  await ui.press({ key: PICKED_UP })
  await ui.press({ key: `picked:${w.item(ids[1] ?? '')}` })

  expect(await ui.find({ type: 'Text', text: /Before the release/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /After the API fixes/ })).toBeUndefined()
})

test("a project's Parked draws a send's several pick-ups, each its own row", async ($, on) => {
  const w = world($, on)
  const { ui } = await pickedUp(w, $)

  await ui.press({ key: 'send' })
  await toProject(ui, PROJECT.key)
  await ui.press({ key: PICKED_UP })

  await expect(ui.drawn()).resolves.toBeDefined()
  expect(new Set(await pickUpRows(ui)).size).toBe(PARKED.length)
})

/** What the ledger parked. */
const EXPORT = 'Export the ledger as CSV'

/** The message a pick-up of the ledger's item goes in as. */
const PICKED = `From the board:\n- Pick up from parked, Invoice ledger's: ${EXPORT}`

/** Long enough ago that a session idle since is past the views. */
const OLD = T0 - CURRENT_MS - MIN

/** A session of the project's, started long ago, its meta naming the project by its name. */
const longAgo = (session: SessionMeta, project = PROJECT): SessionMeta => ({
  ...session,
  project: project.name,
  created: OLD,
})

/** The ledger's file this window writes. */
const LEDGER_LOG = sessionPaths(ROOT, PROJECT.key, LEDGER.id).log(W1)

/** The ledger's own file, which its window writes. */
const LEDGER_OWN = sessionPaths(ROOT, PROJECT.key, LEDGER.id).log(W2)

/** The ledger's inbox file this window writes. */
const LETTERS = sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W1)

/** The ledger as it stands once it parked something: its lines, and whether a window holds it. */
type Standing = { lines: Line[]; isOpen: boolean }

const OPEN: Standing = { lines: [[T0, park('p1', EXPORT)]], isOpen: true }

const FINISHED: Standing = {
  lines: [
    [T0, park('p1', EXPORT)],
    [T0, finish('claude', 'Shipped')],
  ],
  isOpen: false,
}

const STANDING: Record<string, Standing> = {
  'a session open in another window': OPEN,
  'a finished session': FINISHED,
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

/** The ledger's export as Ready to send draws its pick-up. */
const readyExport = async (ui: Board) =>
  rowsOf(await ui.find({ key: `readyanswer:${LEDGER.id}:p1` }))

/** Lee picks up the ledger's parked item, `item`, from the project's view, then goes home. */
const pickUpLedgers = async (ui: Board, item = 'p1') => {
  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGER.id}:${item}` })
  await ui.press({ key: `pickup:${LEDGER.id}:${item}` })
  await ui.press({ key: 'tab:session' })
}

for (const [standing, ledger] of Object.entries(STANDING)) {
  test(`a pick-up of what ${standing} parked goes in this window's own message, and is written down in that session, in this window's own file there: the item leaves Parked`, async ($, on) => {
    const w = world($, on)
    const { id, paths, ui } = await besideLedger(w, ledger)

    await pickUpLedgers(ui)
    expect(
      (await ui.findAll({ type: 'Text' }))
        .map(each => each.text)
        .filter(text => text.startsWith('to ')),
    ).toEqual(['to this session'])

    await ui.press({ key: 'send' })

    const written = parseEntries(w.text(LEDGER_LOG))
    const picked = written.find(line => line.type === 'reply')

    expect(w.prompts.map(prompt => prompt.text)).toEqual([PICKED])
    expect(written.map(line => line.type)).toEqual(['reply', 'delivered'])
    expect(picked, 'naming the session it went to').toMatchObject({
      item: 'p1',
      verdict: 'pickup',
      to: id,
    })
    expect(written.at(-1)).toMatchObject({ replies: [picked?.id] })
    expect(w.files.has(LETTERS), 'nothing in its inbox').toBe(false)
    expect(w.files.has(paths.log(W1)), 'nothing written in this session').toBe(false)
    expect(w.state.queue).toEqual([])

    await toProject(ui)
    expect(
      await ui.find({ type: 'Text', text: 'nothing to come back to' }),
      'the item left Parked',
    ).toBeDefined()
    await ui.press({ key: PICKED_UP })
    await ui.press({ key: `picked:${LEDGER.id}:p1` })
    expect(
      rowsOf(await ui.find({ key: `taken:${LEDGER.id}:p1` })),
      'picked up by the session it went to',
    ).toEqual([
      '● Invoice ledger: Export the ledger as CSV · now',
      '│ picked up by Help desk redesign',
      '└ nothing more was recorded',
    ])
    expect(
      (await ui.findAll({ type: 'Button' }))
        .map(each => each.key)
        .filter(key => key?.startsWith('go:')),
      'the pick-up brings no session back onto the board',
    ).toEqual(ledger.isOpen ? [`go:${id}`, `go:${LEDGER.id}`] : [`go:${id}`])
  })
}

test("this session's own view lists what another session of the project parked, by that session's name; picked up there, it goes in this window's own message as from the project's view, and is written down in that session", async ($, on) => {
  const w = world($, on)
  const { id, ui } = await besideLedger(w, FINISHED)
  const item = `${LEDGER.id}:p1`

  expect(await ui.find({ key: `ppick:${item}`, text: `Invoice ledger: ${EXPORT}` })).toBeDefined()
  await ui.press({ key: `ppick:${item}` })
  await ui.press({ key: `pickup:${item}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.map(prompt => prompt.text)).toEqual([PICKED])
  expect(parseEntries(w.text(LEDGER_LOG)).find(line => line.type === 'reply')).toMatchObject({
    item: 'p1',
    verdict: 'pickup',
    to: id,
  })
  expect(w.files.has(LETTERS), 'nothing in its inbox').toBe(false)
  expect(w.state.pane?.place ?? null, 'pressed and sent from home').toBeNull()
  expect(await ui.find({ type: 'Text', text: 'nothing to come back to' })).toBeDefined()
  expect(await ui.find({ key: PICKED_UP, text: 'show picked up 1' })).toBeDefined()
})

test("Parked's picked up names the session a pick-up went to though the window that sent it left that session and joined it again since", async ($, on) => {
  const w = world($, on)
  const { id, ui } = await besideLedger(w, OPEN)

  await pickUpLedgers(ui)
  await ui.press({ key: 'send' })
  await w.clock.advance(MIN)
  await w.call('join', { session: LEDGER.id })
  await w.clock.advance(MIN)
  await w.call('join', { session: id })

  expect(
    parsePresence(w.text(sessionPaths(ROOT, PROJECT.key, id).heartbeat(W1)), W1)?.attachedAt,
    'attached again after the pick-up',
  ).toBe(w.clock.now())

  await toProject(ui)
  await ui.press({ key: PICKED_UP })
  await ui.press({ key: `picked:${LEDGER.id}:p1` })
  expect(rowsOf(await ui.find({ key: `taken:${LEDGER.id}:p1` }))).toEqual([
    '● Invoice ledger: Export the ledger as CSV · 2m',
    '│ picked up by Help desk redesign',
    '└ nothing more was recorded',
  ])
})

test("held mid-turn, a pick-up of another session's item is named by its address in the claim and said in no heartbeat; taken back it is as it was, and sent again it goes in as the turn ends", async ($, on) => {
  const w = world($, on)
  const { paths, ui } = await besideLedger(w, FINISHED)
  const posted = await asked(w, REVIEW)

  await w.clock.advance(MIN)
  await pickUpLedgers(ui)
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })

  const queued = w.state.queue

  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await w.clock.advance(WATCH_MS)

  expect(w.state.inFlight).toMatchObject({
    source: 'send',
    session: w.state.attachment?.session,
    isHeld: true,
    replies: [
      { item: `${LEDGER.id}:p1`, verdict: 'pickup' },
      { item: posted, verdict: 'yes' },
    ],
  })
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.sending).toMatchObject([
    { replies: [{ item: posted, verdict: 'yes' }] },
  ])

  await ui.press({ key: w.takeBack() })
  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toEqual(queued)
  expect(await ui.find({ key: `unready:${LEDGER.id}:p1` }), 'removable again').toBeDefined()

  await ui.press({ key: 'send' })
  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([`${PICKED}\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`])
  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
})

test("a pick-up claimed mid-turn whose session's session.json is gone as Claude takes it is written down nowhere, a log saying so: the rest lands in its own session, and no folder is made for it", async ($, on) => {
  const w = world($, on)
  const { paths, ui } = await besideLedger(w, FINISHED)
  const posted = await asked(w, REVIEW)
  const ledgerFiles = () =>
    [...w.files.keys()].filter(path => path.includes(`/sessions/${LEDGER.id}/`)).sort()

  await w.clock.advance(MIN)
  await pickUpLedgers(ui)
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  w.files.delete(sessionPaths(ROOT, PROJECT.key, LEDGER.id).meta)

  const left = ledgerFiles()

  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([`${PICKED}\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`])
  expect(w.logs).toContain(`sitrep: Claude has replies to ${LEDGER.id}, whose session.json is gone`)
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
  expect(ledgerFiles(), 'nothing written for it, in any folder').toEqual(left)
})

test('a pick-up still in Ready to send when the window takes up a session of another project stays there, held back, saying the project its session is in; one of its project carries it again, and every other reply stays', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(longAgo(LEDGER))

  ledger.write(yesAsk('k3', 'Review the ledger schema'), park('p1', EXPORT))
  w.elsewhere(longAgo(THEMES))
  w.elsewhere(longAgo({ ...SHIFTS, by: W3 }, ELSEWHERE), ELSEWHERE.key)

  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await pickUpLedgers(ui)
  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  await ui.press({ key: `yes:${LEDGER.id}:k3` })

  const queued = w.state.queue

  await w.call('join', { session: 'sr-0sh1ft' })
  expect(w.state.queue).toEqual(queued)
  expect(await readyExport(ui)).toEqual([
    `└ pick it up · not sent: its session is in ${PROJECT.name}`,
  ])

  await w.call('join', { session: 'sr-themes' })
  expect(w.state.queue, 'a session of this project').toEqual(queued)
  expect(await readyExport(ui)).toEqual(['└ pick it up ✎ comment'])
  expect(w.toasts.filter(toast => toast.includes('pick-up'))).toEqual([])
  expect(w.files.has(LEDGER_LOG), 'the item stays parked').toBe(false)
})

test('a pick-up a send carried, taken back once the window holds a session of another project, stays in Ready to send held back, as on a join: never left undrawn, nor sent', async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, FINISHED)
  const posted = await asked(w, REVIEW)

  w.elsewhere(longAgo({ ...SHIFTS, by: W3 }, ELSEWHERE), ELSEWHERE.key)
  await w.clock.advance(MIN)
  await pickUpLedgers(ui)
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })

  const queued = w.state.queue

  await w.call('join', { session: 'sr-0sh1ft' })
  await ui.press({ key: w.takeBack() })
  expect(w.state.queue).toEqual(queued)
  expect(await readyExport(ui)).toEqual([
    `└ pick it up · not sent: its session is in ${PROJECT.name}`,
  ])
  expect(w.toasts.filter(toast => toast.includes('pick-up'))).toEqual([])

  await w.turnEnds()
  await w.clock.settle()
  expect(w.submitted).toEqual([])
  expect(w.files.has(LEDGER_LOG), 'the item stays parked').toBe(false)
})

test("a pick-up written down in the session that parked its item is Claude's own: the next prompt takes no board for it, though it does for what that session parked meanwhile", async ($, on) => {
  const w = world($, on)
  const lines: Line[] = [
    [T0, park('p1', EXPORT)],
    [T0, park('p2', 'Archive old invoices')],
  ]
  const { ui } = await besideLedger(w, { lines, isOpen: true })

  expect((await $.prompt.submit(PROMPT)).context?.[0], 'told of what it parked').toContain(EXPORT)

  await pickUpLedgers(ui)
  await ui.press({ key: 'send' })
  expect(w.prompts.at(-1)?.text).toBe(PICKED)
  await w.turnStarts(PICKED)
  await w.turnEnds()
  expect((await $.prompt.submit(PROMPT)).context, 'its own pick-up').toBeUndefined()

  await pickUpLedgers(ui, 'p2')
  w.put(LEDGER_OWN, file(...lines, [T0, park('p3', 'Retry the export')]))
  await ui.press({ key: 'send' })

  const context = (await $.prompt.submit(PROMPT)).context?.[0]

  expect(context).toContain(
    '- p3, parked by "Invoice ledger" (session: sr-1edger): Retry the export',
  )
  expect(context).not.toContain('Archive old invoices')
})

/** The ledger open, its item picked up and sent while Claude is mid-turn, held: the reply id its claim drew. */
const heldPickUp = async (w: World) => {
  const { ui } = await besideLedger(w, OPEN)

  await pickUpLedgers(ui)
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })

  return { ui, id: w.flights()[0]?.replies[0]?.id ?? '' }
}

test('a pick-up this window already wrote down in the parking session, its write cut short before the claim ended, is not written again', async ($, on) => {
  const w = world($, on)
  const { id } = await heldPickUp(w)

  w.put(LEDGER_LOG, file([T0 + MIN, reply(id, 'p1', 'pickup')], [T0 + MIN, delivered(id)]))

  const kept = w.text(LEDGER_LOG)

  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([PICKED])
  expect(w.text(LEDGER_LOG)).toBe(kept)
})

/** The replies a file holds, in order. */
const repliesIn = (w: World, path: string) =>
  parseEntries(w.text(path)).flatMap(line => (line.type === 'reply' ? [line] : []))

test('a pick-up written down in the parking session, its load cut short before the claim ended, is written once by its claimed id, however often the claim is taken up again', async ($, on) => {
  const w = world($, on)
  let isCut = true

  on('state.set', { plugin: 'sitrep', key: 'inFlight' }, ($, e, next) =>
    isCut && e.value === null ? { deny: 'the load was cut short' } : next(e),
  )

  const { id } = await heldPickUp(w)

  await w.turnEnds()
  await w.clock.advance(WATCH_MS)
  expect(repliesIn(w, LEDGER_LOG)).toMatchObject([{ id, item: 'p1', verdict: 'pickup' }])

  await $.session.start(CONVERSATION)
  await w.clock.settle()
  isCut = false
  await $.session.start(CONVERSATION)
  await w.clock.settle()

  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
  expect(w.flights()).toEqual([])
})

/** Messages in flight as `$.state` keeps them, a second's replies taking the first's ids, as two claims drawing alike would. */
const drawnAlike = <E extends { value: unknown }>(e: E): E => {
  if (!Array.isArray(e.value) || e.value.length !== 2) {
    return e
  }

  const [first, second] = e.value as [SitrepInFlight, SitrepInFlight]
  const replies = second.replies.map((reply, at) => ({
    ...reply,
    id: first.replies[at]?.id ?? reply.id,
  }))

  return { ...e, value: [first, { ...second, replies }] }
}

test('two sends held at once, each picking up an item one session parked, by the same reply id, are each written down there once, a write taken up again adding nothing; the second, its id taken, stays parked, the rare clash left', async ($, on) => {
  const w = world($, on)
  let isCut = true

  on('state.set', { plugin: 'sitrep', key: 'inFlight' }, ($, e, next) =>
    isCut && e.value === null ? { deny: 'the load was cut short' } : next(drawnAlike(e)),
  )

  const lines: Line[] = [
    [T0, park('p1', EXPORT)],
    [T0, park('p2', 'Archive old invoices')],
  ]
  const { ui } = await besideLedger(w, { lines, isOpen: true })

  await pickUpLedgers(ui)
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await pickUpLedgers(ui, 'p2')
  await ui.press({ key: 'send' })

  await w.turnEnds()
  await w.clock.settle()
  await w.turnStarts(w.submitted[0] ?? '')
  await w.turnEnds()
  await w.clock.settle()

  const written = w.text(LEDGER_LOG)

  expect(repliesIn(w, LEDGER_LOG).map(line => line.item)).toEqual(['p1', 'p2'])

  isCut = false
  await $.session.start(CONVERSATION)
  await w.clock.settle()

  expect(w.text(LEDGER_LOG), 'taken up again, the second writes nothing more').toBe(written)
  expect(w.flights()).toEqual([])
  expect(
    w.state.projects
      ?.find(project => project.key === PROJECT.key)
      ?.parked?.map(parked => parked.id),
  ).toEqual(['p2'])
})

test("a pick-up a send carried, held for the turn's end, goes in as sent once the window holds a session of another project, written down in the session that parked its item", async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, FINISHED)

  w.elsewhere(longAgo({ ...SHIFTS, by: W3 }, ELSEWHERE), ELSEWHERE.key)
  await w.clock.advance(MIN)
  await pickUpLedgers(ui)
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await w.call('join', { session: 'sr-0sh1ft' })
  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([PICKED])
  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
  expect(w.toasts.filter(toast => toast.includes('pick-up'))).toEqual([])
})

test("a tool call of Claude's while a pick-up is written down in the session that parked its item waits for the write: the next prompt takes no board for either", async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)
  let parked: ReturnType<typeof w.call> | undefined

  expect((await $.prompt.submit(PROMPT)).context?.[0], 'told of what it parked').toContain(EXPORT)

  await pickUpLedgers(ui)
  w.after('read', LEDGER_LOG, () => {
    parked = w.call('park', { title: 'Picking the export up' })
  })
  await ui.press({ key: 'send' })
  await w.turnStarts(PICKED)
  expect(await parked, 'a park as the pick-up is written').toHaveProperty('result')
  await w.turnEnds()

  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
  expect((await $.prompt.submit(PROMPT)).context, 'its own park and pick-up').toBeUndefined()
})

test('a prompt while a pick-up is written down in the session that parked its item, before the board reads that session again, finds the board as Claude saw it: it takes none, then or after', async ($, on) => {
  const w = world($, on)
  const { ui } = await besideLedger(w, OPEN)
  let prompted: ReturnType<typeof $.prompt.submit> | undefined

  expect((await $.prompt.submit(PROMPT)).context?.[0], 'told of what it parked').toContain(EXPORT)

  await pickUpLedgers(ui)
  w.after('list', sessionsDir(ROOT, PROJECT.key), () => {
    prompted = $.prompt.submit(PROMPT)
  })
  await ui.press({ key: 'send' })

  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
  expect(prompted, 'a prompt as the board reads it again').toBeDefined()
  expect((await prompted)?.context, 'meanwhile').toBeUndefined()
  expect((await $.prompt.submit(PROMPT)).context, 'after').toBeUndefined()
})

test('a pick-up whose write-down waits behind a join of the session that parked its item is written through the hold: the next post there keeps it', async ($, on) => {
  const w = world($, on)
  let ending: Promise<unknown> | undefined

  await heldPickUp(w)
  w.after('exists', LEDGER_LOG, async () => {
    ending = w.turnEnds()
    await w.clock.settle()
  })
  await w.call('join', { session: LEDGER.id })
  await ending
  await w.clock.settle()

  expect(w.state.attachment?.session).toBe(LEDGER.id)
  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])

  await w.call('park', { title: 'Carrying on here' })
  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered', 'park'])
})

test("a pick-up the receive timer takes up again while its write-down is under way is written once: the second write finds the first's lines", async ($, on) => {
  const w = world($, on)
  let ticked = () => {}
  const isTicked = new Promise<void>(resolve => {
    ticked = resolve
  })

  await heldPickUp(w)
  w.after('read', LEDGER_OWN, async () => {
    await w.clock.advance(WATCH_MS)
    ticked()
  })
  await w.turnEnds()
  await isTicked
  await w.clock.settle()

  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
  expect(w.flights()).toEqual([])
})

test('a pick-up written down is written down though keeping the board as seen after it fails: the claim ends, and the send says nothing went wrong', async ($, on) => {
  const w = world($, on)
  let isRefused = false

  on('state.set', { plugin: 'sitrep', key: 'seen' }, ($, e, next) =>
    isRefused ? { deny: 'the state is read-only' } : next(e),
  )

  const { ui } = await besideLedger(w, OPEN)

  expect((await $.prompt.submit(PROMPT)).context?.[0], 'told of what it parked').toContain(EXPORT)

  await pickUpLedgers(ui)
  isRefused = true
  await ui.press({ key: 'send' })
  await w.clock.settle()

  expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
  expect(w.flights()).toEqual([])
  expect(w.toasts).toEqual([])
})
