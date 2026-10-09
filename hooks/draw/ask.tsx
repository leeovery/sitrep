/**
 * An ask in For you: its title and age, where to look, what Lee replied,
 * and, opened, its buttons. A kind is never drawn as a word: it chooses
 * the first button (DESIGN.md, "Answering an ask"). Any session's asks
 * answer the same way; a reply names the work it goes to.
 */
import { VERDICTS, type Ask, type AskKind, type Verdict } from '../../core'
import type { SitrepAnswer, SitrepItemRef, SitrepQueued } from '../../types'
import { ago, C, GLYPH } from '../look'
import { queuedOn } from '../queue'
import { askMark, type Filed } from '../scene'
import { drawField } from './field'
import {
  canType,
  drawMark,
  drawOnItsWay,
  drawQueued,
  drawTitle,
  onItsWay,
  seeRef,
  shown,
  titleLines,
  tree,
  YES,
  type Drawing,
  type Mark,
} from './kit'

/** The comment button, by kind: on a decide, a comment is the answer. */
const COMMENT: Record<AskKind, string> = {
  review: '✎ comment',
  decide: '✎ answer',
  try: '✎ comment',
  do: '✎ comment',
}

const HINT =
  "Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it."

/** The ask as the item a reply answers. */
const refOf = (filed: Filed, ask: Ask): SitrepItemRef => ({
  project: filed.project,
  work: filed.work.id,
  item: ask.id,
})

/**
 * The buttons a verdict puts on an ask: one for each option of a decision.
 * A yes or a choice on an ask that needs something back opens the field for
 * it, where Lee can type; elsewhere it queues as it would without.
 */
const buttonsFor = (d: Drawing, at: SitrepItemRef, ask: Ask, verdict: Verdict) => {
  const { Button } = d.els
  const reply = (fields: Omit<SitrepQueued, keyof SitrepItemRef>) =>
    d.act.reply({ ...at, ...fields })
  const answer = (given: SitrepAnswer) =>
    ask.needs !== undefined && canType(d) ? d.act.comment({ ...at, answer: given }) : reply(given)

  switch (verdict) {
    case 'choose':
      return (ask.options ?? []).map((option, i) => (
        <Button
          key={`choose:${ask.id}:${i}`}
          variant={i === 0 ? 'primary' : undefined}
          label={option}
          onPress={() => answer({ verdict: 'choose', option })}
        />
      ))
    case 'yes':
      return [
        <Button
          key={`yes:${ask.id}`}
          variant="primary"
          label={YES[ask.kind]}
          onPress={() => answer({ verdict: 'yes' })}
        />,
      ]
    case 'comment':
      return canType(d)
        ? [
            <Button
              key={`comment:${ask.id}`}
              label={COMMENT[ask.kind]}
              onPress={() => d.act.comment(at)}
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

const drawButtons = (d: Drawing, at: SitrepItemRef, ask: Ask) => {
  const { Box, Text } = d.els

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        {VERDICTS[ask.kind].flatMap(verdict => buttonsFor(d, at, ask, verdict))}
      </Box>
      <Text color={C.grey} italic wrap="wrap">
        {HINT}
      </Text>
    </Box>
  )
}

/** The field open on this ask, where Lee can type in it; one for what the ask needs back only while it needs something. */
const fieldOn = (d: Drawing, at: SitrepItemRef, ask: Ask) => {
  const field = d.scene.pane.commenting
  const isOnAsk = field?.work === at.work && field.item === ask.id
  const isStanding = field?.answer === undefined || ask.needs !== undefined

  return isOnAsk && isStanding && canType(d) ? field : undefined
}

/** Where an ask stands as drawn: the reply it waits to send, or the one on its way, and what Lee has open on it. */
const standingOf = (d: Drawing, filed: Filed, ask: Ask) => {
  const { queue, pane } = d.scene
  const at = refOf(filed, ask)
  const queued = queuedOn(queue, filed.work.id, ask.id)
  const isClosed = ask.state === 'closed'

  return {
    at,
    queued,
    sent: queued === undefined ? onItsWay(ask) : undefined,
    isClosed,
    isOpen: pane.selected === ask.id && !isClosed,
    field: fieldOn(d, at, ask),
  }
}

type Standing = ReturnType<typeof standingOf>

/** What hangs from an ask's mark: what it needs back, where to look, Claude's own record of it in the mark's colour, what Lee replied, and whether Claude has it. */
const branchesOf = (
  d: Drawing,
  ask: Ask,
  mark: Mark,
  { queued, sent, isClosed, isOpen }: Standing,
) => {
  const isAnswered = queued !== undefined || sent !== undefined
  const commented = ask.state === 'replied' && !isAnswered ? ask.answer?.note : undefined
  const isDetailed = !isClosed && (isOpen || d.isDock)

  return shown(
    isDetailed && ask.needs !== undefined && { text: `needs: ${ask.needs}`, color: C.ask },
    isDetailed && ask.where,
    isOpen && seeRef(ask.ref, mark.color),
    commented !== undefined && `you commented: “${commented}”. Claude has it.`,
    queued !== undefined && drawQueued(d, ask, queued),
    sent !== undefined && drawOnItsWay(d, ask, sent),
    isClosed && 'sent, and Claude has it',
  )
}

/** What comes after an ask's tree, at its title's column: its buttons, or the field taking Lee's words. */
const drawAfter = (d: Drawing, ask: Ask, { at, queued, sent, isOpen, field }: Standing) => {
  const { Box } = d.els
  const isAnswering = isOpen && queued === undefined && sent === undefined && field === undefined

  return (
    <Box paddingLeft={2} flexDirection="column">
      {isAnswering && drawButtons(d, at, ask)}
      {field !== undefined && drawField(d, field, ask)}
    </Box>
  )
}

/** The mark of an ask Lee's send closed. */
const DONE = { glyph: GLYPH.done, color: C.ok }

export const drawAsk = (d: Drawing, filed: Filed, ask: Ask) => {
  const { Box, Text } = d.els
  const standing = standingOf(d, filed, ask)
  const { isClosed, isOpen } = standing
  const lines = titleLines(d, ask.title, isOpen)
  const mark = isClosed ? DONE : askMark(d.scene, ask)
  const branches = branchesOf(d, ask, mark, standing)

  return (
    <Box key={`ask:${ask.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        {drawMark(d, mark, lines.length, branches.length > 0)}
        <Box flexGrow={1} flexShrink={1}>
          {isClosed ? (
            <Text color={C.faint} wrap="truncate-end">
              {ask.title}
            </Text>
          ) : (
            drawTitle(d, `pick:${ask.id}`, lines, () => d.act.select(ask.id))
          )}
        </Box>
        <Text color={C.grey}>{ago(d.scene.now, ask.at)}</Text>
      </Box>
      {tree(d, `under:${ask.id}`, branches)}
      {drawAfter(d, ask, standing)}
    </Box>
  )
}
