/**
 * Claude's tools: start or join a piece of work, then post to its board and
 * read the board back, and name its project. Only the main conversation may
 * call them. An answer says what was done and names the item, and no more.
 *
 * The descriptions carry the board's wording rules, and load into every
 * session, so they stay short.
 */
import type { ToolSpec } from 'claude-code'
import {
  ASK_KINDS,
  boardText,
  checkAsk,
  checkEdit,
  checkFinish,
  checkJoin,
  checkNote,
  checkPark,
  checkProject,
  checkReopen,
  checkResolve,
  checkStart,
  checkStatus,
  metaText,
  newWorkId,
  projectNamed,
  reopenedText,
  withId,
  workPaths,
  type Body,
  type Checked,
  type Project,
  type Work,
} from '../core'
import type { SitrepAttachment } from '../types'
import { lookAround } from './around'
import { bearingsOf, random, type Host } from './host'
import {
  changeProject,
  filingFor,
  projectFiling,
  projectKeys,
  readProjects,
  workIdsIn,
} from './projects'
import { markSeen, postKnown } from './seen'
import { attachTo, attached, refresh, serially } from './window'

type Fields = { readonly [key: string]: unknown }

type Answer = { result: string } | { deny: string }

/** A tool's spec, its name kept literal: once a load has laid these tools' types, `tool.call`'s matcher takes only their exact names. */
type Spec<N extends string> = ToolSpec & { name: N }

type Tool<N extends string = string> = {
  spec: Spec<N>
  answer: (host: Host, input: Fields) => Promise<Answer>
}

/** How the model names this plugin's tools. */
const PREFIX = 'mcp__sitrep__'

const FOR_THE_REPORT =
  'Refused: only the main conversation writes to the sitrep board. Put this in your report instead, and the main conversation decides what reaches the board.'

const NOT_ATTACHED =
  'No piece of work is attached to this window: start one, or join one by its id, first.'

const UNREADABLE =
  "The attached piece of work's work.json is missing or torn, so its board cannot be read."

const LINE =
  'One line in plain words, starting with the verb; no internal codes such as P- or D-numbers.'

const text = (description: string) => ({ type: 'string', description })

const lines = (description: string) => ({ type: 'array', items: { type: 'string' }, description })

const NAME = text('A few words.')
const SUMMARY = text('One line: what the work is for.')
const PROJECT = text(
  "The project's name as Lee would say it, cased: SitRep, Switchboard; never a slug. A project on the board by the name it has there.",
)
const DIRECTORY = text(
  'Where the project lives, as an absolute path, once you know it: not the folder this session started in.',
)
const ITEM = text('The item’s id, as the board lists it.')
const REASON = text('Why, in a few words.')
const WHERE = text(
  'Where Lee should look, in words: In Paper: the dashboard file, page "round 1", frames 1–6.',
)
const REF = text('Where your own record of it is: a file, a section, a link.')
const KIND = {
  type: 'string',
  enum: ASK_KINDS,
  description: 'review, decide (give options), try, or do.',
}
const OPTIONS = lines('For a decide ask: the choices, one line each.')
const DETAIL = lines('Lines it opens to, one line each.')

const spec = <N extends string>(
  name: N,
  description: string,
  properties: Record<string, unknown> = {},
  required: string[] = [],
): Spec<N> => ({
  name,
  description,
  inputSchema: { type: 'object', properties, required },
  isDeferred: false,
})

/** A tool on the attached work, handed it folded as it stands, and where the window holds it. */
const onWork =
  (answer: (host: Host, work: Work, input: Fields, held: SitrepAttachment) => Promise<Answer>) =>
  async (host: Host, input: Fields): Promise<Answer> => {
    const held = attached()

    if (held === undefined) {
      return { deny: NOT_ATTACHED }
    }

    const work = await refresh(host)

    return work === undefined ? { deny: UNREADABLE } : answer(host, work, input, held)
  }

