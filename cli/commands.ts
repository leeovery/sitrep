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
  checkNote,
  checkPark,
  checkSnooze,
  checkSnoozeTurn,
  checkStatus,
  checkWake,
  checkWakeTurn,
  WANTS,
  withId,
  type Body,
  type Checked,
  type ProjectParked,
  type ProjectSessions,
  type Random,
  type Session,
} from '../core'
import type { Arg, Fields, Flag, Grammar } from './args'
import { boardJson, listing, listJson, listText } from './output'

/** A session, and the key of the project it is filed under. */
export type Filed = { project: string; session: Session }

/** What a command on a session comes to: the lines it posts, and what it prints. */
export type Outcome = { post: Body[]; print: string }

/**
 * What a command on a session is given beyond its words: random bytes, the
 * version the CLI runs, as its plugin's manifest says it, where that reads,
 * the time the session was read at, and, for one that reads its project,
 * what every session of the project parked.
 */
export type Given = {
  random: Random
  version: string | undefined
  now: number
  parked: readonly ProjectParked[]
}

type About = { name: string; about: string; grammar: Grammar }

export type SessionCommand = About & {
  on: 'session'
  /** Where its lines go: the CLI's own file in the session, unless they are an answer, for the session's inbox. */
  into?: 'inbox'
  /** Whether it reads every session of the session's project too, for what they parked. */
  readsProject?: true
  act: (filed: Filed, input: Fields, given: Given) => Checked<Outcome>
}

/** What a command on the projects is given: every one read, with its sessions, from the folder the CLI runs in, at `now`. */
export type Projects = { read: readonly ProjectSessions[]; cwd: string; now: number }

export type ProjectsCommand = About & {
  on: 'projects'
  act: (projects: Projects, input: Fields) => Checked<string>
}

/** The board watched, a line each time it changes, until the run is to end: the loop is `watch.ts`. */
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

/** Lines that print nothing, as they come out. */
const quietly = (checked: Checked<Body[]>): Checked<Outcome> =>
  checked.ok ? { ok: true, value: { post: checked.value, print: '' } } : checked

/** The asks a snooze or a wake names, or in their place the session's turn. */
const ASKS_OR_TURN: Arg = {
  field: 'ask',
  about: "each ask's id, as the board lists it",
  or: 'turn',
  isMany: true,
}

/** In place of asks, the session's turn, which a snooze or a wake names by its end. */
const TURN: Record<string, Flag> = {
  turn: {
    field: 'turn',
    form: 'one',
    value: '<ms>',
    about: "in place of asks, the session's turn, by its end in milliseconds since the epoch, as watch gives its row's since",
  },
}

/** Whether the words name the session's turn, not asks. */
const isTurn = (input: Fields) => input.turn !== undefined

/** The one line a check came to, as a command's lines come out. */
const alone = <B extends Body>(checked: Checked<B>): Checked<Body[]> =>
  checked.ok ? { ok: true, value: [checked.value] } : checked

const note: SessionCommand = {
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
      ...SESSION,
    },
  },
  on: 'session',
  act: ({ session }, input, { random }) => posted(withId(checkNote(input), session, random), idOf),
}

const ask: SessionCommand = {
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
  act: ({ session }, input, { random }) => posted(withId(checkPark(input), session, random), idOf),
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
    "Print the board: its status, open asks, the project's parked items and latest notes, with their ids.",
  grammar: { args: [], flags: { ...JSON_OUT, ...SESSION } },
  on: 'session',
  readsProject: true,
  act: ({ project, session }, input, { parked }) => ({
    ok: true,
    value: {
      post: [],
      print: input.json === true ? boardJson(project, session) : boardText(session, parked),
    },
  }),
}

const answer: SessionCommand = {
  name: 'answer',
  about:
    "Answer a yes or a choice ask, or ignore any ask, as Lee does on the board: into the session's inbox, which its window gives Claude as Lee's own message, now or once a window takes the session up. Words, a comment and a permission prompt need Claude Code's prompt. Prints nothing.",
  grammar: {
    args: [
      { field: 'ask', about: "the ask's id, as the board lists it" },
      {
        field: 'answer',
        about: "a yes ask's yes, in its words, or one of a choice ask's options",
        or: 'ignore',
      },
    ],
    flags: {
      ignore: {
        field: 'ignore',
        form: 'switch',
        about: "in place of an answer: Lee has seen it and won't act on it",
      },
      ...SESSION,
    },
  },
  on: 'session',
  into: 'inbox',
  act: ({ session }, input, { random, version }) =>
    posted(withId(checkAnswer(session, input, version), session, random), () => ''),
}

const snooze: SessionCommand = {
  name: 'snooze',
  about:
    "Snooze asks until a time, as Lee does on the board: they count nowhere as waiting on Lee until it comes, then wait on Lee again. A line for each in the CLI's own file, none in the inbox; every ask named is snoozed, or none is. One snoozed already is snoozed again, to the new time. With --turn, the session's turn waiting on Lee's message, in place of asks: it leaves Your turn for Snoozed until the time, or with none until the session takes another turn, and Claude is never told. Prints nothing.",
  grammar: {
    args: [ASKS_OR_TURN],
    flags: {
      until: {
        field: 'until',
        form: 'one',
        value: '<ms>',
        about:
          'when they wake, in milliseconds since the epoch: a time still to come; asks need one, and a turn with none waits until it moves',
      },
      ...TURN,
      ...SESSION,
    },
  },
  on: 'session',
  act: ({ session }, input, { now }) =>
    quietly(
      isTurn(input)
        ? alone(checkSnoozeTurn(session, input, now))
        : checkSnooze(session, input, now),
    ),
}

const wake: SessionCommand = {
  name: 'wake',
  about:
    "Wake snoozed asks now, as Lee does on the board: they wait on Lee again. A line for each in the CLI's own file; every ask named is woken, or none is. With --turn, the session's turn Lee snoozed, in place of asks: it is back in Your turn. Prints nothing.",
  grammar: { args: [ASKS_OR_TURN], flags: { ...TURN, ...SESSION } },
  on: 'session',
  act: ({ session }, input) =>
    quietly(isTurn(input) ? alone(checkWakeTurn(session, input)) : checkWake(session, input)),
}

const finish: SessionCommand = {
  name: 'finish',
  about:
    'Finish a session no window holds, as Lee does on the board: its open asks stop counting. One a window holds is finished there, by telling Claude. Prints nothing.',
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

const list: ProjectsCommand = {
  name: 'list',
  about:
    "List every project's current sessions, with their ids and what waits on Lee: first the projects living around the folder it runs in.",
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
  note,
  ask,
  park,
  status,
  answer,
  snooze,
  wake,
  finish,
  board,
  list,
  watch,
]

export const commandNamed = (name: string) => COMMANDS.find(command => command.name === name)
