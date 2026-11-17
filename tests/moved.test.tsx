/**
 * A session moved to another project at Lee's word: the move tool, every
 * view seeing the session in its new project, the windows holding it
 * following, and what was in flight going on, its files staying in the
 * folder it was started in.
 */
import type { On } from 'claude-code'
import { expect, test, tier, type Engine } from './kit'
import { parseEntries, parseProject, presenceText, projectPaths } from '../core'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import {
  CLOSES,
  ELSEWHERE,
  GO,
  HOME,
  LEDGER,
  MIN,
  PROJECT,
  REVIEW,
  ROOT,
  SENDER,
  SHIFTS,
  T0,
  W1,
  W2,
  W4,
} from './data'
import { entered } from './answers'
import { file, moveTo, park, reply, yesAsk } from './lines'
import {
  asked,
  asking,
  CONVERSATION,
  kindsIn,
  postedId,
  PROMPT,
  toProject,
  turnEnded,
  world,
  type Board,
  type World,
} from './world'

tier('user')

/** What the session under test parks. */
const BADGE = 'A priority badge across all tabs'

/** What Contoso's own session parked. */
const ROTA = 'Export the rota'

/** What the ledger, another session of Northwind's, parked. */
const EXPORT = 'Export the ledger as CSV'

const MOVED = 'Moved Help desk redesign to the existing project Contoso.'

/** Contoso's line on the board text, for what its own session parked. */
const ROTA_LINE = `- p9, parked by "Shift schedules" (session: ${SHIFTS.id}): ${ROTA}`

/** Contoso on the board, living apart from Northwind, its own session open in another window and parking the rota's export. */
const withContoso = (w: World) => {
  const shifts = w.elsewhere(SHIFTS, ELSEWHERE.key)

  w.project(ELSEWHERE.key, {
    name: ELSEWHERE.name,
    directory: `${HOME}/Code/contoso`,
    created: T0,
    by: W4,
  })
  shifts.write(park('p9', ROTA))
  shifts.beat()
}

/** The ledger, another session of Northwind's, open in another window, having parked its export. */
const withLedger = (w: World) => {
  const ledger = w.elsewhere(LEDGER)

  ledger.write(park('p1', EXPORT))
  ledger.beat()

  return ledger
}

/** The keys of the presses a board draws whose keys start with `prefix`, in order. */
const pressesOf = async (ui: Board, prefix: string) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => String(each.key))
    .filter(key => key.startsWith(prefix))

/** The projects All projects lists, by their presses. */
const allProjects = async (ui: Board) => {
  await ui.press({ key: 'tab:all' })

  return pressesOf(ui, 'proj:')
}

/** The sessions a project's view lists, by their presses. */
const sessionsOf = async (ui: Board, key: string) => {
  await toProject(ui, key)

  return (await pressesOf(ui, 'go:')).sort()
}

/** The first message's sitrep block, as the engine asks for it. */
const firstMessage = async ($: Engine) =>
  (await $.prompt.context({ blocks: [] })).blocks.find(block => block.name === 'sitrep')?.text

/** A project's file, as it stands. */
const projectFile = (w: World, key: string) => parseProject(w.text(projectPaths(ROOT, key).file))

/** The board text Claude's board tool reads back. */
const boardRead = async (w: World) => String((await w.call('board')).result)

/** The paths of the files under a project's folder for a session. */
const filesUnder = (w: World, project: string, session: string) =>
  [...w.files.keys()].filter(path =>
    path.startsWith(`${ROOT}/projects/${project}/sessions/${session}/`),
  )

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

