import { expect, test } from './kit'
import {
  checkAnswer,
  checkAsk,
  checkDrop,
  checkEdit,
  checkJoin,
  checkPark,
  checkReopen,
  checkResolve,
  checkSnooze,
  checkSnoozeAsk,
  checkStart,
  checkStatus,
  checkWake,
  checkWakeAsk,
  closedByLee,
  withId,
  withParkId,
  type Checked,
  type SessionFiles,
} from '../core'
import { MIN, SENDER, T0, W1 } from './data'
import {
  beat,
  choiceAsk,
  delivered,
  drop,
  file,
  finish,
  fold,
  kindAsk,
  oldNote,
  park,
  reopen,
  reply,
  resolve,
  scripted,
  snooze,
  snoozeSession,
  snoozeTurn,
  wakeSession,
  wordsAsk,
  yesAsk,
  type Line,
} from './lines'

/** A board holding one of each item, an ask Lee has commented on, two asks read from their kinds, and a note as one was written before notes went. */
const SESSION = fold({
  logs: {
    [W1]: file(
      [T0, yesAsk('k1', 'Review round 1')],
      [T0, choiceAsk('k2', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
      [T0, yesAsk('k3', 'Try it on the iPad', 'It works')],
      [T0, oldNote('n1', 'Merged')],
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
  name: 'Help desk redesign',
  summary: 'Area by area',
  now: ['Drawing Inbox'],
  next: 'Inbox, round 3',
}

const refusal = <T>(checked: Checked<T>) => (checked.ok ? undefined : checked.error)
const value = <T>(checked: Checked<T>) => (checked.ok ? checked.value : undefined)

test('what Claude posts is trimmed and kept to one line', () => {
  expect(
    value(
      checkAsk({
        wants: 'yes',
        yes: ' Ship\n it ',
        title: '  Review\n Tickets &   Replies ',
        where: '\tIn Paper:\n page 1 ',
        ref: ' ',
      }),
    ),
  ).toEqual({
    type: 'ask',
    wants: 'yes',
    yes: 'Ship it',
    title: 'Review Tickets & Replies',
    where: 'In Paper: page 1',
  })
})

test('an item with no words where its title goes is refused', () => {
  expect(refusal(checkAsk({ wants: 'words', title: ' \n ' }))).toContain('needs a title')
  expect(refusal(checkAsk({ wants: 'words' }))).toContain('needs a title')
  expect(refusal(checkPark({ title: 42 }))).toContain('needs a title')
  expect(refusal(checkStart({ name: 'Help desk', summary: ' ' }))).toContain('needs a summary')
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
  expect(
    value(checkAsk({ wants: 'yes', yes: 'Merge it and ship it', title: 'Give the go' }))?.yes,
    'twenty characters, the most it takes',
  ).toBe('Merge it and ship it')
  expect(
    refusal(checkAsk({ wants: 'yes', yes: 'Merge it and ship it!', title: 'Give the go' })),
    'twenty-one characters',
  ).toBe("A yes button's words are a word or two, 20 characters at most, such as Go or Ship it.")
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
  expect(value(checkStatus({ now: ['Drawing Inbox, round 2', ' '] }, CURRENT))).toEqual({
    type: 'status',
    name: 'Help desk redesign',
    summary: 'Area by area',
    now: ['Drawing Inbox, round 2'],
    next: 'Inbox, round 3',
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

test('a resolve of an ask Lee answered or ignored, or a parked item he picked up, finds it closed by Lee; any other resolve finds none, and is checked as ever', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, yesAsk('k1', 'Review round 1')],
        [T0, choiceAsk('k2', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
        [T0, yesAsk('k3', 'Try it on the iPad', 'It works')],
        [T0, yesAsk('k4', 'Run the apply', 'Done')],
        [T0, yesAsk('k5', 'Ship it', 'Go')],
        [T0, yesAsk('k6', 'Review round 2')],
        [T0, yesAsk('k7', 'Review round 3')],
        [T0, yesAsk('k8', 'Review round 4')],
        [T0, oldNote('n1', 'Merged')],
        [T0, park('p1', 'Later')],
        [T0, park('p2', 'Sooner')],
        [T0 + MIN, reply('r1', 'k1', 'yes', { note: 'Tighten the gutters' })],
        [T0 + MIN, reply('r2', 'k2', 'choose', { option: 'Keep it' })],
        [T0 + MIN, reply('r3', 'k3', 'comment', { note: 'It fails' })],
        [T0 + MIN, reply('r4', 'k4', 'ignore')],
        [T0 + MIN, reply('r5', 'k6', 'yes')],
        [T0 + MIN, reply('r6', 'k7', 'yes')],
        [T0 + MIN, reply('r7', 'k8', 'yes')],
        [T0 + MIN, reply('r8', 'p1', 'pickup')],
        [T0 + MIN, delivered('r1', 'r2', 'r3', 'r4', 'r6', 'r7', 'r8')],
        [T0 + MIN, resolve('k5')],
        [T0 + MIN, resolve('n1')],
        [T0 + MIN, resolve('p2')],
        [T0 + 2 * MIN, reopen('k7')],
        [T0 + 2 * MIN, reopen('k8')],
        [T0 + 3 * MIN, reply('r9', 'k8', 'yes')],
        [T0 + 3 * MIN, delivered('r9')],
      ),
    },
  })

  expect(closedByLee(session, { item: 'k1' })?.id).toBe('k1')
  expect(closedByLee(session, { item: ' k2 ' })?.id).toBe('k2')
  expect(closedByLee(session, { item: 'k4' })?.id, 'ignored').toBe('k4')
  expect(closedByLee(session, { item: 'p1' })?.id, 'picked up').toBe('p1')
  expect(closedByLee(session, { item: 'k8' })?.id, 'reopened, then answered again').toBe('k8')
  expect(closedByLee(session, { item: 'k3' }), 'commented, still open').toBeUndefined()
  expect(closedByLee(session, { item: 'k6' }), 'an answer on its way').toBeUndefined()
  expect(closedByLee(session, { item: 'k7' }), 'answered, then reopened').toBeUndefined()
  expect(closedByLee(session, { item: 'k5' }), 'resolved by Claude').toBeUndefined()
  expect(closedByLee(session, { item: 'p2' }), 'parked, resolved by Claude').toBeUndefined()
  expect(closedByLee(session, { item: 'n1' }), 'a note, as one was written').toBeUndefined()
  expect(closedByLee(session, { item: 'zz' })).toBeUndefined()
  expect(value(checkResolve(session, { item: 'k3' }))).toEqual({ type: 'resolve', item: 'k3' })
  expect(value(checkResolve(session, { item: 'k6' }))).toEqual({ type: 'resolve', item: 'k6' })
  expect(value(checkResolve(session, { item: 'k7' }))).toEqual({ type: 'resolve', item: 'k7' })
  expect(refusal(checkResolve(session, { item: 'k5' }))).toBe('k5 is already closed.')
  expect(refusal(checkResolve(session, { item: 'n1' })), 'a note, as one was written').toBe(
    'There is no item n1 on this board.',
  )
  expect(refusal(checkResolve(session, { item: 'p2' }))).toBe('p2 is already closed.')
})

test("Lee's drop of a parked item is one line naming it, a finished session's too; refused once the item is off Parked, how it left saying why, and while his pick-up of it is on its way", () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, yesAsk('k1', 'Review round 1')],
        [T0, park('p1', 'Parked')],
        [T0, park('p2', 'Picked up')],
        [T0, park('p3', 'Closed')],
        [T0, park('p4', 'Dropped')],
        [T0, park('p5', 'On its way')],
        [T0 + MIN, reply('r1', 'p2', 'pickup')],
        [T0 + MIN, delivered('r1')],
        [T0 + MIN, resolve('p3')],
        [T0 + MIN, drop('p4')],
      ),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r2', 'p5', 'pickup')]) },
  })
  const finished = fold({
    logs: { [W1]: file([T0, park('p1', 'Parked')], [T0 + MIN, finish('claude', 'Shipped')]) },
  })

  expect(value(checkDrop(session, 'p1'))).toEqual({ type: 'drop', item: 'p1' })
  expect(value(checkDrop(finished, 'p1')), 'a finished session').toEqual({
    type: 'drop',
    item: 'p1',
  })
  expect(refusal(checkDrop(session, 'p2'))).toBe('it was picked up already.')
  expect(refusal(checkDrop(session, 'p3'))).toBe('Claude closed it already.')
  expect(refusal(checkDrop(session, 'p4'))).toBe('you dropped it already.')
  expect(refusal(checkDrop(session, 'p5'))).toBe('your pick-up of it is on its way to Claude.')
  expect(refusal(checkDrop(session, 'k1')), 'an ask').toBe('it is no longer on the board.')
  expect(refusal(checkDrop(session, 'zz99'))).toBe('it is no longer on the board.')
  expect(closedByLee(session, { item: 'p4' })?.id, 'a resolve finds it closed by Lee').toBe('p4')
  expect(value(checkReopen(session, { item: 'p4' })), 'reopened as any closed item').toEqual({
    type: 'reopen',
    item: 'p4',
  })
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
  expect(refusal(checkEdit(SESSION, { item: 'p1', yes: 'Go' }))).toBe(
    'An edit to a parked item changes title or text, where, ref; not yes.',
  )
  expect(
    refusal(checkEdit(SESSION, { item: 'n1', text: 'Merged #82' })),
    'a note, as one was written',
  ).toBe('There is no item n1 on this board.')
  expect(refusal(checkEdit(SESSION, { item: 'p1' }))).toBe(
    'An edit names a field to change: for a parked item, title or text, where, ref.',
  )
  expect(refusal(checkEdit(SESSION, { item: 'k1', title: ' ' }))).toContain(
    'cannot leave title empty',
  )
})

