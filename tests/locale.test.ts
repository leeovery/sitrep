import { expect, test } from 'claude-code/testing'
import { childEnvironment } from '../cli/locale'

test("the CLI's programs run with a UTF-8 character type where the CLI was started with no locale, as SitRep starts it", () => {
  expect(childEnvironment({ PATH: '/usr/bin' })).toEqual({ PATH: '/usr/bin', LC_CTYPE: 'UTF-8' })
  expect(childEnvironment({ PATH: '/usr/bin', LANG: '' })).toEqual({
    PATH: '/usr/bin',
    LANG: '',
    LC_CTYPE: 'UTF-8',
  })
})

test('a locale the CLI was started with is left as it is, whichever variable names it', () => {
  for (const env of [{ LANG: 'en_GB.UTF-8' }, { LC_CTYPE: 'C' }, { LC_ALL: 'fr_FR.ISO8859-1' }]) {
    expect(childEnvironment(env)).toEqual(env)
  }
})
