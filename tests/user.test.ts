/**
 * What Claude reads names the person the board is for "the user", as Claude
 * Code does, and guesses at no pronoun (DESIGN.md, "The user"): the board
 * text in every standing, a board message's lines, the narration line, a
 * reopened session's words, the listing, every refusal core's checks give,
 * and the CLI's help. The guide, the tools and each command's help are held
 * to it beside their own tests.
 */
import { expect, test } from './kit'
import { HELP } from '../cli/help'
import {
  boardMessage,
  boardText,
  checkAnswer,
  checkAsk,
  checkDrop,
  checkEdit,
  checkFinish,
  checkJoin,
  checkMove,
  checkMoveTo,
  checkPark,
  checkParkedIn,
  checkProject,
  checkReopen,
  checkResolve,
  checkSnooze,
  checkStart,
  checkStatus,
  checkWake,
  onBoardText,
  reopenedText,
  startText,
  summarise,
  summariseProject,
  toldSummary,
  type Checked,
} from '../core'
import { summarisedLine } from '../hooks/summarised'
import { MIN, PERSON, SENDER, T0, W1 } from './data'
import {
  beat,
  choiceAsk,
  delivered,
  drop,
  file,
  finish,
  fold,
  kindAsk,
  park,
  reply,
  resolve,
  snoozeSession,
  wordsAsk,
  yesAsk,
} from './lines'

const NOW = T0 + 10 * MIN
const LATER = NOW + 60 * MIN

