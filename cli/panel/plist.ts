/**
 * A binary property list, as macOS saves an app's defaults, read only as far
 * as the panel needs it: the data held under a key of its top dictionary.
 *
 * - Its trailer, its last 32 bytes, gives the size of an offset and of a
 *   reference to an object, the top object, and where the table of every
 *   object's offset starts.
 * - Each object opens with a marker, its kind in the high four bits and its
 *   length in the low four; a length of 15 or more comes in an integer
 *   object after the marker.
 * - A dictionary holds its keys' references, then its values'. A key is a
 *   string, in ASCII or in UTF-16.
 * - A list cut short, or not one at all, holds nothing.
 */

const HEADER = 'bplist00'

const TRAILER = 32

const KIND = { data: 0x4, ascii: 0x5, utf16: 0x6, dictionary: 0xd }

/** The marker's low four bits saying an integer object holds the length. */
const LONG = 0x0f

type Item = { kind: number; length: number; start: number }

/** Each byte as the character of its code, as ASCII reads. */
const latin1 = (bytes: Uint8Array) => String.fromCharCode(...bytes)

const utf16 = (bytes: Uint8Array) =>
  String.fromCharCode(...Array.from({ length: bytes.length / 2 }, (_, at) => ((bytes[2 * at] ?? 0) << 8) | (bytes[2 * at + 1] ?? 0)))

const reader = (bytes: Uint8Array) => {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const trailer = bytes.length - TRAILER

  /** The unsigned big-endian integer of `size` bytes at `at`; DataView throws past the end. */
  const uintAt = (at: number, size: number) =>
    Array.from({ length: size }, (_, step) => view.getUint8(at + step)).reduce((value, byte) => value * 256 + byte, 0)

  /** The bytes from `start`, `length` of them, before the trailer; throws past it. */
  const span = (start: number, length: number) => {
    if (start + length > trailer) {
      throw new RangeError('the list is cut short')
    }

    return bytes.subarray(start, start + length)
  }

  const offsetSize = view.getUint8(trailer + 6)
  const refSize = view.getUint8(trailer + 7)
  const table = uintAt(trailer + 24, 8)

  const itemOf = (ref: number): Item => {
    const at = uintAt(table + ref * offsetSize, offsetSize)
    const marker = view.getUint8(at)
    const [kind, low] = [marker >> 4, marker & 0x0f]

    if (low !== LONG) {
      return { kind, length: low, start: at + 1 }
    }

    const size = 1 << (view.getUint8(at + 1) & 0x0f)

    return { kind, length: uintAt(at + 2, size), start: at + 2 + size }
  }

  const textOf = ({ kind, length, start }: Item) => {
    if (kind === KIND.ascii) {
      return latin1(span(start, length))
    }

    return kind === KIND.utf16 ? utf16(span(start, 2 * length)) : undefined
  }

  return { uintAt, span, refSize, top: uintAt(trailer + 16, 8), itemOf, textOf }
}

const read = (bytes: Uint8Array, key: string) => {
  if (latin1(bytes.subarray(0, HEADER.length)) !== HEADER) {
    return undefined
  }

  const { uintAt, span, refSize, top, itemOf, textOf } = reader(bytes)
  const dictionary = itemOf(top)
  const refAt = (index: number) => uintAt(dictionary.start + index * refSize, refSize)
  const keys = Array.from({ length: dictionary.length }, (_, index) => index)
  const found = dictionary.kind === KIND.dictionary ? keys.find(index => textOf(itemOf(refAt(index))) === key) : undefined
  const value = found === undefined ? undefined : itemOf(refAt(dictionary.length + found))

  return value?.kind === KIND.data ? span(value.start, value.length).slice() : undefined
}

/** The data under `key` in the list's top dictionary; none where the key holds none, or the bytes hold no list. */
export const dataIn = (bytes: Uint8Array, key: string): Uint8Array | undefined => {
  try {
    return read(bytes, key)
  } catch {
    return undefined
  }
}
