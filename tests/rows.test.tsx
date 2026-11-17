import type { On } from 'claude-code'
import { expect, test, tier, type Engine } from './kit'
import { NAMES_KEPT } from '../hooks/tools'
import { PROJECT, REVIEW, reviewRound } from './data'
import { asked, startedId, world, type World } from './world'

tier('user')

/** Another session Claude starts in the conversation, which the window then holds. */
const INBOX_PAGE = { name: 'Inbox page', summary: 'Draw the inbox page', project: PROJECT.name }

const SURFACES = ['terminal', 'desktop', 'vscode', 'mobile'] as const

/** A sitrep call's row, done. */
const row = (tool: string, input: { [key: string]: unknown }, requestId = 'toolu_1') => ({
  plugin: 'sitrep',
  component: 'ToolUse' as const,
  requestId,
  props: {
    tool_use_id: requestId,
    tool: `mcp__sitrep__${tool}`,
    input,
    isRunning: false,
    isErrored: false,
    isInterrupted: false,
    output: 'Done.',
  },
})

/** The result drawn under a call's row. */
const result = (tool: string, isErrored = false) => ({
  plugin: 'sitrep',
  component: 'ToolResult' as const,
  requestId: 'toolu_1',
  props: { tool_use_id: 'toolu_1', tool, output: 'Posted ask k3f9.', isErrored },
})

/** Calls a naming tool: the id the engine gave the call, read off the name kept for its row. */
const keeping = async (w: World, tool: string, input: { [key: string]: unknown }) => {
  await w.call(tool, input)

  const kept = w.state.named?.at(-1)

  if (kept === undefined) {
    throw new Error(`${tool} kept no name`)
  }

  return kept.call
}

/** The line a call's row draws, found by its text; undefined where the row draws another. */
const drawnLine = async (
  $: Engine,
  call: string,
  tool: string,
  input: { [key: string]: unknown },
  line: string,
) => {
  const ui = await $.ui.mount({ ...row(tool, input, call), surface: 'terminal' })
  const drawn = await ui.find({ type: 'Text', text: line })

  await ui.unmount()

  return drawn
}

/** The engine's own drawing of any row, beneath the mod. */
function engineRows(on: On) {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>the engine row</Text>
  })
}

const LINES: [tool: string, input: { [key: string]: unknown }, line: string][] = [
  ['start', { name: 'Help desk redesign', summary: 'Redesign it' }, 'started: Help desk redesign'],
  ['status', { now: ['Drawing Inbox'] }, '• status set'],
  ['ask', REVIEW, '◆ asked: Review Tickets & Replies, round 1'],
  ['park', { title: 'A priority badge' }, '◇ parked: A priority badge'],
  ['finish', { reason: 'Shipped' }, '✓ finished a session'],
  ['project', { name: 'Trey Research' }, 'project renamed: Trey Research'],
  ['project', { directory: '/Users/me/trey-research' }, 'project lives in /Users/me/trey-research'],
  [
    'project',
    { name: 'Trey Research', directory: '/Users/me/trey-research' },
    'project renamed: Trey Research · project lives in /Users/me/trey-research',
  ],
  ['move', { project: 'trey research' }, 'moved to project: trey research'],
  ['board', {}, 'read the board back'],
]

test("each of Claude's sitrep calls is one dim line saying what it did, on every surface", async ($, on) => {
  engineRows(on)

  for (const surface of SURFACES) {
    for (const [tool, input, line] of LINES) {
      const ui = await $.ui.mount({ ...row(tool, input, `toolu_${tool}`), surface })
      const drawn = await ui.find({ type: 'Text', text: line })

      expect(drawn?.props.dimColor, `${surface}: ${tool}`).toBe(true)
      expect(await ui.find({ text: 'the engine row' })).toBeUndefined()
      await ui.unmount()
    }
  }
})

test('a call naming an item or a session, with no name kept, names it as the held session has it; an older join, by its work', async ($, on) => {
  const w = world($, on)

  engineRows(on)

  const { id } = await w.begin()
  const posted = await asked(w, reviewRound(1))

  const rows: [tool: string, input: { [key: string]: unknown }, line: string][] = [
    ['resolve', { item: posted }, 'resolved: Review round 1'],
    ['reopen', { item: posted }, 'reopened: Review round 1'],
    ['edit', { item: 'zzzz', title: 'x' }, 'edited: an item'],
    ['join', { session: id }, 'joined: Help desk redesign'],
    ['join', { work: id }, 'joined: Help desk redesign'],
    ['join', { session: 'sr-zzzzzz' }, 'joined a session'],
    ['finish', {}, '✓ finished: Help desk redesign'],
    ['move', { project: 'north wind' }, 'moved to project: Northwind'],
  ]

  for (const [i, [tool, input, line]] of rows.entries()) {
    const ui = await $.ui.mount({ ...row(tool, input, `toolu_${i}`), surface: 'terminal' })

    expect(await ui.find({ type: 'Text', text: line }), tool).toBeDefined()
    await ui.unmount()
  }
})