/** A session holding an ask waiting, one replied to, one with an answer on its way, a words ask, a parked item, and one closed. */
const SESSION = fold(
  {
    logs: {
      [W1]: file(
        [T0, yesAsk('k1', 'Review round 1')],
        [T0, choiceAsk('k2', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
        [T0, yesAsk('k3', 'Try it on the iPad', 'It works')],
        [T0, wordsAsk('k4', 'Run the export', "the command's output")],
        [T0, kindAsk('k5', 'decide', 'Which palette?')],
        [T0, yesAsk('k9', 'Run the apply', 'Done')],
        [T0, park('p1', 'Later')],
        [T0 + MIN, resolve('k9')],
        [T0 + MIN, reply('r1', 'k3', 'comment', { note: 'It fails' })],
        [T0 + MIN, delivered('r1')],
      ),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r2', 'k2', 'choose', { option: 'Keep it' })]) },
  },
  NOW,
)

const SNOOZED = fold(
  {
    logs: {
      [W1]: file([T0, yesAsk('k1', 'Review round 1')], [T0 + MIN, snoozeSession(LATER, 'k1')]),
    },
  },
  NOW,
)

const UNTIL_IT_MOVES = fold(
  {
    logs: {
      [W1]: file([T0, yesAsk('k1', 'Review round 1')], [T0 + MIN, snoozeSession(undefined, 'k1')]),
    },
  },
  NOW,
)

const FINISHED = fold(
  { logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')], [T0 + MIN, finish('lee')]) } },
  NOW,
)

/** A session with a parked item Lee dropped, and one his pick-up is on its way to. */
const DROPPED = fold(
  {
    logs: {
      [W1]: file([T0, park('p1', 'Later')], [T0, park('p2', 'Sooner')], [T0 + MIN, drop('p1')]),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r3', 'p2', 'pickup')]) },
  },
  NOW,
)

/** A session needing nothing: a parked item alone, no window at its turn. */
const QUIET = fold({ logs: { [W1]: file([T0, park('p1', 'Later')]) } }, NOW)

/** A session whose delivering window says no version, behind any the CLI gives. */
const OLD = fold(
  {
    logs: { [W1]: file([T0, yesAsk('k1', 'Review round 1')]) },
    presence: { [W1]: beat(W1, { attachedAt: T0, seenAt: NOW }) },
  },
  NOW,
)

const refusalOf = (checked: Checked<unknown>) => {
  if (checked.ok) {
    throw new Error(`refused nothing: ${JSON.stringify(checked.value)}`)
  }

  return checked.error
}

test('the board text, in every standing, held or not, names the user and no pronoun', () => {
  const texts = [SESSION, SNOOZED, UNTIL_IT_MOVES, FINISHED].flatMap(session => [
    boardText(session, [], true),
    boardText(session, [], false),
  ])

  expect(texts.join('\n')).toContain('waiting on the user: Review round 1')
  expect(texts.join('\n')).toContain('the user replied, yours to act on')
  expect(texts.join('\n')).toContain('snoozed by the user until')
  expect(texts.join('\n')).toContain("can't be answered (the session is finished)")
  expect(texts.join('\n')).not.toMatch(PERSON)
})

test("a board message's lines, each way it leaves an ask, name no person and guess at no pronoun", () => {
  const message = boardMessage(SESSION, [
    { item: 'k1', verdict: 'yes' },
    { item: 'k2', verdict: 'comment', note: 'After lunch' },
    { item: 'k3', verdict: 'comment', note: 'Still fails' },
    { item: 'p1', verdict: 'pickup' },
  ])?.text

  expect(message).toContain('This closes the ask: nothing more to do with it.')
  expect(message).toContain(
    'An answer from the user to this ask, sent apart from this message, closes it.',
  )
  expect(message).toContain('This leaves the ask open: act on it, then resolve it.')
  expect(message).not.toMatch(PERSON)
})

test('the narration line, either way, and a reopened session, either finisher, name the user and no pronoun', () => {
  const lines = [
    summarisedLine(['Merged it.']),
    summarisedLine(['']),
    reopenedText({ who: 'lee', by: W1, at: T0 }),
    reopenedText({ who: 'claude', by: W1, at: T0, reason: 'Shipped' }),
  ]

  expect(lines[2]).toBe('It had been finished by the user; joining it reopened it.')
  expect(lines.join('\n')).not.toMatch(PERSON)
})

test('the listing and the line naming the session a window holds name the user and no pronoun', () => {
  const held = toldSummary(SNOOZED)
  const projects = [summariseProject('northwind', [summarise(SESSION), held])]
  const listing = [onBoardText(projects), startText(projects, held)].join('\n')

  expect(listing).toContain('waiting on the user')
  expect(listing).toContain('This window already holds')
  expect(listing).not.toMatch(PERSON)
})

test("the CLI's help names no person and guesses at no pronoun", () => {
  expect(HELP).not.toMatch(PERSON)
})

test("every refusal core's checks give names no person and guesses at no pronoun; the person's own presses meet you", () => {
  const ask = { wants: 'choice', title: 'Keep it?' }
  const refusals = [
    checkAsk({ ...ask, options: ['Keep it (recommended)', 'Drop it - recommended'] }),
    checkAsk({ ...ask, options: ['Keep it (recommended)', 'Drop it'], recommended: 'Drop it' }),
    checkAsk({ ...ask, options: ['Keep it', 'Keep it (recommended)'] }),
    checkAsk({ ...ask, options: ['Keep it', 'Drop it'], recommended: 'Hold' }),
    checkAsk({ ...ask, options: ['Keep it', 'Drop it'], recommended: 5 }),
    checkAsk({ ...ask, options: ['Keep it'] }),
    checkAsk({ wants: 'yes', title: 'Give the go' }),
    checkAsk({ wants: 'yes', yes: 'Go ahead and merge it all', title: 'Give the go' }),
    checkAsk({ wants: 'words', yes: 'Go', title: 'Run it' }),
    checkAsk({ wants: 'yes', yes: 'Go', title: 'Run it', options: ['A', 'B'] }),
    checkAsk({ wants: 'yes', yes: 'Go', title: 'Run it', needs: 'the output' }),
    checkAsk({ wants: 'yes', yes: 'Go', title: 'Run it', recommended: 'Go' }),
    checkAsk({ title: 'Run it' }),
    checkAsk({ wants: 'words' }),
    checkPark({}),
    checkStart({ summary: 'Area by area' }),
    checkStart({ name: 'Help desk' }),
    checkStart({ name: 'Help desk', summary: 'Area by area' }),
    checkStart({
      name: 'Help desk',
      summary: 'Area by area',
      project: 'Northwind',
      directory: 'x',
    }),
    checkProject({ name: '---' }),
    checkProject({}),
    checkMove({}),
    checkMoveTo(SESSION, 'northwind', { key: 'northwind', name: 'Northwind' }),
    checkJoin({}),
    checkStatus({}, SESSION.status),
    checkStatus({ name: ' ' }, SESSION.status),
    checkStatus({ now: 5 }, SESSION.status),
    checkResolve(SESSION, {}),
    checkResolve(SESSION, { item: 'zz' }),
    checkResolve(SESSION, { item: 'k9' }),
    checkReopen(SESSION, { item: 'k1' }),
    checkParkedIn(SESSION, { item: 'k1' }),
    checkEdit(SESSION, { item: 'k1' }),
    checkEdit(SESSION, { item: 'k1', text: 'One', title: 'Two' }),
    checkEdit(SESSION, { item: 'p1', yes: 'Go' }),
    checkEdit(SESSION, { item: 'k1', title: ' ' }),
    checkFinish(FINISHED, 'claude'),
    checkAnswer(FINISHED, { ask: 'k1', answer: 'Approve' }),
    checkAnswer(OLD, { ask: 'k1', answer: 'Approve' }, '9.9.9'),
    checkAnswer(SESSION, { ask: 'k9', answer: 'Done' }),
    checkAnswer(SESSION, { ask: 'k2', answer: 'Drop it' }),
    checkAnswer(SESSION, { ask: 'k4', answer: ' ' }),
    checkAnswer(SESSION, { ask: 'k5', answer: 'Dark' }),
    checkAnswer(SESSION, { ask: 'k1', answer: 'Go' }),
    checkAnswer(SESSION, { ask: 'k1', answer: 'Approve', ignore: true }),
    checkAnswer(SESSION, { ask: 'p1', answer: 'Yes' }),
    checkSnooze(FINISHED, { ask: ['k1'], until: LATER }, NOW),
    checkSnooze(SESSION, { ask: [], until: LATER }, NOW),
    checkSnooze(QUIET, { ask: [], until: LATER }, NOW),
    checkSnooze(SNOOZED, { ask: ['k1'], until: 'tomorrow' }, NOW),
    checkSnooze(SNOOZED, { ask: ['k1'], until: T0 }, NOW),
    checkWake(FINISHED),
    checkWake(SESSION),
    checkDrop(SESSION, 'k1'),
    checkDrop(DROPPED, 'p1'),
    checkDrop(DROPPED, 'p2'),
  ].map(refusalOf)

  expect(refusals).toContain('This session is finished: its asks wait on you no more.')
  expect(refusals).toContain(
    'An ask waits on you that the snooze did not name: look at it, then snooze again.',
  )
  expect(refusals).toContain('Help desk redesign needs nothing of you: there is nothing to snooze.')
  expect(refusals).toContain(
    "A project's name is one line, as the user would say it, with a letter or a digit.",
  )
  expect(refusals).toContain('you dropped it already.')
  expect(refusals.join('\n')).not.toMatch(PERSON)
})
