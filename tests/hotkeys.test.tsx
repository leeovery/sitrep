/**
 * The pane's keys (DESIGN.md, "Keys"): an opened item's buttons carry the
 * engine's hotkeys, its answers numbered `1` to `9` in the order drawn and
 * none past nine, its ✕ on `x` and its snooze on `z`; a question asked in
 * place numbers its answers, Snooze's cancel on `z`, every other cancel
 * bare. Of two buttons on one hotkey the later wins, so no drawing ever
 * holds two on one key: only the item the pane holds open carries any.
 */
import { expect, test, tier, type FoundElement } from './kit'
import { PANE } from '../hooks/pane'
import { itemKey } from '../hooks/places'
import { DAY, FRAMES, HELD, heldItem, LEDGER, meta, MIN, PROJECT, T0, THEMES, W3 } from './data'
import { finish, park, reply, snoozeSession, yesAsk, type Line } from './lines'
import { pane, sceneFrom, type Desk } from './render'
import { asked, DOCKED, postedId, SURFACES, toProject, world, type Board } from './world'

tier('user')

/** A drawing to read: mounted through the engine, or drawn from a scene alone. */
type Read = Pick<Board, 'findAll'>

/** Every drawn button carrying a hotkey, as what `named` reads of it and its hotkey, in the order drawn. */
const withHotkeys = async (ui: Read, named: (button: FoundElement) => unknown) =>
  (await ui.findAll({ type: 'Button' }))
    .filter(each => each.props.hotkey !== undefined)
    .map(each => [named(each), each.props.hotkey])

/** Every drawn button carrying a hotkey, as its key and its hotkey, in the order drawn. */
const hotkeysOf = (ui: Read) => withHotkeys(ui, each => each.key)

/** Every drawn button carrying a hotkey, as its label and its hotkey, in the order drawn. */
const labelledHotkeysOf = (ui: Read) => withHotkeys(ui, each => each.props.label)

/** The drawing's hotkeys, each asserted drawn on one button at most. */
const uniqueHotkeys = async (ui: Read, why: string) => {
  const drawn = await hotkeysOf(ui)
  const keys = drawn.map(([, hotkey]) => hotkey)

  expect(new Set(keys).size, `${why}: ${JSON.stringify(drawn)}`).toBe(keys.length)
  return drawn
}

/** A choice of `count` options, Option 1 to Option `count`. */
const choiceOf = (count: number, recommended?: string) => ({
  ...FRAMES,
  options: Array.from({ length: count }, (_, i) => `Option ${i + 1}`),
  recommended,
})

test('an opened yes numbers its yes 1 and its comment 2; its ignore takes x, its snooze z', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const item = w.item(await asked(w))
  const ui = await w.pane()

  expect(await uniqueHotkeys(ui, 'one opened yes')).toEqual([
    [`yes:${item}`, '1'],
    [`comment:${item}`, '2'],
    [`ignore:${item}`, 'x'],
    [`snooze:${item}`, 'z'],
  ])
})

test("an opened choice numbers its options as drawn, Claude's pick first, its comment after them", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const item = w.item(await asked(w, choiceOf(3, 'Option 2')))
  const ui = await w.pane()
  const labelled = async (key: string) => (await ui.find({ key }))?.props.label

  expect(await uniqueHotkeys(ui, 'one opened choice')).toEqual([
    [`choose:${item}:0`, '1'],
    [`choose:${item}:1`, '2'],
    [`choose:${item}:2`, '3'],
    [`comment:${item}`, '4'],
    [`ignore:${item}`, 'x'],
    [`snooze:${item}`, 'z'],
  ])
  expect(await labelled(`choose:${item}:0`), 'the recommended first, on 1').toBe('Option 2')
  expect(await labelled(`choose:${item}:1`)).toBe('Option 1')
})

test('past nine answers, none is numbered', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const item = w.item(await asked(w, choiceOf(10)))
  const ui = await w.pane()
  const drawn = await uniqueHotkeys(ui, 'ten options')

  expect(drawn).toEqual([
    ...Array.from({ length: 9 }, (_, i) => [`choose:${item}:${i}`, `${i + 1}`]),
    [`ignore:${item}`, 'x'],
    [`snooze:${item}`, 'z'],
  ])
  expect(await ui.find({ key: `choose:${item}:9` }), 'the tenth drawn, bare').toBeDefined()
  expect(await ui.find({ key: `comment:${item}` }), 'the comment drawn, bare').toBeDefined()
})