test('move takes the held session whole to a project on the board, matched as start matches one: its status, asks, parked items, history and resolved go, its files staying where they were', async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { id, paths } = await w.begin()

  await w.call('status', { now: ['Drawing Inbox'] })

  const ask = await asked(w, REVIEW)
  const parked = postedId(await w.call('park', { title: BADGE }))
  const done = await asked(w, GO)

  await w.call('resolve', { item: done, reason: 'Lee said go in the chat' })
  await w.clock.advance(MIN)

  const before = w.state.board
  const own = filesUnder(w, PROJECT.key, id)

  expect((await w.call('move', { project: 'con-toso' })).result).toBe(MOVED)
  expect(w.state.attachment).toMatchObject({ project: ELSEWHERE.key, session: id, writer: W1 })
  expect(w.state.board).toMatchObject({
    id,
    project: ELSEWHERE.name,
    status: before?.status,
    asks: before?.asks,
    parked: before?.parked,
    items: before?.items,
    history: before?.history,
  })
  expect(w.state.board?.asks.map(each => [each.id, each.state])).toEqual([
    [ask, 'waiting'],
    [done, 'closed'],
  ])
  expect(w.state.board?.parked.map(each => each.id)).toEqual([parked])
  expect(parseEntries(w.text(paths.log(W1))).at(-1)).toMatchObject({
    type: 'move',
    project: ELSEWHERE.key,
  })
  expect(filesUnder(w, PROJECT.key, id), 'its files where they were').toEqual(own)
  expect(filesUnder(w, ELSEWHERE.key, id), 'none in the project it moved to').toEqual([])
  expect(projectFile(w, ELSEWHERE.key)?.by, 'Contoso as it was').toBe(W4)
})

test('every view sees the moved session in its new project, and the project it left, with nothing else on it, leaves the lists', async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { id } = await w.begin()

  await asked(w, REVIEW)
  await w.call('move', { project: 'Contoso' })

  const ui = await w.pane()

  expect(w.state.projects?.map(project => project.key)).toEqual([ELSEWHERE.key])
  expect(await allProjects(ui)).toEqual([`proj:${ELSEWHERE.key}`])
  expect(await sessionsOf(ui, ELSEWHERE.key)).toEqual([`go:${SHIFTS.id}`, `go:${id}`].sort())

  const listing = await firstMessage($)

  expect(listing).toContain(`- Contoso: ${id} "Help desk redesign", 1 waiting on Lee`)
  expect(listing).not.toContain('- Northwind:')
})

test("the project the session left keeps nothing of it, and keeps its own: what it parked is the new project's, on the session's own view and in Claude's board text", async ($, on) => {
  const w = world($, on)

  withContoso(w)
  withLedger(w)

  const { id } = await w.begin()
  const parked = postedId(await w.call('park', { title: BADGE }))
  const ledgers = `- p1, parked by "Invoice ledger" (session: ${LEDGER.id}): ${EXPORT}`

  expect(await boardRead(w)).toContain(ledgers)

  await w.call('move', { project: 'Contoso' })

  const told = (await $.prompt.submit(PROMPT)).context?.[0]

  expect(told, "Claude is told its new project's parked items").toContain(ROTA_LINE)

  const read = await boardRead(w)
  const northwind = w.state.projects?.find(project => project.key === PROJECT.key)
  const contoso = w.state.projects?.find(project => project.key === ELSEWHERE.key)

  expect(read).toContain(`- ${parked}: ${BADGE}`)
  expect(read).toContain(ROTA_LINE)
  expect(read).not.toContain(ledgers)
  expect(northwind?.sessions.map(session => session.id)).toEqual([LEDGER.id])
  expect(northwind?.parked?.map(each => [each.session, each.id])).toEqual([[LEDGER.id, 'p1']])
  expect(contoso?.parked?.map(each => [each.session, each.id])).toEqual([[SHIFTS.id, 'p9']])

  const ui = await w.pane()

  expect(await ui.find({ key: `ppick:${SHIFTS.id}:p9` }), "Contoso's on its view").toBeDefined()
  expect(await ui.find({ key: `ppick:${LEDGER.id}:p1` }), "Northwind's gone").toBeUndefined()
  expect(await sessionsOf(ui, PROJECT.key)).toEqual([`go:${LEDGER.id}`])
  expect(await ui.find({ key: `ppick:${w.item(parked)}` }), 'not on Northwind').toBeUndefined()
  await toProject(ui, ELSEWHERE.key)
  expect(await ui.find({ key: `ppick:${w.item(parked)}` }), "on Contoso's").toBeDefined()
})

test('move makes a new project of a name no project on the board has, with its directory, as start makes one', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()
  const trey = { project: 'Trey Research', directory: `${HOME}/Code/trey/` }

  await w.clock.advance(MIN)

  expect((await w.call('move', trey)).result).toBe(
    'Moved Help desk redesign to a new project, Trey Research.',
  )
  expect(projectFile(w, 'trey-research')).toEqual({
    name: 'Trey Research',
    directory: `${HOME}/Code/trey`,
    created: T0 + MIN,
    by: W1,
  })
  expect(w.state.attachment).toMatchObject({ project: 'trey-research', session: id })
  expect(w.state.board?.project).toBe('Trey Research')
  expect(kindsIn(w, paths.log(W1)).at(-1)).toBe('move')
  expect(filesUnder(w, 'trey-research', id)).toEqual([])
})

