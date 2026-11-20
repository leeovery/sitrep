/**
 * The sessions no terminal on this Mac shows, as core reads SitRep's
 * `here.json`: the file as the app writes it; none for a file missing,
 * garbled, of another shape or of a version this reader does not know; and
 * none for one 10 seconds or more old, as a SitRep no longer reading
 * leaves it.
 */
import { expect, test } from './kit'
import { HERE_STALE_MS, hereFile, notHereOf } from '../core'
import { APP_AT, APP_FILE, APP_NOT_HERE } from './here'

/** A file of the format's version holding `fields`, written at APP_AT unless they say otherwise. */
const fileOf = (fields: object) => JSON.stringify({ v: 1, at: APP_AT, notHere: APP_NOT_HERE, ...fields })

test('the file as the app writes it names the sessions it read as not here', () => {
  expect([...notHereOf(APP_FILE, APP_AT)]).toEqual(APP_NOT_HERE)
})

test('it sits at the top of the board folder, beside projects/ and snooze.json', () => {
  expect(hereFile('/Users/me/.local/state/sitrep')).toBe('/Users/me/.local/state/sitrep/here.json')
})

test('a file is fresh for 10 seconds, three of SitRep\'s reads and a second over, either side of its time; from then on it names none', () => {
  expect(HERE_STALE_MS).toBe(10_000)

  for (const now of [APP_AT, APP_AT + HERE_STALE_MS - 1, APP_AT - HERE_STALE_MS + 1]) {
    expect(notHereOf(APP_FILE, now).size, String(now - APP_AT)).toBe(2)
  }

  for (const now of [APP_AT + HERE_STALE_MS, APP_AT + 60_000, APP_AT - HERE_STALE_MS]) {
    expect(notHereOf(APP_FILE, now).size, String(now - APP_AT)).toBe(0)
  }
})

test('no file, or one that does not read whole, names none', () => {
  for (const text of [undefined, '', 'not json', APP_FILE.slice(0, -5), '[]', 'null', '"here"', '{}']) {
    expect(notHereOf(text, APP_AT).size, String(text)).toBe(0)
  }
})

test('a file of a later version, or with no version or one that is no version, names none', () => {
  for (const v of [2, 0, '1', 1.5, null]) {
    expect(notHereOf(fileOf({ v }), APP_AT).size, String(v)).toBe(0)
  }

  expect(notHereOf(JSON.stringify({ at: APP_AT, notHere: APP_NOT_HERE }), APP_AT).size).toBe(0)
})

test('a file of the wrong shape names none: a time missing or no time, ids missing, not a list, or a list holding anything but text', () => {
  const shapes = [
    { at: undefined },
    { at: '1763650000123' },
    { at: null },
    { at: Infinity },
    { notHere: undefined },
    { notHere: 'sr-nw0001' },
    { notHere: { 'sr-nw0001': true } },
    { notHere: ['sr-nw0001', 7] },
    { notHere: [null] },
  ]

  for (const fields of shapes) {
    expect(notHereOf(fileOf(fields), APP_AT).size, JSON.stringify(fields)).toBe(0)
  }
})

test('a fresh file naming none names none, and a field this reader does not know is passed over', () => {
  expect(notHereOf(fileOf({ notHere: [] }), APP_AT).size).toBe(0)
  expect([...notHereOf(fileOf({ by: 'SitRep' }), APP_AT)]).toEqual(APP_NOT_HERE)
})
