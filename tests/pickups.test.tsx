import { expect, test, tier } from 'claude-code/testing'
import { CURRENT_MS, parseEntries, parsePresence, sessionPaths, type SessionMeta } from '../core'
import { WATCH_MS } from '../hooks/window'
import { file, finish, MIN, park, SLOW, T0, W1, W2, W3, yesAsk, type Line } from './support'
import { ELSEWHERE, postedId, PROJECT, ROOT, toProject, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Engine = Parameters<typeof world>[0]

/** The parked items, and the note each is picked up with, if any. */
const PARKED = [
  { title: 'A tmux indicator across sessions' },
  { title: 'Paper thumbnails inline in Ghostty', note: 'Before the release' },
  { title: 'Space switch without the slide', note: 'After the bug fixes' },
]

/** A session parking each item, the board docked, and each picked up, its note written in the prompt: the parked ids and the board. */
async function pickedUp(w: World, $: Engine) {
  await w.begin()

  const ids: string[] = []

  for (const { title } of PARKED) {
    ids.push(postedId(await w.call('park', { title })))
  }

  const ui = await w.pane()

  for (const [i, id] of ids.entries()) {
    const note = PARKED[i]?.note

    await ui.press({ key: `ppick:${w.item(id)}` })

    if (note === undefined) {
      await ui.press({ key: `pickup:${w.item(id)}` })
    } else {
      await ui.press({ key: `comment:${w.item(id)}` })
      await $.prompt.submit({ text: note, wait: false, origin: { kind: 'composer' } })
    }
  }

  return { ids, ui }
}

/** The keys NOTES opens the pick-ups' lines by, in order. */
const pickUpRows = async (ui: Awaited<ReturnType<World['pane']>>) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => String(each.key))
    .filter(key => key.startsWith('log:') && key.includes(':pickup-'))

test('a send of several pick-ups, some with notes, draws the docked board before, during and after the turn', async ($, on) => {
  const w = world($, on)
  const { ui } = await pickedUp(w, $)

  await expect(ui.drawn(), 'the pick-ups waiting').resolves.toBeDefined()

  await ui.press({ key: 'send' })

  await expect(ui.drawn(), 'sent').resolves.toBeDefined()
  expect(new Set(await pickUpRows(ui)).size).toBe(PARKED.length)

  await w.turnStarts(w.prompts.at(-1)?.text ?? '')
  await expect(ui.drawn(), "during Claude's turn").resolves.toBeDefined()

  await w.turnEnds()
  await expect(ui.drawn(), 'after the turn').resolves.toBeDefined()
  expect(await ui.find({ key: 'tab:session' }), 'the header with the rest').toBeDefined()
  expect(new Set(await pickUpRows(ui)).size).toBe(PARKED.length)
})

test('opening one pick-up line of a send opens only that one', async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await pickedUp(w, $)

  await ui.press({ key: 'send' })
  const second = (await pickUpRows(ui)).find(key => key.includes(`:pickup-${ids[1]}-`)) ?? 'none'
  await ui.press({ key: second })

  expect(await ui.find({ type: 'Text', text: /Before the release/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /After the bug fixes/ })).toBeUndefined()
})

test("a project's NOTES draws a send's several pick-ups, each its own line", async ($, on) => {
  const w = world($, on)
  const { ui } = await pickedUp(w, $)

  await ui.press({ key: 'send' })
  await toProject(ui, PROJECT.key)

  await expect(ui.drawn()).resolves.toBeDefined()
  expect(new Set(await pickUpRows(ui)).size).toBe(PARKED.length)
})

const LEDGER = 'sr-1edger'

const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Sessions & Runway, round 1' }

/** What the ledger parked. */
const EXPORT = 'Export the ledger as CSV'

/** The message a pick-up of the ledger's item goes in as. */
const PICKED = `From the board:\n- Pick up from parked, Request ledger's: ${EXPORT}`

/** Long enough ago that a session idle since is past the views. */
const OLD = T0 - CURRENT_MS - MIN