/** A tool that posts one line, checked from its input, to the attached work: a line Claude knows of. */
const posting = <N extends string, B extends Body>(
  toolSpec: Spec<N>,
  check: (work: Work, input: Fields) => Checked<B>,
  said: (body: B) => string,
): Tool<N> => ({
  spec: toolSpec,
  answer: onWork(async (host, work, input) => {
    const checked = check(work, input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    await postKnown(host, work, [checked.value])

    return { result: said(checked.value) }
  }),
})

/**
 * Attaches the window to a work, and counts its board as seen: Claude gave
 * a work it starts all it holds, and a join answers with the board. A work
 * other than the one held brings the board home to it, and the works around
 * it are read.
 */
const attachKnown = async (host: Host, root: string, attaching: SitrepAttachment) => {
  const before = attached()?.work
  const work = await attachTo(host, root, attaching)

  if (work !== undefined) {
    await markSeen(host, work)
  }

  if (attaching.work !== before) {
    await host.state.pane.update(pane => ({ ...pane, place: null, view: 'board', selected: null }))
  }

  await lookAround(host)

  return work
}

/** What a join writes to a finished work: it is taken up again. */
const UNFINISH: Body = { type: 'unfinish' }

/** A joined work reopened when it was finished, and what the join says of that. */
const reopening = async (host: Host, work: Work) => {
  if (work.finished === undefined) {
    return { work, said: '' }
  }

  const reopened = await postKnown(host, work, [UNFINISH])

  return { work: reopened ?? work, said: ` ${reopenedText(work.finished)}` }
}

const start: Tool<'start'> = {
  spec: spec(
    'start',
    'Start a piece of work on the sitrep board, where Lee sees where work stands and what waits on Lee, in the project it is on: the one being discussed, not the folder this session started in. A project on the board whose name matches, case, spaces and punctuation aside, takes it; else a new project is made. Returns the work id: record it wherever the project tracks the work (design doc, plan, memory), so a later window can join it.',
    { name: NAME, summary: SUMMARY, project: PROJECT, directory: DIRECTORY },
    ['name', 'summary', 'project'],
  ),
  answer: async (host, input) => {
    const checked = checkStart(input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    const { project: name, directory, ...work } = checked.value
    const { root, cwd, writer } = await bearingsOf(host)
    const created = await host.clock.now()
    const keys = await projectKeys(host, root)
    const filing = await filingFor(host, root, keys, { name, directory, created, by: writer })
    const { key } = filing.project
    const id = newWorkId(random, await workIdsIn(host, root, keys))
    const meta = { id, ...work, project: filing.project.name, root: cwd, created, by: writer }

    await host.fs.write(workPaths(root, key, id).meta, metaText(meta))

    await attachKnown(host, root, { project: key, work: id, writer, attachedAt: created })

    return {
      result: `Started ${meta.name} as ${id}, ${filing.said}. Record ${id} wherever the project tracks this work, so a later window can join it.`,
    }
  },
}

const join: Tool<'join'> = {
  spec: spec(
    'join',
    'Join a piece of work on the sitrep board by its id: after a /clear, or from a second window. A resumed session takes its work up again by itself. Joining a finished piece of work reopens it. Returns the board as it stands.',
    { work: text('The work id: sr- and six characters.') },
    ['work'],
  ),
  answer: async (host, input) => {
    const checked = checkJoin(input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    const { work: id } = checked.value
    const { root, writer } = await bearingsOf(host)
    const project = await projectFiling(host, root, id)

    if (project === undefined) {
      return { deny: `There is no piece of work ${id} on the board, in any project.` }
    }

    const attachedAt = await host.clock.now()
    const work = await attachKnown(host, root, { project, work: id, writer, attachedAt })

    if (work === undefined) {
      return { deny: UNREADABLE }
    }

    const joined = await reopening(host, work)

    return {
      result: `Joined ${work.status.name} (${id}).${joined.said} The board as it stands:\n${boardText(joined.work)}`,
    }
  },
}

/** What the project tool says it changed. */
const changedText = (before: Project, after: Project) =>
  [
    ...(after.name === before.name ? [] : [`Renamed the project ${before.name} to ${after.name}.`]),
    ...(after.directory === before.directory ? [] : [`${after.name} lives in ${after.directory}.`]),
  ].join(' ') || `${after.name} was already so.`

const project: Tool<'project'> = {
  spec: spec(
    'project',
    "Rename the attached piece of work's project, or say where the project lives, or both. It never moves a piece of work to another project.",
    { name: PROJECT, directory: DIRECTORY },
  ),
  answer: onWork(async (host, work, input, held) => {
    const checked = checkProject(input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    const { root, writer } = await bearingsOf(host)
    const projects = await readProjects(host, root, await projectKeys(host, root))
    const before = projects.find(each => each.key === held.project) ?? {
      key: held.project,
      name: work.project,
    }
    const { name } = checked.value
    const others = projects.filter(each => each.key !== held.project)
    const other = name === undefined ? undefined : projectNamed(others, name)

    if (other !== undefined) {
      return {
        deny: `Another project is already named ${other.name}. This renames the attached work's project; it moves no work to another.`,
      }
    }

    const writing = { created: await host.clock.now(), by: writer }
    const after = await changeProject(host, root, before, checked.value, writing)

    await refresh(host)
    await lookAround(host)

    return { result: changedText(before, after) }
  }),
}

const board: Tool<'board'> = {
  spec: spec(
    'board',
    'Read the board back: the status, open asks, parked items and latest notes, with their ids, to check against what you know and repair.',
  ),
  answer: onWork(async (host, work) => {
    await markSeen(host, work)

    return { result: boardText(work) }
  }),
}

const TOOLS = [
  start,
  join,
  posting(
    spec(
      'status',
      'Set where the work stands, giving only what changed. The board logs the change itself: do nothing extra for it.',
      {
        name: NAME,
        summary: SUMMARY,
        now: lines('One line per thing under way now, each starting with the verb.'),
        next: text('What comes next, in one line; "" clears it.'),
      },
    ),
    (work, input) => checkStatus(input, work.status),
    () => 'Status set.',
  ),
  posting(
    spec(
      'ask',
      "Post an ask: something only Lee can do or decide. Ask only when you cannot go on without Lee, or Lee's judgement changes what happens next; say it in the chat as well. Lee's answer arrives as a message from the board: a yes, a choice or an answer closes the ask by itself; a comment leaves it open for you to act on, then resolve. If Lee answers in the chat instead, resolve the ask yourself, saying so in the reason.",
      { kind: KIND, title: text(LINE), where: WHERE, options: OPTIONS, ref: REF },
      ['kind', 'title'],
    ),
    (work, input) => withId(checkAsk(input), work, random),
    ({ id }) => `Posted ask ${id}.`,
  ),
  posting(
    spec(
      'note',
      "Add a line to the board's log: something Lee would want to know later, not running commentary.",
      { text: text(LINE), detail: DETAIL, ref: REF },
      ['text'],
    ),
    (work, input) => withId(checkNote(input), work, random),
    ({ id }) => `Logged note ${id}.`,
  ),
  posting(
    spec(
      'park',
      'Park something raised and put off, to come back to.',
      { title: text(LINE), where: WHERE, ref: REF },
      ['title'],
    ),
    (work, input) => withId(checkPark(input), work, random),
    ({ id }) => `Parked ${id}.`,
  ),
  posting(
    spec(
      'resolve',
      'Close an item on the board, an ask, a note or a parked item, by its id.',
      { item: ITEM, reason: REASON },
      ['item'],
    ),
    checkResolve,
    ({ item }) => `Resolved ${item}.`,
  ),
  posting(
    spec('reopen', 'Reopen a closed item by its id.', { item: ITEM, reason: REASON }, ['item']),
    checkReopen,
    ({ item }) => `Reopened ${item}.`,
  ),
  posting(
    spec(
      'edit',
      'Correct an item by its id, giving only the fields to change.',
      {
        item: ITEM,
        kind: KIND,
        title: text(LINE),
        where: WHERE,
        options: OPTIONS,
        ref: REF,
        text: text(LINE),
        detail: DETAIL,
        reason: REASON,
      },
      ['item'],
    ),
    checkEdit,
    ({ item }) => `Edited ${item}.`,
  ),
  posting(
    spec(
      'finish',
      "Mark the attached piece of work done, when it is complete and nothing is left on it. It leaves the board's views, and its open asks stop counting.",
      { reason: REASON },
    ),
    (work, input) => checkFinish(work, 'claude', input),
    () => 'Marked done. This window stays attached; joining the work again reopens it.',
  ),
  project,
  board,
] as const

const nameOf = <N extends string>(tool: Tool<N>): `${typeof PREFIX}${N}` =>
  `${PREFIX}${tool.spec.name}`

const BY_NAME = new Map<string, Tool>(TOOLS.map(tool => [nameOf(tool), tool]))

/** Every tool, as the model calls it. */
export const TOOL_NAMES = TOOLS.map(nameOf)

/** A tool's own name, as its spec gives it. */
export type ToolName = (typeof TOOLS)[number]['spec']['name']

/** The tool a call names, by its own name; undefined for any other tool. */
export const toolNamed = (tool: string) => TOOLS.find(each => nameOf(each) === tool)?.spec.name

export const SPECS = TOOLS.map(tool => tool.spec)

/** Answers a call of one of the tools; a subagent's is refused. */
export const answerCall = async (
  host: Host,
  call: Fields & { tool: string; agentId?: string },
): Promise<Answer> => {
  if (call.agentId !== undefined) {
    return { deny: FOR_THE_REPORT }
  }

  const tool = BY_NAME.get(call.tool)

  return tool === undefined
    ? { deny: `sitrep has no tool ${call.tool}.` }
    : serially(() => tool.answer(host, call))
}
