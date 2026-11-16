import type { SitrepPane, SitrepQueued } from '../types'
import { expect, test, tier } from './kit'
import type { Body } from '../core'
import { hoverScope } from '../hooks/draw/kit'
import { C, GLYPH } from '../hooks/look'
import { rowsOf } from './drawn'
import { HELD, heldItem, MIN, PROJECT, REVIEW, T0, type Asked } from './data'
import { askOf, note, park, status, type Line } from './lines'
import { pane, sceneFrom, type Drawn } from './render'
import { ACROSS, asked, world } from './world'

tier('user')

const FOLD =
  "Move the pilot's results into the spreadsheet pages: contributors by team and level, owner by department, week tally, separate summaries"

/** The first row of FOLD opened: its mark, its title's first line, its age. */
const TITLED = /^◇ Move the pilot's results into the spreadsheet +now$/

const DECIDE = {
  wants: 'choice',
  title: 'Keep the ledger 400 days, or forever?',
  where: 'In Paper: page round 1',
  options: ['400 days', 'Forever'],
} satisfies Asked

/** Lee's reply to an item of the held session, waiting in Ready to send. */
const queued = (item: string, reply: Pick<SitrepQueued, 'verdict' | 'option'>): SitrepQueued => ({
  project: PROJECT.key,
  session: HELD.id,
  item,
  ...reply,
})

/** The board drawn from what Claude wrote at T0, with the pane and Ready to send as given. */
const drawnFrom = (
  bodies: readonly Body[],
  shown: Partial<SitrepPane> = {},
  queue: readonly SitrepQueued[] = [],
) => pane(sceneFrom({ lines: bodies.map((body): Line => [T0, body]), pane: shown, queue }))

/** The rows the element keyed `key` is drawn on, as the docked board draws it. */
const rows = async (ui: Drawn, key: string) => rowsOf(await ui.find({ key }))

/** A line of a tree as drawn: the colour of its text, and of the label it opens with where it has one. */
const lineOn = async (ui: Drawn, line: string) => {
  const found = await ui.find({ type: 'Text', text: line })
  const [first] = found?.children ?? []
  const label =
    typeof first === 'object' && first !== null
      ? (first as { props: { color?: string }; children: unknown[] })
      : undefined

  return {
    color: found?.props.color,
    label:
      label === undefined ? undefined : { text: label.children.join(''), color: label.props.color },
  }
}

/** Each tree glyph, and every colour the board draws it in. */
const glyphColours = async (ui: Drawn) =>
  Object.fromEntries(
    await Promise.all(
      [GLYPH.branch, GLYPH.last, GLYPH.stem].map(async text => [
        text,
        [...new Set((await ui.findAll({ type: 'Text', text })).map(each => each.props.color))],
      ]),
    ),
  )

type Hover = { scope?: string; inverse?: boolean }

type Node = { type?: string; props?: { key?: unknown }; hover?: Hover; children?: unknown[] }

/** The hover of every Button in a drawn tree whose key opens with `prefix`, in document order: what `find` leaves out. */
const hoversIn = (node: unknown, prefix: string): (Hover | undefined)[] => {
  const { type, props, hover, children = [] } = node as Node
  const own = type === 'Button' && String(props?.key).startsWith(prefix) ? [hover] : []

  return [
    ...own,
    ...children.flatMap(child =>
      typeof child === 'object' && child !== null ? hoversIn(child, prefix) : [],
    ),
  ]
}

/** Each tree glyph drawn, and only ever faint. */
const ALL_FAINT = { [GLYPH.branch]: [C.faint], [GLYPH.last]: [C.faint], [GLYPH.stem]: [C.faint] }

test('a log line is its mark, its text and its age at the right edge; opened, a stem runs down from the mark to its tree', async () => {
  const bodies = [
    note('n1', 'Now also drawing Inbox, round 2, and the brief beside it', [
      'Added: Drawing Inbox, round 2',
      'Next: Inbox, round 3',
    ]),
    note('n2', 'PR #82 merged'),
  ]
  const across = async (ui: Drawn, id: string) =>
    rowsOf(await ui.find({ key: `line:${heldItem(id)}` }), ACROSS)

  expect(await across(drawnFrom(bodies), 'n1')).toEqual([
    '• Now also drawing Inbox, round 2, and the brie…   now',
  ])
  expect(await across(drawnFrom(bodies, { selected: heldItem('n1') }), 'n1')).toEqual([
    '• Now also drawing Inbox, round 2, and the brief   now',
    '│ beside it',
    '├ Added: Drawing Inbox, round 2',
    '└ Next: Inbox, round 3',
  ])

  const short = drawnFrom(bodies, { selected: heldItem('n2') })

  expect(await across(short, 'n2')).toEqual([
    '• PR #82 merged                                    now',
    '└ nothing more was recorded',
  ])
  expect(await lineOn(short, 'nothing more was recorded'), 'a detail line, soft').toEqual({
    color: C.soft,
    label: undefined,
  })
})

