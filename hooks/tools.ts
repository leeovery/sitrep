/**
 * Claude's tools: start or join a session, then post to its board and read
 * the board back, name its project, and move it to another at Lee's word.
 * Only the main conversation may call them. An answer says what was done
 * and names the item, and no more, but for an ask's, which says when to put
 * it to Lee. What another session of the project parked is the project's:
 * resolve, reopen and edit act on it, named with that session's id, written
 * into that session in this window's own file there.
 *
 * The descriptions carry the board's wording rules, and load into every
 * conversation, so they stay short.
 */
import type { ToolSpec } from 'claude-code'
import {
  checkAsk,
  checkEdit,
  checkFinish,
  checkJoin,
  checkMove,
  checkMoveTo,
  checkPark,
  checkParkedIn,
  checkProject,
  checkReopen,
  checkResolve,
  checkStart,
  checkStatus,
  closedByLee,
  droppedRecommendation,
  folderKey,
  handsBack,
  itemTitle,
  metaText,
  newSessionId,
  projectNamed,
  reopenedText,
  withId,
  withParkId,
  WANTS,
  sessionPaths,
  type Body,
  type Checked,
  type EditBody,
  type Filed,
  type Project,
  type ProjectKey,
  type Session,
  USER,
} from '../core'
import type { SitrepAttachment } from '../types'
import { filedNow, foldAt, lookAround } from './around'
import { BUSY, byDeadline, progressOf, type Answered, type Budget, type Progress } from './deadline'
import { folderHolding } from './folders'
import { bearingsOf, random, rootFor, type Host } from './host'
import { writeInto, type Into } from './into'
import {
  changeProject,
  fileUnder,
  onBoard,
  projectFor,
  sessionIdsIn,
  type Destination,
} from './projects'
import { changedKnown, markSeen, markStarted, parkedAround, postKnown } from './seen'
import { attachTo, attached, heldProject, refresh, serially } from './window'

type Fields = { readonly [key: string]: unknown }

/** A tool's answer, and the name the call's row gives what it named, where it names one. */
type Answer = { result: string; names?: string } | { deny: string }

/** A tool's spec, its name kept literal, so what draws each tool's row is held to cover every one (draw/tool-row.tsx). */
type Spec<N extends string> = ToolSpec & { name: N }

type Tool<N extends string = string> = {
  spec: Spec<N>
  answer: (host: Host, input: Fields, progress: Progress) => Promise<Answer>
}

/** How the model names this plugin's tools. */
const PREFIX = 'mcp__sitrep__'

const FOR_THE_REPORT =
  'Refused: only the main conversation writes to the sitrep board. Put this in your report instead, and the main conversation decides what reaches the board.'

const NOT_ATTACHED =
  'No session is attached to this window: start one, or join one by its id, first.'

const UNREADABLE =
  "The attached session's session.json is missing or torn, so its board cannot be read."

const LINE =
  'One line in plain words, starting with the verb; no internal codes such as P- or D-numbers.'

const text = (description: string) => ({ type: 'string', description })

const lines = (description: string) => ({ type: 'array', items: { type: 'string' }, description })

const NAME = text('A few words.')
const SUMMARY = text('One line: what the session is for.')
const PROJECT = text(
  `The project's name as ${USER.name} would say it, cased: SitRep, Switchboard; never a slug. A project on the board by the name it has there.`,
)
const DIRECTORY = text(
  'Where the project lives, as an absolute path, once you know it: not the folder this window started in.',
)
const ITEM = text('The item’s id, as the board lists it.')
const PARKED_BY = text(
  'Only for an item another session of this project parked: that session’s id, as the board lists it with the item.',
)
const REASON = text('Why, in a few words.')
const WHERE = text(
  `Where ${USER.name} should look, in words: In Paper: the dashboard file, page "round 1", frames 1–6.`,
)
const REF = text('Where your own record of it is: a file, a section, a link.')
const WANTS_BACK = {
  type: 'string',
  enum: WANTS,
  description: `What you want back from ${USER.name}: yes, for a go, an approval, it works or done (give yes); choice, for one of options (give options); words, for an answer, a command output or feedback (needs may say what).`,
}
const YES = text(
  `For wants yes: the button's words, the verb ${USER.name} is giving, a word or two: Go, Approve, It works, Done, Ship it.`,
)
const OPTIONS = lines(
  'For wants choice: the choices, one line each; two at least. Never write "recommended" into one: give it as recommended.',
)
const RECOMMENDED = text(
  `For wants choice: the option you lean toward, in its words as in options. Give it whenever you lean toward one; ${USER.name} sees it marked beside that option.`,
)
const NEEDS = text(
  "For wants words: what the words are, in a few words, such as the command's output.",
)

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

