import { expect, test } from 'claude-code/testing'
import { foldSession, serialise, VERSION } from '../core'
import {
  choiceAsk,
  CLI,
  file,
  finish,
  fold,
  MIN,
  note,
  park,
  reopen,
  resolve,
  SENDER,
  status,
  T0,
  unfinish,
  W1,
  W2,
  yesAsk,
  type Line,
} from './support'

/** The log's notes, oldest first, as text. */
const notesOf = (files: Parameters<typeof fold>[0]) =>
  fold(files)
    .log.filter(line => line.kind === 'note')
    .map(line => line.text)
    .reverse()

test("writers' lines merge by time, whichever file holds them", () => {
  const logs = {
    [W1]: file([T0 + 1 * MIN, note('n1', 'first')], [T0 + 4 * MIN, note('n4', 'fourth')]),
    [W2]: file([T0 + 2 * MIN, note('n2', 'second')], [T0 + 3 * MIN, note('n3', 'third')]),
  }

  expect(notesOf({ logs })).toEqual(['first', 'second', 'third', 'fourth'])
})

test('lines at the same time order by writer, then by the writer’s own count', () => {
  const at = T0 + MIN
  const outOfOrder = [
    { v: VERSION, at, seq: 2, type: 'note', id: 'b2', text: 'w2, second' },
    { v: VERSION, at, seq: 1, type: 'note', id: 'b1', text: 'w2, first' },
  ]
  const logs = {
    [W2]: outOfOrder.map(line => serialise(line as never)).join(''),
    [W1]: file([T0, note('a1', 'w1, earlier')], [at, note('a2', 'w1, at the same time')]),
  }

  expect(notesOf({ logs })).toEqual([
    'w1, earlier',
    'w1, at the same time',
    'w2, first',
    'w2, second',
  ])
})

test('the latest status across writers wins, whoever wrote it', () => {
  const logs = {
    [W1]: file(
      [T0 + 1 * MIN, status(['Drawing Usage, round 1'])],
      [T0 + 5 * MIN, note('n1', 'later')],
    ),
    [W2]: file([T0 + 3 * MIN, status(['Drawing Usage, round 2'], { next: 'Usage, round 3' })]),
    [CLI]: file([T0 + 2 * MIN, status(['Generating frames'])]),
  }
  const session = fold({ logs })

  expect(session.status).toEqual({
    name: 'Dashboard redesign',
    summary: 'Redesign the dashboard, area by area in Paper',
    now: ['Drawing Usage, round 2'],
    next: 'Usage, round 3',
    at: T0 + 3 * MIN,
    by: W2,
  })
})

test('with no status yet, the session stands as it was started', () => {
  const session = fold({ logs: {} })

  expect(session.status).toMatchObject({ name: 'Dashboard redesign', now: [], at: T0, by: W1 })
  expect(session.updatedAt).toBe(T0)
})