test('move gives a project on the board with no directory the one named, and leaves one that has its own', async ($, on) => {
  const w = world($, on)

  withContoso(w)
  await w.begin()

  const moving = { project: 'Contoso', directory: `${HOME}/Work/contoso` }

  expect((await w.call('move', moving)).result).toBe(
    `Moved Help desk redesign to the existing project Contoso, which lives in ${HOME}/Code/contoso; the project tool changes that.`,
  )
  expect(projectFile(w, ELSEWHERE.key)?.directory).toBe(`${HOME}/Code/contoso`)
})

test('move refuses with no session held, the project the session is in already, and a name with nothing to match by, writing nothing', async ($, on) => {
  const w = world($, on)

  withContoso(w)
  await $.session.start(CONVERSATION)

  expect((await w.call('move', { project: 'Contoso' })).deny).toBe(
    'No session is attached to this window: start one, or join one by its id, first.',
  )

  const { paths } = await w.begin()
  const before = new Map(w.files)

  expect((await w.call('move', { project: 'north wind', directory: '/Users/me/nw' })).deny).toBe(
    'Help desk redesign is in Northwind already.',
  )
  expect((await w.call('move', { project: ' -!- ' })).deny).toBe(
    'Name the project to move the session to: its name as Lee would say it, such as SitRep or Switchboard.',
  )
  expect((await w.call('move', {})).deny).toContain('Name the project to move the session to')
  expect(w.files).toEqual(before)
  expect(w.files.has(paths.log(W1))).toBe(false)

  await w.call('move', { project: 'Contoso' })

  expect((await w.call('move', { project: 'contoso' })).deny).toBe(
    'Help desk redesign is in Contoso already.',
  )
  expect((await w.call('move', { project: 'Northwind' })).result, 'and back again').toBe(
    'Moved Help desk redesign to the existing project Northwind.',
  )
  expect(w.state.attachment?.project).toBe(PROJECT.key)
  expect(w.state.board?.project).toBe(PROJECT.name)
})

test('a window holding the session follows a move another window made, at its next look, and posts, beats and reads on where it was', async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { id, paths } = await w.begin()
  const elsewhere = w.writer(paths, W2)

  elsewhere(moveTo(ELSEWHERE.key))
  await w.clock.advance(WATCH_MS)

  expect(w.state.attachment).toMatchObject({ project: ELSEWHERE.key, session: id })
  expect(w.state.board?.project).toBe(ELSEWHERE.name)
  expect(
    w.state.projects?.map(({ key, sessions }) => [key, sessions.map(each => each.id)]),
    'the sessions around read again, Northwind gone',
  ).toEqual([[ELSEWHERE.key, [SHIFTS.id]]])

  const parked = postedId(await w.call('park', { title: BADGE }))

  elsewhere(moveTo(ELSEWHERE.key), yesAsk('k8', 'Try it'))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.parked.map(each => each.id)).toEqual([parked])
  expect(w.state.board?.asks.map(each => each.id)).toEqual(['k8'])
  expect(kindsIn(w, paths.log(W1))).toEqual(['park'])
  expect(await boardRead(w)).toContain(ROTA_LINE)
  expect(filesUnder(w, ELSEWHERE.key, id)).toEqual([])
  expect(w.text(paths.heartbeat(W1))).toContain(`"writer":"${W1}"`)
})

test("another window's lines written as the move is made and after it are all the session's: nothing is lost", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { paths } = await w.begin()
  const elsewhere = w.writer(paths, W2)

  elsewhere(yesAsk('k7', 'Review it'))
  w.after('read', projectPaths(ROOT, ELSEWHERE.key).file, () => elsewhere(yesAsk('k8', 'Try it')))

  expect((await w.call('move', { project: 'Contoso' })).result).toBe(MOVED)

  elsewhere(yesAsk('k9', 'Ship it'))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.asks.map(each => each.id)).toEqual(['k7', 'k8', 'k9'])
  expect(kindsIn(w, paths.log(W2))).toEqual(['ask', 'ask', 'ask'])
  expect(kindsIn(w, paths.log(W1))).toEqual(['move'])
})

