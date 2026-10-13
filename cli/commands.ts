/**
 * The CLI's commands: the words each takes, and what each makes of a piece
 * of work, of the projects, or of a jump to a work's window. A command on a
 * piece of work hands back the lines it posts, as the CLI's own, and what to
 * print: a post's item id, so a script can keep it. Each is pure: what it
 * needs of the screen is looked at, and the jump made, before it acts.
 *
 * Answering an ask is not one of them yet (DESIGN's open question 4). It
 * would be a command on a piece of work whose reply goes into the work's
 * inbox rather than the CLI's own file, for the work's window to deliver.
 */
import {
  boardText,
  checkAsk,
  checkNote,
  checkPark,
  checkStatus,
  WANTS,
  withId,
  type Body,
  type Checked,
  type ProjectWorks,
  type Random,
  type Work,
} from '../core'
import type { Fields, Flag, Grammar } from './args'
import type { Jumped } from './jump'
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

/** What a command on the projects is given: every one read, with its works, from the folder the CLI runs in, at `now`, and the ids of the works on screen. */
export type Projects = {
  read: readonly ProjectWorks[]
  cwd: string
  now: number
  onScreen: ReadonlySet<string>
}

export type ProjectsCommand = About & {
  on: 'projects'
  /** Whether it tells which works are on screen: only then is tmux asked, and `onScreen` filled. */
  looks: (input: Fields) => boolean
  act: (projects: Projects, input: Fields) => Checked<string>
}

/** A command on a piece of work's window: what the jump to it came to, in words. */
export type WindowCommand = About & {
  on: 'window'
  act: (filed: Filed, jumped: Jumped) => Checked<string>
}

export type Command = WorkCommand | ProjectsCommand | WindowCommand

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
    args: [{ field: 'title', about: LINE }],
    flags: {
      wants: {
        field: 'wants',
        form: 'one',
        value: WANTS.join('|'),
        about: 'what you want back from Lee: a yes, one of the options, or words',
        isNeeded: true,
      },
      yes: {
        field: 'yes',
        form: 'one',
        value: '<label>',
        about: "a yes ask's button: the verb Lee gives, such as Go or Approve",
      },
      option: {
        field: 'options',
        form: 'many',
        value: '<choice>',
        about: "a choice ask's option; one each, two at least",
      },
      needs: {
        field: 'needs',
        form: 'one',
        value: '<words>',
        about: "what a words ask's words are, such as the command's output",
      },
      ...WHERE,
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
  looks: input => input.json === true,
  act: ({ read, cwd, now, onScreen }, input) => {
    const named = typeof input.project === 'string' ? input.project : undefined
    const listed = listing(read, cwd, now, named)

    if (named !== undefined && listed.projects.length === 0) {
      return { ok: false, error: `There is no project named ${named}.` }
    }

    return {
      ok: true,
      value: input.json === true ? listJson(listed, onScreen) : listText(listed.projects),
    }
  },
}

/** Things in plain words: `a`, `a and b`, `a, b and c`. */
const inWords = (things: readonly string[]) =>
  things.length < 2 ? things.join('') : `${things.slice(0, -1).join(', ')} and ${things.at(-1)}`

/** Why a jump brought no window forward, in words, the work named. */
const unjumped = (name: string, jumped: Exclude<Jumped, { is: 'focused' }>) => {
  switch (jumped.is) {
    case 'off screen':
      return `${name} is not on screen: no Ghostty window shows it.`
    case 'unknown':
      return `Could not tell whether ${name} is on screen: ${inWords(jumped.unanswered)} gave no answer.`
    case 'unanswered':
      return `${name} shows on ${inWords(jumped.devices)}, but no Ghostty window there answered.`
  }
}

const jump: WindowCommand = {
  name: 'jump',
  about:
    'Bring the Ghostty window showing the piece of work to the front, on whatever Space it is. Prints nothing.',
  grammar: { args: [], flags: { ...WORK } },
  on: 'window',
  act: ({ work }, jumped) =>
    jumped.is === 'focused'
      ? { ok: true, value: '' }
      : { ok: false, error: unjumped(work.status.name, jumped) },
}

/** Every command, in the order the help lists them. */
export const COMMANDS: readonly Command[] = [note, ask, park, status, board, list, jump]

export const commandNamed = (name: string) => COMMANDS.find(command => command.name === name)
