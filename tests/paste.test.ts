import { expect, test } from 'claude-code/testing'
import { unwrapPastes } from '../hooks/paste'

/** A paste as the engine wraps it in a submitted prompt, the line breaks around it with it (live, 2.1.295). */
const pasted = (text: string, id = '08fd') =>
  `\n\n<pasted_content id="${id}">\n${text}\n</pasted_content id="${id}">\n`

test('a prompt of nothing but a paste gives its text, every line as pasted', () => {
  expect(unwrapPastes(pasted('a\n  b\n\nc'))).toBe('a\n  b\n\nc')
})

test('the words typed around a paste stay in their place, the paste on lines of its own', () => {
  expect(unwrapPastes(`Ran it:${pasted('exported 42 rows\nexit 0')}`)).toBe(
    'Ran it:\nexported 42 rows\nexit 0',
  )
  expect(unwrapPastes(`${pasted('exported 42 rows')}what now?`)).toBe('exported 42 rows\nwhat now?')
  expect(unwrapPastes(`First:${pasted('one', 'a1')}then:${pasted('two', 'b2')}done`)).toBe(
    'First:\none\nthen:\ntwo\ndone',
  )
})

test('a prompt with no paste, or tags that do not close as they open, is as it came', () => {
  expect(unwrapPastes('Carry on.')).toBe('Carry on.')

  for (const prompt of [
    '<pasted_content id="a1">\na\n</pasted_content id="b2">',
    '<pasted_content>\na\n</pasted_content>',
  ]) {
    expect(unwrapPastes(prompt)).toBe(prompt)
  }
})
