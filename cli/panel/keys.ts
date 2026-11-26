/**
 * The keys in what a terminal sends in raw mode, as bytes, in whatever
 * pieces they come.
 *
 * - `CSI` and `SS3` arrows both read as arrows (`ESC [ A`, `ESC O A`), so
 *   application cursor mode doesn't matter, and Home and End the same. PgUp
 *   and PgDn come as `ESC [ 5 ~` and `ESC [ 6 ~`.
 * - `j` and `k` move as `↓` and `↑`; `q` and Ctrl-C both leave.
 * - `1` to `9` each carry their number; `0` is nothing.
 * - A mouse report, in SGR's form or in the old X10 form a terminal without
 *   SGR's sends, its three bytes after `ESC [ M`: a press of the first
 *   button is a tap, the wheel scrolls; a release, or any other button, is
 *   nothing.
 * - A paste, between `ESC [ 200 ~` and `ESC [ 201 ~`, is never keys, however
 *   many pieces it comes in.
 * - A string sequence, `ESC ]` and the like, is read as the terminal answers
 *   the colour query: up to its `BEL` or `ST`, its body only what a colour
 *   holds. Any other byte cuts it short and is read on its own, so a key
 *   typed after Alt+`]` is swallowed only where a colour could hold it.
 * - A sequence the bytes end inside is left to read with the next bytes.
 *   Once nothing more has come, a lone `ESC` is `esc`, and the start of any
 *   other sequence is dropped; a paste under way is kept, to its end.
 * - A start dropped is kept as a tail: once more bytes come, however late,
 *   it is read whole with them, as if never cut, and its key thrown away,
 *   so the rest of a mouse report cut short, its digits among them, is
 *   never read as keys. A tail that turns out a paste's start is held to
 *   the paste's end, and dropped as any paste.
 * - Any other byte, or sequence, does nothing: the terminal's answers to
 *   the colour query among them, so none is taken as a key.
 */

/** A key that says nothing but itself: `open` is `o`, `snooze` is `z`, `snoozed` is `s`, `quit` is `q` or Ctrl-C, `suspend` is Ctrl-Z. */
export type Press = 'up' | 'down' | 'pageUp' | 'pageDown' | 'home' | 'end' | 'enter' | 'open' | 'snooze' | 'snoozed' | 'esc' | 'quit' | 'suspend'

export type Key =
  | { [K in Press]: { kind: K } }[Press]
  /** A press of the first button, at a cell counted from 0. */
  | { kind: 'tap'; x: number; y: number }
  /** A notch of the wheel: up by -1, down by 1. */
  | { kind: 'wheel'; by: number }
  /** A digit, `1` to `9`: the choice of its number in what is open. */
  | { kind: 'digit'; n: number }

/**
 * The keys in some bytes, and what is left of them: the start of a sequence
 * they end inside, to read with the next; or, as `tail`, the start of one
 * dropped once nothing more came, to read with the next and throw away.
 */
export type Keys = { keys: Key[]; rest: string; tail?: string }

const ESC = '\x1b'

/**
 * What one read at a place in the bytes found: a key or nothing, and how
 * many bytes it took; that the bytes end inside it; or that they end inside
 * a paste, and what of it to hold for the next bytes.
 */
type Read = { key?: Key; length: number } | 'unfinished' | { pasting: string }

