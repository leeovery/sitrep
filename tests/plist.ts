/**
 * Binary property lists for the panel's tests: one dictionary, its keys in
 * ASCII, each value a string or data, as macOS saves an app's defaults; and
 * SitRep's own, its settings saved as JSON under their keys.
 */

const HEADER = [...'bplist00'].map(character => character.charCodeAt(0))

const ascii = (text: string) => [...text].map(character => character.charCodeAt(0))

/** An object's marker: its kind, and its length, in an integer of two bytes after it from 15 on. */
const marker = (kind: number, length: number) =>
  length < 15 ? [(kind << 4) | length] : [(kind << 4) | 0x0f, 0x11, length >> 8, length & 0xff]

const objectOf = (value: string | Uint8Array) =>
  typeof value === 'string' ? [...marker(0x5, value.length), ...ascii(value)] : [...marker(0x4, value.length), ...value]

/** Eight bytes, big-endian. */
const long = (value: number) => [0, 0, 0, 0, (value >>> 24) & 0xff, (value >>> 16) & 0xff, (value >>> 8) & 0xff, value & 0xff]

/** The list of one dictionary holding these entries: the dictionary, then its keys, then its values, each by its offset. */
export const plistOf = (entries: Record<string, string | Uint8Array>): Uint8Array => {
  const keys = Object.keys(entries)
  const refs = keys.map((_, at) => at + 1)
  const objects = [
    [...marker(0xd, keys.length), ...refs, ...refs.map(ref => ref + keys.length)],
    ...keys.map(objectOf),
    ...Object.values(entries).map(objectOf),
  ]
  const offsets = objects.reduce<number[]>((sofar, object, at) => [...sofar, (sofar[at] ?? 0) + object.length], [HEADER.length]).slice(0, -1)
  const table = HEADER.length + objects.reduce((sum, object) => sum + object.length, 0)
  const trailer = [0, 0, 0, 0, 0, 0, 2, 1, ...long(objects.length), ...long(0), ...long(table)]

  return new Uint8Array([...HEADER, ...objects.flat(), ...offsets.flatMap(offset => [offset >> 8, offset & 0xff]), ...trailer])
}

/** SitRep's defaults, as it saves them: each settings value JSON, as data under its key. */
export const defaultsOf = (settings: Record<string, unknown>): Uint8Array =>
  plistOf(Object.fromEntries(Object.entries(settings).map(([key, value]) => [key, new TextEncoder().encode(JSON.stringify(value))])))
