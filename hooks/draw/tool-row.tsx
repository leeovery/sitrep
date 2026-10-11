/**
 * Claude's sitrep calls in the transcript: each one dim line saying what
 * it did, its result drawn as nothing, so the chat stays the chat. An item
 * a call names is named by its title, and a work by its name, as they stood
 * when the call was answered; a call with no name kept, by the held work.
 */
import { itemTitle, oneLine, type Work } from '../../core'
import { toolNamed, type ToolName } from '../tools'
import type { Els } from './kit'

type Input = { readonly [key: string]: unknown }

const text = (value: unknown) => (typeof value === 'string' ? oneLine(value) : '')

/** The title of the item a call names, as the held work has it. */
const heldTitle = (work: Work, input: Input) => itemTitle(work, text(input.item))

/** What a project call changed: its name, where it lives, or both. */
const projectSaid = (input: Input) => {
  const name = text(input.name)
  const directory = text(input.directory)
  const said = [
    ...(name === '' ? [] : [`project renamed: ${name}`]),
    ...(directory === '' ? [] : [`project lives in ${directory}`]),
  ]

  return said.length === 0 ? 'set the project' : said.join(' · ')
}

/** What each call did, in Lee's words, given the name of what it names where one is known. */
const SAID: Record<ToolName, (input: Input, name: string | undefined) => string> = {
  start: input => `started: ${text(input.name)}`,
  join: (_, name) => (name === undefined ? 'joined a piece of work' : `joined: ${name}`),
  status: () => '• status set',
  ask: input => `◆ asked: ${text(input.title)}`,
  note: input => `logged: ${text(input.text)}`,
  park: input => `◇ parked: ${text(input.title)}`,
  resolve: (_, name = 'an item') => `resolved: ${name}`,
  reopen: (_, name = 'an item') => `reopened: ${name}`,
  edit: (_, name = 'an item') => `edited: ${name}`,
  finish: (_, name) => (name === undefined ? '✓ finished a piece of work' : `✓ finished: ${name}`),
  project: projectSaid,
  board: () => 'read the board back',
}

/** The calls whose rows name an item or a work, and its name as the held work has it. */
const NAMING: Partial<Record<ToolName, (work: Work, input: Input) => string | undefined>> = {
  join: (work, input) => (work.id === text(input.work) ? work.status.name : undefined),
  resolve: heldTitle,
  reopen: heldTitle,
  edit: heldTitle,
  finish: work => work.status.name,
}

/** Where a call's row finds the name of what it names: kept as the call was answered, else the held work. */
type Naming = {
  kept: () => Promise<string | undefined>
  held: () => Promise<Work | undefined>
}

/** The name of what a naming call names: the name kept, else the held work's, read only then. */
const nameFor = async (
  heldName: (work: Work, input: Input) => string | undefined,
  input: Input,
  naming: Naming,
) => {
  const kept = await naming.kept()

  if (kept !== undefined) {
    return kept
  }

  const work = await naming.held()

  return work === undefined ? undefined : heldName(work, input)
}

/**
 * A call's line, from its input and, where it names an item or a work, its
 * name (read only then, so no other row is drawn again as the board moves).
 * Undefined for a tool that is not sitrep's.
 */
export const toolLine = async (tool: string, input: unknown, naming: Naming) => {
  const name = toolNamed(tool)
  const fields = typeof input === 'object' && input !== null ? (input as Input) : {}

  if (name === undefined) {
    return undefined
  }

  const heldName = NAMING[name]

  return SAID[name](
    fields,
    heldName === undefined ? undefined : await nameFor(heldName, fields, naming),
  )
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
