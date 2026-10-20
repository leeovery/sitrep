import { expect, test } from 'claude-code/testing'
import {
  checkAnswer,
  checkAsk,
  checkEdit,
  checkJoin,
  checkNote,
  checkPark,
  checkReopen,
  checkResolve,
  checkStart,
  checkStatus,
  withId,
  type Checked,
} from '../core'
import {
  choiceAsk,
  delivered,
  file,
  finish,
  fold,
  kindAsk,
  MIN,
  note,
  park,
  reply,
  resolve,
  scripted,
  SENDER,
  T0,
  W1,
  wordsAsk,
  yesAsk,
} from './support'

/** A board holding one of each item, an ask Lee has commented on, and two asks read from their kinds. */
const SESSION = fold({
  logs: {
    [W1]: file(
      [T0, yesAsk('k1', 'Review round 1')],
      [T0, choiceAsk('k2', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
      [T0, yesAsk('k3', 'Try it on the iPad', 'It works')],
      [T0, note('n1', 'Merged')],
      [T0, park('p1', 'Later')],
      [T0, yesAsk('k9', 'Run the apply', 'Done')],
      [T0, wordsAsk('k4', 'Run the export', "the command's output")],
      [T0, kindAsk('o1', 'do', 'Run the export', { needs: "the command's output" })],
      [T0, kindAsk('o2', 'review', 'Review round 1')],
      [T0 + MIN, resolve('k9')],
      [T0 + MIN, reply('r1', 'k3', 'comment', { note: 'It fails' })],
      [T0 + MIN, delivered('r1')],
    ),
  },
})

const CURRENT = {
  name: 'Dashboard redesign',
  summary: 'Area by area',
  now: ['Drawing Usage'],
  next: 'Usage, round 3',
}

const refusal = <T>(checked: Checked<T>) => (checked.ok ? undefined : checked.error)
const value = <T>(checked: Checked<T>) => (checked.ok ? checked.value : undefined)

test('what Claude posts is trimmed and kept to one line', () => {
  expect(
    value(
      checkAsk({
        wants: 'yes',
        yes: ' Ship\n it ',
        title: '  Review\n Sessions &   Runway ',
        where: '\tIn Paper:\n page 1 ',
        ref: ' ',
      }),
    ),
  ).toEqual({
    type: 'ask',
    wants: 'yes',
    yes: 'Ship it',
    title: 'Review Sessions & Runway',
    where: 'In Paper: page 1',
  })
  expect(
    value(checkNote({ text: ' Merged\nPR #82 ', detail: [' 6 files ', '', '6 files', 'a\nb'] })),
  ).toEqual({
    type: 'note',
    text: 'Merged PR #82',
    detail: ['6 files', 'a b'],
  })
})

test('an item with no words where its title or text goes is refused', () => {
  expect(refusal(checkAsk({ wants: 'words', title: ' \n ' }))).toContain('needs a title')
  expect(refusal(checkAsk({ wants: 'words' }))).toContain('needs a title')
  expect(refusal(checkNote({ text: '' }))).toContain('needs its text')
  expect(refusal(checkPark({ title: 42 }))).toContain('needs a title')
  expect(refusal(checkStart({ name: 'Dashboard', summary: ' ' }))).toContain('needs a summary')
  expect(refusal(checkStart({ summary: 'Area by area' }))).toContain('needs a name')
})

test('an ask says what it wants back, one of three shapes; anything else, a kind among them, is refused', () => {
  for (const wants of [undefined, 'approve', 'review', 'decide']) {
    expect(refusal(checkAsk({ wants, title: 'Approve it' })), String(wants)).toBe(
      "An ask's wants is one of yes, choice, words: a yes, one of its options, or words.",
    )
  }
})

test("a yes ask needs its button's words, a word or two, and no other ask takes them", () => {
  expect(refusal(checkAsk({ wants: 'yes', title: 'Give the go' }))).toContain(
    "A yes ask needs yes: its button's words",
  )
  expect(refusal(checkAsk({ wants: 'yes', yes: ' \n ', title: 'Give the go' }))).toContain(
    'A yes ask needs yes',
  )
  expect(
    refusal(checkAsk({ wants: 'yes', yes: 'Go ahead and merge it all', title: 'Give the go' })),
  ).toBe("A yes button's words are a word or two, 20 characters at most, such as Go or Ship it.")
  expect(value(checkAsk({ wants: 'yes', yes: 'It works', title: 'Try it' }))?.yes).toBe('It works')
  expect(refusal(checkAsk({ wants: 'choice', yes: 'Go', title: 'Keep it?' }))).toBe(
    'Only a yes ask takes yes.',
  )
  expect(refusal(checkAsk({ wants: 'words', yes: 'Go', title: 'Run it' }))).toBe(
    'Only a yes ask takes yes.',
  )
})

test('a choice ask needs at least two options, each one line, none repeated', () => {
  expect(refusal(checkAsk({ wants: 'choice', title: 'Keep it?' }))).toContain('at least 2 options')
  expect(
    refusal(checkAsk({ wants: 'choice', title: 'Keep it?', options: ['Keep it', ' Keep it '] })),
  ).toContain('at least 2 options')
  expect(
    value(checkAsk({ wants: 'choice', title: 'Keep it?', options: [' Keep\nit ', 'Drop it', ''] }))
      ?.options,
  ).toEqual(['Keep it', 'Drop it'])
})

test('only a choice ask takes options', () => {
  expect(
    refusal(checkAsk({ wants: 'yes', yes: 'Go', title: 'Review it', options: ['Yes', 'No'] })),
  ).toBe('Only a choice ask takes options.')
  expect(refusal(checkAsk({ wants: 'words', title: 'Run it', options: ['Yes', 'No'] }))).toBe(
    'Only a choice ask takes options.',
  )
  expect(
    value(checkAsk({ wants: 'yes', yes: 'Go', title: 'Review it', options: [] }))?.options,
  ).toBeUndefined()
})

test('a words ask may say what its words are, on one line; no other ask takes needs', () => {
  expect(
    value(checkAsk({ wants: 'words', title: 'Run the export', needs: " the command's\n output " })),
  ).toEqual({ type: 'ask', wants: 'words', title: 'Run the export', needs: "the command's output" })
  expect(value(checkAsk({ wants: 'words', title: 'Say how it went' }))?.needs).toBeUndefined()
  expect(value(checkAsk({ wants: 'words', title: 'Run it', needs: ' \n ' }))?.needs).toBeUndefined()

  for (const ask of [
    { wants: 'yes', yes: 'Done', title: 'Run it' },
    { wants: 'choice', title: 'Keep it?', options: ['Keep it', 'Drop it'] },
  ]) {
    expect(refusal(checkAsk({ ...ask, needs: 'the output' })), ask.wants).toBe(
      'Only a words ask takes needs: what its words are.',
    )
    expect(value(checkAsk({ ...ask, needs: ' ' }))?.needs, ask.wants).toBeUndefined()
  }
})

test('a session is joined by its id, as start gave it', () => {
  expect(value(checkJoin({ session: ' sr-k3f9qa ' }))).toEqual({ session: 'sr-k3f9qa' })

  for (const session of [undefined, 'k3f9qa', 'sr-K3F9QA', 7]) {
    expect(refusal(checkJoin({ session })), String(session)).toContain('by the id start gave it')
  }
})

test('a status keeps what Claude leaves out, and an empty next clears it', () => {
  expect(value(checkStatus({ now: ['Drawing Usage, round 2', ' '] }, CURRENT))).toEqual({
    type: 'status',
    name: 'Dashboard redesign',
    summary: 'Area by area',
    now: ['Drawing Usage, round 2'],
    next: 'Usage, round 3',
  })
  expect(value(checkStatus({ next: '' }, CURRENT))?.next).toBeUndefined()
  expect(value(checkStatus({ now: 'One thing under way' }, CURRENT))?.now).toEqual([
    'One thing under way',
  ])
})

test('a status that names nothing, empties its name or gives now as no list is refused', () => {
  expect(refusal(checkStatus({}, CURRENT))).toContain('at least one of')
  expect(refusal(checkStatus({ name: ' ' }, CURRENT))).toContain('neither can be empty')
  expect(refusal(checkStatus({ now: 3 }, CURRENT))).toContain('a list of lines')
})

test('resolve and reopen name an item on the board by its id', () => {
  expect(value(checkResolve(SESSION, { item: ' k1 ', reason: ' Done in\nthe chat ' }))).toEqual({
    type: 'resolve',
    item: 'k1',
    reason: 'Done in the chat',
  })
  expect(refusal(checkResolve(SESSION, { item: 'zz' }))).toBe('There is no item zz on this board.')
  expect(refusal(checkReopen(SESSION, {}))).toContain('by its id')
})

test('resolving what is closed, or reopening what is open as posted, is refused', () => {
  expect(refusal(checkResolve(SESSION, { item: 'k9' }))).toBe('k9 is already closed.')
  expect(refusal(checkReopen(SESSION, { item: 'k1' }))).toBe('k1 is already open.')
  expect(refusal(checkReopen(SESSION, { item: 'p1' }))).toBe('p1 is already open.')
  expect(value(checkReopen(SESSION, { item: 'k3' }))).toEqual({ type: 'reopen', item: 'k3' })
  expect(value(checkReopen(SESSION, { item: 'k9' }))).toEqual({ type: 'reopen', item: 'k9' })
})

test("an edit changes only the fields of its item's type, each put right", () => {
  expect(
    value(checkEdit(SESSION, { item: 'k1', title: ' Review\nround 2 ', reason: 'Round 2 is up' })),
  ).toEqual({
    type: 'edit',
    item: 'k1',
    changes: { title: 'Review round 2' },
    reason: 'Round 2 is up',
  })
  expect(
    value(checkEdit(SESSION, { item: 'n1', text: 'Merged #82', detail: ['6 files'] }))?.changes,
  ).toEqual({
    text: 'Merged #82',
    detail: ['6 files'],
  })
  expect(refusal(checkEdit(SESSION, { item: 'n1', title: 'A title' }))).toBe(
    'An edit to a note changes text, detail, ref; not title.',
  )
  expect(refusal(checkEdit(SESSION, { item: 'p1' }))).toBe(
    'An edit names a field to change: for a parked item, title, where, ref.',
  )
  expect(refusal(checkEdit(SESSION, { item: 'k1', title: ' ' }))).toContain(
    'cannot leave title empty',
  )
})

test('an edit leaves an ask holding what its shape takes', () => {
  expect(refusal(checkEdit(SESSION, { item: 'k1', wants: 'choice' }))).toContain(
    'at least 2 options',
  )
  expect(
    value(checkEdit(SESSION, { item: 'k1', wants: 'choice', options: ['Ship it', 'Hold it'] }))
      ?.changes,
  ).toEqual({ wants: 'choice', options: ['Ship it', 'Hold it'] })
  expect(refusal(checkEdit(SESSION, { item: 'k2', options: ['Keep it'] }))).toContain(
    'at least 2 options',
  )
  expect(refusal(checkEdit(SESSION, { item: 'k1', options: ['Ship it', 'Hold it'] }))).toBe(
    'Only a choice ask takes options.',
  )
  expect(refusal(checkEdit(SESSION, { item: 'k2', wants: 'yes' }))).toContain('A yes ask needs yes')
  expect(value(checkEdit(SESSION, { item: 'k2', wants: 'yes', yes: 'Keep it' }))?.changes).toEqual({
    wants: 'yes',
    yes: 'Keep it',
  })
  expect(value(checkEdit(SESSION, { item: 'k1', yes: 'Ship it' }))?.changes).toEqual({
    yes: 'Ship it',
  })
  expect(refusal(checkEdit(SESSION, { item: 'k2', yes: 'Keep it' }))).toBe(
    'Only a yes ask takes yes.',
  )
  expect(value(checkEdit(SESSION, { item: 'k1', wants: 'words' }))?.changes).toEqual({
    wants: 'words',
  })
})

test('an edit gives a words ask what its words are, an empty one clearing it; no other shape takes it', () => {
  expect(
    value(checkEdit(SESSION, { item: 'k1', wants: 'words', needs: ' which\nframes ' }))?.changes,
  ).toEqual({ wants: 'words', needs: 'which frames' })
  expect(refusal(checkEdit(SESSION, { item: 'k1', needs: 'which frames' }))).toBe(
    'Only a words ask takes needs: what its words are.',
  )
  expect(value(checkEdit(SESSION, { item: 'k4', needs: ' ' }))?.changes).toEqual({ needs: '' })
  expect(value(checkEdit(SESSION, { item: 'k4', needs: 'the exit code' }))?.changes).toEqual({
    needs: 'the exit code',
  })
  expect(refusal(checkEdit(SESSION, { item: 'k4', needs: 42 }))).toContain('cannot leave needs')
  expect(refusal(checkEdit(SESSION, { item: 'p1', needs: 'which frames' }))).toBe(
    'An edit to a parked item changes title, where, ref; not needs.',
  )
})

test('an edit changing the shape of an ask read from its kind says what the ask wants, so it reads by its shape from then on', () => {
  expect(value(checkEdit(SESSION, { item: 'o1', needs: '' }))?.changes).toEqual({
    wants: 'words',
    needs: '',
  })
  expect(value(checkEdit(SESSION, { item: 'o2', yes: 'Ship it' }))?.changes).toEqual({
    wants: 'yes',
    yes: 'Ship it',
  })
})

test('an edit leaving the shape of an ask read from its kind as it is keeps the kind', () => {
  expect(value(checkEdit(SESSION, { item: 'o1', title: 'Run the export again' }))?.changes).toEqual(
    {
      title: 'Run the export again',
    },
  )
  expect(
    value(checkEdit(SESSION, { item: 'o2', where: 'In Paper', ref: 'docs/plan.md' }))?.changes,
  ).toEqual({ where: 'In Paper', ref: 'docs/plan.md' })
})

test('a checked post is given a fresh item id, unlike any its session uses; a refusal stays one', () => {
  const random = scripted([20, 21, 22, 23], [1, 1, 1, 1])

  expect(value(withId(checkPark({ title: 'Later' }), { ids: new Set(['mnpq']) }, random))).toEqual({
    type: 'park',
    title: 'Later',
    id: '1111',
  })
  expect(refusal(withId(checkPark({}), SESSION, random))).toBe(
    'A parked item needs a title: one line.',
  )
})

test("an answer from outside Claude Code is a yes in its button's words, or one of a choice's options", () => {
  expect(value(checkAnswer(SESSION, { ask: ' k1 ', answer: 'Approve' }))).toEqual({
    type: 'reply',
    item: 'k1',
    verdict: 'yes',
  })
  expect(value(checkAnswer(SESSION, { ask: 'k2', answer: ' Drop\n it ' }))).toEqual({
    type: 'reply',
    item: 'k2',
    verdict: 'choose',
    option: 'Drop it',
  })
  expect(
    value(checkAnswer(SESSION, { ask: 'o2', answer: 'Approve' })),
    'a review read as a yes',
  ).toEqual({ type: 'reply', item: 'o2', verdict: 'yes' })
  expect(
    value(checkAnswer(SESSION, { ask: 'k3', answer: 'It works' })),
    'one Lee commented on, still open',
  ).toEqual({ type: 'reply', item: 'k3', verdict: 'yes' })
})

test('an answer not in the words the ask takes is refused, saying what it takes', () => {
  expect(refusal(checkAnswer(SESSION, { ask: 'k1', answer: 'Go' }))).toBe(
    'k1 wants a yes: answer it with “Approve”.',
  )
  expect(refusal(checkAnswer(SESSION, { ask: 'k1' }))).toBe(
    'k1 wants a yes: answer it with “Approve”.',
  )
  expect(refusal(checkAnswer(SESSION, { ask: 'k2', answer: 'keep it' }))).toBe(
    'k2 wants a choice: answer it with “Keep it” or “Drop it”.',
  )
  expect(refusal(checkAnswer(SESSION, { ask: 'k2', answer: ' ' }))).toBe(
    'k2 wants a choice: answer it with “Keep it” or “Drop it”.',
  )
})

test("a words ask needs Claude Code's prompt, an old one needing something back among them; only an ask is answered", () => {
  const prompt = "wants words, which need Claude Code's prompt: answer it there."

  expect(refusal(checkAnswer(SESSION, { ask: 'k4', answer: 'v1.2.3' }))).toBe(`k4 ${prompt}`)
  expect(refusal(checkAnswer(SESSION, { ask: 'o1', answer: 'Done' }))).toBe(`o1 ${prompt}`)
  expect(refusal(checkAnswer(SESSION, { ask: 'n1', answer: 'Yes' }))).toBe(
    'n1 is a note, not an ask.',
  )
  expect(refusal(checkAnswer(SESSION, { ask: 'p1', answer: 'Yes' }))).toBe(
    'p1 is a parked item, not an ask.',
  )
  expect(refusal(checkAnswer(SESSION, { ask: 'zz', answer: 'Yes' }))).toBe(
    'There is no item zz on this board.',
  )
  expect(refusal(checkAnswer(SESSION, { answer: 'Yes' }))).toContain('by its id')
})

test("an ignore is the board's, on an ask of any shape, a words ask among them, and with no words of its own", () => {
  for (const id of ['k1', 'k2', 'k4', 'o1']) {
    expect(value(checkAnswer(SESSION, { ask: id, ignore: true })), id).toEqual({
      type: 'reply',
      item: id,
      verdict: 'ignore',
    })
  }

  expect(refusal(checkAnswer(SESSION, { ask: 'k1', answer: 'Approve', ignore: true }))).toBe(
    'Give an answer or --ignore, not both.',
  )
  expect(refusal(checkAnswer(SESSION, { ask: 'k9', ignore: true }))).toBe('k9 is already closed.')
})

test('an ask closed, or with a reply on its way, takes no answer; nor does a finished session', () => {
  const sent = fold({
    logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'ignore')]) },
  })
  const finished = fold({
    logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')], [T0 + MIN, finish('lee')]) },
  })

  expect(refusal(checkAnswer(SESSION, { ask: 'k9', answer: 'Done' }))).toBe(
    'k9 is already closed.',
  )
  expect(refusal(checkAnswer(sent, { ask: 'k1', answer: 'Approve' }))).toBe(
    'A reply to k1 is on its way already.',
  )
  expect(refusal(checkAnswer(finished, { ask: 'k1', answer: 'Approve' }))).toBe(
    'This session is finished: its asks wait on Lee no more.',
  )
})
