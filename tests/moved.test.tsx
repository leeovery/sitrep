/**
 * A session moved to another project at Lee's word: the move tool, every
 * view seeing the session in its new project, the windows holding it
 * following, and what was in flight going on, its files staying in the
 * folder it was started in, which every ref the window keeps names.
 */
import type { On } from 'claude-code'
import { expect, test, tier, type Engine } from './kit'
import {
  CURRENT_MS,
  metaText,
  parseEntries,
  parseProject,
  presenceText,
  projectPaths,
  sessionPaths,
  sessionsDir,
} from '../core'
import { AROUND_MS } from '../hooks/around'
import { isHoldOn, WATCH_MS } from '../hooks/window'
import type { SitrepAttachment, SitrepPane, SitrepQueued } from '../types'
import {
  CLOSES,
  ELSEWHERE,
  GO,
  HOME,
  LEDGER,
  META,
  MIN,
  PROJECT,
  REVIEW,
  ROOT,
  SENDER,
  SHIFTS,
  T0,
  THEMES,
  W1,
  W2,
  W4,
} from './data'
import { entered } from './answers'
import { rowsOf } from './drawn'
import { delivered, file, finish, moveTo, park, reply, resolve, status, yesAsk } from './lines'
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

  return shifts
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

/** Where the window holds its session: the folder its attachment names, which no move changes, and the project its board files it under, by key and by name. */
const holding = (w: World) => ({
  folder: w.state.attachment?.project,
  project: w.state.board?.filedUnder,
  name: w.state.board?.project,
})

/** A session of Northwind's folder, held there, filed under Contoso. */
const IN_CONTOSO = { folder: PROJECT.key, project: ELSEWHERE.key, name: ELSEWHERE.name }

/** The toast each window holding a session shows as the session moves to Contoso. */
const MOVED_TO = 'Moved to Contoso.'

/** The toasts saying a session moved. */
const movedToasts = (w: World) => w.toasts.filter(toast => toast.startsWith('Moved to '))

/** The mod finding, as a reload does, `held` in `$.state`: the session the window held. */
const reloading = (on: On, held: SitrepAttachment) => {
  let isReloaded = false

  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return { value: { value: held, version: 1 } }
  })
}

/** The mod finding, as a reload does, `queue` in `$.state` as Ready to send, until it writes its own. */
const queueing = (on: On, queue: SitrepQueued[]) => {
  let isLeft = true

  // As the engine holds it, at its version, so the mod's first update lands on it.
  on('state.get', { plugin: 'sitrep', key: 'queue' }, async ($, e, next) => {
    const read = (await next(e)) as { value: { value: SitrepQueued[]; version: number } }

    return isLeft ? { value: { ...read.value, value: queue } } : read
  })
  on('state.set', { plugin: 'sitrep', key: 'queue' }, ($, e, next) => {
    isLeft = false

    return next(e)
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
  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: id, writer: W1 })
  expect(holding(w)).toEqual(IN_CONTOSO)
  expect(movedToasts(w), "the mover's window says so").toEqual([MOVED_TO])
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

  expect(listing).toContain(`- Contoso: ${id} "Help desk redesign", 1 waiting on the user`)
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
  expect(holding(w)).toEqual({
    folder: PROJECT.key,
    project: 'trey-research',
    name: 'Trey Research',
  })
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
    'Name the project to move the session to: its name as the user would say it, such as SitRep or Switchboard.',
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
  expect(holding(w)).toEqual({ folder: PROJECT.key, project: PROJECT.key, name: PROJECT.name })
})

