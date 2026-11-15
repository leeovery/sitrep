import { expect, test } from './kit'
import { EXIT, WRITER } from '../cli/main'
import {
  boardMessage,
  boardText,
  checkAnswer,
  checkAsk,
  checkEdit,
  droppedRecommendation,
  parseEntries,
  readOptions,
  unmarked,
  type Ask,
  type Body,
  type Changes,
  type Checked,
  type EditBody,
} from '../core'
import {
  choiceAsk,
  file,
  fold,
  META,
  MIN,
  reply,
  T0,
  W1,
  wordsAsk,
  yesAsk,
  type Line,
} from './support'
import { terminal } from './terminal'

const OPTIONS = ['Ship it', 'Redraw', 'Hold off']

const FRAMES = { wants: 'choice', title: 'Ship round 2, or redraw?', options: OPTIONS }

/** A choice ask Claude posted recommending one of its options. */
const recommending = (id: string, recommended: string): Body => ({
  type: 'ask',
  id,
  wants: 'choice',
  title: FRAMES.title,
  options: OPTIONS,
  recommended,
})

const edit = (item: string, changes: Changes): Body => ({ type: 'edit', item, changes })

/** A board holding a choice recommending Ship it, a choice recommending none, a yes and a words ask. */
const SESSION = fold({
  logs: {
    [W1]: file(
      [T0, recommending('k1', 'Ship it')],
      [T0, choiceAsk('k2', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
      [T0, yesAsk('k3', 'Give the go', 'Go')],
      [T0, wordsAsk('k4', 'Run the export')],
    ),
  },
})

const refusal = <T>(checked: Checked<T>) => (checked.ok ? undefined : checked.error)
const value = <T>(checked: Checked<T>) => (checked.ok ? checked.value : undefined)

const askAfter = (...lines: Line[]) => fold({ logs: { [W1]: file(...lines) } }).asks[0]

test('the marker read is "recommended" at the end of an option, any case, in parentheses or brackets or after a dash, stripped', () => {
  for (const option of [
    'Ship it (recommended)',
    'Ship it (Recommended)',
    'Ship it(RECOMMENDED)',
    'Ship it [recommended]',
    'Ship it [Recommended]',
    'Ship it — recommended',
    'Ship it – Recommended',
    'Ship it - Recommended',
    'Ship it -recommended',
  ]) {
    expect(unmarked(option), option).toEqual({ text: 'Ship it', isMarked: true })
  }
})

test('the forms Claude also types are read and stripped: a stop or a bang after, a dash with no space, an adverb, more words after, a leading Recommended:', () => {
  for (const [option, text] of [
    ['Ship it (recommended).', 'Ship it'],
    ['Ship it [Recommended]!', 'Ship it'],
    ['Ship it — recommended.', 'Ship it'],
    ['Ship it—recommended', 'Ship it'],
    ['Ship it–Recommended', 'Ship it'],
    ['Ship it (strongly recommended)', 'Ship it'],
    ['Ship it (Highly Recommended)', 'Ship it'],
    ['Ship it (recommended, fastest)', 'Ship it (fastest)'],
    ['Ship it (Recommended — fastest)', 'Ship it (fastest)'],
    ['Ship it [recommended: fastest]', 'Ship it [fastest]'],
    ['Ship it (recommended) — ships today', 'Ship it — ships today'],
    ['Recommended: Ship it', 'Ship it'],
  ] as const) {
    expect(unmarked(option), option).toEqual({ text, isMarked: true })
  }
})

test('markers are stripped one after another until none is left', () => {
  expect(unmarked('Ship it (recommended) (recommended)')).toEqual({
    text: 'Ship it',
    isMarked: true,
  })
  expect(unmarked('Recommended: Ship it — recommended')).toEqual({
    text: 'Ship it',
    isMarked: true,
  })
})

test('nothing else is read as a marker: the word elsewhere, negated or qualified, a hyphen with no space, or with nothing before it', () => {
  for (const option of [
    'Use the recommended defaults',
    'Recommended defaults',
    'Go with what is recommended',
    'Ship it, recommended',
    'Ship it (not recommended)',
    'Ship it – not recommended',
    'Ship it (recommended by Apple)',
    'Ship it ( recommended )',
    'Pick the non-recommended',
    'Pick the self-recommended',
    'Ship it - recommendedly',
    '(recommended)',
    '- recommended',
  ]) {
    expect(unmarked(option), option).toEqual({ text: option, isMarked: false })
  }
})

test('options are read with their markers stripped, an option given twice so kept once, the ones marked named, and the ones two became', () => {
  expect(readOptions(['Ship it (recommended)', 'Redraw', 'Ship it'])).toEqual({
    options: ['Ship it', 'Redraw'],
    marked: ['Ship it'],
    collapsed: ['Ship it'],
  })
  expect(readOptions(['Ship it', 'Redraw'])).toEqual({
    options: ['Ship it', 'Redraw'],
    marked: [],
    collapsed: [],
  })
})

test('two options that become one once stripped, leaving too few, are refused naming the repeat, on post and on edit', () => {
  const collapsing = { ...FRAMES, options: ['Ship it', 'Ship it (recommended)'] }
  const refused =
    'A choice ask needs at least 2 options: “Ship it” is given twice, once marked recommended.'

  expect(refusal(checkAsk(collapsing))).toBe(refused)
  expect(refusal(checkEdit(SESSION, { item: 'k2', options: collapsing.options }))).toBe(refused)
  expect(value(checkAsk({ ...FRAMES, options: [...collapsing.options, 'Redraw'] }))).toMatchObject({
    options: ['Ship it', 'Redraw'],
    recommended: 'Ship it',
  })
})

test('a recommended that is not text is refused on post, as on edit', () => {
  expect(refusal(checkAsk({ ...FRAMES, recommended: 1 }))).toBe(
    'recommended is text: one of the options, in its words.',
  )
  expect(refusal(checkEdit(SESSION, { item: 'k1', recommended: 1 }))).toBe(
    'An edit cannot leave recommended empty or of the wrong kind.',
  )
})

test("a choice ask takes recommended, one of its options in its words, and Claude's order of options is kept", () => {
  expect(value(checkAsk({ ...FRAMES, recommended: ' Hold\noff ' }))).toEqual({
    type: 'ask',
    wants: 'choice',
    title: FRAMES.title,
    options: OPTIONS,
    recommended: 'Hold off',
  })
  expect(value(checkAsk(FRAMES))?.recommended).toBeUndefined()
  expect(value(checkAsk({ ...FRAMES, recommended: ' ' }))?.recommended).toBeUndefined()
})

test('a marker Claude types in an option is read as recommended and stripped from the option; the order is kept', () => {
  expect(
    value(checkAsk({ ...FRAMES, options: ['Ship it', 'Redraw (Recommended)', 'Hold off'] })),
  ).toMatchObject({ options: OPTIONS, recommended: 'Redraw' })
  expect(
    value(
      checkAsk({ ...FRAMES, options: ['Ship it [recommended]', 'Redraw'], recommended: 'Ship it' }),
    ),
  ).toMatchObject({ options: ['Ship it', 'Redraw'], recommended: 'Ship it' })
  expect(
    value(
      checkAsk({ ...FRAMES, options: ['Ship it', 'Redraw'], recommended: 'Redraw (recommended)' }),
    )?.recommended,
  ).toBe('Redraw')
  expect(
    value(checkAsk({ ...FRAMES, options: ['Use the recommended defaults', 'Pick my own'] })),
  ).toMatchObject({
    options: ['Use the recommended defaults', 'Pick my own'],
    recommended: undefined,
  })
})

test('recommended on a yes or a words ask, or naming none of the options, is refused in plain words', () => {
  expect(
    refusal(checkAsk({ wants: 'yes', yes: 'Go', title: 'Give the go', recommended: 'Go' })),
  ).toBe('Only a choice ask takes recommended: one of its options.')
  expect(refusal(checkAsk({ wants: 'words', title: 'Run it', recommended: 'Ship it' }))).toBe(
    'Only a choice ask takes recommended: one of its options.',
  )
  expect(refusal(checkAsk({ ...FRAMES, recommended: 'Ship' }))).toBe(
    'recommended names one of the options, in its words: “Ship it”, “Redraw” or “Hold off”.',
  )
})

test('two options marked, or one marked and recommended naming another, is refused: recommend one option', () => {
  expect(
    refusal(checkAsk({ ...FRAMES, options: ['Ship it (recommended)', 'Redraw - recommended'] })),
  ).toBe(
    'Recommend one option: more than one is marked recommended. Give the one you lean toward as recommended, and leave the word out of the options.',
  )
  expect(
    refusal(
      checkAsk({ ...FRAMES, options: ['Ship it (recommended)', 'Redraw'], recommended: 'Redraw' }),
    ),
  ).toBe(
    'Recommend one option: “Ship it” is marked recommended in the options, and recommended says otherwise.',
  )
})

test('an edit sets recommended, or clears it with an empty one; one naming no option, or on an ask that is no choice, is refused', () => {
  expect(value(checkEdit(SESSION, { item: 'k2', recommended: 'Drop it' }))?.changes).toEqual({
    recommended: 'Drop it',
  })
  expect(value(checkEdit(SESSION, { item: 'k1', recommended: ' ' }))?.changes).toEqual({
    recommended: '',
  })
  expect(refusal(checkEdit(SESSION, { item: 'k2', recommended: 'Ship it' }))).toBe(
    'recommended names one of the options, in its words: “Keep it” or “Drop it”.',
  )
  expect(refusal(checkEdit(SESSION, { item: 'k3', recommended: 'Go' }))).toBe(
    'Only a choice ask takes recommended: one of its options.',
  )
  expect(
    value(
      checkEdit(SESSION, { item: 'k3', wants: 'choice', options: ['A', 'B'], recommended: 'B' }),
    )?.changes,
  ).toEqual({ wants: 'choice', options: ['A', 'B'], recommended: 'B' })
  expect(
    refusal(checkEdit(SESSION, { item: 'k1', wants: 'yes', yes: 'Go', recommended: 'Ship it' })),
  ).toBe('Only a choice ask takes recommended: one of its options.')
})

test("an edit's options are stripped of their markers, the one marked read as recommended, under the same refusals", () => {
  expect(
    value(checkEdit(SESSION, { item: 'k2', options: ['Keep it', 'Drop it (recommended)'] }))
      ?.changes,
  ).toEqual({ options: ['Keep it', 'Drop it'], recommended: 'Drop it' })
  expect(
    value(
      checkEdit(SESSION, {
        item: 'k2',
        options: ['Keep it', 'Drop it (recommended)'],
        recommended: 'Drop it',
      }),
    )?.changes,
  ).toEqual({ options: ['Keep it', 'Drop it'], recommended: 'Drop it' })
  expect(
    refusal(
      checkEdit(SESSION, {
        item: 'k2',
        options: ['Keep it [recommended]', 'Drop it - recommended'],
      }),
    ),
  ).toContain('Recommend one option: more than one is marked recommended.')
  expect(
    refusal(
      checkEdit(SESSION, {
        item: 'k2',
        options: ['Keep it (recommended)', 'Drop it'],
        recommended: 'Drop it',
      }),
    ),
  ).toBe(
    'Recommend one option: “Keep it” is marked recommended in the options, and recommended says otherwise.',
  )
  expect(
    refusal(
      checkEdit(SESSION, {
        item: 'k2',
        options: ['Keep it (recommended)', 'Drop it'],
        recommended: '',
      }),
    ),
  ).toContain('Recommend one option: “Keep it” is marked recommended')
})

test('an ask keeps recommended as it folds; an edit changes it, and an empty one clears it', () => {
  const posted: Line = [T0, recommending('k1', 'Ship it')]

  expect(askAfter(posted)).toMatchObject({ options: OPTIONS, recommended: 'Ship it' })
  expect(askAfter(posted, [T0 + MIN, edit('k1', { recommended: 'Redraw' })])?.recommended).toBe(
    'Redraw',
  )
  expect(askAfter(posted, [T0 + MIN, edit('k1', { recommended: '' })])?.recommended).toBeUndefined()
})

test('an edit changing the options keeps recommended while its option is among them, and drops it with its option', () => {
  const posted: Line = [T0, recommending('k1', 'Ship it')]

  expect(
    askAfter(posted, [T0 + MIN, edit('k1', { options: ['Redraw', 'Ship it'] })]),
  ).toMatchObject({ options: ['Redraw', 'Ship it'], recommended: 'Ship it' })
  expect(
    askAfter(posted, [T0 + MIN, edit('k1', { options: ['Redraw', 'Hold off'] })])?.recommended,
  ).toBeUndefined()
  expect(
    askAfter(
      posted,
      [T0 + MIN, edit('k1', { options: ['Redraw', 'Hold off'] })],
      [T0 + 2 * MIN, edit('k1', { options: OPTIONS })],
    )?.recommended,
    'gone for good, not back with its option',
  ).toBeUndefined()
  expect(
    askAfter(posted, [T0 + MIN, edit('k1', { wants: 'yes', yes: 'Go' })])?.recommended,
  ).toBeUndefined()
})

test('a line naming an option it does not offer recommends none; an old line without the field reads as before', () => {
  expect(askAfter([T0, recommending('k1', 'Ship')])?.recommended).toBeUndefined()

  const old = askAfter([T0, choiceAsk('k1', FRAMES.title, OPTIONS)])

  expect(old).toMatchObject({ wants: 'choice', options: OPTIONS })
  expect(old !== undefined && 'recommended' in old && old.recommended !== undefined).toBe(false)
  expect(parseEntries(file([T0, recommending('k1', 'Ship it')]))[0]).toMatchObject({
    recommended: 'Ship it',
  })
})

/** An ask posted before markers were read, its first option still carrying one. */
const MARKED_BEFORE = choiceAsk('k1', FRAMES.title, ['Ship it (recommended)', 'Redraw'])

test('on an ask posted before markers were read, edit names an option without its marker, and recommended takes the option in its own words', () => {
  const old = fold({ logs: { [W1]: file([T0, MARKED_BEFORE]) } })

  for (const recommended of ['Ship it', 'Ship it (recommended)']) {
    expect(value(checkEdit(old, { item: 'k1', recommended }))?.changes, recommended).toEqual({
      recommended: 'Ship it (recommended)',
    })
  }

  expect(
    askAfter([T0, MARKED_BEFORE], [T0 + MIN, edit('k1', { recommended: 'Ship it (recommended)' })])
      ?.recommended,
  ).toBe('Ship it (recommended)')
})

test('re-sending such an option stores it stripped and keeps it recommended; a pick of it on its way survives, in the words Lee picked', () => {
  const old = fold({ logs: { [W1]: file([T0, MARKED_BEFORE]) } })
  const stripped = checkEdit(old, { item: 'k1', options: ['Ship it (recommended)', 'Redraw'] })

  expect(value(stripped)?.changes).toEqual({
    options: ['Ship it', 'Redraw'],
    recommended: 'Ship it',
  })

  const recommendedBefore = edit('k1', { recommended: 'Ship it (recommended)' })
  const resent = edit('k1', { options: ['Ship it', 'Redraw'] })

  expect(
    askAfter([T0, MARKED_BEFORE], [T0 + MIN, recommendedBefore], [T0 + 2 * MIN, resent]),
  ).toMatchObject({ options: ['Ship it', 'Redraw'], recommended: 'Ship it' })

  const picked = fold({
    logs: {
      [W1]: file(
        [T0, MARKED_BEFORE],
        [T0 + MIN, reply('r1', 'k1', 'choose', { option: 'Ship it (recommended)' })],
        [T0 + 2 * MIN, resent],
      ),
    },
  })
  const pick = (picked.items.get('k1') as Ask).replies[0]

  expect(pick).toMatchObject({ option: 'Ship it (recommended)', voided: undefined })
  expect(pick?.delivery).not.toBe('void')
  expect(boardMessage(picked, pick === undefined ? [] : [pick])?.text).toContain(
    '→ Ship it (recommended)',
  )
})

test("the CLI's answer takes an option's exact words first, then its words without a marker, either way round", () => {
  const old = fold({
    logs: {
      [W1]: file(
        [T0, MARKED_BEFORE],
        [T0, choiceAsk('k2', 'Keep it?', ['Keep it', 'Keep it (recommended)'])],
      ),
    },
  })
  const option = (session: typeof old, ask: string, answer: string) =>
    value(checkAnswer(session, { ask, answer }))?.option

  expect(option(old, 'k1', 'Ship it')).toBe('Ship it (recommended)')
  expect(option(old, 'k1', 'Ship it (recommended)')).toBe('Ship it (recommended)')
  expect(option(SESSION, 'k2', 'Keep it (recommended)')).toBe('Keep it')
  expect(option(old, 'k2', 'Keep it')).toBe('Keep it')
  expect(option(old, 'k2', 'Keep it (recommended)')).toBe('Keep it (recommended)')
})

test('an edit leaving an ask without its recommended option, unnamed, is told; one keeping it, or naming it, is not', () => {
  const dropped = (item: string, changes: Changes) =>
    droppedRecommendation(SESSION, { type: 'edit', item, changes } satisfies EditBody)

  expect(dropped('k1', { options: ['Redraw', 'Hold off'] })).toBe('Ship it')
  expect(dropped('k1', { wants: 'yes', yes: 'Go' })).toBe('Ship it')
  expect(dropped('k1', { options: ['Hold off', 'Ship it'] })).toBeUndefined()
  expect(dropped('k1', { title: 'Ship it?' })).toBeUndefined()
  expect(dropped('k1', { options: ['Redraw', 'Hold off'], recommended: '' })).toBeUndefined()
  expect(dropped('k2', { options: ['Keep', 'Drop'] })).toBeUndefined()
})

test('the board text names the option recommended once, beside the options; an ask with none says nothing of it', () => {
  const text = boardText(SESSION)

  expect(text).toContain(
    '- k1 wants a choice, waiting on Lee: Ship round 2, or redraw?; options: Ship it | Redraw | Hold off; recommended: Ship it',
  )
  expect(text).toContain(
    '- k2 wants a choice, waiting on Lee: Keep it, or drop it?; options: Keep it | Drop it\n',
  )
  expect(text.match(/recommended/gi)).toHaveLength(1)
})

test("Lee's message when he picks an option is unchanged by its being recommended", () => {
  const plain = fold({ logs: { [W1]: file([T0, choiceAsk('k1', FRAMES.title, OPTIONS)]) } })
  const pick = { id: 'r1', item: 'k1', verdict: 'choose' as const, option: 'Ship it' }

  expect(boardMessage(SESSION, [pick])?.text).toBe(boardMessage(plain, [pick])?.text)
  expect(boardMessage(SESSION, [pick])?.text).not.toMatch(/recommended/i)
})

test('an answer from outside Claude Code not among the options names them, the one recommended marked', () => {
  expect(refusal(checkAnswer(SESSION, { ask: 'k1', answer: 'Ship' }))).toBe(
    'k1 wants a choice: answer it with “Ship it” (recommended), “Redraw” or “Hold off”.',
  )
  expect(value(checkAnswer(SESSION, { ask: 'k1', answer: 'Ship it' }))).toEqual({
    type: 'reply',
    item: 'k1',
    verdict: 'choose',
    option: 'Ship it',
  })
})

test('the CLI posts recommended with --recommended, reads a typed marker as it, and refuses as the tool does', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const session = ['--session', META.id]
  const choice = ['ask', FRAMES.title, '--wants', 'choice']

  await t.run(
    ...choice,
    '--option',
    'Ship it',
    '--option',
    'Redraw',
    '--recommended',
    'Redraw',
    ...session,
  )
  await t.run(...choice, '--option', 'Ship it (recommended)', '--option', 'Redraw', ...session)

  const refused = await t.run(
    ...choice,
    '--option',
    'Ship it',
    '--option',
    'Redraw',
    '--recommended',
    'Hold off',
    ...session,
  )
  const asks = parseEntries(t.text(paths.log(WRITER))).filter(line => line.type === 'ask')

  expect(
    asks.map(line => [
      line.type === 'ask' && line.options,
      line.type === 'ask' && line.recommended,
    ]),
  ).toEqual([
    [['Ship it', 'Redraw'], 'Redraw'],
    [['Ship it', 'Redraw'], 'Ship it'],
  ])
  expect(refused).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: recommended names one of the options, in its words: “Ship it” or “Redraw”.\n',
  })
})

test('board prints the option recommended once, and board --json gives it, null where an ask recommends none', async () => {
  const t = terminal()

  t.seed(META, {
    lines: [
      [T0, recommending('k1', 'Redraw')],
      [T0, yesAsk('k2', 'Give the go', 'Go')],
    ],
  })

  const printed = (await t.run('board', '--session', META.id)).out
  const json = JSON.parse((await t.run('board', '--json', '--session', META.id)).out) as {
    asks: Pick<Ask, 'id' | 'options' | 'recommended'>[]
  }

  expect(printed).toContain('; options: Ship it | Redraw | Hold off; recommended: Redraw')
  expect(printed.match(/recommended/gi)).toHaveLength(1)
  expect(json.asks.map(ask => [ask.id, ask.options, ask.recommended])).toEqual([
    ['k1', OPTIONS, 'Redraw'],
    ['k2', [], null],
  ])
})
