/**
 * The pane's keys (DESIGN.md, "Keys"): an opened item's buttons carry the
 * engine's hotkeys, its answers numbered `1` to `9` in the order drawn and
 * none past nine, its ✕ on `x` and its snooze on `z`; a question asked in
 * place numbers its answers and leaves cancel bare. Of two buttons on one
 * hotkey the later wins, so no drawing ever holds two on one key: only the
 * item the pane holds open carries any.
 */
import { expect, test, tier } from './kit'
import { itemKey } from '../hooks/places'
import { FRAMES, LEDGER, MIN, THEMES } from './data'
import { park, yesAsk } from './lines'
import { asked, postedId, SURFACES, toProject, world, type Board } from './world'

tier('user')

/** Every drawn button carrying a hotkey, as its key and its hotkey, in the order drawn. */
const hotkeysOf = async (ui: Board) =>
  (await ui.findAll({ type: 'Button' }))
    .filter(each => each.props.hotkey !== undefined)
    .map(each => [each.key, each.props.hotkey])

/** The drawing's hotkeys, each asserted drawn on one button at most. */
const uniqueHotkeys = async (ui: Board, why: string) => {
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

test('on every surface, the hotkeys an opened ask carries are each on one button', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await asked(w, choiceOf(4, 'Option 3'))

  for (const surface of SURFACES) {
    const ui = await w.pane(surface)

    expect((await uniqueHotkeys(ui, surface)).length, surface).toBeGreaterThan(0)
    await ui.unmount()
  }
})

test("Snooze's question numbers its times in order, cancel bare, and the ask's buttons gone with their keys", async ($, on) => {
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
  expect(drawn).toEqual(times.map((key, i) => [key, `${i + 1}`]))
  expect(await ui.find({ key: `snooze-no:${item}` })).toBeDefined()
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