/** A session of the project, started by `by` long ago. */
const meta = (id: string, name: string, by: string, project = PROJECT): SessionMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project: project.name,
  root: `/Users/lee/Code/${project.key}`,
  created: OLD,
  by,
})

/** The ledger's file this window writes. */
const LEDGER_LOG = sessionPaths(ROOT, PROJECT.key, LEDGER).log(W1)

/** The ledger's inbox file this window writes. */
const LETTERS = sessionPaths(ROOT, PROJECT.key, LEDGER).letters(W1)

/** The ledger as it stands once it parked something: its lines, and whether a window holds it. */
type Standing = { lines: Line[]; isOpen: boolean }

const FINISHED: Standing = {
  lines: [
    [T0, park('p1', EXPORT)],
    [T0, finish('claude', 'Shipped')],
  ],
  isOpen: false,
}

const STANDING: Record<string, Standing> = {
  'a session open in another window': { lines: [[T0, park('p1', EXPORT)]], isOpen: true },
  'a finished session': FINISHED,
  'a session idle past the views': { lines: [[OLD, park('p1', EXPORT)]], isOpen: false },
}

/** This session beside the ledger, its lines `lines`, held by another window where `isOpen`: a minute on, Lee opens the board. */
async function besideLedger(w: World, { lines, isOpen }: Standing) {
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', W2))

  w.put(ledger.paths.log(W2), file(...lines))

  const { id, paths } = await w.begin()

  await w.clock.advance(MIN)

  if (isOpen) {
    ledger.beat()
  }

  return { id, paths, ui: await w.opened() }
}

type Board = Awaited<ReturnType<World['opened']>>

/** Lee picks up the ledger's parked item from the project's view, then goes home. */
const pickUpLedgers = async (ui: Board) => {
  await toProject(ui)
  await ui.press({ key: `ppick:${LEDGER}:p1` })
  await ui.press({ key: `pickup:${LEDGER}:p1` })
  await ui.press({ key: 'tab:session' })
}

/** The kinds of line a file holds, in order. */
const kindsIn = (w: World, path: string) => parseEntries(w.text(path)).map(line => line.type)

for (const [standing, ledger] of Object.entries(STANDING)) {
  test(
    `a pick-up of what ${standing} parked goes in this window's own message, and is written down in that session, in this window's own file there: the item leaves Parked`,
    SLOW,
    async ($, on) => {
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
      expect(picked).toMatchObject({ item: 'p1', verdict: 'pickup' })
      expect(written.at(-1)).toMatchObject({ replies: [picked?.id] })
      expect(w.files.has(LETTERS), 'nothing in its inbox').toBe(false)
      expect(w.files.has(paths.log(W1)), 'nothing written in this session').toBe(false)
      expect(w.state.queue).toEqual([])

      await toProject(ui)
      expect(
        await ui.find({ type: 'Text', text: 'PARKED' }),
        'the item left Parked',
      ).toBeUndefined()
      expect(
        (await ui.findAll({ type: 'Button' }))
          .map(each => each.key)
          .filter(key => key?.startsWith('go:')),
        'the pick-up brings no session back onto the board',
      ).toEqual(ledger.isOpen ? [`go:${id}`, `go:${LEDGER}`] : [`go:${id}`])
    },
  )
}

