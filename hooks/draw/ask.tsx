/**
 * Asks: a session's asks, or every session's in a project's view, each
 * naming its session there. An ask is drawn as every list's row: its mark,
 * its title and its age, and, while a reply waits on it or is on its way,
 * that one branch. Opened, it shows its whole title, its tree (what its
 * words are, where to look, Claude's own record of it, and where Lee's
 * reply stands) and its buttons, by what it wants back: a yes in its own
 * words, its options, or words, written in the prompt box (DESIGN.md,
 * "Answering an ask"). Any session's asks answer the same way; a reply
 * names the session it goes to.
 *
 * An ask waiting on Lee offers `snooze` among its buttons, which asks in
 * place until when. One snoozed comes after those waiting, quieted, and
 * hangs when it wakes, with `wake now`; opened, it answers as any does.
 */
import {
  isAnswer,
  replyOnItsWay,
  VERDICTS,
  waitsOnLee,
  wakeWords,
  yesOf,
  type Ask,
  type SnoozeChoice,
  type Verdict,
} from '../../core'
import type { SitrepItemRef, SitrepQueued } from '../../types'
import { C, GLYPH } from '../look'
import { itemKey, type AskedAt } from '../places'
import { queuedOn } from '../queue'
import { askMark, isPulsing } from '../scene'
import {
  ANSWERING,
  answeringOf,
  drawOnItsWay,
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
const RESOLVED = { glyph: GLYPH.done, color: C.ok }

/** The mark of an ask Lee snoozed: quieted, as the ◆ by a count with nothing waiting. */
const SNOOZED = { glyph: GLYPH.ask, color: C.grey }

/** What snoozing an ask asks in place. */
const SNOOZE_QUESTION = 'Snooze it? It stops counting until it wakes.'

/** Snooze's choices, each with its press's words. */
const SNOOZE_CHOICES: readonly (readonly [SnoozeChoice, string])[] = [
  ['later', 'later today'],
  ['tomorrow', 'tomorrow'],
  ['week', 'next week'],
]

/** What opens an ask's question of when to snooze it, in place of its buttons: this, then its address. */
const snoozeKey = (key: string) => `snooze:${key}`

/** The ask as the item a reply answers. */
const refOf = ({ at, ask }: AskedAt): SitrepItemRef => ({ ...at, item: ask.id })

/** The comment button's words: an answer's, on an ask read from its kind as a decide, where a comment closes it. */
const commentLabel = (ask: Ask) => (isAnswer(ask, 'comment') ? '✎ answer' : '✎ comment')

/** The buttons a verdict puts on an ask, each keyed by the ask's address: one for each option of a choice. */
const buttonsFor = (d: Drawing, at: SitrepItemRef, ask: Ask, verdict: Verdict) => {
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
      return (ask.options ?? []).map((option, i) => (
        <Button
          key={`choose:${key}:${i}`}
          variant={i === 0 ? 'primary' : undefined}
          label={option}
          onPress={() => reply({ verdict, option })}
        />
      ))
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
 * snoozed, whether it can be snoozed, waiting on Lee and not snoozed, and
 * whether it is asking when to, opened still.
 */
const standingOf = (d: Drawing, asked: AskedAt) => {
  const { ask, snoozedUntil } = asked
  const at = refOf(asked)
  const key = itemKey(at.session, ask.id)
  const queued = queuedOn(d.scene.queue, at.session, ask.id)
  const isClosed = ask.state === 'closed'
  const { selected } = d.scene.pane
  const isChoosing = selected === snoozeKey(key) && !isClosed

  return {
    at,
    key,
    queued,
    sent: queued === undefined ? replyOnItsWay(ask) : undefined,
    isAnswering: isBeingAnswered(d, at),
    isClosed,
    snoozedUntil,
    canSnooze: snoozedUntil === undefined && waitsOnLee(ask),
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
    isOpen && commented !== undefined && `you commented: “${commented}”. Claude has it.`,
    snoozedUntil !== undefined && drawAsleep(d, standing, snoozedUntil),
    replyBranch(d, ask, standing),
    isAnswering && ANSWERING,
  )
}

/** The press that asks when to snooze an ask waiting on Lee; none for one snoozed, or one that waits on Claude or on a reply on its way. */
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

/** Snooze's question, in place of the ask's buttons: until when, each time worked out as it is pressed, or cancel, back to the buttons. */
const drawSnoozing = (d: Drawing, { at, key }: Standing) => {
  const { Box, Text, Button } = d.els

  return (
    <Box flexDirection="column">
      <Text wrap="wrap">{SNOOZE_QUESTION}</Text>
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        {SNOOZE_CHOICES.map(([when, label]) => (
          <Button
            key={`snooze-${when}:${key}`}
            label={label}
            onPress={() => d.act.snooze(at, when)}
          />
        ))}
        <Button
          key={`snooze-no:${key}`}
          dimColor
          label="cancel"
          onPress={() => d.act.select(key)}
        />
      </Box>
    </Box>
  )
}

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

/** An ask's mark: ticked once Lee's send closed it, quieted while snoozed, else its ◆ as it stands in the pulse. */
const markOf = (d: Drawing, ask: Ask, { isClosed, snoozedUntil }: Standing) => {
  if (isClosed) {
    return RESOLVED
  }

  return snoozedUntil === undefined ? askMark(d.scene, ask) : SNOOZED
}

/** An ask's row, its title after its session's name where the list names them, quieted while snoozed. Its buttons stand while nothing waits on it but a comment on its way, which bars no answer. */
const drawAsk = (d: Drawing, asked: AskedAt, isLast: boolean, isNamed: boolean) => {
  const { ask, name } = asked
  const standing = standingOf(d, asked)
  const { key, queued, isAnswering, isClosed, isOpen, snoozedUntil } = standing
  const mark = markOf(d, ask, standing)
  const isAnswerable =
    isOpen && queued === undefined && ask.answerOnItsWay === undefined && !isAnswering

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
          onPress: () => d.act.select(key),
          isDim: snoozedUntil !== undefined,
        },
    branches: branchesOf(d, ask, mark.color, standing),
    after: isAnswerable && drawButtons(d, ask, standing, isLast),
  })
}

