/**
 * The CLI's commands: the words each takes, and what each makes of a
 * session, of the projects, or of a jump to a session's window; and the
 * board watched, which runs until it is told to end. A command on a session
 * hands back the lines it posts, and what to print: a post's item id, so a
 * script can keep it. Its lines are the CLI's own, but an answer's, which
 * go into the session's inbox as the CLI's letters, for the session's
 * window to deliver as it delivers any reply. Each is pure: what it needs
 * of the screen is looked at, and the jump made, before it acts.
 */
import {
  boardText,
  checkAnswer,
  checkAsk,
  checkFinish,
  checkNote,
  checkPark,
  checkStatus,
  inWords,
  WANTS,
  withId,
  type Body,
  type Checked,
  type ProjectSessions,
  type Random,
  type Session,
} from '../core'
import type { Fields, Flag, Grammar } from './args'
import type { Jumped } from './jump'
import { boardJson, listing, listJson, listText } from './output'

/** A session, and the key of the project it is filed under. */
export type Filed = { project: string; session: Session }

/** What a command on a session comes to: the lines it posts, and what it prints. */
export type Outcome = { post: Body[]; print: string }

type About = { name: string; about: string; grammar: Grammar }

export type SessionCommand = About & {
  on: 'session'
  /** Where its lines go: the CLI's own file in the session, unless they are an answer, for the session's inbox. */
  into?: 'inbox'
  act: (filed: Filed, input: Fields, random: Random) => Checked<Outcome>
}

/** What a command on the projects is given: every one read, with its sessions, from the folder the CLI runs in, at `now`, and the ids of the sessions on screen. */
export type Projects = {
  read: readonly ProjectSessions[]
  cwd: string
  now: number
  onScreen: ReadonlySet<string>
}

export type ProjectsCommand = About & {
  on: 'projects'
  /** Whether it tells which sessions are on screen: only then is tmux asked, and `onScreen` filled. */
  looks: (input: Fields) => boolean
  act: (projects: Projects, input: Fields) => Checked<string>
}

/** A command on a session's window: what the jump to it came to, in words. */
export type WindowCommand = About & {
  on: 'window'
  act: (filed: Filed, jumped: Jumped) => Checked<string>
}

/** The board watched, a line each time it changes, until the run is to end: the loop is `watch.ts`. */
export type FeedCommand = About & { on: 'feed' }

export type Command = SessionCommand | ProjectsCommand | WindowCommand | FeedCommand

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
  act: ({ session }, input, random) => posted(withId(checkNote(input), session, random), idOf),
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
  act: ({ session }, input, random) => posted(withId(checkAsk(input), session, random), idOf),
}

const park: SessionCommand = {
  name: 'park',
  about: 'Park something raised and put off, to come back to. Prints its id.',
  grammar: { args: [{ field: 'title', about: LINE }], flags: { ...WHERE, ...REF, ...SESSION } },
  on: 'session',
  act: ({ session }, input, random) => posted(withId(checkPark(input), session, random), idOf),
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
  about: 'Print the board: its status, open asks, parked items and latest notes, with their ids.',
  grammar: { args: [], flags: { ...JSON_OUT, ...SESSION } },
  on: 'session',
  act: ({ project, session }, input) => ({
    ok: true,
    value: {
      post: [],
      print: input.json === true ? boardJson(project, session) : boardText(session),
    },
  }),
}

const answer: SessionCommand = {
  name: 'answer',
  about:
    "Answer a yes or a choice ask, as Lee does on the board: into the session's inbox, which its window gives Claude as Lee's own message, now or once a window takes the session up. A words ask, a comment and a permission prompt need Claude Code's prompt. Prints nothing.",
  grammar: {
    args: [
      { field: 'ask', about: "the ask's id, as the board lists it" },
      { field: 'answer', about: "a yes ask's yes, in its words, or one of a choice ask's options" },
    ],
    flags: { ...SESSION },
  },
  on: 'session',
  into: 'inbox',
  act: ({ session }, input, random) =>
    posted(withId(checkAnswer(session, input), session, random), () => ''),
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

/** Why tmux did not select a pane's window, in words: in tmux's, where it said any. */
const whyUnselected = (said: string | undefined) => {
  if (said === undefined) {
    return 'tmux gave no answer when asked to select it.'
  }

  return said === '' ? 'tmux would not select it.' : `tmux would not select it: ${said}`
}

/** Why a jump brought no window forward, in words, the session named. */
const unjumped = (name: string, jumped: Exclude<Jumped, { is: 'focused' }>) => {
  switch (jumped.is) {
    case 'off screen':
      return `${name} is not on screen: no terminal window on this Mac shows it.`
    case 'unknown':
      return `Could not tell whether ${name} is on screen: ${inWords(jumped.unanswered)} gave no answer.`
    case 'unanswered':
      return jumped.devices.length === 0
        ? `${name} shows in ${inWords(jumped.apps)}, which did not come forward.`
        : `${name} shows on ${inWords(jumped.devices)}, but no ${inWords(jumped.apps, 'or')} window there answered.`
    case 'unselected':
      return `${name} is in a tmux window no terminal shows, and ${whyUnselected(jumped.said)}`
  }
}

const jump: WindowCommand = {
  name: 'jump',
  about:
    'Bring the terminal window showing the session to the front, on whatever Space it is. Prints nothing.',
  grammar: { args: [], flags: { ...SESSION } },
  on: 'window',
  act: ({ session }, jumped) =>
    jumped.is === 'focused'
      ? { ok: true, value: '' }
      : { ok: false, error: unjumped(session.status.name, jumped) },
}

const watch: FeedCommand = {
  name: 'watch',
  about:
    'Print the board as every surface shows it, a line of JSON at the start and each time it changes, until the program that started it quits, a line finds standard output closed, or the plugin is updated: the SitRep app runs one.',
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
  finish,
  board,
  list,
  jump,
  watch,
]

export const commandNamed = (name: string) => COMMANDS.find(command => command.name === name)