test('a window holding the session follows a move another window made, at its next look, and posts, beats and reads on where it was', async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { id, paths } = await w.begin()
  const elsewhere = w.writer(paths, W2)

  elsewhere(moveTo(ELSEWHERE.key))
  await w.clock.advance(WATCH_MS)

  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: id })
  expect(holding(w)).toEqual(IN_CONTOSO)
  expect(movedToasts(w), 'this window says so too').toEqual([MOVED_TO])
  expect(
    w.state.projects?.map(({ key, sessions }) => [key, sessions.map(each => each.id)]),
    'the sessions around read again, Northwind gone',
  ).toEqual([[ELSEWHERE.key, [SHIFTS.id]]])

  const parked = postedId(await w.call('park', { title: BADGE }))

  elsewhere(moveTo(ELSEWHERE.key), yesAsk('k8', 'Try it'))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.parked.map(each => each.id)).toEqual([parked])
  expect(w.state.board?.asks.map(each => each.id)).toEqual(['k8'])
  expect(movedToasts(w), 'a move to where it is already, no more').toEqual([MOVED_TO])
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
  expect(holding(w)).toEqual(IN_CONTOSO)

  await turnEnded(w)

  expect(w.submitted).toEqual([
    `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
  ])
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

test("Ready to send's replies to the session's own items, queued before the move, are sent after it, they and the board's place on the session naming its folder still", async ($, on) => {
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
    [PROJECT.key, id],
    [PROJECT.key, parked],
  ])
  expect(w.state.pane?.place).toMatchObject({ level: 'session', project: PROJECT.key })
  expect(
    w.toasts.filter(toast => toast.includes('pick-up')),
    'none left',
  ).toEqual([])

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

  expect(w.state.answering).toMatchObject({ project: PROJECT.key, item: parked })

  await entered(w, $, 'Before the release')
  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([
    `From the board:\n- Pick up from parked: ${BADGE}. Before the release`,
  ])
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

  expect(holding(w)).toEqual(IN_CONTOSO)
  expect(w.state.queue).toEqual([
    { project: ELSEWHERE.key, session: SHIFTS.id, item: 'p9', verdict: 'pickup' },
  ])
  expect(w.toasts.filter(toast => toast.includes('pick-up'))).toEqual([])
})

/** The ledger's export, as Ready to send queues its pick-up from Northwind's folder. */
const PICK_UP: SitrepQueued = {
  project: PROJECT.key,
  session: LEDGER.id,
  item: 'p1',
  verdict: 'pickup',
}

/** The ledger's export, picked up from Northwind's view. */
const pickingUp = async (w: World) => {
  withContoso(w)

  const ledger = withLedger(w)

  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGER.id}:p1` })
  await ui.press({ key: `pickup:${LEDGER.id}:p1` })

  return { ledger, ui }
}

/** The ledger's export, picked up from Northwind's view, the ledger then moved to Contoso, and the look having read it there. */
const pickedThenMoved = async (w: World) => {
  const picked = await pickingUp(w)

  picked.ledger.write(moveTo(ELSEWHERE.key))
  await w.clock.advance(AROUND_MS)

  return picked
}

/** The ledger's export as Ready to send draws its pick-up, and its ✕. */
const readyPickUp = async (ui: Board) => ({
  rows: rowsOf(await ui.find({ key: `readyanswer:${LEDGER.id}:p1` })),
  isUnreadied: (await ui.find({ key: `unready:${LEDGER.id}:p1` })) !== undefined,
})

/** The ledger's export drawn held back, its session filed under `project`. */
const heldBackIn = (project: string) => ({
  rows: [`└ pick it up · not sent: its session is in ${project}`],
  isUnreadied: true,
})

/** The pick-up of the ledger's export, as Claude's own message carries it. */
const EXPORT_SENT = `From the board:\n- Pick up from parked, Invoice ledger's: ${EXPORT}`

/** The toasts about pick-ups, as a build that dropped them from Ready to send showed. */
const pickUpToasts = (w: World) => w.toasts.filter(toast => toast.includes('pick-up'))

test('a pick-up in Ready to send of what another session of the project it left parked stays there as the session moves, held back, saying the project that session is in; once the session moves back, it goes', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await pickingUp(w)

  await w.call('move', { project: 'Contoso' })
  await w.clock.advance(AROUND_MS)

  expect(w.state.queue).toEqual([PICK_UP])
  expect(await readyPickUp(ui)).toEqual(heldBackIn(PROJECT.name))
  expect(await ui.find({ key: 'send' }), 'no send for it alone').toBeUndefined()
  expect(pickUpToasts(w)).toEqual([])

  await w.call('move', { project: PROJECT.name })
  await w.clock.advance(AROUND_MS)
  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([EXPORT_SENT])
  expect(kindsIn(w, ledger.paths.log(W1))).toEqual(['reply', 'delivered'])
})

test('a pick-up of what a session then moved to another project parked is drawn in Ready to send held back, saying where it went, with its ✕ and its undo, and no send offered for it: none goes until that session is back, then it goes', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await pickedThenMoved(w)

  expect(await readyPickUp(ui)).toEqual(heldBackIn(ELSEWHERE.name))
  expect(await ui.find({ key: 'send' }), 'no send for it alone').toBeUndefined()

  await toProject(ui, ELSEWHERE.key)

  expect(rowsOf(await ui.find({ key: `parked:${LEDGER.id}:p1` })).at(-1)).toMatch(
    /· not sent: its session is in Contoso ↺ undo$/,
  )

  ledger.write(moveTo(PROJECT.key))
  await w.clock.advance(AROUND_MS)

  expect(await readyPickUp(ui)).toEqual({ rows: ['└ pick it up'], isUnreadied: true })

  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([EXPORT_SENT])
  expect(kindsIn(w, ledger.paths.log(W1))).toEqual(['reply', 'delivered'])
  expect(filesUnder(w, ELSEWHERE.key, LEDGER.id)).toEqual([])
})

