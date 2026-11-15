import { expect, test } from './kit'
import { foldSession, serialise, VERSION } from '../core'
import {
  choiceAsk,
  CLI,
  delivered,
  file,
  finish,
  fold,
  MIN,
  note,
  park,
  reopen,
  reply,
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

test("a writer's own file and its letters count apart: of their lines at one moment, the file's comes first, whatever the counts", () => {
  const at = T0 + 2 * MIN
  const session = fold({
    logs: {
      [W1]: file([T0, yesAsk('k1', 'Review it')], [T0 + MIN, resolve('k1')], [at, reopen('k1')]),
    },
    inbox: { [W1]: file([at, reply('r1', 'k1', 'yes')]) },
  })

  expect(session.replies[0]?.voided, 'the reply comes after the reopen').toBeUndefined()
  expect(session.asks[0]?.answerOnItsWay?.id).toBe('r1')
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

test("no line about a parked item but its park moves its session's time: a pick-up, its mark, a resolve, an edit and a reopen leave it as recent as it was, whoever writes them", () => {
  const parked = T0 + 2 * MIN
  const session = fold({
    logs: {
      [W1]: file(
        [T0, status(['Drawing the ledger'])],
        [T0 + MIN, park('p1', 'Export the ledger as CSV')],
        [parked, park('p2', 'Archive old requests')],
        [parked, park('p3', 'A tmux indicator')],
      ),
      [W2]: file(
        [T0 + 10 * MIN, reply('r1', 'p1', 'pickup')],
        [T0 + 10 * MIN, delivered('r1')],
        [T0 + 11 * MIN, resolve('p2', 'Done elsewhere')],
        [T0 + 12 * MIN, { type: 'edit', item: 'p3', changes: { title: 'A tmux badge' } }],
        [T0 + 13 * MIN, resolve('p3')],
        [T0 + 14 * MIN, reopen('p3')],
      ),
    },
  })
  const noted = fold({
    logs: {
      [W1]: file([parked, park('p1', 'Later')], [T0 + 20 * MIN, note('n1', 'Drew it')]),
    },
  })

  expect(session.parked.map(each => [each.id, each.title])).toEqual([['p3', 'A tmux badge']])
  expect(session.updatedAt).toBe(parked)
  expect(noted.updatedAt, 'a note moves it').toBe(T0 + 20 * MIN)
})

test('a mark moves the time unless every reply it names is a pick-up; a mark read before its reply is judged too', () => {
  const asked: Line[] = [
    [T0, yesAsk('k1', 'Run the apply', 'Done')],
    [T0, park('p1', 'A tmux indicator')],
  ]
  const both = fold({
    logs: {
      [W1]: file(...asked, [T0 + 5 * MIN, delivered('r1', 'r2')]),
      [W2]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, reply('r2', 'p1', 'pickup')]),
    },
  })
  const early = fold({
    logs: {
      [W1]: file(...asked, [T0 + 4 * MIN, delivered('r2')]),
      [W2]: file([T0 + 5 * MIN, reply('r2', 'p1', 'pickup')]),
    },
  })

  expect(both.updatedAt, 'a pick-up and an answer').toBe(T0 + 5 * MIN)
  expect(early.parked, 'picked up by the mark read before it').toEqual([])
  expect(early.updatedAt, 'a pick-up alone').toBe(T0)
})

test('a line naming an item or a reply the session does not have moves the time as any line does, and settles nothing', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, park('p1', 'A tmux indicator')],
        [T0 + MIN, reply('r1', 'sr-q7rx01:p1', 'pickup')],
        [T0 + MIN, delivered('r1')],
        [T0 + 2 * MIN, resolve('zz99')],
        [T0 + 3 * MIN, delivered('nope')],
      ),
    },
  })

  expect(
    session.parked.map(each => each.id),
    'an item named by its address is none',
  ).toEqual(['p1'])
  expect(session.replies).toEqual([])
  expect(session.updatedAt).toBe(T0 + 3 * MIN)
})

test('a pick-up and its mark, written together into a finished session, pick its item up: void as it reaches the finished session, the mark lets it in', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, park('p1', 'Export the ledger as CSV')],
        [T0 + MIN, finish('claude', 'Shipped')],
      ),
      [W2]: file(
        [T0 + 5 * MIN, reply('r1', 'p1', 'pickup', { note: 'With the totals' })],
        [T0 + 5 * MIN, delivered('r1')],
      ),
    },
  })

  expect(session.finished?.who).toBe('claude')
  expect(session.parked).toEqual([])
  expect(session.items.get('p1')).toMatchObject({ state: 'picked', closedBy: 'answer' })
  expect(session.replies.map(each => [each.id, each.delivery, each.voided])).toEqual([
    ['r1', 'delivered', undefined],
  ])
  expect(session.log[0]?.text).toBe('Picked up from parked: Export the ledger as CSV')
  expect(session.updatedAt, 'nor does it move its time').toBe(T0 + MIN)
})

test('two windows picking up one item each give their Claude the pick-up: both delivered, the item picked once', () => {
  const session = fold({
    logs: {
      [W1]: file([T0, park('p1', 'Export the ledger as CSV')]),
      [W2]: file([T0 + MIN, reply('r1', 'p1', 'pickup')], [T0 + MIN, delivered('r1')]),
      [SENDER]: file([T0 + 2 * MIN, reply('r2', 'p1', 'pickup')], [T0 + 2 * MIN, delivered('r2')]),
    },
  })

  expect(session.replies.map(each => [each.id, each.delivery])).toEqual([
    ['r1', 'delivered'],
    ['r2', 'delivered'],
  ])
  expect(session.items.get('p1')).toMatchObject({ state: 'picked', closedAt: T0 + MIN })
})