test("an opened words ask numbers its ✎ Answer 1, and the pane's buttons look as they did: no plain chrome", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const item = w.item(await asked(w, { wants: 'words', title: 'Name the import job' }))
  const ui = await w.pane()

  expect(await uniqueHotkeys(ui, 'one opened words ask')).toEqual([
    [`answer:${item}`, '1'],
    [`ignore:${item}`, 'x'],
    [`snooze:${item}`, 'z'],
  ])

  for (const button of await ui.findAll({ type: 'Button' })) {
    if (button.props.hotkey !== undefined) {
      expect(button.props.plain, button.key).toBeUndefined()
    }
  }
})

test('each surface numbers what it draws of an opened choice: the desktop, writing nothing back, its options alone; mobile its comment too', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await asked(w, choiceOf(3, 'Option 3'))

  const options = [
    ['Option 3', '1'],
    ['Option 1', '2'],
    ['Option 2', '3'],
  ]
  const drawn: Record<(typeof SURFACES)[number] | 'mobile', string[][]> = {
    terminal: [...options, ['✎ comment', '4'], ['✕ ignore', 'x'], ['snooze', 'z']],
    desktop: [...options, ['✕ ignore', 'x'], ['snooze', 'z']],
    mobile: [...options, ['✎ comment', '4'], ['✕ ignore', 'x'], ['snooze', 'z']],
  }
  const mounted = {
    terminal: () => w.pane('terminal'),
    desktop: () => w.pane('desktop'),
    mobile: () =>
      $.ui.mount({
        plugin: 'sitrep',
        surface: 'mobile',
        component: 'Pane',
        requestId: PANE,
        props: DOCKED,
      }),
  }

  for (const [surface, mount] of Object.entries(mounted)) {
    const ui = await mount()

    await uniqueHotkeys(ui, surface)
    expect(await labelledHotkeysOf(ui), surface).toEqual(drawn[surface as keyof typeof drawn])
    await ui.unmount()
  }
})

/** The held session's ask `k1`, a yes, opened, with what else the desk holds, drawn as the docked board draws it. */
const openedYes = (desk: Desk = {}, more: readonly Line[] = []) =>
  pane(
    sceneFrom({
      lines: [[T0, yesAsk('k1', 'Review the import mapping')], ...more],
      now: T0 + MIN,
      ...desk,
      pane: { selected: heldItem('k1'), ...desk.pane },
    }),
  )

/** The held session's yes, `k1`, as a reply to it is drawn: Lee's, its id `r1`. */
const AT_K1 = { project: PROJECT.key, session: HELD.id, item: 'k1' }

/** A session of Northwind's Claude finished, an ask of its left open. */
const DONE = meta('sr-nw0001', 'Data import', W3)

