import { expect, test, tier } from 'claude-code/testing'
import { postedId, PROJECT, toProject, world } from './world'

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
  await ui.press({ key: `log:${w.item(`pickup-${ids[1]}`)}` })

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
