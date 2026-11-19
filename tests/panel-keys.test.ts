import { expect, test } from './kit'
import { keysOf, type Key } from '../cli/panel/keys'
import { NORDFOX } from './terminal'

/** The kinds of the keys in the bytes, read whole. */
const kinds = (bytes: string, isQuiet = false) => keysOf(bytes, isQuiet).keys.map(key => key.kind)

const press = (kind: Exclude<Key['kind'], 'tap' | 'wheel'>): Key => ({ kind }) as Key

/** The keys in the pieces, each read with what the one before left, and what the last leaves. */
const readInPieces = (pieces: readonly string[]) =>
  pieces.reduce<{ keys: Key[]; rest: string }>(
    (sofar, piece) => {
      const next = keysOf(sofar.rest + piece)

      return { keys: [...sofar.keys, ...next.keys], rest: next.rest }
    },
    { keys: [], rest: '' },
  )

test('CSI and SS3 arrows both read as arrows, so application cursor mode does not matter; a modifier held changes nothing', () => {
  expect(kinds('\x1b[A\x1b[B\x1bOA\x1bOB')).toEqual(['up', 'down', 'up', 'down'])
  expect(kinds('\x1b[1;5A\x1b[1;2B')).toEqual(['up', 'down'])
})

test('j and k move as ↓ and ↑; s is Snoozed; q and Ctrl-C leave; Ctrl-Z suspends; ⏎ comes as CR, LF or the keypad Enter', () => {
  expect(kinds('jks')).toEqual(['down', 'up', 'snoozed'])
  expect(kinds('q\x03')).toEqual(['quit', 'quit'])
  expect(kinds('\x1a')).toEqual(['suspend'])
  expect(kinds('\r\n\x1bOM')).toEqual(['enter', 'enter', 'enter'])
})

test('PgUp, PgDn, Home and End, in each form terminals send them', () => {
  expect(kinds('\x1b[5~\x1b[6~')).toEqual(['pageUp', 'pageDown'])
  expect(kinds('\x1b[H\x1bOH\x1b[1~\x1b[7~')).toEqual(['home', 'home', 'home', 'home'])
  expect(kinds('\x1b[F\x1bOF\x1b[4~\x1b[8~')).toEqual(['end', 'end', 'end', 'end'])
})

test('any other byte or sequence does nothing: capitals, other letters, other keys, and a letter with Alt', () => {
  expect(kinds('JKSQxé \t')).toEqual([])
  expect(kinds('\x1b[C\x1b[D\x1b[2~\x1b[3~\x1bOP')).toEqual([])
  expect(kinds('\x1bj\x1bq')).toEqual([])
})

test("the terminal's answers to the colour query are never read as keys, its colours nor its DA1", () => {
  expect(kinds(`${NORDFOX}\x1b[?62;22c`)).toEqual([])
  expect(kinds('\x1b]11;rgb:2e2e/3434/4040\x1b\\j')).toEqual(['down'])
})

test('a sequence cut short by a byte no CSI holds is nothing, and that byte is read on its own', () => {
  expect(kinds('\x1b[1\x03')).toEqual(['quit'])
  expect(kinds('\x1b[\x1b[A')).toEqual(['up'])
})

test('a sequence the bytes end inside is left to read with the next bytes, whole', () => {
  const read = readInPieces(['j\x1b', '[', '<64;5', ';7M', '\x1b]11;rgb:2e2e/', '3434/4040\x07k'])

  expect(keysOf('j\x1b')).toEqual({ keys: [press('down')], rest: '\x1b' })
  expect(keysOf('\x1b[<0;5')).toEqual({ keys: [], rest: '\x1b[<0;5' })
  expect(keysOf('\x1bO')).toEqual({ keys: [], rest: '\x1bO' })
  expect(read).toEqual({ keys: [press('down'), { kind: 'wheel', by: -1 }, press('up')], rest: '' })
})