test('a pick-up held back as the session that parked its item moved away stays held back as a send of the rest is taken back, and as the window joins another session of its project: nothing drops it', async ($, on) => {
  const w = world($, on)

  w.elsewhere(THEMES)

  const { ui } = await pickedThenMoved(w)
  const posted = await asked(w, REVIEW)

  await ui.press({ key: 'tab:session' })
  await ui.press({ key: `pick:${w.item(posted)}` })
  await ui.press({ key: `yes:${w.item(posted)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })

  const queued = w.state.queue

  expect(queued).toContainEqual(PICK_UP)

  await ui.press({ key: w.takeBack() })

  expect(w.state.queue, 'taken back').toEqual(queued)
  expect(await readyPickUp(ui), 'taken back').toEqual(heldBackIn(ELSEWHERE.name))

  await w.call('join', { session: THEMES.id })

  expect(w.state.queue, 'joined').toEqual(queued)
  expect(await readyPickUp(ui), 'joined').toEqual(heldBackIn(ELSEWHERE.name))
  expect(pickUpToasts(w)).toEqual([])
})

test('a send pressed as the session that parked a pick-up moves away, before the look reads it there, carries none of it, saying why, and leaves it held back', async ($, on) => {
  const w = world($, on)
  const { ledger, ui } = await pickingUp(w)

  ledger.write(moveTo(ELSEWHERE.key))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([])
  expect(w.toasts.at(-1)).toMatch(
    /^Nothing to send: the items replied to are in another project now\./,
  )
  expect(w.state.queue?.map(each => each.session)).toEqual([LEDGER.id])
})

test('undo takes back a pick-up held back as the session that parked its item moved to another project', async ($, on) => {
  const w = world($, on)
  const { ui } = await pickedThenMoved(w)

  await toProject(ui, ELSEWHERE.key)
  await ui.press({ key: `undo:${LEDGER.id}:p1` })

  expect(w.state.queue).toEqual([])
  expect(await ui.find({ key: `readyanswer:${LEDGER.id}:p1` })).toBeUndefined()
})

test('a pick-up of what a session of the project the held one left parked, still queued as a reload found its session.json torn and its move unread, never goes to its Claude: the send reads where each is filed', async ($, on) => {
  const w = world($, on, { now: T0 + MIN })

  withContoso(w)

  const ledger = withLedger(w)
  const paths = sessionPaths(ROOT, PROJECT.key, META.id)

  reloading(on, { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 })
  queueing(on, [PICK_UP])
  w.put(paths.meta, metaText(META).slice(0, 12))
  w.put(paths.log(W1), file([T0, yesAsk('k1', 'Review it')], [T0, moveTo(ELSEWHERE.key)]))
  w.put(paths.heartbeat(W1), presenceText({ writer: W1, attachedAt: T0, seenAt: T0 }))
  await $.session.start(CONVERSATION)
  w.put(paths.meta, metaText(META))
  await w.clock.advance(WATCH_MS)

  expect(holding(w)).toEqual(IN_CONTOSO)

  const ui = await w.opened()

  await ui.press({ key: `pick:${w.item('k1')}` })
  await ui.press({ key: `yes:${w.item('k1')}` })

  expect(w.state.queue?.map(each => each.session)).toEqual([LEDGER.id, META.id])

  await ui.press({ key: 'send' })

  expect(w.submitted).toHaveLength(1)
  expect(w.submitted[0]).toContain('Review it')
  expect(w.submitted[0]).not.toContain(EXPORT)
  expect(w.files.has(ledger.paths.log(W1))).toBe(false)
  expect(w.state.queue).toContainEqual(PICK_UP)
})

test('a pick-up held back as the session that parked its item moved away stays held back through a reload', async ($, on) => {
  const w = world($, on, { now: T0 + MIN })

  withContoso(w)
  withLedger(w).write(moveTo(ELSEWHERE.key))

  const paths = sessionPaths(ROOT, PROJECT.key, META.id)

  reloading(on, { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 })
  queueing(on, [PICK_UP])
  w.put(paths.meta, metaText(META))
  w.put(paths.log(W1), file([T0, yesAsk('k1', 'Review it')]))
  w.put(paths.heartbeat(W1), presenceText({ writer: W1, attachedAt: T0, seenAt: T0 }))
  await $.session.start(CONVERSATION)
  await w.clock.advance(AROUND_MS)

  expect(await readyPickUp(await w.opened())).toEqual(heldBackIn(ELSEWHERE.name))
  expect(pickUpToasts(w)).toEqual([])
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
  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: LEDGER.id })
  expect(holding(w)).toEqual(IN_CONTOSO)
  expect(movedToasts(w), 'a join moves nothing').toEqual([])

  await w.call('join', { session: SHIFTS.id })

  expect((await w.call('resolve', { session: LEDGER.id, item: 'p1' })).result).toBeDefined()
  expect(kindsIn(w, ledger.paths.log(W1))).toEqual(['resolve'])

  const { id } = await w.begin()

  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: id })
  expect((await w.call('reopen', { session: LEDGER.id, item: 'p1' })).deny).toContain(
    'another project',
  )
})

test('a load from before the move, its `$.state` naming the folder, takes the session up in the project it moved to, and posts on into that folder', async ($, on) => {
  const w = world($, on, { now: T0 + MIN })

  withContoso(w)

  const { paths } = withLedger(w)

  w.put(paths.log(W1), file([T0, yesAsk('k1', 'Review it')], [T0, moveTo(ELSEWHERE.key)]))
  w.put(paths.heartbeat(W1), presenceText({ writer: W1, attachedAt: T0, seenAt: T0 }))
  reloading(on, { project: PROJECT.key, session: LEDGER.id, writer: W1, attachedAt: T0 })
  await $.session.start(CONVERSATION)

  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: LEDGER.id })
  expect(holding(w)).toEqual(IN_CONTOSO)
  expect(w.state.board?.asks.map(ask => ask.id)).toEqual(['k1'])

  await w.call('park', { title: BADGE })

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'move', 'park'])
  expect(filesUnder(w, ELSEWHERE.key, LEDGER.id)).toEqual([])
})

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

  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, session: LEDGER.id })
  expect(holding(w)).toEqual(IN_CONTOSO)
  expect(listing).toContain(`- Contoso: ${LEDGER.id} "Invoice ledger", 1 waiting on the user`)
  expect(listing).toContain(`This window already holds ${LEDGER.id} (Invoice ledger)`)
})

/** Long enough for a new ask's pulse to run out, its buttons drawn. */
const REST_MS = 5_000

/**
 * The session under test begun with an ask and a parked item, moved to
 * Contoso, and the board open on its own view as Contoso's lists it: every
 * ref the view draws names Contoso, where its files are not.
 */
const movedHere = async (w: World) => {
  withContoso(w)

  const { id, paths } = await w.begin()
  const ask = await asked(w, REVIEW)
  const parked = postedId(await w.call('park', { title: BADGE }))

  await w.call('move', { project: 'Contoso' })
  await w.clock.advance(REST_MS)

  const ui = await w.opened()

  await toProject(ui, ELSEWHERE.key)
  await ui.press({ key: `go:${id}` })

  return { id, paths, ask, parked, ui }
}

test("after a move, Lee's snooze and wake of the held session's ask, pressed on its view in its new project, go through the hold: the board shows each, and the next post keeps them", async ($, on) => {
  const w = world($, on)
  const { id, paths, ask, ui } = await movedHere(w)
  const item = w.item(ask)

  await ui.press({ key: `pick:${item}` })
  await ui.press({ key: `snooze:${item}` })
  await ui.press({ key: `snooze-tomorrow:${item}` })

  expect(w.state.board?.asks[0]?.snoozedUntil, 'snoozed on the board').toBeGreaterThan(
    w.clock.now(),
  )

  await w.call('status', { now: ['Drawing Inbox'] })
  await ui.press({ key: `wake:${item}` })

  expect(w.state.board?.asks[0]?.snoozedUntil, 'woken on the board').toBeUndefined()

  await w.call('status', { now: ['Drawing Settings'] })

  expect(kindsIn(w, paths.log(W1))).toEqual([
    'ask',
    'park',
    'move',
    'snoozeSession',
    'status',
    'wakeSession',
    'status',
  ])
  expect(filesUnder(w, ELSEWHERE.key, id)).toEqual([])
})

test("after a move, Lee's pick-up of the held session's own parked item, pressed on its view in its new project, goes through the hold, and the next post keeps it", async ($, on) => {
  const w = world($, on)
  const { paths, parked, ui } = await movedHere(w)

  await ui.press({ key: `ppick:${w.item(parked)}` })
  await ui.press({ key: `pickup:${w.item(parked)}` })
  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([`From the board:\n- Pick up from parked: ${BADGE}`])
  expect(w.state.board?.items.find(each => each.id === parked)?.state).toBe('picked')

  await w.call('status', { now: ['Drawing Inbox'] })

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'park', 'move', 'reply', 'delivered', 'status'])
})

test("after a move, Lee's drop of the held session's own parked item, pressed on its view in its new project, goes through the hold, and the next post keeps it", async ($, on) => {
  const w = world($, on)
  const { id, paths, parked, ui } = await movedHere(w)

  await ui.press({ key: `ppick:${w.item(parked)}` })
  await ui.press({ key: `drop:${w.item(parked)}` })
  await ui.press({ key: `drop-yes:${w.item(parked)}` })

  expect(w.state.board?.items.find(each => each.id === parked)?.state).toBe('dropped')

  await w.call('status', { now: ['Drawing Inbox'] })

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'park', 'move', 'drop', 'status'])
  expect(filesUnder(w, ELSEWHERE.key, id)).toEqual([])
})

test("after a move, Claude's edit, resolve and finish of the held session go through the hold, the board showing each, and each post keeps the last", async ($, on) => {
  const w = world($, on)
  const { paths, ask, parked } = await movedHere(w)
  const title = 'A priority badge on every tab'

  await w.call('edit', { item: parked, title })
  await w.call('resolve', { item: ask, reason: 'Lee said go in the chat' })

  expect(w.state.board?.parked.map(each => each.title)).toEqual([title])
  expect(w.state.board?.asks[0]?.state).toBe('closed')

  await w.call('finish', { reason: 'Shipped' })

  expect(w.state.board?.finished?.reason).toBe('Shipped')
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'park', 'move', 'edit', 'resolve', 'finish'])
})

test("the project a move took the held session to, renamed by another window, names it on its board at the window's next look", async ($, on) => {
  const w = world($, on)

  withContoso(w)
  await w.begin()
  await w.call('move', { project: 'Contoso' })
  w.project(ELSEWHERE.key, {
    name: 'Contoso Ltd',
    directory: `${HOME}/Code/contoso`,
    created: T0,
    by: W4,
  })
  await w.clock.advance(WATCH_MS)

  expect(holding(w)).toEqual({ folder: PROJECT.key, project: ELSEWHERE.key, name: 'Contoso Ltd' })
})

test("the hold is matched by the session's id and the window's writer alone", () => {
  const held = { project: PROJECT.key, session: SHIFTS.id, writer: W1, attachedAt: T0 }

  expect(isHoldOn(held, held), 'its own').toBe(true)
  expect(isHoldOn(held, { ...held, writer: W2 }), 'as another writer').toBe(false)
  expect(isHoldOn(held, { ...held, session: LEDGER.id }), 'another session').toBe(false)
})

test("the window's refs keep naming the session's folder after a move, as a build from before reads them: its attachment, and a place, a reply or a note pressed on a view of the project it moved to", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { id: ask, ui } = await asking(w)
  const session = w.state.attachment?.session ?? ''
  const parked = postedId(await w.call('park', { title: BADGE }))

  await w.call('move', { project: 'Contoso' })
  await toProject(ui, ELSEWHERE.key)
  await ui.press({ key: `go:${session}` })
  await ui.press({ key: `pick:${w.item(ask)}` })
  await ui.press({ key: `yes:${w.item(ask)}` })
  await ui.press({ key: `ppick:${w.item(parked)}` })
  await ui.press({ key: `comment:${w.item(parked)}` })

  expect(w.state.attachment?.project).toBe(PROJECT.key)
  expect(w.state.pane?.place).toEqual({ level: 'session', project: PROJECT.key, session })
  expect(w.state.queue).toEqual([{ project: PROJECT.key, session, item: ask, verdict: 'yes' }])
  expect(w.state.answering).toMatchObject({ project: PROJECT.key, session, item: parked })
})

test('a press on a session no folder holds any more keeps nothing, a toast saying why: never the project the view showed it in, made a folder', async ($, on) => {
  const w = world($, on)
  const ledger = withLedger(w)

  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGER.id}:p1` })
  w.put(ledger.paths.meta, metaText(LEDGER).slice(0, 12))
  await ui.press({ key: `pickup:${LEDGER.id}:p1` })

  expect(w.state.queue, 'nothing queued').toBeUndefined()
  expect(w.toasts).toContain('Not queued: its session is no longer on the board.')
})

