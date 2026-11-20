/**
 * Who views each held session and each multiplexer tty, as core reads
 * SitRep's `here.json`, and which held sessions the panel dims: those whose
 * viewers share none with the panel's own. The file as the app writes it;
 * nothing for a file missing, garbled, of another shape or of a version
 * this reader does not know, or 30 seconds or more from the reader's clock,
 * either side; a version 1 file dimming what it named. The panel is looked
 * at from its own tty's viewers where the file lists any, else the device
 * its own `SSH_CONNECTION` names, else this Mac's screen.
 */
import { expect, test } from './kit'
import { HERE_STALE_MS, hereFile, lookingFrom, notHereOf, sightingsOf, ttyOf, type Lookout, type Sightings } from '../core'
import { APP_AT, APP_FILE, APP_SESSIONS, APP_TTYS, TTY_NUMBERS } from './here'

const PHONE = '192.0.2.7'
const IPAD = '198.51.100.4'

/** The panel on the Mac, over SSH from the phone or the iPad in a plain login, and inside a multiplexer session on the phone, its `SSH_CONNECTION` the Mac's, where the session was made. */
const ON_THE_MAC: Lookout = { tty: '/dev/ttys041' }
const FROM_THE_PHONE: Lookout = { tty: '/dev/ttys080', sshConnection: `${PHONE} 50122 192.0.2.1 22` }
const FROM_THE_IPAD: Lookout = { tty: '/dev/ttys081', sshConnection: `${IPAD} 50123 192.0.2.1 22` }
const IN_ZMX_ON_THE_PHONE: Lookout = { tty: '/dev/ttys004' }

/** A file of the format's version holding `fields`, the app's maps written at APP_AT unless they say otherwise. */
const fileOf = (fields: object) => JSON.stringify({ v: 2, at: APP_AT, sessions: APP_SESSIONS, ttys: APP_TTYS, ...fields })

/** The sightings as plain objects, each list in order, to compare. */
const plain = (sightings: Sightings | undefined) =>
  sightings === undefined
    ? undefined
    : Object.fromEntries(
        Object.entries(sightings).map(([key, map]) => [
          key,
          Object.fromEntries([...(map as Sightings['sessions'])].map(([id, viewers]) => [id, [...viewers].sort()])),
        ]),
      )

const sorted = (ids: ReadonlySet<string>) => [...ids].sort()

test('the file as the app writes it reads as each held session and each tty with its viewers', () => {
  expect(plain(sightingsOf(APP_FILE, APP_AT))).toEqual({ sessions: APP_SESSIONS, ttys: APP_TTYS })
})

test('it sits at the top of the board folder, beside projects/ and snooze.json', () => {
  expect(hereFile('/Users/me/.local/state/sitrep')).toBe('/Users/me/.local/state/sitrep/here.json')
})

test("a file is fresh for 30 seconds either side of its time, three of SitRep's writes at the most it waits between them; from then on it says nothing", () => {
  expect(HERE_STALE_MS).toBe(30_000)

  for (const now of [APP_AT, APP_AT + HERE_STALE_MS - 1, APP_AT - HERE_STALE_MS + 1]) {
    expect(sightingsOf(APP_FILE, now), String(now - APP_AT)).toBeDefined()
    expect(sorted(notHereOf(APP_FILE, now, ON_THE_MAC)), String(now - APP_AT)).toEqual(['sr-ct0002', 'sr-fb0003'])
  }

  for (const now of [APP_AT + HERE_STALE_MS, APP_AT + 60_000, APP_AT - HERE_STALE_MS]) {
    expect(sightingsOf(APP_FILE, now), String(now - APP_AT)).toBeUndefined()
    expect(notHereOf(APP_FILE, now, ON_THE_MAC).size, String(now - APP_AT)).toBe(0)
  }
})