const PLAIN: Readonly<Record<string, Press>> = {
  j: 'down',
  k: 'up',
  o: 'open',
  z: 'snooze',
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

/** What an answer to OSC 10 or 11 holds between its start and its end: its number and `;`, then `rgb:` or `rgba:`, hex digits split by `/`, or `#` and hex. */
const ANSWER_BYTE = /[0-9a-fA-F:;/rg#]/

/** Bracketed paste's start and end. */
const PASTE = { from: `${ESC}[200~`, to: `${ESC}[201~` }

/** The modifiers a mouse report adds to its button: Shift, Meta, Ctrl. */
const MODIFIERS = 4 | 8 | 16

const WHEEL: Readonly<Record<number, number>> = { 64: -1, 65: 1 }

/** How far X10 shifts each of its bytes: a button by 32, a cell by 33, counted from 0. */
const X10 = { button: 32, cell: 33 }

/** `1` to `9`; `0` chooses nothing. */
const DIGIT = /^[1-9]$/

const pressOf = (kind: Press | undefined): Key | undefined => (kind === undefined ? undefined : { kind })

const taken = (length: number, key?: Key): Read => (key === undefined ? { length } : { key, length })

const isBetween = (char: string, from: number, to: number) => {
  const code = char.charCodeAt(0)

  return code >= from && code <= to
}

/** A mouse report's button at a cell counted from 0: a press of the first button is a tap there; a wheel's notch scrolls. */
const buttonKey = (button: number, x: number, y: number): Key | undefined => {
  const plain = button & ~MODIFIERS
  const by = WHEEL[plain]

  if (by !== undefined) {
    return { kind: 'wheel', by }
  }

  return plain === 0 && x >= 0 && y >= 0 ? { kind: 'tap', x, y } : undefined
}

/** An SGR mouse report's parameters, `<b;x;y`, and its last byte, `M` a press, its cell 1-based. */
const mouseOf = (params: string, final: string): Key | undefined => {
  const [button, x, y] = params.slice(1).split(';').map(Number)

  if (final !== 'M' || button === undefined || x === undefined || y === undefined) {
    return undefined
  }

  return buttonKey(button, x - 1, y - 1)
}

const csiKey = (params: string, final: string): Key | undefined => {
  if (params.startsWith('<')) {
    return mouseOf(params, final)
  }

  return pressOf(final === '~' ? TILDE[params.split(';')[0] ?? ''] : FINAL[final])
}

/** An X10 mouse report from `at`, its `ESC [ M` there: its button and cell come as the three bytes after, each shifted. */
const x10At = (bytes: string, at: number): Read => {
  const [button, x, y] = [...bytes.slice(at + 3, at + 6)].map(char => char.charCodeAt(0))

  if (button === undefined || x === undefined || y === undefined) {
    return 'unfinished'
  }

  return taken(6, buttonKey(button - X10.button, x - X10.cell, y - X10.cell))
}

/** A paste from `at`, its start there: dropped whole to its end; held where the bytes end inside it, with as much of its tail as its end could start in. */
const pasteAt = (bytes: string, at: number): Read => {
  const body = at + PASTE.from.length
  const end = bytes.indexOf(PASTE.to, body)

  if (end === -1) {
    return { pasting: PASTE.from + bytes.slice(Math.max(body, bytes.length - (PASTE.to.length - 1))) }
  }

  return taken(end + PASTE.to.length - at)
}

/** A `CSI` sequence from `at`, its `ESC [` there: its parameter and middle bytes, then its last. One cut short by a byte no `CSI` holds is taken up to that byte, as nothing. */
const csiAt = (bytes: string, at: number): Read => {
  let end = at + 2

  while (end < bytes.length && isBetween(bytes[end] ?? '', 0x20, 0x3f)) {
    end++
  }

  const final = bytes[end]
  const params = bytes.slice(at + 2, end)

  if (final === undefined) {
    return 'unfinished'
  }

  if (!isBetween(final, 0x40, 0x7e)) {
    return taken(end - at)
  }

  if (params === '' && final === 'M') {
    return x10At(bytes, at)
  }

  return params === '200' && final === '~' ? pasteAt(bytes, at) : taken(end + 1 - at, csiKey(params, final))
}

/**
 * A string sequence from `at`, as the terminal's answers to the colour
 * query come: up to its `BEL` or `ST`. A byte no answer holds cuts it short,
 * taken up to that byte, as nothing: an `ESC` that is no `ST` starts
 * another sequence, and any other byte is read on its own.
 */
const stringAt = (bytes: string, at: number): Read => {
  for (let end = at + 2; end < bytes.length; end++) {
    const byte = bytes[end] ?? ''

    if (byte === '\x07') {
      return taken(end + 1 - at)
    }

    if (byte === ESC) {
      return bytes[end + 1] === undefined ? 'unfinished' : taken(bytes[end + 1] === '\\' ? end + 2 - at : end - at)
    }

    if (!ANSWER_BYTE.test(byte)) {
      return taken(end - at)
    }
  }

  return 'unfinished'
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

/** A byte on its own: a digit carrying its number, or a plain key. */
const plainOf = (byte: string): Key | undefined => (DIGIT.test(byte) ? { kind: 'digit', n: Number(byte) } : pressOf(PLAIN[byte]))

const readAt = (bytes: string, at: number): Read => {
  const byte = bytes[at] ?? ''

  return byte === ESC ? escapeAt(bytes, at) : taken(1, plainOf(byte))
}

/** The start of a sequence the bytes end inside, read as all there is: a lone `ESC` is `esc`; any other start is dropped, kept as a tail. */
const quietened = (keys: Key[], rest: string): Keys =>
  rest === ESC ? { keys: [...keys, { kind: 'esc' }], rest: '' } : { keys, rest: '', tail: rest }

/**
 * A dropped start read whole with the bytes after it, all of them in
 * `bytes`: how far it took them, its key thrown away; or, where they end
 * inside it, the start held still, as a tail, or as a paste to its end.
 */
const resumed = (bytes: string): number | Keys => {
  const read = readAt(bytes, 0)

  if (read === 'unfinished') {
    return { keys: [], rest: '', tail: bytes }
  }

  return 'pasting' in read ? { keys: [], rest: read.pasting } : read.length
}

/**
 * The keys in the bytes, and the start of a sequence they end inside, left
 * to read with the next bytes; `isQuiet`, as nothing more came within 50
 * ms, such a start is read as all there is, and kept as a tail. A paste
 * under way is held however long, since only its end ends it. `tail`, a
 * start the last read dropped, is read first, whole with the bytes, and
 * its key thrown away.
 */
export const keysOf = (fresh: string, isQuiet = false, tail?: string): Keys => {
  const bytes = (tail ?? '') + fresh
  const first = tail === undefined ? 0 : resumed(bytes)

  if (typeof first !== 'number') {
    return first
  }

  const keys: Key[] = []
  let at = first

  while (at < bytes.length) {
    const read = readAt(bytes, at)

    if (read === 'unfinished') {
      return isQuiet ? quietened(keys, bytes.slice(at)) : { keys, rest: bytes.slice(at) }
    }

    if ('pasting' in read) {
      return { keys, rest: read.pasting }
    }

    if (read.key !== undefined) {
      keys.push(read.key)
    }

    at += read.length
  }

  return { keys, rest: '' }
}
