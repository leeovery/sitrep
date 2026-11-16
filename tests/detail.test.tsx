import { expect, test, tier } from './kit'
import { hoverScope } from '../hooks/draw/kit'
import { C, GLYPH } from '../hooks/look'
import { rowsOf } from './drawn'
import { MIN, REVIEW } from './data'
import { ACROSS, postedId, world, type Board } from './world'

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
}

/** The rows the element keyed `key` is drawn on, as the docked board draws it. */
const rows = async (ui: Board, key: string) => rowsOf(await ui.find({ key }))

/** A line of a tree as drawn: the colour of its text, and of the label it opens with where it has one. */
const lineOn = async (ui: Board, line: string) => {
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
const glyphColours = async (ui: Board) =>
  Object.fromEntries(
    await Promise.all(
      [GLYPH.branch, GLYPH.last, GLYPH.stem].map(async text => [
        text,
        [...new Set((await ui.findAll({ type: 'Text', text })).map(each => each.props.color))],
      ]),
    ),
  )

type Hover = { scope?: string; inverse?: boolean }

type Drawn = { type?: string; props?: { key?: unknown }; hover?: Hover; children?: unknown[] }

/** The hover of every Button in a drawn tree whose key opens with `prefix`, in document order: what `find` leaves out. */
const hoversIn = (node: unknown, prefix: string): (Hover | undefined)[] => {
  const { type, props, hover, children = [] } = node as Drawn
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

test('a log line is its mark, its text and its age at the right edge; opened, a stem runs down from the mark to its tree', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const long = postedId(
    await w.call('note', {
      text: 'Now also drawing Inbox, round 2, and the brief beside it',
      detail: ['Added: Drawing Inbox, round 2', 'Next: Inbox, round 3'],
    }),
  )
  const short = postedId(await w.call('note', { text: 'PR #82 merged' }))
  const ui = await w.pane()
  const across = async (key: string) => rowsOf(await ui.find({ key }), ACROSS)

  expect(await across(`line:${w.item(long)}`)).toEqual([
    '• Now also drawing Inbox, round 2, and the brie…   now',
  ])

  await ui.press({ key: `log:${w.item(long)}` })
  expect(await across(`line:${w.item(long)}`)).toEqual([
    '• Now also drawing Inbox, round 2, and the brief   now',
    '│ beside it',
    '├ Added: Drawing Inbox, round 2',
    '└ Next: Inbox, round 3',
  ])

  await ui.press({ key: `log:${w.item(short)}` })
  expect(await across(`line:${w.item(short)}`)).toEqual([
    '• PR #82 merged                                    now',
    '└ nothing more was recorded',
  ])
  expect(await lineOn(ui, 'nothing more was recorded'), 'a detail line, soft').toEqual({
    color: C.soft,
    label: undefined,
  })
})

test("an opened title's lines light as one: each line's press in one hover group, inverted, and another title in its own", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const fold = postedId(await w.call('park', { title: FOLD }))
  const other = postedId(await w.call('park', { title: 'A priority badge' }))
  const ui = await w.pane()
  const hovers = async (id: string) => hoversIn(await ui.drawn(), `ppick:${w.item(id)}`)

  await ui.press({ key: `ppick:${w.item(fold)}` })

  const scope = hoverScope(`ppick:${w.item(fold)}`)
  const otherScope = hoverScope(`ppick:${w.item(other)}`)

  expect(await hovers(fold), 'its three lines, one group').toEqual(
    Array(3).fill({ scope, inverse: true }),
  )
  expect(await hovers(other)).toEqual([{ scope: otherScope, inverse: true }])
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

test('an opened parked item hangs where and its record from its mark, its buttons under the tree', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('park', {
      title: FOLD,
      where: 'In DESIGN.md, Later',
      ref: 'notes: spreadsheet-pilot.md',
    }),
  )
  const ui = await w.opened()

  await ui.press({ key: `ppick:${w.item(id)}` })
  const drawn = await rows(ui, `parked:${w.item(id)}`)

  expect(drawn[0]).toMatch(TITLED)
  expect(drawn.slice(1)).toEqual([
    '│ pages: contributors by team and level, owner',
    '│ by department, week tally, separate summaries',
    '├ In DESIGN.md, Later',
    '└ see notes: spreadsheet-pilot.md',
    '  [ pick it up ] [ ✎ with a comment ]',
  ])
})

test('a parked item with nothing to hang shows no stem beside its title, only its buttons', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: FOLD }))
  const ui = await w.pane()

  await ui.press({ key: `ppick:${w.item(id)}` })
  const drawn = await rows(ui, `parked:${w.item(id)}`)

  expect(drawn[0]).toMatch(TITLED)
  expect(drawn.slice(1)).toEqual([
    '  pages: contributors by team and level, owner',
    '  by department, week tally, separate summaries',
    '  [ pick it up ] [ ✎ with a comment ]',
  ])
})

test("a pick-up waiting to be sent is the parked item's last branch, and takes the button's place", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: 'A priority badge', where: 'In DESIGN.md' }))
  const ui = await w.pane()

  await ui.press({ key: `ppick:${w.item(id)}` })
  await ui.press({ key: `pickup:${w.item(id)}` })
  expect((await rows(ui, `parked:${w.item(id)}`)).slice(1)).toEqual([
    '├ In DESIGN.md',
    '└ pick it up · not sent yet ↺ undo',
  ])
})