test('no file, or one that does not read whole, says nothing, so no session is dimmed', () => {
  for (const text of [undefined, '', 'not json', APP_FILE.slice(0, -5), '[]', 'null', '"here"', '{}']) {
    expect(sightingsOf(text, APP_AT), String(text)).toBeUndefined()
    expect(notHereOf(text, APP_AT, FROM_THE_PHONE).size, String(text)).toBe(0)
  }
})

test('a file of a later version, or with no version or one that is no version, says nothing', () => {
  for (const v of [3, 0, '2', 2.5, null]) {
    expect(sightingsOf(fileOf({ v }), APP_AT), String(v)).toBeUndefined()
  }

  expect(sightingsOf(JSON.stringify({ at: APP_AT, sessions: APP_SESSIONS, ttys: APP_TTYS }), APP_AT)).toBeUndefined()
})

test('a version 1 file, from a SitRep before viewers, dims what it named wherever the panel is, and leaves the rest filled', () => {
  const v1 = JSON.stringify({ at: APP_AT, notHere: ['sr-ct0002', 'sr-nw0001'], v: 1 })

  for (const lookout of [ON_THE_MAC, FROM_THE_PHONE, IN_ZMX_ON_THE_PHONE]) {
    expect(sorted(notHereOf(v1, APP_AT, lookout)), JSON.stringify(lookout)).toEqual(['sr-ct0002', 'sr-nw0001'])
  }

  expect(sightingsOf(JSON.stringify({ at: APP_AT, notHere: 'sr-nw0001', v: 1 }), APP_AT), 'its list misshapen').toBeUndefined()
})

test('a file of the wrong shape says nothing: a time missing or no time, either map missing, not an object, or a list holding anything but text', () => {
  const shapes = [
    { at: undefined },
    { at: '1763650000123' },
    { at: null },
    { sessions: undefined },
    { sessions: ['sr-nw0001'] },
    { sessions: 'sr-nw0001' },
    { sessions: { 'sr-nw0001': 'mac' } },
    { sessions: { 'sr-nw0001': ['mac', 7] } },
    { sessions: { 'sr-nw0001': null } },
    { ttys: undefined },
    { ttys: [] },
    { ttys: { '/dev/ttys004': [null] } },
  ]

  for (const fields of shapes) {
    expect(sightingsOf(fileOf(fields), APP_AT), JSON.stringify(fields)).toBeUndefined()
  }

  expect(sightingsOf('{"at":1e400,"sessions":{},"ttys":{},"v":2}', APP_AT), 'a time past any date').toBeUndefined()
})

test('a field this reader does not know is passed over, and a viewer it does not know is matched as its words', () => {
  expect(plain(sightingsOf(fileOf({ by: 'SitRep' }), APP_AT))).toEqual({ sessions: APP_SESSIONS, ttys: APP_TTYS })

  const later = fileOf({ sessions: { 'sr-nw0001': ['usb:7'] }, ttys: { '/dev/ttys004': ['usb:7'] } })

  expect(notHereOf(later, APP_AT, IN_ZMX_ON_THE_PHONE).size).toBe(0)
  expect(sorted(notHereOf(later, APP_AT, ON_THE_MAC))).toEqual(['sr-nw0001'])
})

test("the panel is looked at from its own tty's viewers, where the file lists any, whatever its SSH_CONNECTION says", () => {
  const sightings = sightingsOf(APP_FILE, APP_AT)

  expect([...lookingFrom(sightings, IN_ZMX_ON_THE_PHONE)]).toEqual([`ssh:${PHONE}`])
  expect([...lookingFrom(sightings, { tty: '/dev/ttys004', sshConnection: `${IPAD} 50123 192.0.2.1 22` })]).toEqual([`ssh:${PHONE}`])
  expect([...lookingFrom(sightings, { tty: '/dev/ttys1024', sshConnection: `${PHONE} 1 2 3` })]).toEqual(['mac'])
})

