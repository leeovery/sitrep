/**
 * The keys in what a terminal sends in raw mode, as bytes, in whatever
 * pieces they come.
 *
 * - `CSI` and `SS3` arrows both read as arrows (`ESC [ A`, `ESC O A`), so
 *   application cursor mode doesn't matter, and Home and End the same. PgUp
 *   and PgDn come as `ESC [ 5 ~` and `ESC [ 6 ~`.
 * - `j` and `k` move as `↓` and `↑`; `q` and Ctrl-C both leave.
 * - A mouse report in SGR's form: a press of the first button is a tap,
 *   the wheel scrolls; a release, or any other button, is nothing.
 * - A sequence the bytes end inside is left to read with the next bytes.
 *   Once nothing more has come, a lone `ESC` is `esc`, and the start of any
 *   other sequence is dropped.
 * - Any other byte, or sequence, does nothing: the terminal's answers to
 *   the colour query among them, so none is taken as a key.
 */

/** A key that says nothing but itself: `snoozed` is `s`, `quit` is `q` or Ctrl-C, `suspend` is Ctrl-Z. */
export type Press = 'up' | 'down' | 'pageUp' | 'pageDown' | 'home' | 'end' | 'enter' | 'snoozed' | 'esc' | 'quit' | 'suspend'

export type Key =
  | { [K in Press]: { kind: K } }[Press]
  /** A press of the first button, at a cell counted from 0. */
  | { kind: 'tap'; x: number; y: number }
  /** A notch of the wheel: up by -1, down by 1. */
  | { kind: 'wheel'; by: number }

/** The keys in some bytes, and what is left of them: the start of a sequence they end inside, to read with the next. */
export type Keys = { keys: Key[]; rest: string }

const ESC = '\x1b'

/** What one read at a place in the bytes found: a key or nothing, and how many bytes it took; or that the bytes end inside it. */
type Read = { key?: Key; length: number } | 'unfinished'

const PLAIN: Readonly<Record<string, Press>> = {
  j: 'down',
  k: 'up',
  s: 'snoozed',
  q: 'quit',
  '\x03': 'quit',
  '\x1a': 'suspend',
  '\r': 'enter',
  '\n': 'enter',
}

/** A `CSI` or `SS3` sequence's last byte. */
const FINAL: Readonly<Record<string, Press>> = { A: 'up', B: 'down', H: 'home', F: 'end' }

/** `CSI <n> ~`, by its number, rxvt's Home and End among them. */
const TILDE: Readonly<Record<string, Press>> = {
  '1': 'home',
  '7': 'home',
  '4': 'end',
  '8': 'end',
  '5': 'pageUp',
  '6': 'pageDown',
}

/** `SS3`'s last byte: the keypad's Enter beside the arrows. */
const SS3: Readonly<Record<string, Press>> = { ...FINAL, M: 'enter' }

/** The second byte of a sequence ended by `ST` or `BEL`: an OSC, a DCS, an SOS, a PM or an APC. */
const STRING_STARTS = new Set([']', 'P', 'X', '^', '_'])

/** The modifiers a mouse report adds to its button: Shift, Meta, Ctrl. */
const MODIFIERS = 4 | 8 | 16

const WHEEL: Readonly<Record<number, number>> = { 64: -1, 65: 1 }

const pressOf = (kind: Press | undefined): Key | undefined => (kind === undefined ? undefined : { kind })

const taken = (length: number, key?: Key): Read => (key === undefined ? { length } : { key, length })

const isBetween = (char: string, from: number, to: number) => {
  const code = char.charCodeAt(0)

  return code >= from && code <= to
}

/** An SGR mouse report's parameters, `<b;x;y`, and its last byte: a press of the first button is a tap at the cell, 1-based in the report; a wheel's notch scrolls. */
const mouseOf = (params: string, final: string): Key | undefined => {
  const [button, x, y] = params.slice(1).split(';').map(Number)

  if (final !== 'M' || button === undefined || x === undefined || y === undefined) {
    return undefined
  }

  const plain = button & ~MODIFIERS
  const by = WHEEL[plain]

  if (by !== undefined) {
    return { kind: 'wheel', by }
  }

  return plain === 0 && x >= 1 && y >= 1 ? { kind: 'tap', x: x - 1, y: y - 1 } : undefined
}

const csiKey = (params: string, final: string): Key | undefined => {
  if (params.startsWith('<')) {
    return mouseOf(params, final)
  }

  return pressOf(final === '~' ? TILDE[params.split(';')[0] ?? ''] : FINAL[final])
}

/** A `CSI` sequence from `at`, its `ESC [` there: its parameter and middle bytes, then its last. One cut short by a byte no `CSI` holds is taken up to that byte, as nothing. */
const csiAt = (bytes: string, at: number): Read => {
  let end = at + 2

  while (end < bytes.length && isBetween(bytes[end] ?? '', 0x20, 0x3f)) {
    end++
  }

  const final = bytes[end]

  if (final === undefined) {
    return 'unfinished'
  }

  if (!isBetween(final, 0x40, 0x7e)) {
    return taken(end - at)
  }

  return taken(end + 1 - at, csiKey(bytes.slice(at + 2, end), final))
}

/** A string sequence from `at`, as the terminal's answers to the colour query come: up to its `BEL` or `ST`. */
const stringAt = (bytes: string, at: number): Read => {
  const bell = bytes.indexOf('\x07', at + 2)
  const st = bytes.indexOf(`${ESC}\\`, at + 2)
  const ends = [bell === -1 ? Infinity : bell + 1, st === -1 ? Infinity : st + 2]
  const end = Math.min(...ends)

  return end === Infinity ? 'unfinished' : taken(end - at)
}

/** A sequence from `at`, its `ESC` there; `ESC` and any other byte is that byte with Alt, which does nothing. */
const escapeAt = (bytes: string, at: number): Read => {
  const second = bytes[at + 1]

  if (second === undefined) {
    return 'unfinished'
  }

  if (second === '[') {
    return csiAt(bytes, at)
  }

  if (second === 'O') {
    const final = bytes[at + 2]

    return final === undefined ? 'unfinished' : taken(3, pressOf(SS3[final]))
  }

  return STRING_STARTS.has(second) ? stringAt(bytes, at) : taken(2)
}

const readAt = (bytes: string, at: number): Read => {
  const byte = bytes[at] ?? ''

  return byte === ESC ? escapeAt(bytes, at) : taken(1, pressOf(PLAIN[byte]))
}

/**
 * The keys in the bytes, and the start of a sequence they end inside, left
 * to read with the next bytes; `isQuiet`, as nothing more came within 50
 * ms, such a start is read as all there is: a lone `ESC` is `esc`, and any
 * other start is dropped.
 */
export const keysOf = (bytes: string, isQuiet = false): Keys => {
  const keys: Key[] = []
  let at = 0

  while (at < bytes.length) {
    const read = readAt(bytes, at)

    if (read === 'unfinished') {
      const rest = bytes.slice(at)

      return isQuiet ? { keys: rest === ESC ? [...keys, { kind: 'esc' }] : keys, rest: '' } : { keys, rest }
    }

    if (read.key !== undefined) {
      keys.push(read.key)
    }

    at += read.length
  }

  return { keys, rest: '' }
}