test("a send of Lee's claimed before the move, held while Claude's turn runs, is written down through the hold after it, never beside it", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { paths, id, ui } = await asking(w)

  await ui.press({ key: `yes:${w.item(id)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })

  expect(w.state.inFlight).toMatchObject({ project: PROJECT.key, isHeld: true })

  w.writer(paths, W2)(moveTo(ELSEWHERE.key))
  await w.clock.advance(WATCH_MS)
  expect(w.state.attachment?.project).toBe(ELSEWHERE.key)

  await turnEnded(w)

  expect(w.submitted).toEqual([`From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.inFlight).toBeNull()

  await w.call('park', { title: BADGE })

  expect(kindsIn(w, paths.log(W1)), 'the hold kept the lines').toEqual([
    'ask',
    'reply',
    'delivered',
    'park',
  ])
})

test("Ready to send's replies to the session's own items, queued before the move, are sent after it; the board's place on the session follows it", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { paths, id, ui } = await asking(w)
  const parked = postedId(await w.call('park', { title: BADGE }))

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `ppick:${w.item(parked)}` })
  await ui.press({ key: `pickup:${w.item(parked)}` })
  await toProject(ui)
  await ui.press({ key: `go:${w.state.attachment?.session}` })

  expect(w.state.queue?.map(each => each.project)).toEqual([PROJECT.key, PROJECT.key])

  await w.call('move', { project: 'Contoso' })

  expect(w.state.queue?.map(each => [each.project, each.item])).toEqual([
    [ELSEWHERE.key, id],
    [ELSEWHERE.key, parked],
  ])
  expect(w.state.pane?.place).toMatchObject({ level: 'session', project: ELSEWHERE.key })
  expect(w.toasts.filter(toast => toast.includes('pick-up')), 'none left').toEqual([])

  await ui.press({ key: 'send' })

  expect(w.submitted).toHaveLength(1)
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'park', 'move', 'reply', 'reply', 'delivered'])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.board?.items.find(each => each.id === parked)?.state).toBe('picked')
  expect(w.state.queue).toEqual([])
})

test("a pick-up of the session's own parked item Lee is writing a note for as it moves goes with its note, the item still the session's", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { paths } = await w.begin()
  const parked = postedId(await w.call('park', { title: BADGE }))
  const ui = await w.opened()

  await ui.press({ key: `ppick:${w.item(parked)}` })
  await ui.press({ key: `comment:${w.item(parked)}` })
  w.writer(paths, W2)(moveTo(ELSEWHERE.key))
  await w.clock.advance(WATCH_MS)

  expect(w.state.answering).toMatchObject({ project: ELSEWHERE.key, item: parked })

  await entered(w, $, 'Before the release')
  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([`From the board:\n- Pick up from parked: ${BADGE}. Before the release`])
  expect(kindsIn(w, paths.log(W1))).toEqual(['park', 'reply', 'delivered'])
})

test("a window joining a moved session keeps Ready to send's pick-ups of what its new project's sessions parked", async ($, on) => {
  const w = world($, on)

  withContoso(w)
  withLedger(w).write(moveTo(ELSEWHERE.key))
  await $.session.start(CONVERSATION)
  await w.call('start', { name: 'Rota', summary: 'The rota, week by week', project: 'Contoso' })

  const ui = await w.opened()

  await ui.press({ key: `ppick:${SHIFTS.id}:p9` })
  await ui.press({ key: `pickup:${SHIFTS.id}:p9` })
  await w.call('join', { session: LEDGER.id })

  expect(w.state.attachment?.project).toBe(ELSEWHERE.key)
  expect(w.state.queue).toEqual([
    { project: ELSEWHERE.key, session: SHIFTS.id, item: 'p9', verdict: 'pickup' },
  ])
  expect(w.toasts.filter(toast => toast.includes('pick-up'))).toEqual([])
})

