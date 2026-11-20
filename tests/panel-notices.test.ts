import { expect, test } from './kit'
import { newAsks, noticeBytes, noticesOf, osc777, passedThrough } from '../cli/panel/notices'
import type { Row } from '../core'
import { boardRow, feedOfRows as feedOf, MIN, T0 } from './data'

const HELP_DESK = 'sr-nw0001'

const SHIFTS = 'sr-co0002'

/** Help desk redesign's row in Northwind, of `lines` asks, the newest at `since`, each saying `lead`. */
const helpDesk = (lead: string, { since = T0, lines = 1 } = {}): Row =>
  boardRow(HELP_DESK, 'ask', { name: 'Help desk redesign', first: { lead }, since, lines })

/** Shift schedules' row in Contoso, a line of the kind given, saying `lead`, at `since`. */
const shifts = (is: Row['lines'][number]['is'], lead: string, { since = T0, isAway = false } = {}): Row =>
  boardRow(SHIFTS, is, { name: 'Shift schedules', project: 'Contoso', first: { lead }, since, isAway })

test("a new ask's notice is its words, then its project and session, an away row's too", () => {
  const feed = feedOf([shifts('ask', 'Approve the rota', { isAway: true })])

  expect(newAsks(feed, ['ask:sr-co0002:0'])).toEqual([{ title: 'Approve the rota', place: 'Contoso · Shift schedules' }])
})

test('only asks new on the board notify: never one already shown, a permission prompt, a question, Stopped or a working row', () => {
  const feed = feedOf([
    helpDesk('Review round 1', { lines: 2 }),
    shifts('permission', 'Allow Bash'),
    boardRow('sr-fa0003', 'question', { first: { lead: 'Which layout?' } }),
    boardRow('sr-tw0004', 'yourTurn'),
    boardRow('sr-wg0005', 'working'),
  ])
  const news = ['ask:sr-nw0001:1', 'permission:sr-co0002:0', 'question:sr-fa0003:0', 'yourTurn:sr-tw0004:0', 'working:sr-wg0005:0']

  expect(newAsks(feed, news).map(each => each.title)).toEqual(['Review round 1'])
  expect(newAsks(feed, [])).toEqual([])
})

test('several new asks notify the oldest first, whatever the board order; a tie keeps board order', () => {
  const feed = feedOf([
    helpDesk('Newer here', { since: T0 + 5 * MIN, lines: 2 }),
    shifts('ask', 'Oldest', { since: T0 }),
    boardRow('sr-fa0003', 'ask', { name: 'Invoice ledger', first: { lead: 'Tied, after' }, since: T0 + 4 * MIN }),
  ])
  const news = ['ask:sr-nw0001:0', 'ask:sr-nw0001:1', 'ask:sr-co0002:0', 'ask:sr-fa0003:0']

  // Help desk's older line is at T0 + 4m, tied with Invoice ledger's, and above it on the board.
  expect(newAsks(feed, news).map(each => each.place)).toEqual([
    'Contoso · Shift schedules',
    'Northwind · Help desk redesign',
    'Northwind · Invoice ledger',
    'Northwind · Help desk redesign',
  ])
})

test('the sequence is OSC 777: notify, the title, then the place, ended by BEL', () => {
  expect(osc777({ title: 'Ship it', place: 'Northwind · Help desk redesign' })).toBe(
    '\x1b]777;notify;Ship it;Northwind · Help desk redesign\x07',
  )
})

test("control characters are dropped from both fields, C1's among them, lines run together, and a ; in either becomes ,", () => {
  expect(osc777({ title: 'Ship\x07 it;\x1b]0;now\x9c\nplease', place: 'North\x1bwind; · Help\x00 desk\r\nredesign' })).toBe(
    '\x1b]777;notify;Ship it,]0,now please;Northwind, · Help desk redesign\x07',
  )
})

test('the title is cut to 200 code points, its ellipsis among them, never inside a character outside the BMP', () => {
  const long = `${'a'.repeat(198)}😀😀 and more`
  const place = 'Northwind · Help desk redesign'

  expect(osc777({ title: long, place })).toBe(`\x1b]777;notify;${'a'.repeat(198)}😀…;${place}\x07`)
  expect(osc777({ title: `${'a'.repeat(199)}😀`, place }), 'one of 200 is kept whole').toBe(
    `\x1b]777;notify;${'a'.repeat(199)}😀;${place}\x07`,
  )
  expect(osc777({ title: 'b'.repeat(10_000), place }).length).toBe('\x1b]777;notify;'.length + 200 + place.length + 2)
})

test("inside tmux the sequence goes in tmux's passthrough, each ESC in it doubled; outside, as it is", () => {
  const notice = { title: 'Ship it', place: 'Northwind · Help desk redesign' }

  expect(passedThrough('\x1b]777;x\x07')).toBe('\x1bPtmux;\x1b\x1b]777;x\x07\x1b\\')
  expect(noticeBytes(notice, { TMUX: '/private/tmp/tmux-501/default,123,0' })).toBe(
    '\x1bPtmux;\x1b\x1b]777;notify;Ship it;Northwind · Help desk redesign\x07\x1b\\',
  )
  expect(noticeBytes(notice, {})).toBe(osc777(notice))
  expect(noticeBytes(notice, { TMUX: '' })).toBe(osc777(notice))
})

test("the bytes for a look's news: one each, the oldest first, each whole", () => {
  const feed = feedOf([helpDesk('Ship it', { lines: 2 })])

  expect(noticesOf(feed, ['ask:sr-nw0001:0', 'ask:sr-nw0001:1'], {})).toEqual([
    '\x1b]777;notify;Ship it;Northwind · Help desk redesign\x07',
    '\x1b]777;notify;Ship it;Northwind · Help desk redesign\x07',
  ])
})