test("an opened title's lines light as one: each line's press in one hover group, inverted, and another title in its own", async () => {
  const ui = drawnFrom([park('p1', FOLD), park('p2', 'A priority badge')], {
    selected: heldItem('p1'),
  })
  const hovers = async (id: string) => hoversIn(await ui.drawn(), `ppick:${heldItem(id)}`)
  const scope = hoverScope(`ppick:${heldItem('p1')}`)
  const otherScope = hoverScope(`ppick:${heldItem('p2')}`)

  expect(await hovers('p1'), 'its three lines, one group').toEqual(
    Array(3).fill({ scope, inverse: true }),
  )
  expect(await hovers('p2')).toEqual([{ scope: otherScope, inverse: true }])
  expect(otherScope).not.toBe(scope)
})

test("a title's hover group is named by its press key, or, where the key is too long or holds a control character, by a fingerprint of it within 64 characters", () => {
  const long = (end: string) => `pick:sr-k3f9qa:${'x'.repeat(80)}${end}`
  const scopes = [long('a'), long('b'), 'pick:sr-k3f9qa:k3f9\n'].map(hoverScope)

  expect(hoverScope('pick:sr-k3f9qa:k3f9')).toBe('pick:sr-k3f9qa:k3f9')
  expect([...new Set(scopes)]).toHaveLength(3)

  for (const scope of scopes) {
    expect(scope.length).toBeGreaterThan(0)
    expect(scope.length).toBeLessThanOrEqual(64)
    expect(scope).not.toMatch(/\p{Cc}/u)
  }
})

test('an opened parked item hangs where and its record from its mark, its buttons under the tree', async () => {
  const ui = drawnFrom(
    [park('p1', FOLD, { where: 'In DESIGN.md, Later', ref: 'notes: spreadsheet-pilot.md' })],
    { selected: heldItem('p1') },
  )
  const drawn = await rows(ui, `parked:${heldItem('p1')}`)

  expect(drawn[0]).toMatch(TITLED)
  expect(drawn.slice(1)).toEqual([
    '│ pages: contributors by team and level, owner',
    '│ by department, week tally, separate summaries',
    '├ In DESIGN.md, Later',
    '└ see notes: spreadsheet-pilot.md',
    '  [ pick it up ] [ ✎ with a comment ]',
  ])
})

test('a parked item with nothing to hang shows no stem beside its title, only its buttons', async () => {
  const ui = drawnFrom([park('p1', FOLD)], { selected: heldItem('p1') })
  const drawn = await rows(ui, `parked:${heldItem('p1')}`)

  expect(drawn[0]).toMatch(TITLED)
  expect(drawn.slice(1)).toEqual([
    '  pages: contributors by team and level, owner',
    '  by department, week tally, separate summaries',
    '  [ pick it up ] [ ✎ with a comment ]',
  ])
})

test("a pick-up waiting to be sent is the parked item's last branch, and takes the button's place", async () => {
  const ui = drawnFrom(
    [park('p1', 'A priority badge', { where: 'In DESIGN.md' })],
    { selected: heldItem('p1') },
    [queued('p1', { verdict: 'pickup' })],
  )

  expect((await rows(ui, `parked:${heldItem('p1')}`)).slice(1)).toEqual([
    '├ In DESIGN.md',
    '└ pick it up · not sent yet ↺ undo',
  ])
})

test("an opened ask hangs where and its record from its mark; its buttons and hint come after, at the title's column", async () => {
  const ui = drawnFrom(
    [askOf('k1', { ...REVIEW, where: 'In Paper: page round 1', ref: 'docs/help-desk.md' })],
    { selected: heldItem('k1') },
  )

  expect((await rows(ui, `ask:${heldItem('k1')}`)).slice(1, 5)).toEqual([
    '├ In Paper: page round 1',
    '└ see docs/help-desk.md',
    '  [ ✓ Approve ] [ ✎ comment ] [ ✕ ignore ] [ snooze ]',
    "  Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it.",
  ])
})

test("a reply waiting to be sent is the ask's last branch", async () => {
  const ui = drawnFrom([askOf('k1', DECIDE)], { selected: heldItem('k1') }, [
    queued('k1', { verdict: 'choose', option: 'Forever' }),
  ])

  expect(await rows(ui, `ask:${heldItem('k1')}`)).toEqual([
    '◆ Keep the ledger 400 days, or forever? now',
    '├ In Paper: page round 1',
    '└ → Forever · not sent yet ↺ undo ✎ comment',
  ])
})