test("an edit takes an item's one line as text or as title alike, whatever the item; both, saying different things, are refused", () => {
  expect(value(checkEdit(SESSION, { item: 'p1', text: ' Later,\nafter the release ' }))).toEqual({
    type: 'edit',
    item: 'p1',
    changes: { title: 'Later, after the release' },
  })
  expect(value(checkEdit(SESSION, { item: 'k1', text: 'Review round 2' }))?.changes).toEqual({
    title: 'Review round 2',
  })
  expect(
    value(checkEdit(SESSION, { item: 'p1', text: 'Later', title: ' Later ' }))?.changes,
  ).toEqual({ title: 'Later' })
  expect(refusal(checkEdit(SESSION, { item: 'p1', text: 'Later', title: 'Sooner' }))).toBe(
    "An edit gives an item's one line as text or as title, not both with different words.",
  )
  expect(refusal(checkEdit(SESSION, { item: 'k1', title: ' ' }))).toContain(
    'cannot leave title empty',
  )
  expect(refusal(checkEdit(SESSION, { item: 'p1', text: ' ' }))).toContain(
    'cannot leave text empty',
  )
  expect(refusal(checkEdit(SESSION, { item: 'p1', text: '', title: 'Later' }))).toContain(
    'cannot leave text empty',
  )
  expect(refusal(checkEdit(SESSION, { item: 'k1', text: 'Merged', title: 42 }))).toContain(
    'cannot leave title empty or of the wrong kind',
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
    'An edit to a parked item changes title or text, where, ref; not needs.',
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

test('an edit answers for the rules of the shape it changes, not for one its ask broke already, as a decide written before asks had options does', () => {
  const session = fold({ logs: { [W1]: file([T0, kindAsk('o3', 'decide', 'Which palette?')]) } })
  const edited = (fields: object) => checkEdit(session, { item: 'o3', ...fields })

  expect(value(edited({ title: 'Which palette for the band?' }))?.changes).toEqual({
    title: 'Which palette for the band?',
  })
  expect(value(edited({ where: 'In Paper', ref: 'docs/palette.md' }))?.changes).toEqual({
    where: 'In Paper',
    ref: 'docs/palette.md',
  })
  expect(value(edited({ needs: '' }))?.changes, 'its needs, cleared').toEqual({
    wants: 'choice',
    needs: '',
  })
  expect(value(edited({ wants: 'words' }))?.changes).toEqual({ wants: 'words' })
  expect(value(edited({ options: ['Dark', 'Light'] }))?.changes).toEqual({
    wants: 'choice',
    options: ['Dark', 'Light'],
  })

  expect(refusal(edited({ options: ['Dark'] }))).toBe('A choice ask needs at least 2 options.')
  expect(refusal(edited({ wants: 'choice' })), 'what it wants, the whole shape').toBe(
    'A choice ask needs at least 2 options.',
  )
  expect(refusal(edited({ title: 'Pick one', yes: 'Go' }))).toBe('Only a yes ask takes yes.')
  expect(refusal(edited({ needs: 'which palette' }))).toBe(
    'Only a words ask takes needs: what its words are.',
  )
  expect(
    refusal(edited({ recommended: 'Dark' })),
    'an option recommended, of options too few',
  ).toBe('A choice ask needs at least 2 options.')
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

test("a park's id is unlike any its session uses and any its project's other sessions parked, so no two share one in Claude's Parked", () => {
  const random = scripted([19, 3, 15, 9], [20, 2, 22, 8])

  expect(
    value(withParkId(checkPark({ title: 'Later' }), { ids: new Set() }, [{ id: 'k3f9' }], random)),
  ).toMatchObject({ id: 'm2p8' })
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

test("a words ask, an old one needing something back among them, takes its words on one line as the pane's words answer; only an ask is answered", () => {
  const answer = '  Ship the\n Tuesday  build '

  expect(value(checkAnswer(SESSION, { ask: 'k4', answer }))).toEqual({
    type: 'reply',
    item: 'k4',
    verdict: 'answer',
    note: 'Ship the Tuesday build',
  })
  expect(value(checkAnswer(SESSION, { ask: 'o1', answer: 'Done' }))).toEqual({
    type: 'reply',
    item: 'o1',
    verdict: 'answer',
    note: 'Done',
  })

  for (const given of [undefined, '', ' \n ']) {
    expect(refusal(checkAnswer(SESSION, { ask: 'k4', answer: given })), JSON.stringify(given)).toBe(
      'k4 wants words: give them after its id.',
    )
  }

  expect(
    refusal(checkAnswer(SESSION, { ask: 'n1', answer: 'Yes' })),
    'a note, as one was written',
  ).toBe('There is no item n1 on this board.')
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

test('an ask closed, or with an answer on its way, takes no answer, though a comment on its way bars none; nor does a finished session', () => {
  const sent = fold({
    logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'ignore')]) },
  })
  const commented = fold({
    logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'comment', { note: 'Tighten it' })]) },
  })
  const finished = fold({
    logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')], [T0 + MIN, finish('lee')]) },
  })

  expect(refusal(checkAnswer(SESSION, { ask: 'k9', answer: 'Done' }))).toBe('k9 is already closed.')
  expect(refusal(checkAnswer(sent, { ask: 'k1', answer: 'Approve' }))).toBe(
    'An answer to k1 is on its way already.',
  )
  expect(value(checkAnswer(commented, { ask: 'k1', answer: 'Approve' }))).toMatchObject({
    verdict: 'yes',
  })
  expect(refusal(checkAnswer(finished, { ask: 'k1', answer: 'Approve' }))).toBe(
    'This session is finished: its asks wait on you no more.',
  )
})

/** When a snooze is checked, and a time still to come then. */
const NOW = T0 + 10 * MIN
const LATER = NOW + 60 * MIN

/** A window holding the session, in the state given since a minute in. */
const windowIn = (is: 'yourTurn' | 'working' | 'permission') => ({
  [W1]: beat(W1, { attachedAt: T0, seenAt: NOW, state: { is, since: T0 + MIN } }),
})

const atTurn = windowIn('yourTurn')

/**
 * A board for snoozing: two asks waiting on Lee, one Lee commented on, one
 * ignored, one closed, one with Lee's answer on its way, and a parked item,
 * a window holding it at Lee's turn unless `presence` says otherwise.
 */
const boardOf = (lines: Line[] = [], presence: SessionFiles['presence'] = atTurn) =>
  fold(
    {
      logs: {
        [W1]: file(
          [T0, yesAsk('k1', 'Review round 1')],
          [T0, choiceAsk('k2', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
          [T0, yesAsk('k3', 'Try it on the iPad', 'It works')],
          [T0, yesAsk('k4', 'Tag the release', 'Done')],
          [T0, yesAsk('k5', 'Run the apply', 'Done')],
          [T0, yesAsk('k6', 'Ship it', 'Go')],
          [T0, park('p1', 'Later')],
          [T0 + MIN, reply('r1', 'k3', 'comment', { note: 'It fails' })],
          [T0 + MIN, reply('r2', 'k4', 'ignore')],
          [T0 + MIN, delivered('r1', 'r2')],
          [T0 + MIN, resolve('k5')],
          [T0 + MIN, reply('r3', 'k6', 'yes')],
          ...lines,
        ),
      },
      presence,
    },
    NOW,
  )

const BOARD = boardOf()

/** Every ask waiting on Lee, as its row shows them. */
const SHOWN = ['k1', 'k2']

const snoozeOf = (ask: unknown, until: unknown = LATER) => checkSnooze(BOARD, { ask, until }, NOW)

/** The snooze, holding the asks waiting on Lee as it is checked. */
const SNOOZED = { type: 'snoozeSession', until: LATER, asks: SHOWN }

test("a snooze is one line, the session's, until a time still to come, naming the asks its row shows: every one waiting on Lee, those waiting on him no more as they please", () => {
  expect(value(snoozeOf(SHOWN))).toEqual(SNOOZED)
  expect(value(snoozeOf(['k2', ' k1 ', 'k1', 'k3', 'k4', 'k5', 'k6']))).toEqual(SNOOZED)
  expect(
    value(snoozeOf(SHOWN, String(LATER + MIN))),
    'the time in digits, as the CLI gives it',
  ).toEqual({ ...SNOOZED, until: LATER + MIN })
  expect(value(snoozeOf(SHOWN, NOW + 1)), 'a moment on').toEqual({ ...SNOOZED, until: NOW + 1 })
  expect(value(snoozeOf(SHOWN, 8.64e15)), 'the last time a Date holds').toEqual({
    ...SNOOZED,
    until: 8.64e15,
  })
  expect(value(checkSnooze(BOARD, { ask: SHOWN }, NOW)), 'no time, until it moves').toEqual({
    type: 'snoozeSession',
    asks: SHOWN,
  })
})

test('a session snoozed already is snoozed again, to the new time, its asks asleep naming none; one at its turn alone names none, and one away with asks waiting snoozes too', () => {
  const asleep = boardOf([[T0 + 2 * MIN, snoozeSession(LATER, ...SHOWN)]])
  const turnAlone = fold({ presence: atTurn }, NOW)
  const away = boardOf([], {})

  expect(value(checkSnooze(asleep, { until: LATER + MIN }, NOW))).toEqual({
    ...SNOOZED,
    until: LATER + MIN,
  })
  expect(value(checkSnooze(turnAlone, { until: LATER }, NOW))).toEqual({ ...SNOOZED, asks: [] })
  expect(value(checkSnooze(away, { ask: SHOWN, until: LATER }, NOW))).toEqual(SNOOZED)
})

test("a snooze is refused, the first refusal in order saying why: the session finished; an id no item or no ask; an ask waiting on Lee its row did not show; nothing needing Lee, a window's stop its own; then its time no time, or come already", () => {
  const finished = fold({
    logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')], [T0 + MIN, finish('lee')]) },
  })
  const settled = (presence: SessionFiles['presence']) =>
    checkSnooze(
      fold(
        {
          logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')], [T0, resolve('k1')]) },
          presence,
        },
        NOW,
      ),
      { ask: ['k1'], until: LATER },
      NOW,
    )
  const unseen = 'An ask waits on you that the snooze did not name: look at it, then snooze again.'
  const nothing = 'Help desk redesign needs nothing of you: there is nothing to snooze.'
  const noTime =
    'A snooze wakes at a time in milliseconds since the epoch, or with none until it moves.'
  const come = 'That time has come already: give one still to come.'

  for (const [why, refused, error] of [
    [
      'finished',
      checkSnooze(finished, { ask: ['k1'], until: LATER }, NOW),
      'This session is finished: its asks wait on you no more.',
    ],
    ['no item', snoozeOf([...SHOWN, 'zz']), 'There is no item zz on this board.'],
    ['a parked item', snoozeOf(['p1', ...SHOWN]), 'p1 is a parked item, not an ask.'],
    ['one left out', snoozeOf(['k1'], 'soon'), unseen],
    ['none named', snoozeOf([]), unseen],
    ['no ids at all', checkSnooze(BOARD, { until: LATER }, NOW), unseen],
    ['nothing waiting, away', settled({}), nothing],
    ['working', settled(windowIn('working')), nothing],
    ['a permission prompt alone', settled(windowIn('permission')), nothing],
    ['not a time', snoozeOf(SHOWN, 'tomorrow'), noTime],
    ['not a whole time', snoozeOf(SHOWN, `${LATER}.5`), noTime],
    ['a number not whole', snoozeOf(SHOWN, LATER + 0.5), noTime],
    ['digits past any time', snoozeOf(SHOWN, '99999999999999999999'), noTime],
    ['nanoseconds, as date +%s%N gives them', snoozeOf(SHOWN, `${LATER}000000`), noTime],
    ['just past what a Date holds', snoozeOf(SHOWN, 8.64e15 + 1), noTime],
    ['come already', snoozeOf(SHOWN, NOW), come],
    ['long gone', snoozeOf(SHOWN, String(T0)), come],
  ] as const) {
    expect(refusal(refused), why).toBe(error)
  }
})

test("a wake is one line, the session's, wherever a snooze of Lee's stands, run out at its time, his own of one ask, or an old line's of a turn; refused in a finished session, or one not snoozed", () => {
  const woken = { type: 'wakeSession' }

  expect(value(checkWake(boardOf([[T0 + 2 * MIN, snoozeSession(LATER, ...SHOWN)]])))).toEqual(woken)
  expect(
    value(checkWake(boardOf([[T0 + 2 * MIN, snoozeSession(NOW, ...SHOWN)]]))),
    'run out',
  ).toEqual(woken)
  expect(
    value(checkWake(boardOf([[T0 + 2 * MIN, snooze('k1', LATER)]]))),
    'his own of one ask',
  ).toEqual(woken)
  expect(value(checkWake(boardOf([[T0 + 2 * MIN, snoozeTurn(T0)]]))), "an old line's").toEqual(
    woken,
  )
  expect(refusal(checkWake(fold({ logs: { [W1]: file([T0, finish('lee')]) } })))).toBe(
    'This session is finished: its asks wait on you no more.',
  )
  expect(refusal(checkWake(BOARD))).toBe('Help desk redesign is not snoozed.')
  expect(
    refusal(
      checkWake(
        boardOf([
          [T0 + 2 * MIN, snoozeSession(LATER, ...SHOWN)],
          [T0 + 3 * MIN, wakeSession()],
        ]),
      ),
    ),
    'woken already',
  ).toBe('Help desk redesign is not snoozed.')
})

const FINISHED = 'This session is finished: its asks wait on you no more.'

/** Lee's snooze of k1 alone until LATER, as the pane writes it. */
const K1_ASLEEP: Line = [T0 + 2 * MIN, snooze('k1', LATER)]

/** Lee's snooze of the session until LATER, as the card writes it. */
const SESSION_ASLEEP: Line = [T0 + 2 * MIN, snoozeSession(LATER, ...SHOWN)]

/** Lee's snooze of one ask on the board, as the pane gives it. */
const snoozeAskOf = (id: string, until = LATER, board = BOARD) =>
  checkSnoozeAsk(board, id, until, NOW)

test("Lee's snooze of one ask is one line, that ask's, until a time still to come; one snoozed already, on its own or with its session, is snoozed again, to the new time", () => {
  const again = { type: 'snooze', item: 'k1', until: LATER + MIN }

  expect(value(snoozeAskOf('k1'))).toEqual({ type: 'snooze', item: 'k1', until: LATER })
  expect(value(snoozeAskOf('k1', NOW + 1)), 'a moment on').toMatchObject({ until: NOW + 1 })
  expect(value(snoozeAskOf('k1', LATER + MIN, boardOf([K1_ASLEEP]))), 'on its own').toEqual(again)
  expect(
    value(snoozeAskOf('k1', LATER + MIN, boardOf([SESSION_ASLEEP]))),
    'with its session',
  ).toEqual(again)
})

test("Lee's snooze of one ask is refused, the first refusal in order saying why: the session finished; the ask gone, or no ask; closed or ignored; his reply on its way to it, an answer or a comment; his comment Claude's to act on; then its time come already", () => {
  const finished = boardOf([[T0 + 2 * MIN, finish('lee')]])
  const commenting = boardOf([[T0 + 2 * MIN, reply('r4', 'k1', 'comment', { note: 'Off' })]])
  const gone = 'it is no longer on the board.'
  const onItsWay = 'your reply to it is on its way to Claude.'
  const claudes = "it waits on Claude: your comment is Claude's to act on."
  const come = 'That time has come already: give one still to come.'

  for (const [why, refused, error] of [
    ['finished', snoozeAskOf('k1', LATER, finished), FINISHED],
    ['no item', snoozeAskOf('zz'), gone],
    ['a parked item', snoozeAskOf('p1'), gone],
    ['closed', snoozeAskOf('k5'), 'it is closed already.'],
    ['ignored', snoozeAskOf('k4'), 'it is ignored already.'],
    ['an answer on its way', snoozeAskOf('k6'), onItsWay],
    ['a comment on its way', snoozeAskOf('k1', LATER, commenting), onItsWay],
    ['Claude has a comment', snoozeAskOf('k3'), claudes],
    ['come already', snoozeAskOf('k1', NOW), come],
  ] as const) {
    expect(refusal(refused), why).toBe(error)
  }
})

test("Lee's wake now on an ask wakes that ask alone where his own snooze of it stands, run out at its time or not; its session where the session's snooze holds it; refused in a finished session, and for an ask not snoozed", () => {
  const own = boardOf([K1_ASLEEP])
  const ranOut = boardOf([[T0 + 2 * MIN, snooze('k1', NOW)]])
  const finished = boardOf([K1_ASLEEP, [T0 + 3 * MIN, finish('lee')]])
  const wakeK1 = { type: 'wake', item: 'k1' }

  expect(value(checkWakeAsk(own, 'k1'))).toEqual(wakeK1)
  expect(value(checkWakeAsk(ranOut, 'k1')), 'run out').toEqual(wakeK1)
  expect(value(checkWakeAsk(boardOf([SESSION_ASLEEP]), 'k1')), "the session's").toEqual({
    type: 'wakeSession',
  })
  expect(refusal(checkWakeAsk(finished, 'k1'))).toBe(FINISHED)
  expect(refusal(checkWakeAsk(own, 'k2')), 'another ask, waiting').toBe('it is not snoozed.')
  expect(refusal(checkWakeAsk(own, 'zz')), 'no item').toBe('it is not snoozed.')
})