test('the first line to use an id keeps it', () => {
  const logs = {
    [W1]: file([T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')]),
    [W2]: file(
      [T0 + 2 * MIN, note('k3f9', 'A clashing note')],
      [T0 + 3 * MIN, park('k3f9', 'A clashing park')],
    ),
  }
  const session = fold({ logs })

  expect([...session.items.values()].map(item => item.type)).toEqual(['ask'])
  expect(session.log).toEqual([])
})

test("an edit changes only its item's own fields, and the log shows a note as edited", () => {
  const logs = {
    [W1]: file(
      [T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')],
      [T0 + 2 * MIN, note('n4m5', 'PR #81 merged')],
      [
        T0 + 3 * MIN,
        {
          type: 'edit',
          item: 'k3f9',
          changes: { title: 'Review round 2', text: 'not an ask field' },
        },
      ],
      [
        T0 + 4 * MIN,
        { type: 'edit', item: 'n4m5', changes: { text: 'PR #82 merged' }, reason: 'Wrong number' },
      ],
    ),
  }
  const session = fold({ logs })
  const edited = session.items.get('k3f9')

  expect(edited).toMatchObject({ title: 'Review round 2', editedAt: T0 + 3 * MIN })
  expect(edited).not.toHaveProperty('text')
  expect(session.log[0]).toMatchObject({
    kind: 'note',
    id: 'n4m5',
    text: 'PR #82 merged',
    at: T0 + 2 * MIN,
  })
  expect(session.items.get('n4m5')).toMatchObject({ reason: 'Wrong number' })
})

test('an ask edited to want something other than a choice keeps no options', () => {
  const logs = {
    [W1]: file(
      [T0 + 1 * MIN, choiceAsk('k2', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
      [
        T0 + 2 * MIN,
        {
          type: 'edit',
          item: 'k2',
          changes: { wants: 'yes', yes: 'Approve', title: 'Review the cut' },
        },
      ],
    ),
  }

  expect(fold({ logs }).asks[0]).toMatchObject({
    wants: 'yes',
    yes: 'Approve',
    title: 'Review the cut',
    options: undefined,
  })
})

test('a resolved note leaves the log; reopened, it is back where it was', () => {
  const posted: Line[] = [
    [T0 + 1 * MIN, note('n1', 'first')],
    [T0 + 2 * MIN, note('n2', 'second')],
    [T0 + 3 * MIN, resolve('n1', 'Posted twice')],
  ]

  expect(notesOf({ logs: { [W1]: file(...posted) } })).toEqual(['second'])
  expect(notesOf({ logs: { [W1]: file(...posted, [T0 + 4 * MIN, reopen('n1')]) } })).toEqual([
    'first',
    'second',
  ])
})

test('changes to an item no line posted change nothing', () => {
  const logs = {
    [W1]: file(
      [T0 + 1 * MIN, resolve('gone')],
      [T0 + 2 * MIN, reopen('gone')],
      [T0 + 3 * MIN, { type: 'edit', item: 'gone', changes: { title: 'x' } }],
    ),
  }

  expect(fold({ logs }).items.size).toBe(0)
})

test('an inbox holds only replies: anything else a sender wrote there is ignored', () => {
  const session = fold({
    logs: { [W1]: file([T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')]) },
    inbox: {
      [SENDER]: file(
        [T0 + 2 * MIN, yesAsk('a2b3', 'Posted from elsewhere', 'Done')],
        [T0 + 3 * MIN, status(['Hijacked'])],
        [T0 + 4 * MIN, resolve('k3f9')],
      ),
    },
  })

  expect([...session.items.keys()]).toEqual(['k3f9'])
  expect(session.asks[0]?.state).toBe('waiting')
  expect(session.status.now).toEqual([])
})

test('the session knows every id its lines use, items and replies alike', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')],
        [T0 + 2 * MIN, note('n4m5', 'Merged')],
        [T0 + 3 * MIN, park('p1q2', 'Later')],
      ),
    },
    inbox: {
      [SENDER]: file([T0 + 4 * MIN, { type: 'reply', id: 'r7x2', item: 'k3f9', verdict: 'yes' }]),
    },
  })

  expect([...session.ids].sort()).toEqual(['k3f9', 'n4m5', 'p1q2', 'r7x2'])
  expect(session.updatedAt).toBe(T0 + 4 * MIN)
})

test('a session whose session.json is missing or torn does not fold', () => {
  expect(foldSession({ meta: '', logs: {} }, T0)).toBeUndefined()
  expect(foldSession({ meta: '{"v":1,"id":"sr-k3f9', logs: {} }, T0)).toBeUndefined()
})

test('a finish finishes the session, by whom and why; its waiting asks stop counting, and later lines leave it finished', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')],
        [T0 + 2 * MIN, finish('claude', 'Shipped')],
      ),
      [CLI]: file([T0 + 3 * MIN, yesAsk('k4a1', 'Run the apply', 'Done')]),
    },
  })

  expect(session.finished).toEqual({ at: T0 + 2 * MIN, by: W1, who: 'claude', reason: 'Shipped' })
  expect(session.asks.map(each => each.state)).toEqual(['waiting', 'waiting'])
  expect(session.waiting).toBe(0)
})

test('an unfinish takes a finished session up again, its waiting asks counting once more', () => {
  const session = fold({
    logs: {
      [W1]: file([T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')], [T0 + 2 * MIN, finish('lee')]),
      [W2]: file([T0 + 3 * MIN, unfinish()]),
    },
  })

  expect(session.finished).toBeUndefined()
  expect(session.waiting).toBe(1)
})

test('a finish in the inbox, or by a finisher the format does not know, finishes nothing', () => {
  const session = fold({
    logs: {
      [W1]: `${JSON.stringify({ v: VERSION, at: T0 + MIN, seq: 1, type: 'finish', who: 'cli' })}\n`,
    },
    inbox: { [SENDER]: file([T0 + 2 * MIN, finish('lee')]) },
  })

  expect(session.finished).toBeUndefined()
})
