/**
 * Asks: a session's asks, or every session's in a project's view, each
 * naming its session there. An ask is drawn as every list's row: its mark,
 * its title and its age, and, while a reply waits on it or is on its way,
 * that one branch. Opened, it shows its whole title, its tree (what its
 * words are, where to look, Claude's own record of it, and where Lee's
 * reply stands) and its buttons, by what it wants back: a yes in its own
 * words, its options, the one Claude recommends marked in its button, or
 * words, written in the prompt box (DESIGN.md, "Answering an ask"). Any
 * session's asks answer the same way; a reply names the session it goes to.
 *
 * An ask waiting on Lee offers `snooze` among its buttons, which asks in
 * place until when, and snoozes that ask alone. One snoozed, on its own or
 * with its session, comes after those waiting, quieted, and hangs when it
 * wakes, with `wake now`, which wakes what holds it; opened, it answers as
 * any does. Asks a finished session left open wait on no one, but in the
 * session this window holds: each drawn faint, with no buttons, a line
 * under the heading saying why.
 */
import {
  isAnswer,
  replyOnItsWay,
  shownWords,
  snoozeChoicesAt,
  VERDICTS,
  waitsOnLee,
  wakeWords,
  yesOf,
  type Ask,
  type ProjectKey,
  type SnoozeChoice,
  type Verdict,
} from '../../core'
import type { SitrepItemRef, SitrepQueued } from '../../types'
import { C, GLYPH } from '../look'
import { canReach, itemKey, type AskedAt } from '../places'
import { queuedOn } from '../queue'
import { askMark, isPulsing } from '../scene'
import {
  ANSWERING,
  answeringOf,
  drawOnItsWay,
  drawQuestion,
  drawQueued,
  drawRow,
  drawWrite,
  emptyLine,
  heading,
  isBeingAnswered,
  seeRef,
  shown,
  type Block,
  type Drawing,
} from './kit'

const HINT =
  "Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it."

/** The mark of an ask Lee's send closed. */
const RESOLVED = { glyph: GLYPH.closed, color: C.ok }

/** The mark of an ask Lee snoozed: quieted, as the ● by a count with nothing waiting. */
const SNOOZED = { glyph: GLYPH.ask, color: C.grey }

/** The mark of an ask left open in a finished session: a closed thing, which waits on no one. */
const LEFT_OPEN = { glyph: GLYPH.ask, color: C.faint }

/** Why a finished session's asks offer no reply, under ASKS. */
const FINISHED_LINE = "Finished: its asks can't be answered."

/** What snoozing an ask asks in place. */
const SNOOZE_QUESTION = 'Snooze it? It stops counting until it wakes.'

/** Each of Snooze's choices as its press words it. */
const SNOOZE_WORDS: Record<SnoozeChoice, string> = {
  hour: 'in an hour',
  later: 'later today',
  tonight: 'tonight',
  tomorrow: 'tomorrow',
  weekend: 'this weekend',
  week: 'next week',
}

/** What opens an ask's question of when to snooze it, in place of its buttons: this, then its address. */
const snoozeKey = (key: string) => `snooze:${key}`

/** The ask as the item a reply answers. */
const refOf = ({ at, ask }: AskedAt): SitrepItemRef<ProjectKey> => ({ ...at, item: ask.id })

/** The comment button's words: an answer's, on an ask read from its kind as a decide, where a comment closes it. */
const commentLabel = (ask: Ask) => (isAnswer(ask, 'comment') ? '✎ answer' : '✎ comment')

/** What ends the label of the option Claude recommends, in a darker lilac than its own. */
const RECOMMENDED = '· recommended'

/** The option pressed first: the one Claude recommends, else the first. */
const primaryOf = (ask: Ask) => ask.recommended ?? ask.options?.[0]