test('else from the device its own SSH_CONNECTION names, by its first field; else from this Mac', () => {
  const sightings = sightingsOf(fileOf({ ttys: { '/dev/ttys080': [] } }), APP_AT)

  expect([...lookingFrom(sightings, FROM_THE_PHONE)], 'a tty listed with no viewer').toEqual([`ssh:${PHONE}`])
  expect([...lookingFrom(sightings, { sshConnection: `  ${IPAD}  50123 192.0.2.1 22\n` })], 'no tty').toEqual([`ssh:${IPAD}`])
  expect([...lookingFrom(undefined, { sshConnection: '2001:db8::7 50124 2001:db8::1 22' })], 'no file').toEqual(['ssh:2001:db8::7'])
  expect([...lookingFrom(sightings, ON_THE_MAC)]).toEqual(['mac'])
  expect([...lookingFrom(sightings, { tty: '/dev/ttys041', sshConnection: '' })], 'set empty').toEqual(['mac'])
  expect([...lookingFrom(undefined, {})]).toEqual(['mac'])
})

test('over SSH, a held session is dimmed where none of its viewers is the device the panel is looked at from', () => {
  expect(sorted(notHereOf(APP_FILE, APP_AT, FROM_THE_PHONE))).toEqual(['sr-fb0003'])
  expect(sorted(notHereOf(APP_FILE, APP_AT, FROM_THE_IPAD))).toEqual(['sr-ct0002', 'sr-fb0003', 'sr-nw0001'])
  expect(sorted(notHereOf(APP_FILE, APP_AT, { sshConnection: '2001:db8::7 50124 2001:db8::1 22' }))).toEqual([
    'sr-fb0003',
    'sr-nw0001',
  ])
})

test("Lee's case: open on the phone and detached on the Mac draws filled on the phone, the panel inside zmx there; open only in the Mac's Ghostty draws hollow there; on the Mac, the other way round", () => {
  const text = JSON.stringify({
    at: APP_AT,
    sessions: { 'sr-nw0001': [`ssh:${PHONE}`], 'sr-ct0002': ['mac'] },
    ttys: { '/dev/ttys004': [`ssh:${PHONE}`] },
    v: 2,
  })

  expect([...notHereOf(text, APP_AT, IN_ZMX_ON_THE_PHONE)]).toEqual(['sr-ct0002'])
  expect([...notHereOf(text, APP_AT, FROM_THE_PHONE)]).toEqual(['sr-ct0002'])
  expect([...notHereOf(text, APP_AT, ON_THE_MAC)]).toEqual(['sr-nw0001'])
})

test("on the Mac, as before: the dimmed are the sessions whose viewers hold no mac, the notch's own, and a session the file doesn't name, never read, draws filled", () => {
  const sightings = sightingsOf(APP_FILE, APP_AT)
  const notches = [...(sightings?.sessions ?? [])].filter(([, viewers]) => !viewers.has('mac')).map(([id]) => id)

  expect(sorted(notHereOf(APP_FILE, APP_AT, ON_THE_MAC))).toEqual(notches.sort())
  expect(sorted(notHereOf(APP_FILE, APP_AT, { tty: '/dev/ttys1024' }))).toEqual(notches.sort())
  expect(notHereOf(APP_FILE, APP_AT, ON_THE_MAC).has('sr-tw0004')).toBe(false)
})

test('a tty is named from its numbers as the app names a process\'s, the pairs both suites read: a pty, major 16, at least three digits; nothing for any other device or none', () => {
  const pairs = JSON.parse(TTY_NUMBERS) as [number, string | null][]

  expect(pairs.length).toBe(5)

  for (const [numbers, tty] of pairs) {
    expect(ttyOf(numbers), String(numbers)).toBe(tty ?? undefined)
  }

  expect(ttyOf((16 << 24) | 32)).toBe('/dev/ttys032')
  expect(ttyOf(0xffff_ffff), 'all ones').toBeUndefined()
  expect(ttyOf(Number.NaN)).toBeUndefined()
})