test('a closed ask keeps its faint title and tick, and hangs that Claude has it from the tick', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, DECIDE)
  const ui = await w.pane()

  await ui.press({ key: `choose:${w.item(id)}:1` })
  await ui.press({ key: 'send' })
  expect(await rows(ui, `ask:${w.item(id)}`)).toEqual([
    '✓ Keep the ledger 400 days, or forever? now',
    '└ sent, and Claude has it',
  ])
  expect((await ui.find({ type: 'Text', text: DECIDE.title }))?.props.color).toBe('#565f89')
})

test('a branch whose text wraps keeps the tree unbroken: a stem beside it under a ├, blank under the └', async () => {
  const ui = drawnFrom(
    [
      askOf('k1', {
        ...REVIEW,
        where: 'In Paper: the help desk file, page "draft 1", panels 1–6, beside the brief',
        ref: 'docs/help-desk.md, under "Tickets & Replies", the first round of three',
      }),
    ],
    { selected: heldItem('k1') },
  )

  expect((await rows(ui, `ask:${heldItem('k1')}`)).slice(1, 5)).toEqual([
    '├ In Paper: the help desk file, page "draft 1", panels',
    '│ 1–6, beside the brief',
    '└ see docs/help-desk.md, under "Tickets & Replies",',
    '  the first round of three',
  ])
})

test('an opened status change opens each detail line with its label in the status teal, the text after it soft', async () => {
  const lines: Line[] = [
    [
      T0,
      status(['Reviewing round 1', 'Drawing Inbox'], {
        name: HELD.name,
        summary: HELD.summary,
        next: 'Inbox, round 2',
      }),
    ],
    [
      T0 + MIN,
      status(['Drawing Inbox', 'Drawing Macros'], {
        next: 'Macros, round 2',
        name: 'Help desk, round 2',
        summary: 'The second round of the help desk',
      }),
    ],
  ]
  const drawn = (selected: string | null) =>
    pane(sceneFrom({ lines, pane: { selected }, now: T0 + MIN }))
  // A line the board derives is keyed by its kind and its time.
  const latest = heldItem(`status-${T0 + MIN}`)

  expect(await drawn(null).find({ key: `log:${latest}` }), 'the latest status line').toBeDefined()

  const ui = drawn(latest)

  for (const [label, text] of [
    ['Added:', 'Drawing Macros'],
    ['No longer:', 'Reviewing round 1'],
    ['Still there:', 'Drawing Inbox'],
    ['Next:', 'Macros, round 2'],
    ['Name:', 'Help desk, round 2'],
    ['Summary:', 'The second round of the help desk'],
  ]) {
    expect(await lineOn(ui, `${label} ${text}`), label).toEqual({
      color: C.soft,
      label: { text: label, color: C.now },
    })
  }
})

test("a note's detail lines are Claude's own words, unlabelled and soft, whatever they open with; its see is labelled in the note's blue", async () => {
  const ui = drawnFrom(
    [
      note('n1', 'Wrote the schema', ['Added: the ledger table', '6 files, +214 −51'], {
        ref: 'docs/ledger.md',
      }),
    ],
    { selected: heldItem('n1') },
  )

  expect(await lineOn(ui, 'Added: the ledger table')).toEqual({ color: C.soft, label: undefined })
  expect(await lineOn(ui, '6 files, +214 −51')).toEqual({ color: C.soft, label: undefined })
  expect(await lineOn(ui, 'see docs/ledger.md')).toEqual({
    color: C.soft,
    label: { text: 'see', color: C.log },
  })
})

test("an opened ask's see is labelled in the ask's amber, a parked item's in its purple", async () => {
  const bodies = [
    askOf('k1', {
      wants: 'yes',
      yes: 'Approve',
      title: 'Review round 1',
      ref: 'docs/help-desk.md',
    }),
    park('p1', 'A priority badge', { ref: 'docs/badging.md' }),
  ]

  const ask = drawnFrom(bodies, { selected: heldItem('k1') })
  const parked = drawnFrom(bodies, { selected: heldItem('p1') })

  expect(await lineOn(ask, 'see docs/help-desk.md')).toEqual({
    color: C.soft,
    label: { text: 'see', color: C.ask },
  })
  expect(await lineOn(parked, 'see docs/badging.md')).toEqual({
    color: C.soft,
    label: { text: 'see', color: C.parked },
  })
})

test("every tree's glyphs are drawn faint: a log line's, an ask's, Ready to send's, a parked item's, and the stem beside a title", async () => {
  const bodies = [
    note('n1', FOLD, ['6 files', '+214 −51']),
    askOf('k1', DECIDE),
    park('p1', FOLD, { where: 'In DESIGN.md', ref: 'docs/badging.md' }),
  ]
  const opening = (id: string) =>
    drawnFrom(bodies, { selected: heldItem(id) }, [
      queued('k1', { verdict: 'choose', option: 'Forever' }),
    ])

  expect(await glyphColours(opening('n1'))).toEqual(ALL_FAINT)
  expect(await glyphColours(opening('p1'))).toEqual(ALL_FAINT)
})