test('once nothing more has come, a lone ESC is esc, and the start of any other sequence is dropped', () => {
  expect(keysOf('\x1b', true)).toEqual({ keys: [press('esc')], rest: '' })
  expect(keysOf('j\x1b', true)).toEqual({ keys: [press('down'), press('esc')], rest: '' })
  expect(keysOf('\x1b[', true)).toEqual({ keys: [], rest: '' })
  expect(keysOf('\x1b]11;rgb:2e', true)).toEqual({ keys: [], rest: '' })
})

test("a press of the mouse's first button is a tap at its cell, counted from 0; a release, another button, or a motion is nothing", () => {
  expect(keysOf('\x1b[<0;5;7M').keys).toEqual([{ kind: 'tap', x: 4, y: 6 }])
  expect(keysOf('\x1b[<16;1;1M').keys, 'Ctrl held').toEqual([{ kind: 'tap', x: 0, y: 0 }])
  expect(kinds('\x1b[<0;5;7m\x1b[<1;5;7M\x1b[<2;5;7M\x1b[<32;5;7M')).toEqual([])
})

test('the wheel scrolls a notch at a time: up by -1, down by 1, a modifier held changing nothing', () => {
  expect(keysOf('\x1b[<64;5;7M\x1b[<65;5;7M\x1b[<81;5;7M').keys).toEqual([
    { kind: 'wheel', by: -1 },
    { kind: 'wheel', by: 1 },
    { kind: 'wheel', by: 1 },
  ])
})

test("an X10 mouse report, its three bytes after ESC [ M, is read as SGR's is, never as keys: a press of the first button a tap, the wheel a notch", () => {
  expect(keysOf('\x1b[M q!').keys, 'never q').toEqual([{ kind: 'tap', x: 80, y: 0 }])
  expect(keysOf("\x1b[M %'").keys).toEqual([{ kind: 'tap', x: 4, y: 6 }])
  expect(keysOf("\x1b[M`%'\x1b[Ma%'").keys).toEqual([
    { kind: 'wheel', by: -1 },
    { kind: 'wheel', by: 1 },
  ])
  expect(kinds("\x1b[M#%'\x1b[M!%'j"), 'a release and the second button').toEqual(['down'])
  expect(keysOf('\x1b[M q')).toEqual({ keys: [], rest: '\x1b[M q' })
  expect(readInPieces(['\x1b[M', ' ', 'q!', 'k']).keys).toEqual([{ kind: 'tap', x: 80, y: 0 }, press('up')])
})

test('a paste is never keys, however many pieces it comes in, its end split among them; what it holds meanwhile stays short', () => {
  expect(kinds('\x1b[200~jq\x03\x1b[A\x1b[201~k')).toEqual(['up'])
  expect(readInPieces(['j\x1b[200~', 'qq\x1b[2', '01~k']).keys).toEqual([press('down'), press('up')])
  expect(readInPieces(['\x1b[200~q', 'q\x1b', '[201~j']).keys).toEqual([press('down')])
  expect(readInPieces(['\x1b[20', '0~q', 's\x1b[201~']).keys).toEqual([])
  expect(keysOf(`\x1b[200~${'q'.repeat(1_000)}`).rest.length).toBeLessThan(12)
})

test('a paste under way is held once nothing more has come, since only its end ends it', () => {
  const held = keysOf('\x1b[200~qq', true)

  expect(held.keys).toEqual([])
  expect(held.rest.startsWith('\x1b[200~')).toBe(true)
  expect(keysOf(`${held.rest}q\x1b[201~j`, true).keys).toEqual([press('down')])
})

test('a string sequence holds only what a colour holds: any other byte cuts it short and is read, so a key typed after Alt+] or the like is never swallowed', () => {
  expect(kinds('\x1b]j')).toEqual(['down'])
  expect(kinds('\x1bPq')).toEqual(['quit'])
  expect(kinds('\x1b_\r')).toEqual(['enter'])
  expect(kinds('\x1b]1\x1b[A')).toEqual(['up'])
  expect(readInPieces(['\x1b]1', '1;', 'k']).keys).toEqual([press('up')])
  expect(kinds('\x1b]11;rgba:2e2e/3434/4040/ffff\x07\x1b]10;#cdcecf\x1b\\')).toEqual([])
})
