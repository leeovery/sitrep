import { expect, test } from './kit'
import { ago } from '../core'
import { DAY, HOUR, MIN, T0 } from './data'

test('how long ago a time was reads in its largest whole unit, rounded, under a minute as now', () => {
  const elapsed = [0, MIN - 1, MIN, 12 * MIN + 29_999, HOUR - 1, HOUR, 23 * HOUR, DAY, 3 * DAY]

  expect(elapsed.map(each => ago(T0 + each, T0))).toEqual([
    'now',
    'now',
    '1m',
    '12m',
    '60m',
    '1h',
    '23h',
    '1d',
    '3d',
  ])
})
