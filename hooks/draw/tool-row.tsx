/**
 * Claude's sitrep calls in the transcript: each one dim line saying what
 * it did, its result drawn as nothing, so the chat stays the chat. An item
 * a call names is named by its title, where the held work has it.
 */
import { oneLine, type Work } from '../../core'
import { toolNamed, type ToolName } from '../tools'
import type { Els } from './kit'

type Input = { readonly [key: string]: unknown }

const text = (value: unknown) => (typeof value === 'string' ? oneLine(value) : '')

/** The title of the item a call names, or the plain word where the held work does not have it. */
const titleOf = (work: Work | undefined, input: Input) => {
  const item = work?.items.get(text(input.item))

  if (item === undefined) {
    return 'an item'
  }

  return item.type === 'note' ? item.text : item.title
}

/** What each call did, in Lee's words. */
const SAID: Record<ToolName, (input: Input, work: Work | undefined) => string> = {
  start: input => `started: ${text(input.name)}`,
  join: (input, work) =>
    work !== undefined && work.id === text(input.work)
      ? `joined: ${work.status.name}`
      : 'joined a piece of work',
  status: () => '• status set',
  ask: input => `◆ asked: ${text(input.title)}`,
  note: input => `logged: ${text(input.text)}`,
  park: input => `◇ parked: ${text(input.title)}`,
  resolve: (input, work) => `resolved: ${titleOf(work, input)}`,
  reopen: (input, work) => `reopened: ${titleOf(work, input)}`,
  edit: (input, work) => `edited: ${titleOf(work, input)}`,
  board: () => 'read the board back',
}

/** The calls whose rows name what only the held work can put a name to. */
const NAMING: ReadonlySet<ToolName> = new Set(['join', 'resolve', 'reopen', 'edit'])

/**
 * A call's line, from its input and, where it names an item, the held work
 * (read only then, so no other row is drawn again as the board moves).
 * Undefined for a tool that is not sitrep's.
 */
export const toolLine = async (
  tool: string,
  input: unknown,
  held: () => Promise<Work | undefined>,
) => {
  const name = toolNamed(tool)
  const fields = typeof input === 'object' && input !== null ? (input as Input) : {}

  if (name === undefined) {
    return undefined
  }

  return SAID[name](fields, NAMING.has(name) ? await held() : undefined)
}

/** The call's row, indented as a folded group's count line is. */
export const drawToolRow = (els: Els, line: string) => {
  const { Box, Text } = els

  return (
    <Box paddingLeft={2}>
      <Text dimColor wrap="truncate-end">
        {line}
      </Text>
    </Box>
  )
}

/** The result under the row: nothing the row has not said. */
export const drawToolResult = (els: Els) => {
  const { Box } = els

  return <Box />
}
