import { expect, test, tier } from './kit'
import { parseEntries } from '../core'
import { C } from '../hooks/look'
import { SPECS } from '../hooks/tools'
import { rowsOf } from './drawn'
import { W1 } from './support'
import { postedId, SURFACES, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const FRAMES = {
  wants: 'choice',
  title: 'Ship round 2, or redraw?',
  options: ['Ship it', 'Redraw', 'Hold off'],
}

const asked = async (w: World, ask: { [key: string]: unknown }) =>
  postedId(await w.call('ask', ask))

/** The asks of the held session, as the board in `$.state` has them. */
const asksOf = (w: World) => w.state.board?.asks ?? []

test('the ask tool takes recommended, and reads a marker Claude types as it, stripped from the option', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const named = await asked(w, { ...FRAMES, recommended: 'Redraw' })
  const marked = await asked(w, {
    ...FRAMES,
    options: ['Ship it', 'Redraw', 'Hold off — Recommended'],
  })

  expect(parseEntries(w.text(paths.log(W1))).filter(line => line.type === 'ask')).toMatchObject([
    { id: named, options: FRAMES.options, recommended: 'Redraw' },
    { id: marked, options: FRAMES.options, recommended: 'Hold off' },
  ])
  expect(asksOf(w).map(ask => [ask.id, ask.recommended])).toEqual([
    [named, 'Redraw'],
    [marked, 'Hold off'],
  ])
  expect((await w.call('ask', { ...FRAMES, recommended: 'Ship' })).deny).toBe(
    'recommended names one of the options, in its words: “Ship it”, “Redraw” or “Hold off”.',
  )
  expect(
    (await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go', recommended: 'Go' }))
      .deny,
  ).toBe('Only a choice ask takes recommended: one of its options.')
})

test('edit sets recommended or clears it; one changing the options keeps it while its option stays, and says so where it goes', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { ...FRAMES, recommended: 'Ship it' })
  const recommended = () => asksOf(w)[0]?.recommended

  expect((await w.call('edit', { item: id, options: ['Redraw', 'Ship it'] })).result).toBe(
    `Edited ${id}.`,
  )
  expect(recommended()).toBe('Ship it')
  expect((await w.call('edit', { item: id, options: ['Redraw', 'Hold off'] })).result).toBe(
    `Edited ${id}. Its recommended option “Ship it” is gone, so it recommends none now.`,
  )
  expect(recommended()).toBeUndefined()
  expect((await w.call('edit', { item: id, recommended: 'Hold off' })).result).toBe(`Edited ${id}.`)
  expect(recommended()).toBe('Hold off')
  expect((await w.call('edit', { item: id, recommended: '' })).result).toBe(`Edited ${id}.`)
  expect(recommended()).toBeUndefined()
  expect(
    (await w.call('edit', { item: id, options: ['Redraw [recommended]', 'Hold off'] })).result,
  ).toBe(`Edited ${id}.`)
  expect(asksOf(w)[0]).toMatchObject({ options: ['Redraw', 'Hold off'], recommended: 'Redraw' })
})

test("edit's answer says the recommendation went exactly where the folded ask lost it unnamed: a reshape, an option removed; never where it moved or was cleared by name", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const cases: [edit: { [key: string]: unknown }, lost: boolean][] = [
    [{ wants: 'words' }, true],
    [{ options: ['Redraw', 'Hold off'] }, true],
    [{ options: ['Redraw (recommended)', 'Hold off'] }, false],
    [{ options: ['Ship it', 'Redraw (recommended)'] }, false],
    [{ recommended: '' }, false],
    [{ recommended: 'Redraw' }, false],
    [{ options: ['Hold off', 'Ship it'] }, false],
  ]

  for (const [changes, lost] of cases) {
    const id = await asked(w, { ...FRAMES, recommended: 'Ship it' })
    const answer = String((await w.call('edit', { item: id, ...changes })).result)
    const after = asksOf(w).find(ask => ask.id === id)?.recommended
    const said = `Edited ${id}. Its recommended option “Ship it” is gone, so it recommends none now.`

    expect(answer, JSON.stringify(changes)).toBe(lost ? said : `Edited ${id}.`)
    expect(after === undefined && changes.recommended === undefined, JSON.stringify(changes)).toBe(
      lost,
    )
  }
})

test('edit clearing recommended while its options mark one is refused', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { ...FRAMES, recommended: 'Ship it' })

  expect(
    (
      await w.call('edit', {
        item: id,
        options: ['Ship it', 'Redraw (recommended)'],
        recommended: '',
      })
    ).deny,
  ).toBe(
    'Recommend one option: “Redraw” is marked recommended in the options, and recommended says otherwise.',
  )
  expect(asksOf(w)[0]).toMatchObject({ options: FRAMES.options, recommended: 'Ship it' })
})

test('the board tool reads back which option is recommended, once', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { ...FRAMES, recommended: 'Redraw' })
  const board = String((await w.call('board')).result)

  expect(board).toContain(
    `- ${id} wants a choice, waiting on Lee: Ship round 2, or redraw?; options: Ship it | Redraw | Hold off; recommended: Redraw`,
  )
  expect(board.match(/recommended/gi)).toHaveLength(1)
})

test('the ask and edit tools take recommended, and ask Claude to give it whenever it leans, never the word in an option', () => {
  const [ask, edit] = ['ask', 'edit'].map(name => SPECS.find(spec => spec.name === name))
  const property = (spec: typeof ask) =>
    (spec?.inputSchema?.properties as Record<string, { description: string }> | undefined)
      ?.recommended?.description

  expect(property(ask)).toContain('Give it whenever you lean toward one')
  expect(property(edit)).toContain('"" clears it.')
  expect(ask?.description).toContain('giving recommended whenever you lean toward one')
  expect(ask?.description).toContain('never the word in an option')
})

test('the pane marks the recommended option with the word once, quiet beside it, on every surface; the option keeps its own words', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { ...FRAMES, options: ['Ship it', 'Redraw (recommended)', 'Hold off'] })

  for (const surface of SURFACES) {
    const ui = await w.pane(surface)
    const words = await ui.findAll({ type: 'Text', text: /recommended/i })
    const options = await Promise.all(
      [0, 1, 2].map(i => ui.find({ key: `choose:${w.item(id)}:${i}` })),
    )

    expect(
      words.map(each => [each.props.color]),
      surface,
    ).toEqual([[C.grey]])
    expect(
      options.map(each => [each?.props.label, each?.props.variant]),
      surface,
    ).toEqual([
      ['Ship it', undefined],
      ['Redraw', 'primary'],
      ['Hold off', undefined],
    ])
    await ui.unmount()
  }

  const terminal = await w.pane()
  const marked = await terminal.find({ key: `recommended:choose:${w.item(id)}:1` })

  expect(rowsOf(marked)).toEqual(['[ Redraw ] recommended'])
  expect(marked?.props.flexWrap, 'the word wraps under a long label').toBe('wrap')
  expect(
    marked?.children?.map(child =>
      typeof child === 'object' && child !== null && 'props' in child
        ? (child.props as { flexShrink?: number }).flexShrink
        : undefined,
    ),
    'and keeps whole',
  ).toEqual([undefined, 0])
})

test('a choice with nothing recommended draws no such word, its first option the primary one', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, FRAMES)

  for (const surface of SURFACES) {
    const ui = await w.pane(surface)

    expect(await ui.findAll({ type: 'Text', text: /recommended/i }), surface).toEqual([])
    expect((await ui.find({ key: `choose:${w.item(id)}:0` }))?.props.variant, surface).toBe(
      'primary',
    )
    await ui.unmount()
  }
})