/** An option's button, its label ending with the word saying so where Claude recommends it: inside the button, so a long label wraps with it. */
const drawOption = (d: Drawing, key: string, option: string, ask: Ask, onPress: () => void) => {
  const { Text, Button } = d.els
  const variant = option === primaryOf(ask) ? 'primary' : undefined

  return option === ask.recommended ? (
    <Button key={key} variant={variant} label={option} onPress={onPress}>
      {option} <Text color={C.recommended}>{RECOMMENDED}</Text>
    </Button>
  ) : (
    <Button key={key} variant={variant} label={option} onPress={onPress} />
  )
}

/** The buttons a verdict puts on an ask, each keyed by the ask's address: one for each option of a choice. */
const buttonsFor = (d: Drawing, at: SitrepItemRef<ProjectKey>, ask: Ask, verdict: Verdict) => {
  const { Button } = d.els
  const key = itemKey(at.session, ask.id)
  const reply = (fields: Omit<SitrepQueued, keyof SitrepItemRef>) =>
    d.act.reply({ ...at, ...fields })

  switch (verdict) {
    case 'yes':
      return [
        <Button
          key={`yes:${key}`}
          variant="primary"
          label={`✓ ${yesOf(ask)}`}
          onPress={() => reply({ verdict })}
        />,
      ]
    case 'choose':
      return (ask.options ?? []).map((option, i) =>
        drawOption(d, `choose:${key}:${i}`, option, ask, () => reply({ verdict, option })),
      )
    case 'answer':
      return drawWrite(d, `answer:${key}`, '✎ Answer', answeringOf(d, at, ask, 'answer'), 'primary')
    case 'comment':
      return drawWrite(d, `comment:${key}`, commentLabel(ask), answeringOf(d, at, ask, 'comment'))
    case 'ignore':
      return [
        <Button
          key={`ignore:${key}`}
          dimColor
          label="✕ ignore"
          onPress={() => reply({ verdict })}
        />,
      ]
    case 'pickup':
      return []
  }
}

/**
 * Where an ask stands as drawn: the reply it waits to send, or the one on
 * its way, whether Lee is answering it in the prompt, when it wakes while
 * snoozed, whether no reply can reach it (`canReach`), left open in a
 * finished session, whether it can be snoozed, waiting on Lee in a session
 * not finished and not snoozed with some choice offered, the choices
 * offered, and whether it is asking when to, opened still.
 */
const standingOf = (d: Drawing, asked: AskedAt) => {
  const { ask, snoozedUntil, isFinished } = asked
  const at = refOf(asked)
  const key = itemKey(at.session, ask.id)
  const queued = queuedOn(d.scene.queue, at.session, ask.id)
  const isClosed = ask.state === 'closed'
  const { selected } = d.scene.pane
  const isChoosing = selected === snoozeKey(key) && !isClosed
  const offered = snoozeChoicesAt(d.scene.now, d.scene.snooze)

  return {
    at,
    key,
    queued,
    sent: queued === undefined ? replyOnItsWay(ask) : undefined,
    isAnswering: isBeingAnswered(d, at),
    isClosed,
    snoozedUntil,
    isUnreachable: !canReach(d.scene, at.session, ask),
    canSnooze: !isFinished && snoozedUntil === undefined && waitsOnLee(ask) && offered.length > 0,
    offered,
    isChoosing,
    isOpen: (selected === key && !isClosed) || isChoosing,
  }
}

type Standing = ReturnType<typeof standingOf>

/** Lee's reply as the branch the ask's row keeps, opened or not: waiting to be sent, or on its way; or, just closed, with Claude. */
const replyBranch = (d: Drawing, ask: Ask, { queued, sent, isClosed }: Standing) => {
  if (queued !== undefined) {
    return drawQueued(d, ask, queued)
  }

  if (sent !== undefined) {
    return drawOnItsWay(d, ask, sent)
  }

  return isClosed && 'sent, and Claude has it'
}