/** Where the window holds its session: its attachment, and the key of the project the session is filed under. */
type Holding = { held: SitrepAttachment; here: ProjectKey }

/**
 * The held session folded afresh, taking in a move made elsewhere, and
 * where the window holds it as that fold files it; why not, with none held,
 * or with its session.json missing or torn.
 */
const holdNow = async (
  host: Host,
): Promise<{ deny: string } | { session: Session; holding: Holding }> => {
  const session = await refresh(host)
  const held = attached()
  const here = heldProject()

  if (held === undefined) {
    return { deny: NOT_ATTACHED }
  }

  return session === undefined || here === undefined
    ? { deny: UNREADABLE }
    : { session, holding: { held, here } }
}

/** A tool on the attached session, handed it folded as it stands, and where the window holds it as that fold files it. */
const onSession =
  (answer: (host: Host, session: Session, input: Fields, holding: Holding) => Promise<Answer>) =>
  async (host: Host, input: Fields): Promise<Answer> => {
    const now = await holdNow(host)

    return 'deny' in now ? now : answer(host, now.session, input, now.holding)
  }

/** A post's answer once decided, kept before anything is written, so its deadline can give it; a post dropped meanwhile answers as its deadline did. */
const decided = (progress: Progress, answer: Answer): Answer =>
  progress.knows(answer) ? answer : { deny: BUSY }

/**
 * A tool that posts one line, checked from its input, to the attached
 * session: a line Claude knows of. `names` names what the line is about, in
 * the session as it stands after it. Until its answer is decided its
 * deadline may drop it, the fold its check reads included; whatever it
 * decides, the line's answer or one with nothing to write, is kept before
 * anything is written.
 */
const posting = <N extends string, B extends Body>(
  toolSpec: Spec<N>,
  check: (session: Session, input: Fields, host: Host) => Checked<B> | Promise<Checked<B>>,
  said: Said<B>,
  names: (session: Session, body: B) => string | undefined = () => undefined,
  unchanged: Unchanged = () => undefined,
): Tool<N> => ({
  spec: toolSpec,
  answer: async (host, input, progress) => {
    progress.posts()

    const now = await holdNow(host)

    if ('deny' in now) {
      return decided(progress, now)
    }

    const { session } = now
    // Read with the check, from the one read the post appends after: nothing re-reads in between.
    const quiet = unchanged(session, input)

    if (quiet !== undefined) {
      return decided(progress, quiet)
    }

    const checked = await check(session, input, host)

    if (!checked.ok) {
      return decided(progress, { deny: checked.error })
    }

    const answer = decided(progress, { result: said(checked.value, session) })

    if ('deny' in answer) {
      return answer
    }

    const after = await postKnown(host, session, [checked.value])

    return { ...answer, names: after === undefined ? undefined : names(after, checked.value) }
  },
})

/** What a tool's answer says it did, given the line it wrote and the session as it stood before, where that was read. */
type Said<B extends Body> = (body: B, before: Session | undefined) => string

/** The answer to a call that would change nothing, so posts nothing; undefined where it posts as checked. */
type Unchanged = (session: Session, input: Fields) => Answer | undefined

/** The title of the item a line is about, as a session has it. */
const itemNamed = (session: Session, { item }: { item: string }) => itemTitle(session, item)

