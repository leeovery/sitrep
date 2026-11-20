/**
 * A binary property list, as macOS saves an app's defaults, read only as far
 * as the panel needs it: the data held under a key of its top dictionary.
 *
 * - Its trailer, its last 32 bytes, gives the size of an offset and of a
 *   reference to an object, the top object, and where the table of every
 *   object's offset starts.
 * - Each object opens with a marker, its kind in the high four bits and its
 *   length in the low four; a length of 15 or more comes in an integer
 *   object after the marker, of 8 bytes at most: a list claiming a longer
 *   one holds nothing, read no further.
 * - A dictionary holds its keys' references, then its values'. A key is a
 *   string, in ASCII or in UTF-16.
 * - A list cut short, or not one at all, holds nothing: every length is
 *   held to the bytes there are before anything is read by it, so a list
 *   claiming more than it holds costs no more than its own size.
 */

const HEADER = 'bplist00'

const TRAILER = 32

const KIND = { data: 0x4, ascii: 0x5, utf16: 0x6, dictionary: 0xd }

/** The marker's low four bits saying an integer object holds the length. */
const LONG = 0x0f

/** The most bytes an integer object holds. */
const INTEGER_BYTES = 8

type Item = { kind: number; length: number; start: number }

/** Each byte as the character of its code, as ASCII reads. */
const latin1 = (bytes: Uint8Array) => String.fromCharCode(...bytes)

const utf16 = (bytes: Uint8Array) =>
  String.fromCharCode(...Array.from({ length: bytes.length / 2 }, (_, at) => ((bytes[2 * at] ?? 0) << 8) | (bytes[2 * at + 1] ?? 0)))

/** Thrown for a list that is not one, or is cut short. */
const unreadable = () => new RangeError('not a binary property list, or one cut short')

const reader = (bytes: Uint8Array) => {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const trailer = bytes.length - TRAILER

  /** The unsigned big-endian integer of `size` bytes at `at`; DataView throws past the end. */
  const uintAt = (at: number, size: number) =>
    Array.from({ length: size }, (_, step) => view.getUint8(at + step)).reduce((value, byte) => value * 256 + byte, 0)

  /** The bytes from `start`, `length` of them, before the trailer; throws past it. */
  const span = (start: number, length: number) => {
    if (start + length > trailer) {
      throw unreadable()
    }

    return bytes.subarray(start, start + length)
  }

  const offsetSize = view.getUint8(trailer + 6)
  const refSize = view.getUint8(trailer + 7)
  const table = uintAt(trailer + 24, 8)

  if (offsetSize === 0 || refSize === 0) {
    throw unreadable()
  }

  const itemOf = (ref: number): Item => {
    const at = uintAt(table + ref * offsetSize, offsetSize)
    const marker = view.getUint8(at)
    const [kind, low] = [marker >> 4, marker & 0x0f]

    if (low !== LONG) {
      return { kind, length: low, start: at + 1 }
    }

    const size = 1 << (view.getUint8(at + 1) & 0x0f)

    if (size > INTEGER_BYTES) {
      throw unreadable()
    }

    return { kind, length: uintAt(at + 2, size), start: at + 2 + size }
  }

  /** Whether the item is a string saying `text`, read only where its length could. */
  const says = ({ kind, length, start }: Item, text: string) => {
    if (kind === KIND.ascii) {
      return length === text.length && latin1(span(start, length)) === text
    }

    return kind === KIND.utf16 && length === text.length && utf16(span(start, 2 * length)) === text
  }

  /** The top dictionary, its references held to the bytes before the trailer; none where the top is no dictionary. */
  const topDictionary = () => {
    const dictionary = itemOf(uintAt(trailer + 16, 8))

    if (dictionary.kind !== KIND.dictionary) {
      return undefined
    }

    if (dictionary.length * 2 * refSize > trailer - dictionary.start) {
      throw unreadable()
    }

    return dictionary
  }

  return { uintAt, span, refSize, itemOf, says, topDictionary }
}

const read = (bytes: Uint8Array, key: string) => {
  if (latin1(bytes.subarray(0, HEADER.length)) !== HEADER) {
    return undefined
  }

  const { uintAt, span, refSize, itemOf, says, topDictionary } = reader(bytes)
  const dictionary = topDictionary()

  if (dictionary === undefined) {
    return undefined
  }

  const itemAt = (index: number) => itemOf(uintAt(dictionary.start + index * refSize, refSize))

  for (let index = 0; index < dictionary.length; index += 1) {
    if (says(itemAt(index), key)) {
      const value = itemAt(dictionary.length + index)

      return value.kind === KIND.data ? span(value.start, value.length).slice() : undefined
    }
  }

  return undefined
}

/** The data under `key` in the list's top dictionary; none where the key holds none, or the bytes hold no list. */
export const dataIn = (bytes: Uint8Array, key: string): Uint8Array | undefined => {
  try {
    return read(bytes, key)
  } catch {
    return undefined
  }
}