/** When a snoozed ask wakes, worded at the board's now, and the press that wakes it now. */
const drawAsleep = (d: Drawing, { at, key }: Standing, until: number) => {
  const { Box, Text, Button } = d.els

  return (
    <Box flexDirection="row" columnGap={1}>
      <Text color={C.grey}>{`snoozed until ${wakeWords(until, d.scene.now)}`}</Text>
      <Button key={`wake:${key}`} plain dimColor label="wake now" onPress={() => d.act.wake(at)} />
    </Box>
  )
}

/**
 * What hangs from an ask's mark: opened, what its words are, where to look,
 * Claude's own record of it in the mark's colour and what Lee commented;
 * then, opened or not, when it wakes while snoozed, Lee's reply, and Lee
 * writing in the prompt.
 */
const branchesOf = (d: Drawing, ask: Ask, color: string, standing: Standing) => {
  const { queued, sent, isOpen, isAnswering, snoozedUntil } = standing
  const isAnswered = queued !== undefined || sent !== undefined
  const commented = ask.state === 'replied' && !isAnswered ? ask.answer?.note : undefined

  return shown(
    isOpen && ask.needs !== undefined && { text: `needs: ${ask.needs}`, color: C.ask },
    isOpen && ask.where,
    isOpen && seeRef(ask.ref, color),
    isOpen &&
      commented !== undefined &&
      `you commented: “${shownWords(commented)}”. Claude has it.`,
    snoozedUntil !== undefined && drawAsleep(d, standing, snoozedUntil),
    replyBranch(d, ask, standing),
    isAnswering && ANSWERING,
  )
}

/** The press that asks when to snooze an ask waiting on Lee; none for one snoozed, one that waits on Claude or on a reply on its way, or while no choice is offered. */
const snoozeButton = (d: Drawing, { key, canSnooze }: Standing) => {
  const { Button } = d.els

  return canSnooze
    ? [
        <Button
          key={snoozeKey(key)}
          dimColor
          label="snooze"
          onPress={() => d.act.select(snoozeKey(key))}
        />,
      ]
    : []
}

/** An opened ask's buttons, snooze among them where it can be, and the hint under them. */
const drawAnswers = (d: Drawing, ask: Ask, standing: Standing) => {
  const { Box, Text } = d.els
  const verdicts = VERDICTS[ask.wants]

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        {verdicts.flatMap(verdict => buttonsFor(d, standing.at, ask, verdict))}
        {snoozeButton(d, standing)}
      </Box>
      <Text color={C.grey} italic wrap="wrap">
        {HINT}
      </Text>
    </Box>
  )
}

/** Snooze's question, in place of the ask's buttons: until when, the choices offered at the board's now as the app set them, each time worked out as it is pressed, or cancel, back to the buttons. */
const drawSnoozing = (d: Drawing, { at, key, offered }: Standing) =>
  drawQuestion(
    d,
    SNOOZE_QUESTION,
    offered.map(when => ({
      key: `snooze-${when}:${key}`,
      label: SNOOZE_WORDS[when],
      onPress: () => d.act.snooze(at, when),
    })),
    { key: `snooze-no:${key}`, onPress: () => d.act.select(key) },
  )

/** An opened ask's buttons and the hint under them, or Snooze's question in their place, at its title's column, a blank row after them unless it is the last ask. */
const drawButtons = (d: Drawing, ask: Ask, standing: Standing, isLast: boolean) => {
  const { Box } = d.els

  return (
    <Box paddingLeft={2} paddingBottom={isLast ? 0 : 1} flexDirection="column">
      {standing.isChoosing && standing.canSnooze
        ? drawSnoozing(d, standing)
        : drawAnswers(d, ask, standing)}
    </Box>
  )
}

/** An ask's mark: ticked once Lee's send closed it, faint where no reply can reach it, quieted while snoozed, else its ● as it stands in the pulse. */
const markOf = (d: Drawing, ask: Ask, { isClosed, isUnreachable, snoozedUntil }: Standing) => {
  if (isClosed) {
    return RESOLVED
  }

  if (isUnreachable) {
    return LEFT_OPEN
  }

  return snoozedUntil === undefined ? askMark(d.scene, ask) : SNOOZED
}

