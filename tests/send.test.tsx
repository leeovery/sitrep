import { expect, test, tier } from 'claude-code/testing'
import { parseEntries } from '../core'
import { LINGER_MS } from '../hooks/scene'
import { WATCH_MS } from '../hooks/window'
import { note, W1 } from './support'
import { postedId, PROMPT, SESSION, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const REVIEW = { kind: 'review', title: 'Review Sessions & Runway, round 1' }

const FROM_THE_BOARD = { kind: 'plugin', name: 'sitrep', asUser: true }

/** A work begun with one review asked: its folder's paths, the ask's id, and the board drawn. */
async function asking(w: World) {
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))

  return { paths, id, ui: await w.pane() }
}

/** The kinds of line the window's own file holds, in order. */
const kindsIn = (w: World, path: string) => parseEntries(w.text(path)).map(line => line.type)

test("send delivers the replies as Lee's own message, and writes them only once it is taken", async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)
  const turn = w.holdPrompts()

  await ui.press({ key: `yes:${id}` })

  const pressed = ui.press({ key: 'send' })

  await turn.arrived
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.state.sending).toEqual([
    {
      project: w.state.attachment?.project,
      work: w.state.attachment?.work,
      item: id,
      verdict: 'yes',
    },
  ])

  turn.end()
  await pressed

  const lines = parseEntries(w.text(paths.log(W1)))
  const replied = lines.find(line => line.type === 'reply')

  expect(w.prompts).toEqual([
    {
      text: 'From the board:\n- Review Sessions & Runway, round 1 → approved',
      origin: FROM_THE_BOARD,
      context: undefined,
    },
  ])
  expect(lines.map(line => line.type)).toEqual(['ask', 'reply', 'delivered'])
  expect(replied).toMatchObject({ item: id, verdict: 'yes' })
  expect(lines.at(-1)).toMatchObject({ replies: [replied?.type === 'reply' && replied.id] })
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.queue).toEqual([])
  expect(w.state.sending).toEqual([])
})

test('the board then shows the ask closed, and folds it into what was done once its moment passes', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `yes:${id}` })
  await ui.press({ key: 'send' })

  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: 'sent, and Claude has it' })).toBeDefined()
  expect(await ui.find({ key: `pick:${id}` })).toBeUndefined()

  await w.clock.advance(LINGER_MS)

  expect(await ui.find({ type: 'Text', text: 'sent, and Claude has it' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '✓ 1 done earlier' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'nothing waiting' })).toBeDefined()
})

test('while a send waits for its turn, its replies are on their way and cannot be undone', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)
  const turn = w.holdPrompts()

  await ui.press({ key: `yes:${id}` })

  const pressed = ui.press({ key: 'send' })

  await turn.arrived

  expect(await ui.find({ type: 'Text', text: /⧗ Sending/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  expect(await ui.find({ key: `undo:${id}` })).toBeUndefined()
  expect(await ui.find({ key: `unready:${id}` })).toBeUndefined()
  expect(await ui.find({ key: 'send' })).toBeUndefined()

  turn.end()
  await pressed
})

test('a send Claude Code refuses leaves every reply on the board, and a toast says why', async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)

  w.dropPrompts('the session is closing')
  await ui.press({ key: `yes:${id}` })
  await ui.press({ key: 'send' })

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.toasts).toContain(
    'Not sent: the session is closing. Your replies are still on the board.',
  )
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'sent, and Claude has it' })).toBeUndefined()
  expect(await ui.find({ key: 'send' })).toBeDefined()
})

test('a comment on a review leaves the ask open, replied, for Claude to act on', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `comment:${id}` })
  await ui.key({ key: 'thinner bars', in: `area:${id}` })
  await ui.press({ key: `save:${id}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.text).toBe(
    'From the board:\n- Review Sessions & Runway, round 1 → comment: “thinner bars”',
  )
  expect(w.state.board?.asks[0]?.state).toBe('replied')
  expect(w.state.board?.waiting).toBe(0)
  expect(
    await ui.find({ type: 'Text', text: 'you commented: “thinner bars”. Claude has it.' }),
  ).toBeDefined()
  expect(await ui.find({ key: `pick:${id}` })).toBeDefined()
})

test('a pick-up from parked is sent like any reply, and the log says what was picked up', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const id = postedId(await w.call('park', { title: 'A tmux indicator across sessions' }))
  const ui = await w.pane()

  await ui.press({ key: 'parked' })
  await ui.press({ key: `ppick:${id}` })
  await ui.press({ key: `pickup:${id}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.text).toBe(
    'From the board:\n- Pick up from parked: A tmux indicator across sessions',
  )
  expect(kindsIn(w, paths.log(W1))).toEqual(['park', 'reply', 'delivered'])
  expect(await ui.find({ type: 'Text', text: /Nothing parked/ })).toBeDefined()
  expect(w.state.board?.log[0]?.text).toBe(
    'Picked up from parked: A tmux indicator across sessions',
  )
})

test("the board's own message carries no board context; a change it did not carry rides in with the next prompt", async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)
  const elsewhere = w.writer(paths)

  elsewhere(note('n9', 'Merged the band'))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: `yes:${id}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.context).toBeUndefined()

  const next = await $.prompt.submit(PROMPT)

  expect(next.context?.[0]).toContain('- n9: Merged the band')
  expect(next.context?.[0]).not.toContain('Review Sessions & Runway')
})

test('with nothing else changed, what a send told Claude never rides in again', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `yes:${id}` })
  await ui.press({ key: 'send' })

  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test('a prompt from the board itself is left as it came, whatever changed', async ($, on) => {
  const w = world($, on)
  const { paths } = await asking(w)

  w.writer(paths)(note('n9', 'Merged the band'))
  await w.clock.advance(WATCH_MS)

  const entered = await $.prompt.submit({ ...PROMPT, origin: FROM_THE_BOARD } as never)

  expect(entered.context).toBeUndefined()
  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain('- n9: Merged the band')
})

test('a reload keeps Ready to send as Lee left it, and a send the last load made waits to be sent again', async ($, on) => {
  const w = world($, on)
  let inFlight: unknown

  // What a reload finds of a send the last load made: its replies, still marked as on their way.
  on('state.get', { plugin: 'sitrep', key: 'sending' }, ($, e, next) => {
    const value = inFlight

    inFlight = undefined

    return value === undefined ? next(e) : { value: { value, version: 1 } }
  })

  const { id, ui } = await asking(w)

  await ui.press({ key: `yes:${id}` })
  inFlight = w.state.queue
  await $.session.start(SESSION)

  expect(w.state.sending).toEqual([])
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await ui.find({ key: 'send' })).toBeDefined()
})
