import { expect, test, tier } from './kit'
import { AROUND_MS } from '../hooks/around'
import type { SitrepProject, SitrepProjectParked } from '../types'
import { LEDGER, META, PROJECT, T0, W2 } from './data'
import { file, note, park } from './lines'
import { CONVERSATION, PROMPT, world, type World } from './world'

tier('user')

const CHANGED = 'The sitrep board changed since you last saw it. It now reads:'

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
  expect(context?.[0]).toStartWith(`${CHANGED}\nsitrep board: Help desk redesign`)
  expect(context?.[0]).toContain('- n9: Merged the band')
  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test('another session of the project parking something changes the board: it rides into the next prompt, naming that session', async ($, on) => {
  const w = world($, on)

  await begun(w)

  const ledger = w.elsewhere({ ...META, id: 'sr-1edger', name: 'Invoice ledger', by: W2 })

  ledger.write(park('p1', 'Export the ledger as CSV'))
  await w.clock.advance(AROUND_MS)

  const context = (await $.prompt.submit(PROMPT)).context

  expect(context?.[0]).toStartWith(`${CHANGED}\nsitrep board: Help desk redesign`)
  expect(context?.[0]).toContain(
    '- p1, parked by "Invoice ledger" (session: sr-1edger): Export the ledger as CSV',
  )
  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

/** Another session of the project, the invoice ledger, which parks things. */
/** The board's line for something the ledger parked. */
const ledgers = (id: string, title: string) =>
  `- ${id}, parked by "Invoice ledger" (session: sr-1edger): ${title}`

/** What the ledger parks as a look lands. */
const MORE = {
  type: 'park',
  id: 'p9',
  title: 'Archive old invoices',
  state: 'parked',
  by: W2,
  at: T0,
  openedAt: T0,
  replies: [],
  session: LEDGER.id,
  name: LEDGER.name,
} satisfies SitrepProjectParked

/**
 * A look around landing in the middle of something the mod does: from
 * `land()` on, what the sessions around parked reads with the ledger's item
 * among it. The engine gives one dispatch's reads of `$.state` one moment;
 * this answers them from beneath as if each read were live, so what is kept
 * as seen is shown to be the text Claude was given, whichever moment it is
 * read at.
 */
const lookLanding = (on: Parameters<typeof world>[1]) => {
  let isLanded = false
  const landed = (project: SitrepProject) =>
    project.key === PROJECT.key
      ? { ...project, parked: [...(project.parked ?? []), MORE] }
      : project

  on('state.get', { plugin: 'sitrep', key: 'projects' }, async ($, e, next) => {
    const read = (await next(e)) as { value: { value: SitrepProject[]; version: number } }

    return isLanded ? { value: { ...read.value, value: read.value.value.map(landed) } } : read
  })

  return {
    land: () => {
      isLanded = true
    },
  }
}

test('a look landing while a prompt goes in still rides into the next: what is kept as seen is the text the prompt took', async ($, on) => {
  const w = world($, on)
  const look = lookLanding(on)

  await begun(w)
  w.elsewhere(LEDGER).write(park('p1', 'Export the ledger as CSV'))
  await w.clock.advance(AROUND_MS)

  const turn = w.holdPrompts()
  const entering = $.prompt.submit(PROMPT)

  await turn.arrived
  look.land()
  turn.end()

  const took = (await entering).context?.[0]

  expect(took).toContain(ledgers('p1', 'Export the ledger as CSV'))
  expect(took).not.toContain('Archive old invoices')
  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain(
    ledgers('p9', 'Archive old invoices'),
  )
})

test("Claude's own post keeps as seen the board it had seen, its post added: a look landing as it is written still rides in", async ($, on) => {
  const w = world($, on)
  const look = lookLanding(on)
  let isArmed = false

  // The look lands as the post folds the session again.
  on('state.set', { plugin: 'sitrep', key: 'board' }, ($, e, next) => {
    if (isArmed) {
      look.land()
    }

    return next(e)
  })

  await w.begin()
  isArmed = true
  await w.call('note', { text: 'Drew round 2' })

  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain(
    ledgers('p9', 'Archive old invoices'),
  )
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