test("a pick-up in Ready to send of what another session of the project it left parked leaves it as the session moves, a toast saying so; one pressed for a session that then moved goes as pressed, written down in that session's folder", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const ledger = withLedger(w)

  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGER.id}:p1` })
  await ui.press({ key: `pickup:${LEDGER.id}:p1` })

  await w.call('move', { project: 'Contoso' })

  expect(w.state.queue).toEqual([])
  expect(w.toasts).toContain(
    '1 pick-up of another project left Ready to send: pick up from a window of that project.',
  )

  await w.call('move', { project: 'Northwind' })
  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGER.id}:p1` })
  await ui.press({ key: `pickup:${LEDGER.id}:p1` })
  ledger.write(moveTo(ELSEWHERE.key))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([
    `From the board:\n- Pick up from parked, Invoice ledger's: ${EXPORT}`,
  ])
  expect(kindsIn(w, ledger.paths.log(W1))).toEqual(['reply', 'delivered'])
  expect(filesUnder(w, ELSEWHERE.key, LEDGER.id)).toEqual([])
})

test("a reply in the session's inbox from before the move is delivered after it, from the folder it was always in", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { paths } = await w.begin()
  const posted = await asked(w, REVIEW)

  await w.clock.advance(MIN)
  w.put(paths.letters(SENDER), file([w.clock.now(), reply('r1', posted, 'yes')]))
  await w.call('move', { project: 'Contoso' })
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted).toEqual([
    `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
  ])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'move', 'delivered'])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
})

test('join takes up a moved session in the project it moved to, and a session there acts on what it parked; a session of the project it left no longer does', async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const ledger = withLedger(w)

  ledger.write(moveTo(ELSEWHERE.key))
  await $.session.start(CONVERSATION)

  const joined = await w.call('join', { session: LEDGER.id })

  expect(joined.result).toContain(`Joined Invoice ledger (${LEDGER.id}).`)
  expect(w.state.attachment).toMatchObject({ project: ELSEWHERE.key, session: LEDGER.id })
  expect(w.state.board?.project).toBe(ELSEWHERE.name)

  await w.call('join', { session: SHIFTS.id })

  expect((await w.call('resolve', { session: LEDGER.id, item: 'p1' })).result).toBeDefined()
  expect(kindsIn(w, ledger.paths.log(W1))).toEqual(['resolve'])

  const { id } = await w.begin()

  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: id })
  expect((await w.call('reopen', { session: LEDGER.id, item: 'p1' })).deny).toContain(
    'another project',
  )
})

const KEPT = {
  'a load from before the move, its `$.state` naming the folder, takes the session up in the project it moved to':
    PROJECT.key,
  "a load whose `$.state` names the project the session moved to finds its folder by the session's id":
    ELSEWHERE.key,
}

for (const [said, project] of Object.entries(KEPT)) {
  test(`${said}, and posts on into that folder`, async ($, on) => {
    const w = world($, on, { now: T0 + MIN })

    withContoso(w)

    const { paths } = withLedger(w)

    w.put(paths.log(W1), file([T0, yesAsk('k1', 'Review it')], [T0, moveTo(ELSEWHERE.key)]))
    w.put(paths.heartbeat(W1), presenceText({ writer: W1, attachedAt: T0, seenAt: T0 }))
    reloading(on, { project, session: LEDGER.id, writer: W1, attachedAt: T0 })
    await $.session.start(CONVERSATION)

    expect(w.state.attachment).toMatchObject({ project: ELSEWHERE.key, session: LEDGER.id })
    expect(w.state.board?.asks.map(ask => ask.id)).toEqual(['k1'])

    await w.call('park', { title: BADGE })

    expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'move', 'park'])
    expect(filesUnder(w, ELSEWHERE.key, LEDGER.id)).toEqual([])
  })
}

test('a conversation resumed after its session moved takes it up again in the project it moved to', async ($, on) => {
  const w = world($, on, { now: T0 + 10 * MIN })

  withContoso(w)

  const ledger = w.elsewhere({ ...LEDGER, by: W1 })

  ledger.write(yesAsk('k1', 'Review it'), moveTo(ELSEWHERE.key))
  w.put(
    ledger.paths.heartbeat(W1),
    presenceText({ writer: W1, attachedAt: T0, seenAt: T0 + MIN, leftAt: T0 + MIN }),
  )

  const listing = await firstMessage($)

  expect(w.state.attachment).toMatchObject({ project: ELSEWHERE.key, session: LEDGER.id })
  expect(listing).toContain(`- Contoso: ${LEDGER.id} "Invoice ledger", 1 waiting on Lee`)
  expect(listing).toContain(`This window already holds ${LEDGER.id} (Invoice ledger)`)
})