test("an opened ask hangs where and its record from its mark; its buttons and hint come after, at the title's column", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('ask', {
      ...REVIEW,
      where: 'In Paper: page round 1',
      ref: 'docs/help-desk.md',
    }),
  )
  const ui = await w.pane()

  expect((await rows(ui, `ask:${w.item(id)}`)).slice(1, 5)).toEqual([
    '├ In Paper: page round 1',
    '└ see docs/help-desk.md',
    '  [ ✓ Approve ] [ ✎ comment ] [ ✕ ignore ] [ snooze ]',
    "  Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it.",
  ])
})

test("a reply waiting to be sent is the ask's last branch", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', DECIDE))
  const ui = await w.pane()

  await ui.press({ key: `choose:${w.item(id)}:1` })
  expect(await rows(ui, `ask:${w.item(id)}`)).toEqual([
    '◆ Keep the ledger 400 days, or forever? now',
    '├ In Paper: page round 1',
    '└ → Forever · not sent yet ↺ undo ✎ comment',
  ])
})

test('a closed ask keeps its faint title and tick, and hangs that Claude has it from the tick', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', DECIDE))
  const ui = await w.pane()

  await ui.press({ key: `choose:${w.item(id)}:1` })
  await ui.press({ key: 'send' })
  expect(await rows(ui, `ask:${w.item(id)}`)).toEqual([
    '✓ Keep the ledger 400 days, or forever? now',
    '└ sent, and Claude has it',
  ])
  expect((await ui.find({ type: 'Text', text: DECIDE.title }))?.props.color).toBe('#565f89')
})

test('a branch whose text wraps keeps the tree unbroken: a stem beside it under a ├, blank under the └', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('ask', {
      ...REVIEW,
      where: 'In Paper: the help desk file, page "round 1", frames 1–6, beside the brief',
      ref: 'docs/help-desk.md, under "Tickets & Replies", the first round of three',
    }),
  )
  const ui = await w.pane()

  expect((await rows(ui, `ask:${w.item(id)}`)).slice(1, 5)).toEqual([
    '├ In Paper: the help desk file, page "round 1", frames',
    '│ 1–6, beside the brief',
    '└ see docs/help-desk.md, under "Tickets & Replies",',
    '  the first round of three',
  ])
})

test('an opened status change opens each detail line with its label in the status teal, the text after it soft', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('status', { now: ['Reviewing round 1', 'Drawing Inbox'], next: 'Inbox, round 2' })
  await w.clock.advance(MIN)
  await w.call('status', {
    now: ['Drawing Inbox', 'Drawing Macros'],
    next: 'Macros, round 2',
    name: 'Help desk, round 2',
    summary: 'The second round of the help desk',
  })

  const ui = await w.pane()
  const [latest] = (await ui.findAll({ type: 'Button' })).filter(each =>
    each.key?.startsWith(`log:${w.item('status-')}`),
  )

  await ui.press({ key: latest?.key ?? 'no status line' })

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

test("a note's detail lines are Claude's own words, unlabelled and soft, whatever they open with; its see is labelled in the note's blue", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('note', {
      text: 'Wrote the schema',
      detail: ['Added: the ledger table', '6 files, +214 −51'],
      ref: 'docs/ledger.md',
    }),
  )
  const ui = await w.pane()

  await ui.press({ key: `log:${w.item(id)}` })
  expect(await lineOn(ui, 'Added: the ledger table')).toEqual({ color: C.soft, label: undefined })
  expect(await lineOn(ui, '6 files, +214 −51')).toEqual({ color: C.soft, label: undefined })
  expect(await lineOn(ui, 'see docs/ledger.md')).toEqual({
    color: C.soft,
    label: { text: 'see', color: C.log },
  })
})

test("an opened ask's see is labelled in the ask's amber, a parked item's in its purple", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ask = postedId(
    await w.call('ask', {
      wants: 'yes',
      yes: 'Approve',
      title: 'Review round 1',
      ref: 'docs/help-desk.md',
    }),
  )
  const parked = postedId(
    await w.call('park', { title: 'A priority badge', ref: 'docs/badging.md' }),
  )
  const ui = await w.pane()

  expect(await lineOn(ui, 'see docs/help-desk.md')).toEqual({
    color: C.soft,
    label: { text: 'see', color: C.ask },
  })

  await ui.press({ key: `ppick:${w.item(parked)}` })
  expect(await lineOn(ui, 'see docs/badging.md')).toEqual({
    color: C.soft,
    label: { text: 'see', color: C.parked },
  })
})

test("every tree's glyphs are drawn faint: a log line's, an ask's, Ready to send's, a parked item's, and the stem beside a title", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const note = postedId(await w.call('note', { text: FOLD, detail: ['6 files', '+214 −51'] }))
  const ask = postedId(await w.call('ask', DECIDE))
  const parked = postedId(
    await w.call('park', { title: FOLD, where: 'In DESIGN.md', ref: 'docs/badging.md' }),
  )
  const ui = await w.pane()

  await ui.press({ key: `choose:${w.item(ask)}:1` })
  await ui.press({ key: `log:${w.item(note)}` })
  expect(await glyphColours(ui)).toEqual(ALL_FAINT)

  await ui.press({ key: `ppick:${w.item(parked)}` })
  expect(await glyphColours(ui)).toEqual(ALL_FAINT)
})