test("a move another window made, before this window's next look, is read before the tools act: move takes the session from where it is now, never refused as still where it was", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { paths } = await w.begin()

  w.writer(paths, W2)(moveTo(ELSEWHERE.key))
  await w.clock.advance(1)

  expect((await w.call('move', { project: 'Northwind' })).result).toBe(
    'Moved Help desk redesign to the existing project Northwind.',
  )
  expect(holding(w).project).toBe(PROJECT.key)
})

test("a move another window made, before this window's next look, is read before the tools act: project renames the project the session is in now, never the one it left", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const { paths } = await w.begin()

  w.writer(paths, W2)(moveTo(ELSEWHERE.key))

  expect((await w.call('project', { name: 'Contoso Ltd' })).result).toBe(
    'Renamed the project Contoso to Contoso Ltd.',
  )
  expect(projectFile(w, ELSEWHERE.key)?.name).toBe('Contoso Ltd')
  expect(projectFile(w, PROJECT.key)?.name).toBe(PROJECT.name)
})

test("a move another window made, before this window's next look, is read before the tools act on what another session parked: one of the project the session is in now is the session's to act on", async ($, on) => {
  const w = world($, on)
  const shifts = withContoso(w)
  const { paths } = await w.begin()

  w.writer(paths, W2)(moveTo(ELSEWHERE.key))

  expect((await w.call('resolve', { session: SHIFTS.id, item: 'p9' })).result).toBeDefined()
  expect(kindsIn(w, shifts.paths.log(W1))).toEqual(['resolve'])
})

