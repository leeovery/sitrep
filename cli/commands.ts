/**
 * The CLI's commands: the words each takes, and what each makes of a piece
 * of work or of the projects. A command on a piece of work hands back the
 * lines it posts, as the CLI's own, and what to print: a post's item id, so
 * a script can keep it.
 *
 * Answering an ask is not one of them yet (DESIGN's open question 4). It
 * would be a command on a piece of work whose reply goes into the work's
 * inbox rather than the CLI's own file, for the work's window to deliver.
 */
import {
  ASK_KINDS,
  boardText,
  checkAsk,
  checkNote,
  checkPark,
  checkStatus,
  withId,
  type Body,
  type Checked,
  type ProjectWorks,
  type Random,
  type Work,
} from '../core'
import type { Fields, Flag, Grammar } from './args'
import { boardJson, listing, listJson, listText } from './output'

/** A piece of work, and the key of the project it is filed under. */
export type Filed = { project: string; work: Work }

/** What a command on a piece of work comes to: the lines it posts, and what it prints. */
export type Outcome = { post: Body[]; print: string }

type About = { name: string; about: string; grammar: Grammar }

export type WorkCommand = About & {
  on: 'work'
  act: (filed: Filed, input: Fields, random: Random) => Checked<Outcome>
}

/** A command on the projects: every one read, with its works, from the folder the CLI runs in, at `now`. */
export type ProjectsCommand = About & {
  on: 'projects'
  act: (read: readonly ProjectWorks[], cwd: string, now: number, input: Fields) => Checked<string>
}

export type Command = WorkCommand | ProjectsCommand

/** The flag naming the piece of work, which every command on one takes. */
export const WORK_FLAG = 'work'

const WORK: Record<string, Flag> = {
  [WORK_FLAG]: {
    field: 'work',
    form: 'one',
    value: '<id>',
    about: 'the piece of work: sr- and six characters; else $SITREP_WORK',
  },
}

const REF: Record<string, Flag> = {
  ref: { field: 'ref', form: 'one', value: '<ref>', about: 'where your own record of it is' },
}

const WHERE: Record<string, Flag> = {
  where: {
    field: 'where',
    form: 'one',
    value: '<words>',
    about: 'where Lee should look, in words',
  },
}

const JSON_OUT: Record<string, Flag> = {
  json: { field: 'json', form: 'switch', about: 'print JSON, for tools' },
}

const LINE = 'one line, starting with the verb'

/** A post as it comes out: its line, and what it prints. */
const posted = <B extends Body>(
  checked: Checked<B>,
  print: (body: B) => string,
): Checked<Outcome> =>
  checked.ok ? { ok: true, value: { post: [checked.value], print: print(checked.value) } } : checked

const idOf = (body: { id: string }) => body.id

const note: WorkCommand = {
  name: 'note',
  about: "Add a line to the board's log: something Lee would want to know later. Prints its id.",
  grammar: {
    args: [{ field: 'text', about: LINE }],
    flags: {
      detail: {
        field: 'detail',
        form: 'many',
        value: '<line>',
        about: 'a line it opens to; one each',
      },
      ...REF,
      ...WORK,
    },
  },
  on: 'work',
  act: ({ work }, input, random) => posted(withId(checkNote(input), work, random), idOf),
}

const ask: WorkCommand = {
  name: 'ask',
  about: 'Post an ask: something only Lee can do or decide. Prints its id.',
  grammar: {
    args: [
      { field: 'kind', about: ASK_KINDS.join(', ') },
      { field: 'title', about: LINE },
    ],
    flags: {
      ...WHERE,
      option: {
        field: 'options',
        form: 'many',
        value: '<choice>',
        about: "a decide ask's choice; one each, two at least",
      },
      ...REF,
      ...WORK,
    },
  },
  on: 'work',
  act: ({ work }, input, random) => posted(withId(checkAsk(input), work, random), idOf),
}

const park: WorkCommand = {
  name: 'park',
  about: 'Park something raised and put off, to come back to. Prints its id.',
  grammar: { args: [{ field: 'title', about: LINE }], flags: { ...WHERE, ...REF, ...WORK } },
  on: 'work',
  act: ({ work }, input, random) => posted(withId(checkPark(input), work, random), idOf),
}

const status: WorkCommand = {
  name: 'status',
  about: 'Set where the work stands, giving only what changed. Prints nothing.',
  grammar: {
    args: [],
    flags: {
      name: { field: 'name', form: 'one', value: '<words>', about: 'its name, in a few words' },
      summary: { field: 'summary', form: 'one', value: '<line>', about: 'what the work is for' },
      now: {
        field: 'now',
        form: 'many',
        value: '<line>',
        about: 'what is under way, one each: the whole list; "" for nothing',
      },
      next: { field: 'next', form: 'one', value: '<line>', about: 'what comes next; "" clears it' },
      ...WORK,
    },
  },
  on: 'work',
  act: ({ work }, input) => posted(checkStatus(input, work.status), () => ''),
}

const board: WorkCommand = {
  name: 'board',
  about: 'Print the board: its status, open asks, parked items and latest notes, with their ids.',
  grammar: { args: [], flags: { ...JSON_OUT, ...WORK } },
  on: 'work',
  act: ({ project, work }, input) => ({
    ok: true,
    value: {
      post: [],
      print: input.json === true ? boardJson(project, work) : boardText(work),
    },
  }),
}

const list: ProjectsCommand = {
  name: 'list',
  about:
    "List every project's current pieces of work, with their ids and what waits on Lee: first the projects living around the folder it runs in.",
  grammar: {
    args: [],
    flags: {
      project: {
        field: 'project',
        form: 'one',
        value: '<name>',
        about: "only that project's, its name matched as start matches it",
      },
      ...JSON_OUT,
    },
  },
  on: 'projects',
  act: (read, cwd, now, input) => {
    const named = typeof input.project === 'string' ? input.project : undefined
    const listed = listing(read, cwd, now, named)

    if (named !== undefined && listed.projects.length === 0) {
      return { ok: false, error: `There is no project named ${named}.` }
    }

    return { ok: true, value: input.json === true ? listJson(listed) : listText(listed.projects) }
  },
}

/** Every command, in the order the help lists them. */
export const COMMANDS: readonly Command[] = [note, ask, park, status, board, list]

export const commandNamed = (name: string) => COMMANDS.find(command => command.name === name)
