import type { ClientSurface } from 'claude-code'
import { expect, test } from 'claude-code/testing'
import TextArea from '../hooks/draw/textarea'

type State = { text: string; cursor: number; isFocused: boolean; times: number }

type Key = Parameters<Parameters<ClientSurface['onKey']>[0]>[0]

/** A surface for the text area: its state as given, and what it set and posted, and the key it listens with. */
const surfaceWith = (state?: State) => {
  const set: State[] = []
  const posted: unknown[] = []
  let onKey: (event: Key) => void = () => {}
  const element = () => ({ type: 'Box', props: {}, children: [] })
  const surface = {
    elements: { Box: element, Text: element },
    state,
    columns: 40,
    rows: 3,
    setState: (next: State) => set.push(next),
    post: (data: unknown) => posted.push(data),
    onPointer: () => () => {},
    onKey: (fn: (event: Key) => void) => {
      onKey = fn

      return () => {}
    },
  } as unknown as ClientSurface<State>

  return { surface, set, posted, key: (event: Key) => onKey(event) }
}

const PROPS = { placeholder: 'Click here, then type', minRows: 3 }

test('the text area takes up what the board put in it once, the cursor at its end, and edits on from there', () => {
  const typed: State = { text: 'Ran it:', cursor: 7, isFocused: true, times: 0 }
  const filled = { text: 'Ran it:\nexit 0', times: 1 }
  const first = surfaceWith(typed)

  TextArea({ ...PROPS, filled }, first.surface)
  expect(first.set).toEqual([{ text: 'Ran it:\nexit 0', cursor: 14, isFocused: true, times: 1 }])

  first.key({ key: '!' } as Key)
  expect(first.posted).toEqual([{ text: 'Ran it:\nexit 0!', isSubmit: false }])

  const later = surfaceWith({ text: 'Ran it:\nexit 0!', cursor: 15, isFocused: true, times: 1 })

  TextArea({ ...PROPS, filled }, later.surface)
  expect(later.set).toEqual([])
})

test('with nothing put in it, the text area keeps what was typed', () => {
  const typed: State = { text: 'ok', cursor: 2, isFocused: true, times: 0 }
  const drawn = surfaceWith(typed)

  TextArea({ ...PROPS, filled: null }, drawn.surface)
  expect(drawn.set).toEqual([])
})