test("the move's answer and its row name the project the session is in once the move is posted: where another window moved it at the same moment, the later move's", async ($, on) => {
  const w = world($, on)

  withContoso(w)
  w.project('fabrikam', { name: 'Fabrikam', created: T0, by: W4 })

  const { paths } = await w.begin()
  const elsewhere = w.writer(paths, W2)

  w.after('read', projectPaths(ROOT, ELSEWHERE.key).file, () => elsewhere(moveTo('fabrikam')))

  expect((await w.call('move', { project: 'Contoso' })).result).toBe(
    'Help desk redesign is in Fabrikam: a move another window made at the same moment took it there.',
  )
  expect(holding(w)).toEqual({ folder: PROJECT.key, project: 'fabrikam', name: 'Fabrikam' })
  expect(w.state.named?.at(-1)?.name).toBe('Fabrikam')
})

test("a move's row names the project as the board does, not as Claude's call spelled it", async ($, on) => {
  const w = world($, on)

  withContoso(w)
  await w.begin()

  const input = { project: 'con-toso' }

  await w.call('move', input)

  const call = w.state.named?.at(-1)?.call ?? ''
  const ui = await $.ui.mount({
    plugin: 'sitrep',
    component: 'ToolUse',
    requestId: call,
    surface: 'terminal',
    props: {
      tool_use_id: call,
      tool: 'mcp__sitrep__move',
      input,
      isRunning: false,
      isErrored: false,
      isInterrupted: false,
      output: MOVED,
    },
  })

  expect(await ui.find({ type: 'Text', text: 'moved to: Contoso' })).toBeDefined()
})

