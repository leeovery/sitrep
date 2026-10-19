import type { On } from 'claude-code'
import { expect, test, tier, type Engine } from 'claude-code/testing'
import { NAMES_KEPT } from '../hooks/tools'
import { SLOW } from './support'
import { postedId, PROJECT, startedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

/** Another session Claude starts in the conversation, which the window then holds. */
const USAGE = { name: 'Usage page', summary: 'Draw the usage page', project: PROJECT.name }

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
  ['start', { name: 'Dashboard redesign', summary: 'Redesign it' }, 'started: Dashboard redesign'],
  ['status', { now: ['Drawing Usage'] }, '• status set'],
  [
    'ask',
    { wants: 'yes', yes: 'Approve', title: 'Review Sessions & Runway, round 1' },
    '◆ asked: Review Sessions & Runway, round 1',
  ],
  ['note', { text: 'PR #82 merged' }, 'noted: PR #82 merged'],
  ['park', { title: 'A tmux indicator' }, '◇ parked: A tmux indicator'],
  ['finish', { reason: 'Shipped' }, '✓ finished a session'],
  ['project', { name: 'SitRep' }, 'project renamed: SitRep'],
  ['project', { directory: '/Users/lee/sitrep' }, 'project lives in /Users/lee/sitrep'],
  [
    'project',
    { name: 'SitRep', directory: '/Users/lee/sitrep' },
    'project renamed: SitRep · project lives in /Users/lee/sitrep',
  ],
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
  const asked = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' }),
  )

  const rows: [tool: string, input: { [key: string]: unknown }, line: string][] = [
    ['resolve', { item: asked }, 'resolved: Review round 1'],
    ['reopen', { item: asked }, 'reopened: Review round 1'],
    ['edit', { item: 'zzzz', title: 'x' }, 'edited: an item'],
    ['join', { session: id }, 'joined: Dashboard redesign'],
    ['join', { work: id }, 'joined: Dashboard redesign'],
    ['join', { session: 'sr-zzzzzz' }, 'joined a session'],
    ['finish', {}, '✓ finished: Dashboard redesign'],
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

  const asked = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' }),
  )
  const rows: [tool: string, input: { [key: string]: unknown }, line: string][] = [
    ['resolve', { item: asked }, 'resolved: Review round 1'],
    ['reopen', { item: asked }, 'reopened: Review round 1'],
    ['edit', { item: asked, where: 'In Paper' }, 'edited: Review round 1'],
  ]
  const kept = []

  for (const [tool, input, line] of rows) {
    kept.push({ call: await keeping(w, tool, input), tool, input, line })
  }

  const other = startedId(await w.call('start', USAGE))

  await w.call('join', { session: other })

  for (const { call, tool, input, line } of kept) {
    expect(await drawnLine($, call, tool, input, line), tool).toBeDefined()
  }
})

test("an edit's row names the item's title as the edit left it", async ($, on) => {
  const w = world($, on)

  engineRows(on)
  await w.begin()

  const asked = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' }),
  )
  const input = { item: asked, title: 'Review round 2' }
  const edited = await keeping(w, 'edit', input)

  await w.call('edit', { item: asked, title: 'Review round 3' })

  expect(await drawnLine($, edited, 'edit', input, 'edited: Review round 2')).toBeDefined()
})

test("a join row and a finish row keep the session's name after a later join", async ($, on) => {
  const w = world($, on)

  engineRows(on)

  const { id } = await w.begin()
  const other = startedId(await w.call('start', USAGE))
  const joined = await keeping(w, 'join', { session: id })
  const finished = await keeping(w, 'finish', { reason: 'Shipped' })

  await w.call('join', { session: other })

  expect(
    await drawnLine($, joined, 'join', { session: id }, 'joined: Dashboard redesign'),
  ).toBeDefined()
  expect(
    await drawnLine($, finished, 'finish', { reason: 'Shipped' }, '✓ finished: Dashboard redesign'),
  ).toBeDefined()
})

test('a refused call keeps no name', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('resolve', { item: 'zzzz' })
  await w.call('join', { session: 'sr-zzzzzz' })

  expect(w.state.named ?? []).toEqual([])
})

test('only the latest calls keep their names, the oldest let go', SLOW, async ($, on) => {
  const w = world($, on)

  await w.begin()

  const asked = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' }),
  )
  const first = await keeping(w, 'resolve', { item: asked })

  for (let i = 0; i < NAMES_KEPT; i += 1) {
    await w.call(i % 2 === 0 ? 'reopen' : 'resolve', { item: asked })
  }

  expect(w.state.named).toHaveLength(NAMES_KEPT)
  expect(w.state.named?.some(each => each.call === first)).toBe(false)
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

  const ask = row('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' })

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
