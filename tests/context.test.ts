import { expect, test, tier } from 'claude-code/testing'
import { file, note, W2 } from './support'
import { PROMPT, CONVERSATION, world } from './world'

tier('user')

const CHANGED = 'The sitrep board changed since you last saw it. It now reads:'

type World = ReturnType<typeof world>

/** A session started, and a way for a second window on it to write a note. */
async function begun(w: World) {
  const { paths } = await w.begin()
  const lines: Parameters<typeof file> = []

  const noteFromElsewhere = (id: string, text: string) => {
    lines.push([w.clock.now(), note(id, text)])
    w.put(paths.log(W2), file(...lines))
  }

  return { noteFromElsewhere }
}

test('with no session attached, a prompt takes nothing', async ($, on) => {
  world($, on)

  await $.session.start(CONVERSATION)

  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test('what Claude posted itself never rides in: it knows it', async ($, on) => {
  const w = world($, on)

  await begun(w)
  await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' })
  await w.call('status', { now: ['Drawing round 2'] })

  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test("another writer's change rides into the next prompt once, as context Lee does not see", async ($, on) => {
  const w = world($, on)
  const { noteFromElsewhere } = await begun(w)

  noteFromElsewhere('n9', 'Merged the band')

  const context = (await $.prompt.submit(PROMPT)).context

  expect(context).toHaveLength(1)
  expect(context?.[0]).toStartWith(`${CHANGED}\nsitrep board: Dashboard redesign`)
  expect(context?.[0]).toContain('- n9: Merged the band')
  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test("Claude's own post does not hide a change it was not told of", async ($, on) => {
  const w = world($, on)
  const { noteFromElsewhere } = await begun(w)

  noteFromElsewhere('n9', 'Merged the band')
  await w.call('note', { text: 'Drew round 2' })

  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain('- n9: Merged the band')
})

test('reading the board back counts as seeing it', async ($, on) => {
  const w = world($, on)
  const { noteFromElsewhere } = await begun(w)

  noteFromElsewhere('n9', 'Merged the band')
  await w.call('board')

  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test('a prompt that did not enter leaves the change to ride in with the next', async ($, on) => {
  const w = world($, on)
  const { noteFromElsewhere } = await begun(w)

  noteFromElsewhere('n9', 'Merged the band')
  w.dropPrompts('busy')

  expect((await $.prompt.submit(PROMPT)).drop).toBe('busy')

  w.dropPrompts()

  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain('- n9: Merged the band')
})
