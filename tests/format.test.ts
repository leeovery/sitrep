import { expect, test } from './kit'
import {
  addition,
  append,
  attach,
  heartbeat,
  leave,
  metaText,
  parseEntries,
  parseMeta,
  parsePresence,
  presenceText,
  serialise,
  stamp,
  VERSION,
  type Body,
  type Entry,
} from '../core'
import { META, T0, W1 } from './support'

/** One line of every kind, as the format writes it, and the ask and edit lines written before asks said what they want back. */
const EVERY_KIND: Body[] = [
  {
    type: 'status',
    name: 'Dashboard redesign',
    summary: 'Area by area',
    now: ['Drawing Usage, round 2'],
    next: 'Usage, round 3',
  },
  {
    type: 'ask',
    id: 'k3f9',
    wants: 'choice',
    title: 'Keep the ledger 400 days, or forever?',
    where: 'docs/design.md',
    options: ['400 days', 'Forever'],
    ref: 'docs/design.md#ledger',
  },
  {
    type: 'note',
    id: 'n4m5',
    text: 'PR #82 merged',
    detail: ['6 files, +214 −51'],
    ref: 'https://github.com/leeovery/switchboard/pull/82',
  },
  {
    type: 'park',
    id: 'p1q2',
    title: 'A tmux indicator across sessions',
    where: 'DESIGN.md, Later',
  },
  { type: 'resolve', item: 'k3f9', reason: 'Decided in the chat' },
  { type: 'reopen', item: 'k3f9', reason: 'Asked again' },
  {
    type: 'edit',
    item: 'k3f9',
    changes: { title: 'Keep the ledger a year, or forever?' },
    reason: 'Wrong length',
  },
  {
    type: 'reply',
    id: 'r7x2',
    item: 'k3f9',
    verdict: 'choose',
    option: 'Forever',
    note: 'Storage is cheap',
  },
  { type: 'delivered', replies: ['r7x2'] },
  { type: 'ask', id: 'g0g0', wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' },
  {
    type: 'ask',
    id: 'w0rd',
    wants: 'words',
    title: 'Run sitrep list and paste what it prints',
    needs: "the command's output",
  },
  {
    type: 'edit',
    item: 'g0g0',
    changes: { wants: 'choice', options: ['Now', 'After the review'] },
  },
  { type: 'reply', id: 'r8y3', item: 'w0rd', verdict: 'answer', note: 'exported 42 rows' },
  {
    type: 'ask',
    id: '01d0',
    kind: 'do',
    title: 'Run the export',
    needs: "the command's output",
  },
  { type: 'edit', item: '01d0', changes: { kind: 'review' } },
  { type: 'snooze', item: 'k3f9', until: T0 + 3 * 60 * 60_000 },
  { type: 'wake', item: 'k3f9' },
]

const entry = (at: number, seq: number, body: Body): Entry => ({ v: VERSION, at, seq, ...body })

test('every kind of line reads back as it was written', () => {
  const entries = EVERY_KIND.map((body, i) => entry(T0 + i, i + 1, body))

  expect(parseEntries(entries.map(serialise).join(''))).toEqual(entries)
})

test('a line is one JSON object, its stamp first', () => {
  expect(serialise(entry(T0, 3, { type: 'delivered', replies: ['r7x2'] }))).toBe(
    `{"v":1,"at":${T0},"seq":3,"type":"delivered","replies":["r7x2"]}\n`,
  )
})

test('a torn last line is skipped and the lines before it stand', () => {
  const whole = [entry(T0, 1, EVERY_KIND[1]!), entry(T0 + 1, 2, EVERY_KIND[2]!)]
  const torn = serialise(entry(T0 + 2, 3, EVERY_KIND[3]!)).slice(0, 30)

  expect(parseEntries(whole.map(serialise).join('') + torn)).toEqual(whole)
})

for (const [why, line] of [
  ['that is not JSON', 'Drawing Usage'],
  ['that is a list', '[1,2,3]'],
  ['of a kind no reader knows', `{"v":1,"at":${T0},"seq":1,"type":"vote","id":"x"}`],
  ['of a later version', `{"v":2,"at":${T0},"seq":1,"type":"note","id":"n1","text":"hi"}`],
  ['with no count', `{"v":1,"at":${T0},"type":"note","id":"n1","text":"hi"}`],
  ['with a field of the wrong type', `{"v":1,"at":${T0},"seq":1,"type":"note","id":"n1","text":7}`],
  [
    'posting an ask of no known kind',
    `{"v":1,"at":${T0},"seq":1,"type":"ask","id":"k1","kind":"vote","title":"x"}`,
  ],
  [
    'posting an ask wanting nothing it knows',
    `{"v":1,"at":${T0},"seq":1,"type":"ask","id":"k1","wants":"vote","title":"x"}`,
  ],
  [
    'posting an ask that says neither what it wants nor its kind',
    `{"v":1,"at":${T0},"seq":1,"type":"ask","id":"k1","title":"x"}`,
  ],
  [
    'replying with no known verdict',
    `{"v":1,"at":${T0},"seq":1,"type":"reply","id":"r1","item":"k1","verdict":"maybe"}`,
  ],
  ['editing nothing', `{"v":1,"at":${T0},"seq":1,"type":"edit","item":"k1","changes":{}}`],
  [
    'stamped at no time a Date holds',
    `{"v":1,"at":1e+23,"seq":1,"type":"note","id":"n1","text":"hi"}`,
  ],
  ['snoozing with no time', `{"v":1,"at":${T0},"seq":1,"type":"snooze","item":"k1"}`],
  [
    'snoozing until no time a Date holds',
    `{"v":1,"at":${T0},"seq":1,"type":"snooze","item":"k1","until":1e+23}`,
  ],
  ['waking no item', `{"v":1,"at":${T0},"seq":1,"type":"wake"}`],
] as const) {
  test(`a line ${why} is skipped, and the rest stand`, () => {
    const good = entry(T0, 1, EVERY_KIND[2]!)

    expect(parseEntries(`${line}\n${serialise(good)}`)).toEqual([good])
  })
}

test('fields a line has beyond its kind are dropped', () => {
  const [read] = parseEntries(
    `{"v":1,"at":${T0},"seq":1,"type":"park","id":"p1","title":"Later","colour":"red"}\n`,
  )

  expect(read).toStrictEqual(entry(T0, 1, { type: 'park', id: 'p1', title: 'Later' }))
})

test("appending stamps the writer's next counts and gives the whole file", () => {
  const first = append('', [EVERY_KIND[1]!], T0)
  const next = append(first.text, [EVERY_KIND[7]!, EVERY_KIND[8]!], T0 + 5)

  expect(first.entries.map(each => each.seq)).toEqual([1])
  expect(next.entries.map(each => [each.seq, each.at])).toEqual([
    [2, T0 + 5],
    [3, T0 + 5],
  ])
  expect(next.text.startsWith(first.text)).toBe(true)
  expect(parseEntries(next.text)).toEqual([...first.entries, ...next.entries])
})

test('appending to a file left torn ends the torn line first, so only it is lost', () => {
  const whole = append('', [EVERY_KIND[1]!], T0).text
  const torn = `${whole}{"v":1,"at":${T0},"seq":2,"ty`
  const next = append(torn, [EVERY_KIND[2]!], T0 + 1)

  expect(next.text.startsWith(`${torn}\n`)).toBe(true)
  expect(parseEntries(next.text).map(each => each.type)).toEqual(['ask', 'note'])
  expect(next.entries[0]?.seq).toBe(2)
})

test('an addition ends a torn line of the file it goes on, whatever text its count went on from', () => {
  const whole = append('', [EVERY_KIND[1]!], T0).text
  const torn = `${whole}{"v":1,"at":${T0},"seq":2,"ty`
  const entries = stamp(whole, [EVERY_KIND[2]!], T0 + 1)

  expect(addition(torn, entries)).toBe(`\n${serialise(entries[0]!)}`)
  expect(addition(whole, stamp(torn, [EVERY_KIND[2]!], T0 + 1))).toBe(serialise(entries[0]!))
})

test('the count continues from the highest a file holds, whatever its order', () => {
  const text = [entry(T0, 7, EVERY_KIND[2]!), entry(T0, 3, EVERY_KIND[3]!)].map(serialise).join('')

  expect(append(text, [EVERY_KIND[8]!], T0).entries[0]?.seq).toBe(8)
})

test('session.json reads back as written, and a torn or later-version one reads as nothing', () => {
  const text = metaText(META)

  expect(parseMeta(text)).toEqual(META)
  expect(parseMeta(text.slice(0, 20))).toBeUndefined()
  expect(parseMeta(text.replace('"v":1', '"v":2'))).toBeUndefined()
  expect(parseMeta('null')).toBeUndefined()
})

test("a heartbeat reads back under its file's writer; a torn one reads as nothing", () => {
  const attached = attach(W1, T0)
  const beaten = heartbeat(attached, T0 + 30_000)
  const left = leave(beaten, T0 + 40_000)

  expect(beaten).toEqual({ writer: W1, attachedAt: T0, seenAt: T0 + 30_000 })
  expect(parsePresence(presenceText(left), W1)).toEqual(left)
  expect(parsePresence(presenceText(left), 'other')?.writer).toBe('other')
  expect(parsePresence(presenceText(left).slice(0, 12), W1)).toBeUndefined()
  expect(parsePresence('{"attachedAt":"soon","seenAt":1}', W1)).toBeUndefined()
})
