import { expect, test } from './kit'
import { foldSession, newItemId, serialise, stamp, VERSION } from '../core'
import { CLI, MIN, SENDER, T0, W1, W2 } from './data'
import {
  choiceAsk,
  delivered,
  file,
  finish,
  fold,
  oldNote,
  park,
  reopen,
  reply,
  resolve,
  scripted,
  status,
  unfinish,
  yesAsk,
  type Line,
} from './lines'

/** The parked items, in the order their lines were read, as text. */
const parkedOf = (files: Parameters<typeof fold>[0]) =>
  fold(files).parked.map(parked => parked.title)

test("writers' lines merge by time, whichever file holds them", () => {
  const logs = {
    [W1]: file([T0 + 1 * MIN, park('n1', 'first')], [T0 + 4 * MIN, park('n4', 'fourth')]),
    [W2]: file([T0 + 2 * MIN, park('n2', 'second')], [T0 + 3 * MIN, park('n3', 'third')]),
  }

  expect(parkedOf({ logs })).toEqual(['first', 'second', 'third', 'fourth'])
})

test('lines at the same time order by writer, then by the writer’s own count', () => {
  const at = T0 + MIN
  const outOfOrder = [
    { v: VERSION, at, seq: 2, type: 'park', id: 'b2', title: 'w2, second' },
    { v: VERSION, at, seq: 1, type: 'park', id: 'b1', title: 'w2, first' },
  ]
  const logs = {
    [W2]: outOfOrder.map(line => serialise(line as never)).join(''),
    [W1]: file([T0, park('a1', 'w1, earlier')], [at, park('a2', 'w1, at the same time')]),
  }

  expect(parkedOf({ logs })).toEqual([
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
      [T0 + 1 * MIN, status(['Drawing Inbox, round 1'])],
      [T0 + 5 * MIN, park('p1', 'later')],
    ),
    [W2]: file([T0 + 3 * MIN, status(['Drawing Inbox, round 2'], { next: 'Inbox, round 3' })]),
    [CLI]: file([T0 + 2 * MIN, status(['Generating frames'])]),
  }
  const session = fold({ logs })

  expect(session.status).toEqual({
    name: 'Help desk redesign',
    summary: 'Redesign the help desk, page by page in Paper',
    now: ['Drawing Inbox, round 2'],
    next: 'Inbox, round 3',
    at: T0 + 3 * MIN,
    by: W2,
  })
})

test('with no status yet, the session stands as it was started', () => {
  const session = fold({ logs: {} })

  expect(session.status).toMatchObject({ name: 'Help desk redesign', now: [], at: T0, by: W1 })
  expect(session.updatedAt).toBe(T0)
})

test('the first line to use an id keeps it', () => {
  const logs = {
    [W1]: file([T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')]),
    [W2]: file([T0 + 3 * MIN, park('k3f9', 'A clashing park')]),
  }
  const session = fold({ logs })

  expect([...session.items.values()].map(item => item.type)).toEqual(['ask'])
  expect(session.parked).toEqual([])
})

test('an item whose id a reply already holds is never posted: the reply keeps the id', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, yesAsk('k1', 'Review round 1')],
        [T0 + 2 * MIN, park('r1', 'A clashing park')],
      ),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect([...session.items.keys()]).toEqual(['k1'])
  expect(session.replies.map(each => each.id)).toEqual(['r1'])
})