/** What Asks lists: how many of its asks wait, and how many are snoozed, whether this session's are among them, and whether each names its session. */
export type AsksListed = { waiting: number; snoozed: number; isHome: boolean; isNamed: boolean }

/** How many asks wait, and how many are snoozed where any are: `1 waiting · 2 snoozed`. */
const countsOf = ({ waiting, snoozed }: AsksListed) => {
  const words = waiting > 0 ? `${waiting} waiting` : 'nothing waiting'

  return snoozed > 0 ? `${words} · ${snoozed} snoozed` : words
}

/** Asks' few words: new while one of this session's asks pulses there, else how many wait and sleep. */
const noteOf = (d: Drawing, listing: AsksListed) => {
  if (listing.isHome && isPulsing(d.scene)) {
    return { note: '✦ new', color: askMark(d.scene).color }
  }

  return { note: countsOf(listing), color: C.grey }
}

/** Asks' heading, then each ask, keyed by its address, since a project's view lists every session's. */
export const drawAsks = (d: Drawing, asked: readonly AskedAt[], listing: AsksListed): Block[] => {
  const { Box } = d.els
  const { note, color } = noteOf(d, listing)

  return [
    {
      key: 'asks',
      element: (
        <Box flexDirection="column">
          {heading(d, 'ASKS', C.ask, note, color)}
          {asked.length === 0 && emptyLine(d, 'Nothing waiting on you.')}
        </Box>
      ),
    },
    ...asked.map((each, i) => ({
      key: `ask:${itemKey(each.at.session, each.ask.id)}`,
      element: drawAsk(d, each, i === asked.length - 1, listing.isNamed),
    })),
  ]
}
