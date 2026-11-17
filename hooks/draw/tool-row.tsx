/**
 * Claude's sitrep calls in the transcript: each one dim line saying what it
 * did, its result drawn as nothing, so the chat stays the chat. An item a
 * call names is named by its title, and a session by its name, as they
 * stood when the call was answered; a call with no name kept, by the held
 * session.
 */
import { itemTitle, oneLine, type Session } from '../../core'
import { toolNamed, type ToolName } from '../tools'
import type { Els } from './kit'

type Input = { readonly [key: string]: unknown }

const text = (value: unknown) => (typeof value === 'string' ? oneLine(value) : '')

/** The id a join names: a call from before the parameter was renamed names it as its `work`. */
const joinedId = (input: Input) => text(input.session ?? input.work)

/** The title of the item a call names, as the held session has it. */
const heldTitle = (session: Session, input: Input) => itemTitle(session, text(input.item))

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
  join: (_, name) => (name === undefined ? 'joined a session' : `joined: ${name}`),
  status: () => '• status set',
  ask: input => `◆ asked: ${text(input.title)}`,
  park: input => `◇ parked: ${text(input.title)}`,
  resolve: (_, name = 'an item') => `resolved: ${name}`,
  reopen: (_, name = 'an item') => `reopened: ${name}`,
  edit: (_, name = 'an item') => `edited: ${name}`,
  finish: (_, name) => (name === undefined ? '✓ finished a session' : `✓ finished: ${name}`),
  project: projectSaid,
  move: (input, name) => `moved to project: ${name ?? text(input.project)}`,
  board: () => 'read the board back',
}

/** The calls whose rows name an item or a session, and its name as the held session has it. */
const NAMING: Partial<Record<ToolName, (session: Session, input: Input) => string | undefined>> = {
  join: (session, input) => (session.id === joinedId(input) ? session.status.name : undefined),
  resolve: heldTitle,
  reopen: heldTitle,
  edit: heldTitle,
  finish: session => session.status.name,
  move: session => session.project,
}

/** Where a call's row finds the name of what it names: kept as the call was answered, else the held session. */
type Naming = {
  kept: () => Promise<string | undefined>
  held: () => Promise<Session | undefined>
}

/** The name of what a naming call names: the name kept, else the held session's, read only then. */
const nameFor = async (
  heldName: (session: Session, input: Input) => string | undefined,
  input: Input,
  naming: Naming,
) => {
  const kept = await naming.kept()

  if (kept !== undefined) {
    return kept
  }

  const session = await naming.held()

  return session === undefined ? undefined : heldName(session, input)
}

/**
 * A call's line, from its input and, where it names an item or a session, its
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