test("the way back from another session's view goes to the project it is filed under, once it moved, as its project's press does", async ($, on) => {
  const w = world($, on)

  withContoso(w)

  const ledger = withLedger(w)

  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  expect(await ui.find({ key: 'up', text: '← Northwind' })).toBeDefined()

  ledger.write(moveTo(ELSEWHERE.key))
  await w.clock.advance(AROUND_MS)

  expect(await ui.find({ key: 'up', text: '← Contoso' })).toBeDefined()
  await ui.press({ key: 'up' })
  expect(w.state.pane?.place).toEqual({ level: 'project', project: ELSEWHERE.key })
})

test("a moved session's view draws its new project's picked up under its PARKED, the look reading that project's past for it", async ($, on) => {
  const w = world($, on)

  withContoso(w)
  w.elsewhere(LEDGER).write(park('p1', EXPORT), resolve('p1', 'Exported'), moveTo(ELSEWHERE.key))
  await w.begin()

  const ui = await w.opened()

  await toProject(ui, ELSEWHERE.key)
  await ui.press({ key: `go:${LEDGER.id}` })

  expect((await ui.find({ key: `pickedup:project:${ELSEWHERE.key}` }))?.props).toMatchObject({
    label: 'show picked up 1',
  })
})

/** Contoso on the board with nothing on it yet: its file alone. */
const emptyContoso = (w: World) =>
  w.project(ELSEWHERE.key, { name: ELSEWHERE.name, created: T0, by: W4 })

/**
 * Lee's pick-up of the ledger's export sent while Claude's turn runs, held
 * for its end, Claude having read the board with the export on it; then the
 * session under test moved to Contoso by another window, and, where
 * `isLedgerMoving`, the ledger with it, both followed.
 */
const pickUpAcross = async (w: World, isLedgerMoving: boolean) => {
  emptyContoso(w)

  const ledger = withLedger(w)
  const { paths } = await w.begin()

  await boardRead(w)

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGER.id}:p1` })
  await ui.press({ key: `pickup:${LEDGER.id}:p1` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })

  if (isLedgerMoving) {
    ledger.write(moveTo(ELSEWHERE.key))
  }

  w.writer(paths, W2)(moveTo(ELSEWHERE.key))
  await w.clock.advance(AROUND_MS)
  await turnEnded(w)
  await w.clock.advance(AROUND_MS)

  return ledger
}

test('a pick-up in flight as the session and the ledger move to Contoso together is written down in the ledger, and Claude, whose own message carried it, is told of no change', async ($, on) => {
  const w = world($, on)
  const ledger = await pickUpAcross(w, true)

  expect(w.submitted).toEqual([
    `From the board:\n- Pick up from parked, Invoice ledger's: ${EXPORT}`,
  ])
  expect(kindsIn(w, ledger.paths.log(W1))).toEqual(['reply', 'delivered'])
  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test('a pick-up in flight as the session moves away from the ledger is written down in the ledger, and Claude is told its board changed with the move', async ($, on) => {
  const w = world($, on)
  const ledger = await pickUpAcross(w, false)

  expect(kindsIn(w, ledger.paths.log(W1))).toEqual(['reply', 'delivered'])
  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain(
    'The sitrep board changed since you last saw it.',
  )
})