/** A check of a line about an item, against the session it names as that stands. */
type ItemCheck<B extends Body> = (session: Session, input: Fields) => Checked<B>

/** A call on an item as decided on its session as it stands: the line to write, or why it is refused; or, where `unchanged` answers it, that answer, with nothing to write. */
type Decided<B> = Checked<B> | { unchanged: Answer }

const decide = <B extends Body>(
  session: Session,
  input: Fields,
  check: ItemCheck<B>,
  unchanged: Unchanged,
): Decided<B> => {
  const quiet = unchanged(session, input)

  return quiet === undefined ? check(session, input) : { unchanged: quiet }
}

/** Whether a call was decided as a line to write. */
const isWritten = <B>(decided: Decided<B>): decided is { ok: true; value: B } =>
  'ok' in decided && decided.ok

/** Writes into this window's own file in a session the line `decided` makes of it as it stands, read with the write; what was decided. */
const writeDecided = async <B extends Body>(
  host: Host,
  into: Into,
  decided: (session: Session) => Decided<B>,
): Promise<Decided<B>> => {
  let outcome: Decided<B> = {
    ok: false,
    error: `${into.session}'s session.json is missing or torn.`,
  }

  await writeInto(host, into, session => {
    outcome = decided(session)

    return isWritten(outcome) ? [outcome.value] : []
  })

  return outcome
}

/** Where this window writes into the session `input.session` names, by the folder its files are in, while it is another of the project the attached session is filed under; else why it does not. */
const otherOfProject = async (
  host: Host,
  input: Fields,
  { held, here }: Holding,
): Promise<Checked<Into>> => {
  const named = checkJoin(input)

  if (!named.ok) {
    return named
  }

  const { session } = named.value
  const root = await rootFor(host)
  const folder = await folderHolding(host, root, session)
  const at = folder === undefined ? undefined : { project: folder, session }
  const filed =
    at === undefined ? undefined : await filedNow(host, root, at, await host.clock.now())

  if (at === undefined || filed === undefined) {
    return { ok: false, error: `There is no session ${session} on the board, in any project.` }
  }

  return filed.project === here
    ? { ok: true, value: { ...at, writer: held.writer } }
    : {
        ok: false,
        error: `${session} is a session of another project: only what a session of this one's project parked is yours to act on.`,
      }
}

/**
 * Writes a line about a parked item of another session into that session,
 * as `check` makes it of the session as it stands, unless `unchanged`
 * answers it there: only about what it parked, which is the project's. The
 * sessions around are read again after a line, so the board text lists the
 * item as it now stands.
 */
const writeParked = async <B extends Body>(
  host: Host,
  into: Into,
  input: Fields,
  check: ItemCheck<B>,
  unchanged: Unchanged,
) => {
  const written = await writeDecided(host, into, session => {
    const parked = checkParkedIn(session, input)

    return parked.ok ? decide(session, input, check, unchanged) : parked
  })

  if (isWritten(written)) {
    await lookAround(host, [into.session])
  }

  return written
}

/**
 * A line about a parked item another session of the attached session's
 * project parked, written into that session, in this window's own file
 * there: a change Claude knows of, unless `unchanged` answers it with
 * nothing to write. Another session's ask is refused, as is a session of
 * another project.
 */
const parkedElsewhere = async <B extends Body & { item: string }>(
  host: Host,
  input: Fields,
  check: ItemCheck<B>,
  said: Said<B>,
  unchanged: Unchanged,
): Promise<Answer> => {
  const now = await holdNow(host)

  if ('deny' in now) {
    return now
  }

  const into = await otherOfProject(host, input, now.holding)

  if (!into.ok) {
    return { deny: into.error }
  }

  const root = await rootFor(host)
  const before = await foldAt(host, root, into.value, await host.clock.now())
  const written = await writeParked(host, into.value, input, check, unchanged)

  if ('unchanged' in written) {
    return written.unchanged
  }

  if (!written.ok) {
    return { deny: written.error }
  }

  // In the tool's own turn of the window's queue, after the look that read the change in.
  if (before !== undefined) {
    await changedKnown(host, [{ before, items: [written.value.item] }])
  }

  const after = await foldAt(host, root, into.value, await host.clock.now())

  return {
    result: said(written.value, before),
    names: after === undefined ? undefined : itemNamed(after, written.value),
  }
}