/**
 * An ask's row, its title after its session's name where the list names
 * them, quieted while snoozed or while its session finished, no reply
 * reaching it. Its buttons stand while nothing waits on it but a comment on
 * its way, which bars no answer, and never where no reply reaches it:
 * opened there, it shows only its tree.
 */
const drawAsk = (d: Drawing, asked: AskedAt, isLast: boolean, isNamed: boolean) => {
  const { ask, name } = asked
  const standing = standingOf(d, asked)
  const { key, queued, isAnswering, isClosed, isOpen, isChoosing, snoozedUntil, isUnreachable } =
    standing
  const mark = markOf(d, ask, standing)
  // `select` toggles the key it is given, so the title gives the one the pane holds: one press closes the ask from Snooze's question too.
  const opener = isChoosing ? snoozeKey(key) : key
  const isAnswerable =
    isOpen && !isUnreachable && queued === undefined && ask.answerOnItsWay === undefined && !isAnswering

  return drawRow(d, {
    key: `ask:${key}`,
    mark,
    title: isNamed ? `${name}: ${ask.title}` : ask.title,
    at: ask.at,
    isOpen,
    press: isClosed
      ? undefined
      : {
          key: `pick:${key}`,
          onPress: () => d.act.select(opener),
          isDim: snoozedUntil !== undefined || isUnreachable,
        },
    branches: branchesOf(d, ask, mark.color, standing),
    after: isAnswerable && drawButtons(d, ask, standing, isLast),
  })
}

/** What Asks lists: how many of its asks wait, and how many are snoozed, whether this session's are among them, and whether each names its session. */
export type AsksListed = { waiting: number; snoozed: number; isHome: boolean; isNamed: boolean }

/** How many asks wait, how many are snoozed where any are, and how many were left open, their session finished, no reply reaching them: `1 waiting · 2 snoozed`, `nothing waiting · 2 left open`. */
const countsOf = ({ waiting, snoozed }: AsksListed, left: number) => {
  const words = waiting > 0 ? `${waiting} waiting` : 'nothing waiting'
  const asides = [
    ...(snoozed > 0 ? [`${snoozed} snoozed`] : []),
    ...(left > 0 ? [`${left} left open`] : []),
  ]

  return [words, ...asides].join(' · ')
}

/** Asks' few words: new while one of this session's asks pulses there, else how many wait, sleep, or were left open. */
const noteOf = (d: Drawing, listing: AsksListed, left: number) => {
  if (listing.isHome && isPulsing(d.scene)) {
    return { note: '✦ new', color: askMark(d.scene).color }
  }

  return { note: countsOf(listing, left), color: C.grey }
}

/** How many of the asks listed were left open, their session finished, no reply reaching them (`canReach`). */
const leftOpen = (d: Drawing, asked: readonly AskedAt[]) =>
  asked.filter(each => each.ask.state !== 'closed' && !canReach(d.scene, each.at.session, each.ask))
    .length

/** Asks' heading, then each ask, keyed by its address, since a project's view lists every session's. */
export const drawAsks = (d: Drawing, asked: readonly AskedAt[], listing: AsksListed): Block[] => {
  const { Box, Text } = d.els
  const left = leftOpen(d, asked)
  const { note, color } = noteOf(d, listing, left)

  return [
    {
      key: 'asks',
      element: (
        <Box flexDirection="column">
          {heading(d, 'ASKS', C.ask, note, color)}
          {asked.length === 0 && emptyLine(d, 'Nothing waiting on you.')}
          {left > 0 && (
            <Text color={C.faint} wrap="wrap">
              {FINISHED_LINE}
            </Text>
          )}
        </Box>
      ),
    },
    ...asked.map((each, i) => ({
      key: `ask:${itemKey(each.at.session, each.ask.id)}`,
      element: drawAsk(d, each, i === asked.length - 1, listing.isNamed),
    })),
  ]
}
