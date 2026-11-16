import { expect, test } from './kit'
import {
  attach,
  heartbeat,
  leave,
  parseDevice,
  parsePresence,
  presenceText,
  whereOf,
  type Where,
} from '../core'
import { T0, W1 } from './support'

const SOCKET = '/private/tmp/tmux-501/default'

const IN_TMUX: Where = {
  device: '/dev/ttys043',
  terminal: 'tmux',
  tmux: { socket: SOCKET, pane: '%148' },
}

/** A heartbeat file holding `where` as given, its times good. */
const fileWith = (where: unknown) =>
  JSON.stringify({ writer: W1, attachedAt: T0, seenAt: T0, where })

test('a heartbeat reads back with where its window is, through every beat and the leaving', () => {
  const left = leave(heartbeat(attach(W1, T0, { where: IN_TMUX }), T0 + 30_000), T0 + 40_000)

  expect(left.where).toEqual(IN_TMUX)
  expect(parsePresence(presenceText(left), W1)).toEqual(left)
})

test('a heartbeat written before windows said where they are reads as it always did', () => {
  const read = parsePresence('{"writer":"w","attachedAt":1,"seenAt":2,"leftAt":3}\n', W1)

  expect(read).toEqual({ writer: W1, attachedAt: 1, seenAt: 2, leftAt: 3 })
  expect(read?.where).toBeUndefined()
})

test('a heartbeat reads back with the folder its Claude runs in, through every beat and the leaving', () => {
  const directory = '/Users/me/Code/northwind/.claude/worktrees/lobby'
  const left = leave(heartbeat(attach(W1, T0, { directory }), T0 + 30_000), T0 + 40_000)

  expect(parsePresence(presenceText(left), W1)).toEqual(left)
  expect(parsePresence(presenceText(left), W1)?.directory).toBe(directory)
})

test('a leave whose Claude lives on into another conversation says so, and reads back so; any other value of it reads as none', () => {
  const left = leave(attach(W1, T0), T0 + 40_000, true)

  expect(left.livesOn).toBe(true)
  expect(parsePresence(presenceText(left), W1)).toEqual(left)
  expect(parsePresence(presenceText(leave(attach(W1, T0), T0 + 40_000)), W1)?.livesOn).toBeUndefined()

  for (const livesOn of [false, 'true', 1, null]) {
    const read = parsePresence(JSON.stringify({ attachedAt: T0, seenAt: T0, leftAt: T0, livesOn }), W1)

    expect(read, JSON.stringify(livesOn)).toEqual({ writer: W1, attachedAt: T0, seenAt: T0, leftAt: T0 })
  }
})

test('a heartbeat written before heartbeats said their folder reads as ever, with none; a bad one is dropped and the heartbeat kept', () => {
  expect(parsePresence('{"attachedAt":1,"seenAt":2}\n', W1)).toEqual({
    writer: W1,
    attachedAt: 1,
    seenAt: 2,
  })

  for (const directory of ['', 5, null, {}]) {
    const read = parsePresence(JSON.stringify({ attachedAt: T0, seenAt: T0, directory }), W1)

    expect(read, JSON.stringify(directory)).toEqual({ writer: W1, attachedAt: T0, seenAt: T0 })
  }
})

test('with nothing known of where a window is, its heartbeat has no where at all', () => {
  expect(whereOf({})).toBeUndefined()
  expect(JSON.parse(presenceText(attach(W1, T0, { where: whereOf({}) })))).not.toHaveProperty(
    'where',
  )
})

test('a bad where is dropped and the heartbeat kept', () => {
  for (const where of ['ghostty', 5, null, [], {}, { device: 'ttys043' }]) {
    const read = parsePresence(fileWith(where), W1)

    expect(read, JSON.stringify(where)).toEqual({ writer: W1, attachedAt: T0, seenAt: T0 })
    expect(read?.where, JSON.stringify(where)).toBeUndefined()
  }
})

test('a bad field of where is dropped, the good ones kept, and keys it does not know ignored', () => {
  const read = (where: unknown) => parsePresence(fileWith(where), W1)?.where

  expect(read({ ...IN_TMUX, device: '/tmp/ttys043' })).toEqual({ ...IN_TMUX, device: undefined })
  expect(read({ ...IN_TMUX, terminal: '' })).toEqual({ ...IN_TMUX, terminal: undefined })
  expect(read({ ...IN_TMUX, terminal: 7 })).toEqual({ ...IN_TMUX, terminal: undefined })
  expect(read({ ...IN_TMUX, tmux: { socket: '', pane: '%148' } })).toEqual({
    ...IN_TMUX,
    tmux: undefined,
  })
  expect(read({ ...IN_TMUX, tmux: { socket: SOCKET, pane: '148' } })).toEqual({
    ...IN_TMUX,
    tmux: undefined,
  })
  expect(read({ ...IN_TMUX, tmux: SOCKET })).toEqual({ ...IN_TMUX, tmux: undefined })
  expect(read({ ...IN_TMUX, window: 3, tmux: { ...IN_TMUX.tmux, session: 'code' } })).toEqual(
    IN_TMUX,
  )
})