test("after the move, a pick-up in flight of what the new project's own session parked is written down in that session, and Claude, whose own message carried it, is told of no change", async ($, on) => {
  const w = world($, on)
  const shifts = withContoso(w)

  await w.begin()
  await w.call('move', { project: 'Contoso' })
  expect(await boardRead(w), 'Claude reads the rota parked').toContain(ROTA_LINE)

  const ui = await w.opened()

  await ui.press({ key: `ppick:${SHIFTS.id}:p9` })
  await ui.press({ key: `pickup:${SHIFTS.id}:p9` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await turnEnded(w)
  await w.clock.advance(AROUND_MS)

  expect(w.submitted).toHaveLength(1)
  expect(kindsIn(w, shifts.paths.log(W1))).toEqual(['reply', 'delivered'])
  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test('Lee finishes a moved session from its view in the project it moved to: the finish is written in its folder, and the board goes up to that project', async ($, on) => {
  const w = world($, on)

  withContoso(w)
  w.elsewhere(LEDGER).write(park('p1', EXPORT), moveTo(ELSEWHERE.key))
  await w.begin()

  const ui = await w.opened()

  await toProject(ui, ELSEWHERE.key)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `finish:${LEDGER.id}` })
  await ui.press({ key: `finish-yes:${LEDGER.id}` })

  expect(kindsIn(w, sessionPaths(ROOT, PROJECT.key, LEDGER.id).log(W1))).toEqual(['finish'])
  expect(filesUnder(w, ELSEWHERE.key, LEDGER.id)).toEqual([])
  expect(w.state.pane?.place).toEqual({ level: 'project', project: ELSEWHERE.key })
})

test("a move line naming a project not on the board moves nothing: no window follows, and every view keeps the session in its folder's project", async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()

  w.writer(paths, W2)(moveTo('fabrikam'))
  await w.clock.advance(WATCH_MS)

  expect(holding(w)).toEqual({ folder: PROJECT.key, project: PROJECT.key, name: PROJECT.name })
  expect(movedToasts(w)).toEqual([])
  expect(await firstMessage($)).toContain(`- Northwind: ${id} "Help desk redesign"`)
})

/** Which session moved to Contoso once Themes picked up an item, the one that parked it or Themes, and which parked it: the ledger, or this one. */
type PickedThenMoved = { mover: 'parker' | 'picker'; parker: 'ledger' | 'held' }

const PICKED_THEN_MOVED: Record<string, PickedThenMoved> = {
  'the session that parked it': { mover: 'parker', parker: 'ledger' },
  'the session that picked it up': { mover: 'picker', parker: 'ledger' },
  'the session that picked up what this session parked': { mover: 'picker', parker: 'held' },
}

for (const [moved, { mover, parker }] of Object.entries(PICKED_THEN_MOVED)) {
  test(`Parked's picked up names the session a pick-up went to, filed under another project than the item's since ${moved} moved to Contoso`, async ($, on) => {
    const w = world($, on)

    withContoso(w)

    const ledger = withLedger(w)
    const themes = w.elsewhere(THEMES)
    const { id, paths } = await w.begin()
    const item =
      parker === 'held'
        ? { paths, id: postedId(await w.call('park', { title: EXPORT })), session: id }
        : { paths: ledger.paths, id: 'p1', session: LEDGER.id }

    w.writer(item.paths, THEMES.by)(
      reply('r1', item.id, 'pickup', { to: THEMES.id }),
      delivered('r1'),
    )
    ;(mover === 'parker' ? ledger : themes).write(moveTo(ELSEWHERE.key))
    await w.clock.advance(AROUND_MS)

    const project = mover === 'parker' ? ELSEWHERE.key : PROJECT.key
    const ui = await w.opened()

    await toProject(ui, project)
    await ui.press({ key: `pickedup:project:${project}` })
    await ui.press({ key: `picked:${item.session}:${item.id}` })
    expect(rowsOf(await ui.find({ key: `taken:${item.session}:${item.id}` }))).toContain(
      '│ picked up by Themes',
    )
  })
}

/** Contoso's own session, as `withContoso` puts it on the board. */
type Shifts = ReturnType<typeof withContoso>

/** A move emptying the project whose view the board shows: the project left, and the move. */
type Emptying = { left: string; moves: (w: World, shifts: Shifts) => Promise<unknown> }

/** Ways a move empties the project whose view the board shows: its only session moved away by another window, or this session, its project's only one, moved by Claude. */
const EMPTYING: Record<string, Emptying> = {
  "Contoso's only session moved to Northwind by its own window": {
    left: ELSEWHERE.key,
    moves: async (w, shifts) => shifts.write(moveTo(PROJECT.key)),
  },
  "this session, Northwind's only one, moved to Contoso by Claude": {
    left: PROJECT.key,
    moves: w => w.call('move', { project: 'Contoso' }),
  },
}

for (const [moved, { left, moves }] of Object.entries(EMPTYING)) {
  test(`the view of a project a move empties goes up to All projects at the next look, which no longer lists it, never drawing the project by its key: ${moved}`, async ($, on) => {
    const w = world($, on)
    const shifts = withContoso(w)

    await w.begin()

    const ui = await w.opened()

    await toProject(ui, left)
    await moves(w, shifts)
    await w.clock.advance(AROUND_MS)

    expect(w.state.pane?.place).toEqual({ level: 'all' })
    expect(await ui.find({ type: 'Text', text: new RegExp(`^${left}\\b`) })).toBeUndefined()
    expect(await pressesOf(ui, 'proj:')).not.toContain(`proj:${left}`)
  })
}

test('the view of a project whose only session finished stays where it is: the project is still on the board', async ($, on) => {
  const w = world($, on)
  const shifts = withContoso(w)

  await w.begin()

  const ui = await w.opened()

  await toProject(ui, ELSEWHERE.key)
  shifts.write(finish('claude', 'Shipped'))
  await w.clock.advance(AROUND_MS)

  expect(w.state.pane?.place).toEqual({ level: 'project', project: ELSEWHERE.key })
  expect(await ui.find({ type: 'Text', text: /^Contoso\b/ })).toBeDefined()
})

/** Contoso's view, the board standing on it: the window's board, and Contoso's own session. */
const onContoso = async (w: World) => {
  const shifts = withContoso(w)

  await w.begin()

  const ui = await w.opened()

  await toProject(ui, ELSEWHERE.key)

  return { shifts, ui }
}

/** Contoso's view, as the board stands on it. */
const CONTOSO_VIEW = { level: 'project', project: ELSEWHERE.key }

test("the view of a project whose current session moved away, its old one still filed under it, stays where it is: the project's old sessions are still the board's", async ($, on) => {
  const w = world($, on)
  const old = T0 - CURRENT_MS - MIN
  const themes = w.elsewhere({ ...THEMES, created: old }, ELSEWHERE.key)

  w.put(themes.paths.log(THEMES.by), file([old, status(['Drawing the dark theme'], THEMES)]))

  const { shifts } = await onContoso(w)

  shifts.write(moveTo(PROJECT.key))
  await w.clock.advance(AROUND_MS)

  expect(w.state.pane?.place).toEqual(CONTOSO_VIEW)
})

test("the view of a project whose folder's listing failed stays where it is: a look that could not read the project's sessions saw no move empty it", async ($, on) => {
  let isFailing = false

  // Registered before the world's own, so it is outermost.
  on('fs.list', { path: sessionsDir(ROOT, ELSEWHERE.key) }, ($, e, next) =>
    isFailing ? { deny: `EIO: i/o error, scandir ${e.path}` } : next(e),
  )

  const w = world($, on)

  await onContoso(w)
  isFailing = true
  await w.clock.advance(AROUND_MS)

  expect(w.state.pane?.place).toEqual(CONTOSO_VIEW)
})

test("a look reading no board of the held session's goes up from no view: it files that session nowhere sure, so the project it moved to stays on screen", async ($, on) => {
  let isBoardless = false

  on('state.get', { plugin: 'sitrep', key: 'board' }, async ($, e, next) => {
    const read = (await next(e)) as { value: { value: unknown; version: number } }

    return isBoardless ? { value: { ...read.value, value: null } } : read
  })

  const w = world($, on)

  emptyContoso(w)
  await w.begin()
  await w.call('move', { project: 'Contoso' })

  const ui = await w.opened()

  await toProject(ui, ELSEWHERE.key)
  await w.clock.advance(AROUND_MS)
  isBoardless = true
  await w.clock.advance(AROUND_MS)

  expect(w.state.pane?.place).toEqual(CONTOSO_VIEW)
})

test("Lee's press landing as the look goes up from a project a move emptied wins: the board stays where he went, its scroll left alone", async ($, on) => {
  let isRacing = false
  let scrolls = 0

  on('state.set', { plugin: 'sitrep', key: 'pane' }, async ($, e, next) => {
    const going = e.value as SitrepPane

    if (isRacing && going.place?.level === 'all') {
      isRacing = false
      await next({ ...e, value: { ...going, place: { level: 'project', project: PROJECT.key } } })
    }

    return next(e)
  })
  on('state.set', { plugin: 'sitrep', key: 'scroll' }, ($, e, next) => {
    scrolls += 1

    return next(e)
  })

  const w = world($, on)
  const { shifts } = await onContoso(w)

  shifts.write(moveTo(PROJECT.key))
  isRacing = true
  scrolls = 0
  await w.clock.advance(AROUND_MS)

  expect(isRacing, 'the look went up as Lee pressed').toBe(false)
  expect(w.state.pane?.place).toEqual({ level: 'project', project: PROJECT.key })
  expect(scrolls, 'no scroll to the top of where Lee went').toBe(0)
})

test("Claude's board text right after a move lists what the new project's sessions parked, a finished one's too: the look reads every project holding a parked item, whichever the session is in", async ($, on) => {
  const w = world($, on)

  withContoso(w).write(finish('claude', 'Shipped'))
  await w.begin()
  await w.call('move', { project: 'Contoso' })

  expect(await boardRead(w)).toContain(ROTA_LINE)
})
