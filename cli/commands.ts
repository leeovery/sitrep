/**
 * The CLI's commands: the words each takes, and what each makes of a
 * session or of the projects; and the board watched, which runs until it is
 * told to end. A command on a session hands back the lines it posts, and what to
 * print: a post's item id, so a script can keep it. Its lines are the CLI's
 * own, a snooze's and a wake's among them, but an answer's, which go into
 * the session's inbox as the CLI's letters, for the session's window to
 * deliver as it delivers any reply. Each is pure: the files are read before
 * it acts.
 */
import {
  boardText,
  checkAnswer,
  checkAsk,
  checkFinish,
  checkMove,
  checkMoveTo,
  checkPark,
  checkSnooze,
  checkStatus,
  checkWake,
  projectNamed,
  USER,
  WANTS,
  withId,
  withParkId,
  type Body,
  type Checked,
  type Filed,
  type Project,
  type ProjectParked,
  type ProjectSessions,
  type Random,
} from '../core'
import type { Arg, Fields, Flag, Grammar } from './args'
import { boardJson, listing, listJson, listText } from './output'

/** What a command on a session comes to: the lines it posts, and what it prints. */
export type Outcome = { post: Body[]; print: string }

/**
 * What a command on a session is given beyond its words: random bytes, the
 * version the CLI runs, as its plugin's manifest says it, where that reads,
 * the time the session was read at, and, for one that reads the board, what
 * every session of the session's project parked, and the projects on it.
 */
export type Given = {
  random: Random
  version: string | undefined
  now: number
  parked: readonly ProjectParked[]
  projects: readonly Project[]
}

type About = { name: string; about: string; grammar: Grammar }

export type SessionCommand = About & {
  on: 'session'
  /** Where its lines go: the CLI's own file in the session, unless they are an answer, for the session's inbox. */
  into?: 'inbox'
  /** Whether it reads every project too: for what every session filed under the session's project parked, and the projects a move names. */
  readsBoard?: true
  act: (filed: Filed, input: Fields, given: Given) => Checked<Outcome>
}

/** What a command on the projects is given: every one read, with its sessions, from the folder the CLI runs in, at `now`. */
export type Projects = { read: readonly ProjectSessions[]; cwd: string; now: number }

export type ProjectsCommand = About & {
  on: 'projects'
  act: (projects: Projects, input: Fields) => Checked<string>
}

/** The board watched, a line each time it changes, until the run is to end: the loop is `looks.ts`, the printing `watch.ts`. */
export type FeedCommand = About & { on: 'feed' }

export type Command = SessionCommand | ProjectsCommand | FeedCommand

/** The flag naming the session, which every command on one takes. */
export const SESSION_FLAG = 'session'