/**
 * A tool on an item by its id: one of the attached session's, posted to it;
 * or, given another session of its project (`session`), a parked item that
 * session parked (`parkedElsewhere`). Either way `unchanged` may answer it
 * with nothing to write.
 */
const onItem = <N extends string, B extends Body & { item: string }>(
  toolSpec: Spec<N>,
  check: ItemCheck<B>,
  said: Said<B>,
  unchanged: Unchanged = () => undefined,
): Tool<N> => {
  const here = posting(toolSpec, check, said, itemNamed, unchanged)

  return {
    spec: toolSpec,
    answer: (host, input, progress) =>
      input.session === undefined || input.session === attached()?.session
        ? here.answer(host, input, progress)
        : parkedElsewhere(host, input, check, said, unchanged),
  }
}

/** What an edit says it did: where it left an ask without the option it recommended, that it recommends none now; and where it handed an ask back, that it waits on Lee again. */
const editedText = (body: EditBody, before: Session | undefined) => {
  const dropped = before === undefined ? undefined : droppedRecommendation(before, body)
  const said = [
    `Edited ${body.item}.`,
    dropped === undefined
      ? undefined
      : `Its recommended option “${dropped}” is gone, so it recommends none now.`,
    before !== undefined && handsBack(before, body)
      ? `It waits on ${USER.name} again: put it to ${USER.name} in full after your last tool call.`
      : undefined,
  ]

  return said.filter(each => each !== undefined).join(' ')
}

/** A resolve of an item Lee closed already, an ask he answered or ignored, a parked item he picked up or dropped: nothing to write, and nothing refused. */
const resolvedByLee: Unchanged = (session, input) => {
  const item = closedByLee(session, input)
  const how = item?.closedBy === 'drop' ? 'dropped' : 'closed'

  return item === undefined
    ? undefined
    : {
        result: `${item.id} was ${how} already by ${USER.name}: nothing to resolve.`,
        names: itemTitle(session, item.id),
      }
}

/**
 * Attaches the window to a session: one other than the one held brings the
 * board home to it, and the sessions around it are read. What Claude has
 * seen of its board its caller keeps: all a session it starts holds, or the
 * board a join answers with.
 */
const attachHere = async (host: Host, root: string, attaching: SitrepAttachment) => {
  const before = attached()?.session
  const session = await attachTo(host, root, attaching)

  if (attaching.session !== before) {
    await host.state.pane.update(pane => ({ ...pane, place: null, selected: null }))
  }

  await lookAround(host)

  return session
}

/** What a join writes to a finished session: it is taken up again. */
const UNFINISH: Body = { type: 'unfinish' }

/** A joined session reopened when it was finished, and what the join says of that. */
const reopening = async (host: Host, session: Session) => {
  if (session.finished === undefined) {
    return { session, said: '' }
  }

  const reopened = await postKnown(host, session, [UNFINISH])

  return { session: reopened ?? session, said: ` ${reopenedText(session.finished)}` }
}