test(
  "held mid-turn, a pick-up of another session's item is named by its address in the claim and said in no heartbeat; taken back it is as it was, and sent again it goes in as the turn ends",
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { paths, ui } = await besideLedger(w, FINISHED)
    const asked = postedId(await w.call('ask', REVIEW))

    await w.clock.advance(MIN)
    await pickUpLedgers(ui)
    await ui.press({ key: `pick:${w.item(asked)}` })
    await ui.press({ key: `yes:${w.item(asked)}` })

    const queued = w.state.queue

    await w.turnStarts('Carry on.')
    await ui.press({ key: 'send' })
    await w.clock.advance(WATCH_MS)

    expect(w.state.inFlight).toMatchObject({
      source: 'send',
      session: w.state.attachment?.session,
      isHeld: true,
      replies: [
        { item: `${LEDGER}:p1`, verdict: 'pickup' },
        { item: asked, verdict: 'yes' },
      ],
    })
    expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.sending).toMatchObject([
      { replies: [{ item: asked, verdict: 'yes' }] },
    ])

    await ui.press({ key: w.takeBack() })
    expect(w.state.inFlight).toBeNull()
    expect(w.state.queue).toEqual(queued)
    expect(await ui.find({ key: `unready:${LEDGER}:p1` }), 'removable again').toBeDefined()

    await ui.press({ key: 'send' })
    await w.turnEnds()
    await w.clock.settle()

    expect(w.submitted).toEqual([`${PICKED}\n- Review Sessions & Runway, round 1 → Approve`])
    expect(kindsIn(w, LEDGER_LOG)).toEqual(['reply', 'delivered'])
    expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
  },
)

test(
  'a pick-up still in Ready to send when the window takes up a session of another project leaves it, a toast saying so; a session of this project keeps it, and every other reply stays',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', W2))
    const pickUpsLeft = () => w.toasts.filter(toast => toast.includes('pick-up'))

    ledger.write(yesAsk('k3', 'Review the ledger schema'), park('p1', EXPORT))
    w.elsewhere(meta('sr-themes', 'Themes', W3))
    w.elsewhere(meta('sr-0rders', 'Standing orders', W3, ELSEWHERE), ELSEWHERE.key)

    await w.begin()
    await w.clock.advance(MIN)
    ledger.beat()

    const ui = await w.opened()

    await pickUpLedgers(ui)
    await toProject(ui)
    await ui.press({ key: `go:${LEDGER}` })
    await ui.press({ key: `pick:${LEDGER}:k3` })
    await ui.press({ key: `yes:${LEDGER}:k3` })

    const queued = w.state.queue

    await w.call('join', { session: 'sr-themes' })
    expect(w.state.queue, 'a session of this project').toEqual(queued)
    expect(pickUpsLeft()).toEqual([])

    await w.call('join', { session: 'sr-0rders' })
    expect(w.state.queue).toEqual([
      { project: PROJECT.key, session: LEDGER, item: 'k3', verdict: 'yes' },
    ])
    expect(pickUpsLeft()).toEqual([
      '1 pick-up of another project left Ready to send: pick up from a window of that project.',
    ])
    expect(w.files.has(LEDGER_LOG), 'the item stays parked').toBe(false)
  },
)

test(
  'a pick-up a send carried, taken back once the window holds a session of another project, leaves Ready to send as on a join: never left undrawn',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ui } = await besideLedger(w, FINISHED)
    const asked = postedId(await w.call('ask', REVIEW))
    const pickUpsLeft = () => w.toasts.filter(toast => toast.includes('pick-up'))

    w.elsewhere(meta('sr-0rders', 'Standing orders', W3, ELSEWHERE), ELSEWHERE.key)
    await w.clock.advance(MIN)
    await pickUpLedgers(ui)
    await ui.press({ key: `pick:${w.item(asked)}` })
    await ui.press({ key: `yes:${w.item(asked)}` })
    await w.turnStarts('Carry on.')
    await ui.press({ key: 'send' })

    const [own] = w.state.queue?.filter(reply => reply.verdict === 'yes') ?? []

    await w.call('join', { session: 'sr-0rders' })
    expect(pickUpsLeft(), 'carried, it stays as the window joins').toEqual([])

    await ui.press({ key: w.takeBack() })
    expect(w.state.queue).toEqual([own])
    expect(pickUpsLeft()).toEqual([
      '1 pick-up of another project left Ready to send: pick up from a window of that project.',
    ])

    await w.turnEnds()
    await w.clock.settle()
    expect(w.submitted).toEqual([])
    expect(w.files.has(LEDGER_LOG), 'the item stays parked').toBe(false)
  },
)
