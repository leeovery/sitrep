/**
 * What a row shows of a tool call: the tool's name, and what it acts on,
 * taken from one field of its arguments (a file tool's path, Bash's
 * command, a search's pattern, an agent's description); and of a question
 * Claude puts to Lee, the first question and how many there are. Every
 * text is one line, cut short where it runs long: the row is one line, and
 * a heartbeat stays small whatever the command.
 */
import { isObject } from './entries'
import { oneLine } from './text'
import type { QuestionShown, ToolShown } from './types'

/** The tool that puts a question to Lee. */
export const QUESTION_TOOL = 'AskUserQuestion'

/** The most characters a subject or a question keeps, its ellipsis among them. */
export const SHOWN_LENGTH = 200

/**
 * The argument each tool's subject is, by the tool's name. Any other tool,
 * an MCP tool among them, shows by its name alone.
 */
const SUBJECTS: ReadonlyMap<string, string> = new Map([
  ['Read', 'file_path'],
  ['Edit', 'file_path'],
  ['MultiEdit', 'file_path'],
  ['Write', 'file_path'],
  ['NotebookEdit', 'notebook_path'],
  ['LSP', 'filePath'],
  ['Bash', 'command'],
  ['Monitor', 'description'],
  ['Grep', 'pattern'],
  ['Glob', 'pattern'],
  ['WebFetch', 'url'],
  ['WebSearch', 'query'],
  ['Agent', 'description'],
  ['Task', 'description'],
  ['Skill', 'skill'],
])

/** Text as one line, cut to SHOWN_LENGTH characters with an ellipsis where it was cut; empty for anything but text. */
const shown = (value: unknown) => {
  const characters = Array.from(typeof value === 'string' ? oneLine(value) : '')

  return characters.length <= SHOWN_LENGTH
    ? characters.join('')
    : `${characters.slice(0, SHOWN_LENGTH - 1).join('')}…`
}

/** A tool call as a row shows it, from the tool's name and its arguments. */
export const toolShown = (name: string, input: unknown): ToolShown => {
  const field = SUBJECTS.get(name)
  const subject = field !== undefined && isObject(input) ? shown(input[field]) : ''

  return subject === '' ? { name } : { name, subject }
}

/** The question a call of QUESTION_TOOL asks, from its arguments; undefined when its first question has no text. */
export const questionShown = (input: unknown): QuestionShown | undefined => {
  const questions: unknown[] =
    isObject(input) && Array.isArray(input.questions) ? input.questions : []
  const [first] = questions
  const text = isObject(first) ? shown(first.question) : ''

  return text === '' ? undefined : { text, count: questions.length }
}
