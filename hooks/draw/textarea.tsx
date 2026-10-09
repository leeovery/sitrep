/**
 * A text field a few rows tall that grows as it fills: Claude Code's own
 * Input is one line. A click focuses it; it posts its text to the hooks
 * module on every change, with `isSubmit` when Enter saves. Shift+Enter (or
 * ctrl+J) starts a new line. What the board puts in it itself (`filled`) it
 * takes up once, the cursor at its end.
 */
import type { ClientKeyEvent, ClientModule } from 'claude-code'
import type { SitrepFilled } from '../../types'

type Props = { placeholder: string; minRows: number; filled: SitrepFilled | null }

/** `times`: how many of the board's fills it has taken up. */
type State = { text: string; cursor: number; isFocused: boolean; times: number }

/** A row as [start, end) into the text. */
type Row = [start: number, end: number]

/** Keys that are no character to insert. */
const NAMED = new Set([
  'up',
  'down',
  'left',
  'right',
  'return',
  'tab',
  'backspace',
  'delete',
  'pageup',
  'pagedown',
  'home',
  'end',
  'escape',
])

/** A paragraph's rows, word-wrapped to `width`, each offset by where the paragraph starts. */
const wrapped = (paragraph: string, offset: number, width: number): Row[] => {
  const rows: Row[] = []
  let start = 0

  while (start < paragraph.length) {
    let end = Math.min(paragraph.length, start + width)

    if (end < paragraph.length) {
      const space = paragraph.lastIndexOf(' ', end)

      if (space > start) {
        end = space + 1
      }
    }

    rows.push([offset + start, offset + end])
    start = end
  }

  return paragraph.length === 0 ? [[offset, offset]] : rows
}

/** Every row of the text, word-wrapped to `width`; a newline ends a row. */
const layout = (text: string, width: number): Row[] => {
  let offset = 0

  return text.split('\n').flatMap(paragraph => {
    const rows = wrapped(paragraph, offset, width)

    offset += paragraph.length + 1

    return rows
  })
}

/** The row and column the cursor sits at; past a full row it wraps onto the next. */
const locate = (rows: readonly Row[], cursor: number, width: number) => {
  const row = rows.reduce((at, [start], i) => (start <= cursor ? i : at), 0)
  const col = cursor - (rows[row]?.[0] ?? 0)

  return col >= width ? { row: row + 1, col: 0 } : { row, col }
}

const TextArea: ClientModule<Props, State> = (props, surface) => {
  const { Box, Text } = surface.elements
  const width = Math.max(10, surface.columns || 40)
  let current: State = surface.state ?? { text: '', cursor: 0, isFocused: false, times: 0 }
  const filled = props.filled ?? { text: '', times: 0 }

  if (filled.times !== current.times) {
    current = { ...current, text: filled.text, cursor: filled.text.length, times: filled.times }
    surface.setState(current)
  }

  const apply = (next: State, isSubmit = false) => {
    current = next
    surface.setState(next)
    surface.post({ text: next.text, isSubmit })
  }

  const insert = (piece: string) => {
    const { text, cursor } = current

    apply({
      ...current,
      text: text.slice(0, cursor) + piece + text.slice(cursor),
      cursor: cursor + piece.length,
      isFocused: true,
    })
  }

  const moveTo = (to: number) =>
    apply({
      ...current,
      cursor: Math.max(0, Math.min(current.text.length, to)),
      isFocused: true,
    })

  /** The rows as laid out, and the row and column the cursor is at. */
  const position = () => {
    const rows = layout(current.text, width)

    return { rows, here: locate(rows, current.cursor, width) }
  }

  const moveRow = (by: number) => {
    const { rows, here } = position()
    const target = rows[here.row + by]

    if (target !== undefined) {
      moveTo(Math.min(target[0] + here.col, target[1]))
    }
  }

  const moveInRow = (edge: 0 | 1, fallback: number) => {
    const { rows, here } = position()

    moveTo(rows[here.row]?.[edge] ?? fallback)
  }

  /** The keys that edit or move rather than insert. */
  const editing: Partial<Record<string, (event: ClientKeyEvent) => void>> = {
    return: event =>
      event.shift || event.meta ? insert('\n') : apply({ ...current, isFocused: true }, true),
    backspace: () => {
      const { text, cursor } = current

      if (cursor > 0) {
        apply({
          ...current,
          text: text.slice(0, cursor - 1) + text.slice(cursor),
          cursor: cursor - 1,
          isFocused: true,
        })
      }
    },
    delete: () => {
      const { text, cursor } = current

      if (cursor < text.length) {
        apply({ ...current, text: text.slice(0, cursor) + text.slice(cursor + 1) })
      }
    },
    left: () => moveTo(current.cursor - 1),
    right: () => moveTo(current.cursor + 1),
    up: () => moveRow(-1),
    down: () => moveRow(1),
    home: () => moveInRow(0, 0),
    end: () => moveInRow(1, current.text.length),
  }

  surface.onPointer(event => {
    if (event.type === 'down' && !current.isFocused) {
      current = { ...current, isFocused: true }
      surface.setState(current)
    }
  })

  surface.onKey(event => {
    const key = editing[event.key]

    if (key !== undefined) {
      key(event)
    } else if (event.ctrl && event.key === 'j') {
      insert('\n')
    } else if (!event.ctrl && !event.meta && !NAMED.has(event.key)) {
      // One key, or a whole paste arriving at once.
      insert(event.key.replace(/\r\n?/g, '\n'))
    }
  })

  const rows = layout(current.text, width)
  const at = locate(rows, current.cursor, width)
  const count = Math.max(props.minRows, rows.length, at.row + 1)

  const drawRow = (r: number) => {
    const span = rows[r]
    const line = span === undefined ? '' : current.text.slice(span[0], span[1])

    if (r === 0 && current.text === '' && !current.isFocused) {
      return <Text dimColor>{props.placeholder}</Text>
    }

    if (current.isFocused && r === at.row) {
      return (
        <Box flexDirection="row">
          <Text>{line.slice(0, at.col)}</Text>
          <Text inverse>{line[at.col] ?? ' '}</Text>
          <Text>{line.slice(at.col + 1)}</Text>
        </Box>
      )
    }

    return <Text>{line === '' ? ' ' : line}</Text>
  }

  return (
    <Box flexDirection="column" width="100%">
      {Array.from({ length: count }, (_, r) => drawRow(r))}
    </Box>
  )
}

export default TextArea