test('in tmux, the socket is $TMUX up to its first comma, with $TMUX_PANE as the pane', () => {
  const where = whereOf(
    { TMUX: `${SOCKET},30249,129`, TMUX_PANE: '%148', TERM_PROGRAM: 'tmux' },
    '/dev/ttys043',
  )

  expect(where).toEqual(IN_TMUX)
})

test('outside tmux, or with $TMUX and no pane, there is no tmux', () => {
  expect(whereOf({ TERM_PROGRAM: 'ghostty' }, '/dev/ttys043')).toEqual({
    device: '/dev/ttys043',
    terminal: 'ghostty',
  })
  expect(whereOf({ TMUX: `${SOCKET},30249,129` })).toBeUndefined()
  expect(whereOf({ TMUX: `${SOCKET},30249,129`, TMUX_PANE: '' })).toBeUndefined()
  expect(whereOf({ TMUX: ',30249,129', TMUX_PANE: '%148' })).toBeUndefined()
})

test('in zmx, the session is $ZMX_SESSION whole, its spaces and · kept, beside the device and the terminal; none when empty', () => {
  expect(
    whereOf({ ZMX_SESSION: 'litware · invoice-card', TERM_PROGRAM: 'ghostty' }, '/dev/ttys087'),
  ).toEqual({ device: '/dev/ttys087', terminal: 'ghostty', zmx: { session: 'litware · invoice-card' } })
  expect(whereOf({ ZMX_SESSION: '', TERM_PROGRAM: 'ghostty' })).toEqual({ terminal: 'ghostty' })
})

test('a zmx session reads back from the heartbeat; one with no name, or not a session, is dropped and the rest kept', () => {
  const read = (where: unknown) => parsePresence(fileWith(where), W1)?.where
  const IN_ZMX: Where = { device: '/dev/ttys087', terminal: 'ghostty', zmx: { session: 'litware' } }

  expect(read(IN_ZMX)).toEqual(IN_ZMX)
  expect(read({ ...IN_ZMX, zmx: { session: 'litware', pane: '%1' } })).toEqual(IN_ZMX)

  for (const zmx of ['litware', { session: '' }, { session: 7 }, null]) {
    expect(read({ ...IN_ZMX, zmx }), JSON.stringify(zmx)).toEqual({ ...IN_ZMX, zmx: undefined })
  }
})

test('the terminal is $TERM_PROGRAM as given, and none without it', () => {
  expect(whereOf({ TERM_PROGRAM: 'iTerm.app' })).toEqual({ terminal: 'iTerm.app' })
  expect(whereOf({ TERM_PROGRAM: '' })).toBeUndefined()
})

test("a device is kept only when it is a tty, the form of Ghostty's `tty`, which the jump asks for", () => {
  const read = (device: string) => parsePresence(fileWith({ device }), W1)?.where

  expect(whereOf({}, '/dev/ttys043')).toEqual({ device: '/dev/ttys043' })
  expect(read('/dev/ttys043')).toEqual({ device: '/dev/ttys043' })

  for (const device of ['/dev/../x', '/dev/null', '/dev/ttys043/x', '/dev/', 'ttys043', '']) {
    expect(whereOf({}, device), device).toBeUndefined()
    expect(read(device), device).toBeUndefined()
  }
})

test("the walk's output names a device by its tty name; anything else, ?? and nothing among it, names none", () => {
  expect(parseDevice('ttys043\n')).toBe('/dev/ttys043')
  expect(parseDevice('  ttys043  ')).toBe('/dev/ttys043')
  expect(parseDevice('??\n')).toBeUndefined()
  expect(parseDevice('')).toBeUndefined()
  expect(parseDevice('\n')).toBeUndefined()
  expect(parseDevice('ps: illegal option')).toBeUndefined()
  expect(parseDevice('ttys043\nttys044')).toBeUndefined()
  expect(parseDevice('../../etc/passwd')).toBeUndefined()
})
