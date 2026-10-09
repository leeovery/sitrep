/**
 * An ask in For you, drawn as every list's row: its mark, its title and its
 * age, and, while a reply waits on it or is on its way, that one branch.
 * Opened, it shows its whole title, its tree (what its words are, where to
 * look, Claude's own record of it, and where Lee's reply stands) and its
 * buttons, by what it wants back: a yes in its own words, its options, or
 * words, written in the prompt box (DESIGN.md, "Answering an ask"). Any
 * session's asks answer the same way; a reply names the work it goes to.
 */
import { isClosing, VERDICTS, type Ask, type Verdict } from '../../core'
import type { SitrepItemRef, SitrepQueued } from '../../types'
import { answeringIn } from '../answering'
import { C, GLYPH } from '../look'
import { queuedOn } from '../queue'
import { askMark, type Filed } from '../scene'
import {
  answeringOf,
  canWrite,
  drawOnItsWay,
  drawQueued,
  drawRow,
  onItsWay,
  seeRef,
  shown,
  type Drawing,
} from './kit'

const HINT =
  "Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it."

const ANSWERING = 'answering in the prompt…'

/** The mark of an ask Lee's send closed. */
const DONE = { glyph: GLYPH.done, color: C.ok }

/** The ask as the item a reply answers. */
const refOf = (filed: Filed, ask: Ask): SitrepItemRef => ({
  project: filed.project,
  work: filed.work.id,
  item: ask.id,
})

/** The comment button's words: an answer's, on an ask read from its kind as a decide, where a comment closes it. */
const commentLabel = (ask: Ask) => (isClosing(ask, 'comment') ? '✎ answer' : '✎ comment')

/** The buttons a verdict puts on an ask: one for each option of a choice; none to write with on a surface Lee cannot write back from. */
const buttonsFor = (d: Drawing, at: SitrepItemRef, ask: Ask, verdict: Verdict) => {
  const { Button } = d.els
  const reply = (fields: Omit<SitrepQueued, keyof SitrepItemRef>) =>
    d.act.reply({ ...at, ...fields })

  switch (verdict) {
    case 'yes':
      return [
        <Button
          key={`yes:${ask.id}`}
          variant="primary"
          label={`✓ ${ask.yes ?? 'yes'}`}
          onPress={() => reply({ verdict })}
        />,
      ]
    case 'choose':
      return (ask.options ?? []).map((option, i) => (
        <Button
          key={`choose:${ask.id}:${i}`}
          variant={i === 0 ? 'primary' : undefined}
          label={option}
          onPress={() => reply({ verdict, option })}
        />
      ))
    case 'answer':
      return canWrite(d)
        ? [
            <Button
              key={`answer:${ask.id}`}
              variant="primary"
              label="✎ Answer"
              onPress={() => d.act.answer(answeringOf(at, ask, 'answer'))}
            />,
          ]
        : []
    case 'comment':
      return canWrite(d)
        ? [
            <Button
              key={`comment:${ask.id}`}
              label={commentLabel(ask)}
              onPress={() => d.act.answer(answeringOf(at, ask, 'comment'))}
            />,
          ]
        : []
    case 'ignore':
      return [
        <Button
          key={`ignore:${ask.id}`}
          dimColor
          label="✕ ignore"
          onPress={() => reply({ verdict })}
        />,
      ]
    case 'pickup':
      return []
  }
}

/** Where an ask stands as drawn: the reply it waits to send, or the one on its way, and whether Lee is answering it in the prompt. */
const standingOf = (d: Drawing, filed: Filed, ask: Ask) => {
  const at = refOf(filed, ask)
  const queued = queuedOn(d.scene.queue, filed.work.id, ask.id)
  const answering = answeringIn(d.scene)?.answering
  const isClosed = ask.state === 'closed'

  return {
    at,
    queued,
    sent: queued === undefined ? onItsWay(ask) : undefined,
    isAnswering: answering?.work === at.work && answering.item === at.item,
    isClosed,
    isOpen: d.scene.pane.selected === ask.id && !isClosed,
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

/**
 * What hangs from an ask's mark: opened, what its words are, where to look,
 * Claude's own record of it in the mark's colour and what Lee commented;
 * then, opened or not, Lee's reply, and Lee writing in the prompt.
 */
const branchesOf = (d: Drawing, ask: Ask, color: string, standing: Standing) => {
  const { queued, sent, isOpen, isAnswering } = standing
  const isAnswered = queued !== undefined || sent !== undefined
  const commented = ask.state === 'replied' && !isAnswered ? ask.answer?.note : undefined

  return shown(
    isOpen && ask.needs !== undefined && { text: `needs: ${ask.needs}`, color: C.ask },
    isOpen && ask.where,
    isOpen && seeRef(ask.ref, color),
    isOpen && commented !== undefined && `you commented: “${commented}”. Claude has it.`,
    replyBranch(d, ask, standing),
    isAnswering && ANSWERING,
  )
}

/** An opened ask's buttons and the hint under them, at its title's column, a blank row after them unless it is the last ask. */
const drawButtons = (d: Drawing, ask: Ask, { at }: Standing, isLast: boolean) => {
  const { Box, Text } = d.els
  const verdicts = VERDICTS[ask.wants]

  return (
    <Box paddingLeft={2} paddingBottom={isLast ? 0 : 1} flexDirection="column">
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        {verdicts.flatMap(verdict => buttonsFor(d, at, ask, verdict))}
      </Box>
      <Text color={C.grey} italic wrap="wrap">
        {HINT}
      </Text>
    </Box>
  )
}

export const drawAsk = (d: Drawing, filed: Filed, ask: Ask, isLast: boolean) => {
  const standing = standingOf(d, filed, ask)
  const { queued, sent, isAnswering, isClosed, isOpen } = standing
  const mark = isClosed ? DONE : askMark(d.scene, ask)
  const isAnswerable = isOpen && queued === undefined && sent === undefined && !isAnswering

  return drawRow(d, {
    key: `ask:${ask.id}`,
    mark,
    title: ask.title,
    at: ask.at,
    isOpen,
    press: isClosed ? undefined : { key: `pick:${ask.id}`, onPress: () => d.act.select(ask.id) },
    branches: branchesOf(d, ask, mark.color, standing),
    after: isAnswerable && drawButtons(d, ask, standing, isLast),
  })
}
