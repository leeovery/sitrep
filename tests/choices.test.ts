/**
 * Snooze's choices as core reads the app's `snooze.json`: the file as the
 * app writes it; the defaults for a file missing, garbled or of a version
 * this reader does not know; within a file, each choice and each field
 * read on its own, by its type, one missing or out of range keeping its
 * default; and settings a window holds, read whole.
 */
import { expect, test } from './kit'
import { heldSnooze, SNOOZE_CHOICES, snoozeFile, SNOOZE_DEFAULTS, snoozeSettingsOf } from '../core'
import { APP_FILE, APP_SETTINGS } from './choices'

/** A file of the format's version holding `choices`. */
const fileOf = (choices: object) => JSON.stringify({ v: 1, ...choices })

test('the file as the app writes it reads as the app set it: every choice, its switch and its time', () => {
  expect(snoozeSettingsOf(APP_FILE)).toEqual(APP_SETTINGS)
  expect(APP_SETTINGS).not.toEqual(SNOOZE_DEFAULTS)
})

test('it sits at the top of the board folder, beside projects/', () => {
  expect(snoozeFile('/Users/me/.local/state/sitrep')).toBe('/Users/me/.local/state/sitrep/snooze.json')
})

test("the defaults are today's choices: In an hour, Later today at 3 hours, Tonight at 18:00, Tomorrow and Next week at Monday 09:00, each on, and This weekend off, at Saturday 09:00", () => {
  expect(SNOOZE_DEFAULTS).toEqual({
    hour: { isOn: true },
    later: { isOn: true, hours: 3 },
    tonight: { isOn: true, at: { hour: 18, minute: 0 } },
    tomorrow: { isOn: true, at: { hour: 9, minute: 0 } },
    weekend: { isOn: false, day: 'saturday', at: { hour: 9, minute: 0 } },
    week: { isOn: true, day: 'monday', at: { hour: 9, minute: 0 } },
  })
})

test('no file, or one that does not read whole, is the defaults', () => {
  for (const text of [
    undefined,
    '',
    APP_FILE.slice(0, 80),
    'not json',
    'null',
    '[]',
    '"snooze"',
    '42',
  ]) {
    expect(snoozeSettingsOf(text), String(text)).toBe(SNOOZE_DEFAULTS)
  }
})

test("a file of a later version, or with no version or one that is no version, is the defaults: what it says may mean otherwise than this reader's", () => {
  for (const v of [2, 0, -1, 1.5, '1', null]) {
    expect(snoozeSettingsOf(APP_FILE.replace('"v" : 1', `"v" : ${JSON.stringify(v)}`)), String(v)).toBe(
      SNOOZE_DEFAULTS,
    )
  }

  expect(snoozeSettingsOf(APP_FILE.replace('"v" : 1,', ''))).toBe(SNOOZE_DEFAULTS)
})

test('a file partly filled keeps what it says, and the rest take their defaults: a choice missing, or a field of one', () => {
  expect(
    snoozeSettingsOf(fileOf({ later: { hours: 2 }, week: { on: false }, weekend: { on: true } })),
  ).toEqual({
    ...SNOOZE_DEFAULTS,
    later: { isOn: true, hours: 2 },
    weekend: { ...SNOOZE_DEFAULTS.weekend, isOn: true },
    week: { ...SNOOZE_DEFAULTS.week, isOn: false },
  })
  expect(snoozeSettingsOf(fileOf({}))).toEqual(SNOOZE_DEFAULTS)
})

test('a field out of range keeps its default, and the rest of its choice stands: hours past 1 to 4, a time not HH:MM on the 24-hour clock, a day no weekday, This weekend on a weekday, a switch not true or false', () => {
  const read = snoozeSettingsOf(
    fileOf({
      hour: { on: 'yes' },
      later: { on: false, hours: 5 },
      tonight: { on: false, at: '24:00' },
      tomorrow: { at: '9:00' },
      weekend: { on: true, day: 'monday', at: '10:60' },
      week: { day: 'Friday', at: '08:30' },
    }),
  )

  expect(read).toEqual({
    hour: SNOOZE_DEFAULTS.hour,
    later: { isOn: false, hours: 3 },
    tonight: { isOn: false, at: { hour: 18, minute: 0 } },
    tomorrow: SNOOZE_DEFAULTS.tomorrow,
    weekend: { isOn: true, day: 'saturday', at: { hour: 9, minute: 0 } },
    week: { isOn: true, day: 'monday', at: { hour: 8, minute: 30 } },
  })

  for (const later of [0, 2.5, '2', null, [2]]) {
    expect(snoozeSettingsOf(fileOf({ later: { hours: later } })).later.hours, String(later)).toBe(3)
  }

  for (const at of ['18:00:00', ' 18:00', '18.00', 1800, '1800', '-1:00', ['20:00']]) {
    expect(snoozeSettingsOf(fileOf({ tonight: { at } })).tonight.at, JSON.stringify(at)).toEqual({
      hour: 18,
      minute: 0,
    })
  }
})

test('a choice that is no object keeps its defaults, and a field or a choice this reader does not know is passed over', () => {
  expect(snoozeSettingsOf(fileOf({ later: 2, tonight: ['20:00'], tomorrow: null }))).toEqual(
    SNOOZE_DEFAULTS,
  )
  expect(
    snoozeSettingsOf(fileOf({ hour: { on: false, length: 2 }, fortnight: { on: true } })),
  ).toEqual({ ...SNOOZE_DEFAULTS, hour: { isOn: false } })
})

/** A value of each JSON type no field takes, an object that cannot be made text and a list of one good time among them. */
const NO_FIELD_VALUES: unknown[] = [null, 0, '', 'x', [], ['20:00'], [2], {}, { toString: 0 }, { valueOf: 0 }]

test('a field holding a value of another type reads as its default, never throwing', () => {
  for (const value of NO_FIELD_VALUES) {
    const choice = { on: value, hours: value, at: value, day: value }
    const file = fileOf(Object.fromEntries(SNOOZE_CHOICES.map(each => [each, choice])))

    expect(snoozeSettingsOf(file), JSON.stringify(value)).toEqual(SNOOZE_DEFAULTS)
  }
})

test('settings as a window holds them are read whole: a choice missing, or a field of one, takes its default; the rest stand', () => {
  const { weekend, ...missingWeekend } = APP_SETTINGS
  const { hours, ...laterWithoutHours } = APP_SETTINGS.later

  expect(heldSnooze(APP_SETTINGS)).toEqual(APP_SETTINGS)
  expect(heldSnooze(missingWeekend)).toEqual({ ...APP_SETTINGS, weekend: SNOOZE_DEFAULTS.weekend })
  expect(heldSnooze({ ...APP_SETTINGS, later: laterWithoutHours }).later).toEqual({
    isOn: APP_SETTINGS.later.isOn,
    hours: SNOOZE_DEFAULTS.later.hours,
  })
  expect(weekend).not.toEqual(SNOOZE_DEFAULTS.weekend)
  expect(hours).not.toBe(SNOOZE_DEFAULTS.later.hours)

  for (const held of [undefined, null, 'x', [], {}]) {
    expect(heldSnooze(held), JSON.stringify(held)).toEqual(SNOOZE_DEFAULTS)
  }
})