const SESSION: Record<string, Flag> = {
  [SESSION_FLAG]: {
    field: 'session',
    form: 'one',
    value: '<id>',
    about: 'the session: sr- and six characters; else $SITREP_SESSION',
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
    about: `where ${USER.name} should look, in words`,
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

/** A line that prints nothing, as it comes out. */
const quietly = (checked: Checked<Body>): Checked<Outcome> => posted(checked, () => '')

/** The asks a snooze names: those its row shows. */
const ASKS_SHOWN: Arg = {
  field: 'ask',
  about: `each ask the session's row shows, by its id, as the board lists it: an ask waiting on ${USER.name} left out refuses the snooze, so none is snoozed unseen; none for a row of its turn alone`,
  isMany: true,
}

const ask: SessionCommand = {
  name: 'ask',
  about: `Post an ask: something only ${USER.name} can do or decide. Prints its id.`,
  grammar: {
    args: [{ field: 'title', about: LINE }],
    flags: {
      wants: {
        field: 'wants',
        form: 'one',
        value: WANTS.join('|'),
        about: `what you want back from ${USER.name}: a yes, one of the options, or words`,
        isNeeded: true,
      },
      yes: {
        field: 'yes',
        form: 'one',
        value: '<label>',
        about: `a yes ask's button: the verb ${USER.name} gives, such as Go or Approve`,
      },
      option: {
        field: 'options',
        form: 'many',
        value: '<choice>',
        about: "a choice ask's option; one each, two at least",
      },
      recommended: {
        field: 'recommended',
        form: 'one',
        value: '<choice>',
        about:
          'the option you lean toward, in its words: give it whenever you lean toward one, rather than writing recommended into the option',
      },
      needs: {
        field: 'needs',
        form: 'one',
        value: '<words>',
        about: "what a words ask's words are, such as the command's output",
      },
      ...WHERE,
      ...REF,
      ...SESSION,
    },
  },
  on: 'session',
  act: ({ session }, input, { random }) => posted(withId(checkAsk(input), session, random), idOf),
}

const park: SessionCommand = {
  name: 'park',
  about: 'Park something raised and put off, to come back to. Prints its id.',
  grammar: { args: [{ field: 'title', about: LINE }], flags: { ...WHERE, ...REF, ...SESSION } },
  on: 'session',
  readsBoard: true,
  act: ({ session }, input, { random, parked }) =>
    posted(withParkId(checkPark(input), session, parked, random), idOf),
}

const status: SessionCommand = {
  name: 'status',
  about: 'Set where the session stands, giving only what changed. Prints nothing.',
  grammar: {
    args: [],
    flags: {
      name: { field: 'name', form: 'one', value: '<words>', about: 'its name, in a few words' },
      summary: { field: 'summary', form: 'one', value: '<line>', about: 'what the session is for' },
      now: {
        field: 'now',
        form: 'many',
        value: '<line>',
        about: 'what is under way, one each: the whole list; "" for nothing',
      },
      next: { field: 'next', form: 'one', value: '<line>', about: 'what comes next; "" clears it' },
      ...SESSION,
    },
  },
  on: 'session',
  act: ({ session }, input) => posted(checkStatus(input, session.status), () => ''),
}

const board: SessionCommand = {
  name: 'board',
  about:
    "Print the board: its status, open asks and the project's parked items, with their ids. With --json, the session alone: its open asks, the items it parked itself, its latest status changes and its resolved asks.",
  grammar: { args: [], flags: { ...JSON_OUT, ...SESSION } },
  on: 'session',
  readsBoard: true,
  act: ({ project, session }, input, { parked }) => ({
    ok: true,
    value: {
      post: [],
      print: input.json === true ? boardJson(project, session) : boardText(session, parked, session.isOpen),
    },
  }),
}

const answer: SessionCommand = {
  name: 'answer',
  about: `Answer a yes, a choice or a words ask, or ignore any ask, as ${USER.name} does on the board: into the session's inbox, which its window gives Claude as ${USER.possessive} own message, now or once a window takes the session up. Words keep to one line. A comment and a permission prompt need Claude Code's prompt. Prints nothing.`,
  grammar: {
    args: [
      { field: 'ask', about: "the ask's id, as the board lists it" },
      {
        field: 'answer',
        about: "a yes ask's yes, in its words, one of a choice ask's options, or a words ask's words",
        or: 'ignore',
      },
    ],
    flags: {
      ignore: {
        field: 'ignore',
        form: 'switch',
        about: `in place of an answer: ${USER.name} has seen it and won't act on it`,
      },
      ...SESSION,
    },
  },
  on: 'session',
  into: 'inbox',
  act: ({ session }, input, { random, version }) =>
    posted(withId(checkAnswer(session, input, version), session, random), () => ''),
}

export const snooze: SessionCommand = {
  name: 'snooze',
  about: `Snooze a session until a time, as ${USER.name} does from its row: everything it needs of ${USER.name}, its asks and its turn, counts nowhere until it comes, or until a new ask, ${USER.possessive} reply to one it holds, or a prompt typed in its window wakes it. Its turn ending alone does not; with no time, it holds until it moves, as its next turn ends. One line in the CLI's own file, none in the inbox. Snoozed already, it is snoozed again, to the new time. Prints nothing.`,
  grammar: {
    args: [ASKS_SHOWN],
    flags: {
      until: {
        field: 'until',
        form: 'one',
        value: '<ms>',
        about:
          'when it wakes, in milliseconds since the epoch: a time still to come; none, until it moves',
      },
      ...SESSION,
    },
  },
  on: 'session',
  act: ({ session }, input, { now }) => quietly(checkSnooze(session, input, now)),
}

export const wake: SessionCommand = {
  name: 'wake',
  about: `Wake a snoozed session now, as ${USER.name} does from its row: everything it needs of ${USER.name} counts again. One line in the CLI's own file. Prints nothing.`,
  grammar: { args: [], flags: { ...SESSION } },
  on: 'session',
  act: ({ session }) => quietly(checkWake(session)),
}

const finish: SessionCommand = {
  name: 'finish',
  about: `Finish a session no window holds, as ${USER.name} does on the board: its open asks stop counting. One a window holds is finished there, by telling Claude. Prints nothing.`,
  grammar: { args: [], flags: { ...SESSION } },
  on: 'session',
  act: ({ session }) => {
    const finished = checkFinish(session, 'lee')

    return finished.ok && session.isOpen
      ? {
          ok: false,
          error: `${session.status.name} is open in a window: tell Claude there to finish it.`,
        }
      : posted(finished, () => '')
  },
}

const move: SessionCommand = {
  name: 'move',
  about: `Move a session to another project on the board, as Claude does at ${USER.possessive} word: the whole session goes, and every window holding it follows. It makes no project. One line in the CLI's own file. Prints nothing.`,
  grammar: {
    args: [{ field: 'project', about: "the project's name, matched as start matches it" }],
    flags: { ...SESSION },
  },
  on: 'session',
  readsBoard: true,
  act: ({ project, session }, input, { projects }) => {
    const checked = checkMove(input)

    if (!checked.ok) {
      return checked
    }

    const to = projectNamed(projects, checked.value.project)

    return to === undefined
      ? { ok: false, error: `There is no project named ${checked.value.project}.` }
      : quietly(checkMoveTo(session, project, to))
  },
}

const list: ProjectsCommand = {
  name: 'list',
  about: `List every project's current sessions, with their ids and what waits on ${USER.name}: first the projects living around the folder it runs in.`,
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
  act: ({ read, cwd, now }, input) => {
    const named = typeof input.project === 'string' ? input.project : undefined
    const listed = listing(read, cwd, now, named)

    if (named !== undefined && listed.projects.length === 0) {
      return { ok: false, error: `There is no project named ${named}.` }
    }

    return {
      ok: true,
      value: input.json === true ? listJson(listed) : listText(listed.projects),
    }
  },
}

const watch: FeedCommand = {
  name: 'watch',
  about:
    'Print the board as every surface shows it, a line of JSON at the start and each time it changes, with the boards of the sessions followed, each line on standard input saying them ({"follow": ["sr-xxxxxx", ...]}), until the program that started it quits, a line finds standard output closed, or the plugin is updated: the SitRep app runs one.',
  grammar: { args: [], flags: {} },
  on: 'feed',
}

/** Every command, in the order the help lists them. */
export const COMMANDS: readonly Command[] = [
  ask,
  park,
  status,
  answer,
  snooze,
  wake,
  finish,
  move,
  board,
  list,
  watch,
]

export const commandNamed = (name: string) => COMMANDS.find(command => command.name === name)