const start: Tool<'start'> = {
  spec: spec(
    'start',
    `Start a session on the sitrep board, where ${USER.name} sees where each session stands and what is waiting, in the project it is on: the one being discussed, not the folder this window started in. A project on the board whose name matches, case, spaces and punctuation aside, takes it; else a new project is made. Returns the session id: record it wherever the project tracks the work (design doc, plan, memory), so a later window can join it.`,
    { name: NAME, summary: SUMMARY, project: PROJECT, directory: DIRECTORY },
    ['name', 'summary', 'project'],
  ),
  answer: async (host, input) => {
    const checked = checkStart(input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    const { project: name, directory, ...session } = checked.value
    const { root, cwd, writer } = await bearingsOf(host)
    const created = await host.clock.now()
    const known = await onBoard(host, root)
    const wanted = { name, directory, created, by: writer }
    const destination = await fileUnder(host, root, projectFor(known, name), wanted)
    const { key } = destination.project
    const id = newSessionId(random, await sessionIdsIn(host, root, known.keys))
    const meta = {
      id,
      ...session,
      project: destination.project.name,
      root: cwd,
      created,
      by: writer,
    }

    const folder = folderKey(key)

    await host.fs.write(sessionPaths(root, folder, id).meta, metaText(meta))

    const started = await attachHere(host, root, {
      project: folder,
      session: id,
      writer,
      attachedAt: created,
    })

    if (started !== undefined) {
      await markStarted(host, started)
    }

    return {
      result: `Started ${meta.name} as ${id}, in ${destination.said}. Record ${id} wherever the project tracks this work, so a later window can join it.`,
    }
  },
}

const join: Tool<'join'> = {
  spec: spec(
    'join',
    'Join a session on the sitrep board by its id: after a /clear, or from a second window. A resumed conversation takes its session up again by itself. Joining a finished session reopens it. Returns the board as it stands.',
    { session: text('The session id: sr- and six characters.') },
    ['session'],
  ),
  answer: async (host, input) => {
    const checked = checkJoin(input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    const { session: id } = checked.value
    const { root, writer } = await bearingsOf(host)
    const project = await folderHolding(host, root, id)

    if (project === undefined) {
      return { deny: `There is no session ${id} on the board, in any project.` }
    }

    const attachedAt = await host.clock.now()
    const session = await attachHere(host, root, { project, session: id, writer, attachedAt })

    if (session === undefined) {
      return { deny: UNREADABLE }
    }

    const joined = await reopening(host, session)
    const board = await markSeen(host, joined.session)

    return {
      result: `Joined ${session.status.name} (${id}).${joined.said} Correct anything on it that is stale against what you know. The board as it stands:\n${board}`,
      names: joined.session.status.name,
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
    `Rename the attached session's project, or say where the project lives, or both. It never moves the session to another project: the move tool does, at ${USER.possessive} word.`,
    { name: PROJECT, directory: DIRECTORY },
  ),
  answer: onSession(async (host, session, input, { here }) => {
    const checked = checkProject(input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    const { root, writer } = await bearingsOf(host)
    const { projects } = await onBoard(host, root)
    const before = projects.find(each => each.key === here) ?? { key: here, name: session.project }
    const { name } = checked.value
    const others = projects.filter(each => each.key !== here)
    const other = name === undefined ? undefined : projectNamed(others, name)

    if (other !== undefined) {
      return {
        deny: `Another project is already named ${other.name}. Renaming can't give this project that name. Moving this session there instead is ${USER.possessive} call, so ask first.`,
      }
    }

    const writing = { created: await host.clock.now(), by: writer }
    const after = await changeProject(host, root, before, checked.value, writing)

    await refresh(host)
    await lookAround(host)

    return { result: changedText(before, after) }
  }),
}

/** What a move's answer says of where the session went: where the call took it, else, where a move another window made at the same moment wins, where that one took it. */
const movedText = (session: Session, destination: Destination, landed: Filed | undefined) =>
  landed === undefined || landed.project === destination.project.key
    ? `Moved ${session.status.name} to ${destination.said}.`
    : `${session.status.name} is in ${landed.session.project}: a move another window made at the same moment took it there.`

const move: Tool<'move'> = {
  spec: spec(
    'move',
    `Move the attached session to another project, when ${USER.name} asks for it to go there: the whole session goes, with its asks, parked items, status and history, and every window holding it follows; never start a new session for this. Name the project as the board names it when it is one there; a name no project has makes a new project.`,
    { project: PROJECT, directory: DIRECTORY },
    ['project'],
  ),
  answer: onSession(async (host, session, input, { here }) => {
    const checked = checkMove(input)

    if (!checked.ok) {
      return { deny: checked.error }
    }

    const { project: name, directory } = checked.value
    const { root, writer } = await bearingsOf(host)
    const named = projectFor(await onBoard(host, root), name)
    const moving = checkMoveTo(session, here, named.project)

    if (!moving.ok) {
      return { deny: moving.error }
    }

    const created = await host.clock.now()
    const wanted = { name, directory, created, by: writer }
    const destination = await fileUnder(host, root, named, wanted)
    const after = await postKnown(host, session, [moving.value])
    const project = heldProject()
    const landed =
      after === undefined || project === undefined ? undefined : { project, session: after }

    return {
      result: movedText(session, destination, landed),
      names: landed?.session.project ?? destination.project.name,
    }
  }),
}

const board: Tool<'board'> = {
  spec: spec(
    'board',
    "Read the board back: the status, open asks and the project's parked items, with their ids, to check against what you know and repair.",
  ),
  answer: onSession(async (host, session) => ({ result: await markSeen(host, session) })),
}

const TOOLS = [
  start,
  join,
  posting(
    spec(
      'status',
      'Set where the session stands, giving only what changed. The board keeps the change in its history itself: do nothing extra for it.',
      {
        name: NAME,
        summary: SUMMARY,
        now: lines('One line per thing under way now, each starting with the verb.'),
        next: text('What comes next, in one line; "" clears it.'),
      },
    ),
    (session, input) => checkStatus(input, session.status),
    () => 'Status set.',
  ),
  posting(
    spec(
      'ask',
      `Post an ask: something only ${USER.name} can do or decide. Ask when you cannot go on without ${USER.name}, when ${USER.possessive} judgement changes what happens next, or when you leave ${USER.name} something to do, such as a release, a merge or a command to run; say it in full in the chat as well, after your last tool call: the board never stands in for the chat. Want a yes for a go, an approval, or word that it works or is done, its button the verb given (Go, Approve, Done); a choice for one of options, giving recommended whenever you lean toward one, never the word in an option; words for something written back, such as a command's output (needs says what). A reply from ${USER.name} arrives as a message from the board, each line saying whether it closed the ask: a yes, a choice, an answer or an ignore closes it by itself, a comment going with a yes or a choice too; a comment alone leaves it open for you to act on, then resolve, unless an answer to it was sent apart from that message, which closes it; rewording such an ask with edit instead hands it back, waiting on ${USER.name} again. If ${USER.name} answers in the chat instead, resolve the ask yourself, saying so in the reason.`,
      {
        wants: WANTS_BACK,
        yes: YES,
        title: text(LINE),
        where: WHERE,
        options: OPTIONS,
        recommended: RECOMMENDED,
        needs: NEEDS,
        ref: REF,
      },
      ['wants', 'title'],
    ),
    (session, input) => withId(checkAsk(input), session, random),
    ({ id }) => `Posted ask ${id}. Put it to ${USER.name} in full after your last tool call.`,
  ),
  posting(
    spec(
      'park',
      `Park something raised and put off, to come back to, on the attached session's project: any session of it sees it. A parked item may be dropped by ${USER.name} from the board: one gone that you didn't close was dropped, so leave it, and park it again or reopen it only at ${USER.possessive} word.`,
      { title: text(LINE), where: WHERE, ref: REF },
      ['title'],
    ),
    async (session, input, host) =>
      withParkId(checkPark(input), session, await parkedAround(host), random),
    ({ id }) => `Parked ${id}.`,
  ),
  onItem(
    spec(
      'resolve',
      "Close an item on the board, an ask or a parked item, by its id; a parked item another session of this project parked, with that session's id.",
      { item: ITEM, session: PARKED_BY, reason: REASON },
      ['item'],
    ),
    checkResolve,
    ({ item }) => `Resolved ${item}.`,
    resolvedByLee,
  ),
  onItem(
    spec(
      'reopen',
      "Reopen a closed item by its id; a parked item another session of this project parked, with that session's id.",
      { item: ITEM, session: PARKED_BY, reason: REASON },
      ['item'],
    ),
    checkReopen,
    ({ item }) => `Reopened ${item}.`,
  ),
  onItem(
    spec(
      'edit',
      `Correct an item by its id, giving only the fields to change; a parked item another session of this project parked, with that session's id. An item's one line is its title or its text alike, an ask's or a parked item's. An ask changed to want a yes needs yes; to want a choice, options. An ask's recommended stays while its option is among the options. Editing an ask ${USER.name} commented on, yours to act on, hands it back: it waits on ${USER.name} again; resolve it instead once acted on.`,
      {
        item: ITEM,
        session: PARKED_BY,
        wants: WANTS_BACK,
        yes: YES,
        title: text(LINE),
        where: WHERE,
        options: OPTIONS,
        recommended: text(`${RECOMMENDED.description} "" clears it.`),
        needs: text(`${NEEDS.description} "" clears it.`),
        ref: REF,
        text: text(LINE),
        reason: REASON,
      },
      ['item'],
    ),
    checkEdit,
    editedText,
  ),
  posting(
    spec(
      'finish',
      "Finish the attached session, when it is complete and nothing is left on it; what it parked stays its project's, and holds no finish back. It leaves the board's views, and its open asks stop counting.",
      { reason: REASON },
    ),
    (session, input) => checkFinish(session, 'claude', input),
    () => 'Finished. This window stays attached; joining the session again reopens it.',
    session => session.status.name,
  ),
  project,
  move,
  board,
] as const

const nameOf = (tool: Tool) => `${PREFIX}${tool.spec.name}`

const BY_NAME = new Map<string, Tool>(TOOLS.map(tool => [nameOf(tool), tool]))

/**
 * Every call of this plugin's tools, by the prefix the model names them
 * with. Matched by their names instead, a matcher is typed against the
 * tools the engine laid out at the last load, so a tool added since fails
 * the type-check until a load lays it out.
 */
export const OWN_TOOLS = new RegExp(`^${PREFIX}`)

/** A tool's own name, as its spec gives it. */
export type ToolName = (typeof TOOLS)[number]['spec']['name']

/** The tool a call names, by its own name; undefined for any other tool. */
export const toolNamed = (tool: string) => TOOLS.find(each => nameOf(each) === tool)?.spec.name

export const SPECS = TOOLS.map(tool => tool.spec)

/** The latest calls whose names are kept: `$.state` lasts as long as the window, and an older row falls back to the held session. */
export const NAMES_KEPT = 300

/** Keeps the name a call's row gives what it named, so the row keeps it as the window moves on. */
const keepName = (host: Host, call: string, name: string) =>
  host.state.named.update(named => [...named, { call, name }].slice(-NAMES_KEPT))

/** The name a call's row gives what it named, as kept when the call was answered; undefined with none kept. */
export const nameKept = async (host: Host, call: string) =>
  (await host.state.named.read()).find(each => each.call === call)?.name

/** A tool's answer as the model reads it, the name its row gives kept first. */
const answered = async (host: Host, call: string, answer: Answer): Promise<Answered> => {
  if ('deny' in answer) {
    return answer
  }

  if (answer.names !== undefined) {
    await keepName(host, call, answer.names)
  }

  return { result: answer.result }
}

/**
 * Answers a call of one of the tools; a subagent's is refused. Its work
 * waits its turn in the window's queue, and is answered within its hook's
 * `budget`, as the hook reads it live (deadline.ts).
 */
export const answerCall = async (
  host: Host,
  call: Fields & { tool: string; tool_use_id: string; agentId?: string },
  budget: Budget,
): Promise<Answered> => {
  if (call.agentId !== undefined) {
    return { deny: FOR_THE_REPORT }
  }

  const tool = BY_NAME.get(call.tool)

  if (tool === undefined) {
    return { deny: `sitrep has no tool ${call.tool}.` }
  }

  const progress = progressOf()
  const work = serially(async () =>
    progress.begin()
      ? answered(host, call.tool_use_id, await tool.answer(host, call, progress))
      : { deny: BUSY },
  )

  return byDeadline(host, tool.spec.name, work, progress, budget)
}