test("an edit changes only its item's own fields", () => {
  const logs = {
    [W1]: file(
      [T0 + 1 * MIN, yesAsk('k3f9', 'Review round 1')],
      [T0 + 2 * MIN, park('p4m5', 'Export as CSV')],
      [
        T0 + 3 * MIN,
        { type: 'edit', item: 'k3f9', changes: { title: 'Review round 2', where: 'In Paper' } },
      ],
      [
        T0 + 4 * MIN,
        {
          type: 'edit',
          item: 'p4m5',
          changes: { title: 'Export as JSON', needs: 'not a parked item field' },
          reason: 'Wrong format',
        },
      ],
    ),
  }
  const session = fold({ logs })

  expect(session.items.get('k3f9')).toMatchObject({
    title: 'Review round 2',
    where: 'In Paper',
    editedAt: T0 + 3 * MIN,
  })
  expect(session.items.get('p4m5')).toMatchObject({ title: 'Export as JSON', reason: 'Wrong format' })
  expect(session.items.get('p4m5')).not.toHaveProperty('needs')
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

test('a resolved parked item leaves Parked; reopened, it is back where it was', () => {
  const posted: Line[] = [
    [T0 + 1 * MIN, park('p1', 'first')],
    [T0 + 2 * MIN, park('p2', 'second')],
    [T0 + 3 * MIN, resolve('p1', 'Posted twice')],
  ]

  expect(parkedOf({ logs: { [W1]: file(...posted) } })).toEqual(['second'])
  expect(parkedOf({ logs: { [W1]: file(...posted, [T0 + 4 * MIN, reopen('p1')]) } })).toEqual([
    'first',
    'second',
  ])
})

/** A session's lines with notes as the board wrote them before notes went, and lines naming one. */
const NOTED = file(
  [T0 + 1 * MIN, yesAsk('k1', 'Review round 1')],
  [T0 + 2 * MIN, oldNote('k3f9', 'PR #81 merged', ['6 files'], { ref: 'PR #81' })],
  [T0 + 3 * MIN, { type: 'edit', item: 'k3f9', changes: { title: 'PR #82 merged' } }],
  [T0 + 4 * MIN, resolve('k3f9', 'Wrong number')],
  [T0 + 5 * MIN, reopen('k3f9')],
  [T0 + 6 * MIN, oldNote('n5p6', 'Shipped')],
)

test('a note line as the board wrote it before notes went is read for its id and its time alone: it posts no item and no history, and the lines naming it change nothing', () => {
  const session = fold({ logs: { [W1]: NOTED } })

  expect([...session.items.keys()]).toEqual(['k1'])
  expect([...session.ids]).toEqual(['k1', 'k3f9', 'n5p6'])
  expect(session.asks[0]?.state).toBe('waiting')
  expect(session.history).toEqual([])
  expect(session.updatedAt, 'the last note moves the time, as it did').toBe(T0 + 6 * MIN)
})

test("an old note's id is never given again, and a line after it counts on from its count", () => {
  const { ids } = fold({ logs: { [W1]: NOTED } })

  expect(newItemId(scripted([19, 3, 15, 9], [1, 1, 1, 1]), ids)).toBe('1111')
  expect(stamp(NOTED, [park('p1', 'Later')], T0 + 7 * MIN).map(entry => entry.seq)).toEqual([7])
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
        [T0 + 2 * MIN, park('n4m5', 'Merged')],
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
        [parked, park('p2', 'Archive old invoices')],
        [parked, park('p3', 'A priority badge')],
      ),
      [W2]: file(
        [T0 + 10 * MIN, reply('r1', 'p1', 'pickup')],
        [T0 + 10 * MIN, delivered('r1')],
        [T0 + 11 * MIN, resolve('p2', 'Done elsewhere')],
        [T0 + 12 * MIN, { type: 'edit', item: 'p3', changes: { title: 'A priority flag' } }],
        [T0 + 13 * MIN, resolve('p3')],
        [T0 + 14 * MIN, reopen('p3')],
      ),
    },
  })
  const asked = fold({
    logs: {
      [W1]: file([parked, park('p1', 'Later')], [T0 + 20 * MIN, yesAsk('k1', 'Review it')]),
    },
  })

  expect(session.parked.map(each => [each.id, each.title])).toEqual([['p3', 'A priority flag']])
  expect(session.updatedAt).toBe(parked)
  expect(asked.updatedAt, 'an ask moves it').toBe(T0 + 20 * MIN)
})

test('a mark moves the time unless every reply it names is a pick-up; a mark read before its reply is judged too', () => {
  const asked: Line[] = [
    [T0, yesAsk('k1', 'Run the apply', 'Done')],
    [T0, park('p1', 'A priority badge')],
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
        [T0, park('p1', 'A priority badge')],
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