test('an opened ask whose buttons are gone carries no hotkey: its reply queued, its answer on its way, answered in the prompt, or no reply reaching it', async () => {
  const queued = openedYes({ queue: [{ ...AT_K1, verdict: 'yes' }] })

  expect(await queued.find({ key: `undo:${heldItem('k1')}` }), 'its reply queued').toBeDefined()
  expect(await hotkeysOf(queued)).toEqual([])

  const sent = openedYes({}, [[T0, reply('r1', 'k1', 'yes')]])

  expect(await sent.find({ type: 'Text', text: '· on its way' }), 'on its way').toBeDefined()
  expect(await hotkeysOf(sent)).toEqual([])

  const answering = openedYes({
    answering: { ...AT_K1, as: 'comment', title: 'Review the import mapping', surface: 'terminal' },
  })

  expect(await answering.find({ type: 'Text', text: /answering in the prompt/ })).toBeDefined()
  expect(await hotkeysOf(answering)).toEqual([])

  const unreachable = pane(
    sceneFrom({
      now: T0 + MIN,
      around: [
        {
          meta: DONE,
          lines: [
            [T0, yesAsk('k1', 'Check the import totals')],
            [T0, finish('claude', 'Imported')],
          ],
        },
      ],
      pane: {
        place: { level: 'session', project: PROJECT.key, session: DONE.id },
        selected: itemKey(DONE.id, 'k1'),
      },
    }),
  )

  expect(await unreachable.find({ type: 'Text', text: /can't be answered/ })).toBeDefined()
  expect(await hotkeysOf(unreachable)).toEqual([])
})

test('an opened snoozed ask keeps its digits and its x, and has no z', async () => {
  const ui = openedYes({}, [[T0, snoozeSession(T0 + DAY, 'k1')]])
  const item = heldItem('k1')

  expect(await ui.find({ key: `wake:${item}` }), 'snoozed').toBeDefined()
  expect(await uniqueHotkeys(ui, 'a snoozed ask')).toEqual([
    [`yes:${item}`, '1'],
    [`comment:${item}`, '2'],
    [`ignore:${item}`, 'x'],
  ])
})

test("Snooze's question numbers its times in order, its cancel on z as every snooze menu's close, and the ask's buttons gone with their keys", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const item = w.item(await asked(w))
  const ui = await w.pane()

  await ui.press({ key: `snooze:${item}` })

  const drawn = await uniqueHotkeys(ui, "Snooze's question")
  const times = (await ui.findAll({ type: 'Button' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith('snooze-') && key !== `snooze-no:${item}`)

  expect(times.length).toBeGreaterThan(0)
  expect(drawn).toEqual([...times.map((key, i) => [key, `${i + 1}`]), [`snooze-no:${item}`, 'z']])
})

test("an opened parked item's ✕ drop takes x; the drop's question numbers its yes, cancel bare", async ($, on) => {
  const w = world($, on)
  const { id: session } = await w.begin()
  const key = itemKey(session, postedId(await w.call('park', { title: 'Export as CSV' })))
  const ui = await w.opened()

  await ui.press({ key: `ppick:${key}` })
  expect(await uniqueHotkeys(ui, 'an opened parked item')).toEqual([[`drop:${key}`, 'x']])

  await ui.press({ key: `drop:${key}` })
  expect(await uniqueHotkeys(ui, "the drop's question")).toEqual([[`drop-yes:${key}`, '1']])
})

test("a session finish's question numbers its yes, cancel bare; its press carries none", async ($, on) => {
  const w = world($, on)

  w.elsewhere(THEMES).write(yesAsk('k4', 'Pick the dark palette'))
  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${THEMES.id}` })
  expect(await ui.find({ key: `finish:${THEMES.id}` })).toBeDefined()
  expect(await uniqueHotkeys(ui, 'nothing opened')).toEqual([])

  await ui.press({ key: `finish:${THEMES.id}` })
  expect(await uniqueHotkeys(ui, "the finish's question")).toEqual([
    [`finish-yes:${THEMES.id}`, '1'],
  ])
})

test("a project's view of several sessions' asks and parked items gives hotkeys to the opened item alone, wherever it is", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'), park('p1', 'Ledger totals by month'))
  await w.begin()
  await asked(w)
  await asked(w, choiceOf(2))
  await w.call('park', { title: 'Export as CSV' })
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await toProject(ui)

  const theirs = itemKey(LEDGER.id, 'k3')
  const parked = itemKey(LEDGER.id, 'p1')
  const shown = (await ui.findAll({ type: 'Button' })).map(each => each.key ?? '')

  expect(shown).toEqual(expect.arrayContaining([`pick:${theirs}`, `ppick:${parked}`]))
  expect(shown.filter(key => key.startsWith('pick:')).length).toBeGreaterThan(2)

  await ui.press({ key: `pick:${theirs}` })
  expect(await uniqueHotkeys(ui, "the ledger's ask opened")).toEqual([
    [`yes:${theirs}`, '1'],
    [`comment:${theirs}`, '2'],
    [`ignore:${theirs}`, 'x'],
    [`snooze:${theirs}`, 'z'],
  ])

  await ui.press({ key: `ppick:${parked}` })
  expect(await uniqueHotkeys(ui, "the ledger's parked item opened")).toEqual([
    [`drop:${parked}`, 'x'],
  ])

  await ui.press({ key: `ppick:${parked}` })
  expect(await uniqueHotkeys(ui, 'nothing opened')).toEqual([])
})