test("a resolve, reopen or edit row keeps its item's title after Claude joins another session", async ($, on) => {
  const w = world($, on)

  engineRows(on)
  await w.begin()

  const posted = await asked(w, reviewRound(1))
  const rows: [tool: string, input: { [key: string]: unknown }, line: string][] = [
    ['resolve', { item: posted }, 'resolved: Review round 1'],
    ['reopen', { item: posted }, 'reopened: Review round 1'],
    ['edit', { item: posted, where: 'In Paper' }, 'edited: Review round 1'],
  ]
  const kept = []

  for (const [tool, input, line] of rows) {
    kept.push({ call: await keeping(w, tool, input), tool, input, line })
  }

  const other = startedId(await w.call('start', INBOX_PAGE))

  await w.call('join', { session: other })

  for (const { call, tool, input, line } of kept) {
    expect(await drawnLine($, call, tool, input, line), tool).toBeDefined()
  }
})

test("an edit's row names the item's title as the edit left it", async ($, on) => {
  const w = world($, on)

  engineRows(on)
  await w.begin()

  const posted = await asked(w, reviewRound(1))
  const input = { item: posted, title: 'Review round 2' }
  const edited = await keeping(w, 'edit', input)

  await w.call('edit', { item: posted, title: 'Review round 3' })

  expect(await drawnLine($, edited, 'edit', input, 'edited: Review round 2')).toBeDefined()
})

test("a join row and a finish row keep the session's name after a later join", async ($, on) => {
  const w = world($, on)

  engineRows(on)

  const { id } = await w.begin()
  const other = startedId(await w.call('start', INBOX_PAGE))
  const joined = await keeping(w, 'join', { session: id })
  const finished = await keeping(w, 'finish', { reason: 'Shipped' })

  await w.call('join', { session: other })

  expect(
    await drawnLine($, joined, 'join', { session: id }, 'joined: Help desk redesign'),
  ).toBeDefined()
  expect(
    await drawnLine($, finished, 'finish', { reason: 'Shipped' }, '✓ finished: Help desk redesign'),
  ).toBeDefined()
})

test('a refused call keeps no name', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('resolve', { item: 'zzzz' })
  await w.call('join', { session: 'sr-zzzzzz' })

  expect(w.state.named ?? []).toEqual([])
})

test('only the latest calls keep their names, the oldest let go', async ($, on) => {
  const w = world($, on)
  const earlier = Array.from({ length: NAMES_KEPT }, (_, i) => ({
    call: `toolu_${i}`,
    name: INBOX_PAGE.name,
  }))
  let isWritten = false

  // As many names as are kept, left by the window's earlier calls, read until it keeps the next.
  on('state.get', { plugin: 'sitrep', key: 'named' }, ($, e, next) =>
    isWritten ? next(e) : { value: { value: earlier, version: 0 } },
  )
  on('state.set', { plugin: 'sitrep', key: 'named' }, ($, e, next) => {
    isWritten = true

    return next(e)
  })

  await w.begin()

  const round = reviewRound(1)
  const latest = await keeping(w, 'resolve', { item: await asked(w, round) })

  expect(w.state.named).toEqual([...earlier.slice(1), { call: latest, name: round.title }])
})

test("a call's result draws nothing, on every surface", async ($, on) => {
  engineRows(on)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...result('mcp__sitrep__ask'), surface })

    expect(await ui.findAll({ type: 'Text' }), surface).toEqual([])
    await ui.unmount()
  }
})

test('a refused or interrupted call keeps the engine row', async ($, on) => {
  engineRows(on)

  const ask = row('ask', reviewRound(1))

  for (const [requestId, change] of [
    ['toolu_2', { isErrored: true }],
    ['toolu_3', { isInterrupted: true }],
  ] as const) {
    const ui = await $.ui.mount({
      ...ask,
      requestId,
      props: { ...ask.props, ...change },
      surface: 'terminal',
    })

    expect(await ui.find({ text: 'the engine row' })).toBeDefined()
  }

  const refused = await $.ui.mount({ ...result('mcp__sitrep__ask', true), surface: 'terminal' })

  expect(await refused.find({ text: 'the engine row' })).toBeDefined()
})

test("another tool's row and result are the engine's", async ($, on) => {
  engineRows(on)

  const bash = row('ask', {})
  const ui = await $.ui.mount({
    ...bash,
    props: { ...bash.props, tool: 'Bash' },
    surface: 'terminal',
  })
  const under = await $.ui.mount({ ...result('Bash'), surface: 'terminal' })

  expect(await ui.find({ text: 'the engine row' })).toBeDefined()
  expect(await under.find({ text: 'the engine row' })).toBeDefined()
})
