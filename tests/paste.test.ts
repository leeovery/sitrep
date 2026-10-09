import { expect, test } from 'claude-code/testing'
import { holdsFolded, pastedOnly } from '../hooks/paste'

/** A paste as the engine wraps it in a submitted prompt (live, 2.1.295). */
const pasted = (text: string, id = '08fd') =>
  `<pasted_content id="${id}">\n${text}\n</pasted_content id="${id}">`

test('a prompt of nothing but pastes gives their text, every line as pasted, the pastes a line apart', () => {
  expect(pastedOnly(`\n\n${pasted('a\n  b\n\nc')}\n`)).toBe('a\n  b\n\nc')
  expect(pastedOnly(`${pasted('one', 'a1')}\n\n${pasted('two', 'b2')}`)).toBe('one\ntwo')
})

test('a prompt with anything besides its pastes, or none, or tags that do not close as they open, gives nothing', () => {
  expect(pastedOnly('Carry on.')).toBeUndefined()
  expect(pastedOnly('  \n ')).toBeUndefined()
  expect(pastedOnly(`Look: ${pasted('a')}`)).toBeUndefined()
  expect(pastedOnly(`${pasted('a')} ok?`)).toBeUndefined()
  expect(pastedOnly('<pasted_content id="a1">\na\n</pasted_content id="b2">')).toBeUndefined()
  expect(pastedOnly('<pasted_content>\na\n</pasted_content>')).toBeUndefined()
})

test('the prompt box holds a paste folded away by its placeholder', () => {
  expect(holdsFolded('[Pasted text #1 +3 lines]')).toBe(true)
  expect(holdsFolded('see [Pasted text #12]')).toBe(true)
  expect(holdsFolded('v1.2.3\nexit 0')).toBe(false)
})
