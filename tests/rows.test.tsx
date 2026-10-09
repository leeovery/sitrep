import type { On } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import { postedId, world } from './world'

tier('user')

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
    { kind: 'review', title: 'Review Sessions & Runway, round 1' },
    '◆ asked: Review Sessions & Runway, round 1',
  ],
  ['note', { text: 'PR #82 merged' }, 'logged: PR #82 merged'],
  ['park', { title: 'A tmux indicator' }, '◇ parked: A tmux indicator'],
  ['finish', { reason: 'Shipped' }, '✓ finished a piece of work'],
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

test('a call naming an item or a work names it as the held work has it', async ($, on) => {
  const w = world($, on)

  engineRows(on)

  const { id } = await w.begin()
  const asked = postedId(await w.call('ask', { kind: 'review', title: 'Review round 1' }))

  const rows: [tool: string, input: { [key: string]: unknown }, line: string][] = [
    ['resolve', { item: asked }, 'resolved: Review round 1'],
    ['reopen', { item: asked }, 'reopened: Review round 1'],
    ['edit', { item: 'zzzz', title: 'x' }, 'edited: an item'],
    ['join', { work: id }, 'joined: Dashboard redesign'],
    ['join', { work: 'sr-zzzzzz' }, 'joined a piece of work'],
    ['finish', {}, '✓ finished: Dashboard redesign'],
  ]

  for (const [i, [tool, input, line]] of rows.entries()) {
    const ui = await $.ui.mount({ ...row(tool, input, `toolu_${i}`), surface: 'terminal' })

    expect(await ui.find({ type: 'Text', text: line }), tool).toBeDefined()
    await ui.unmount()
  }
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

  const ask = row('ask', { kind: 'review', title: 'Review round 1' })

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
