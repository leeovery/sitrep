/**
 * An ask in For you: its title and age, where to look, what Lee replied,
 * and, opened, its buttons. A kind is never drawn as a word: it chooses
 * the first button (DESIGN.md, "Answering an ask").
 */
import { VERDICTS, type Ask, type AskKind, type Verdict } from '../../core'
import { ago, C, clip, GLYPH } from '../look'
import { queuedOn } from '../queue'
import { askMark } from '../scene'
import type { SitrepQueued } from '../../types'
import { drawField } from './field'
import { canType, drawQueued, hung, type Drawing } from './kit'

/** A yes, by the kind of ask it answers: its button's words. A decide ask offers no yes, so its words are never drawn. */
const YES: Record<AskKind, string> = {
  review: '✓ approve',
  decide: '✓ approve',
  try: '✓ it works',
  do: '✓ done',
}

/** The comment button, by kind: on a decide, a comment is the answer. */
const COMMENT: Record<AskKind, string> = {
  review: '✎ comment',
  decide: '✎ answer',
  try: '✎ comment',
  do: '✎ comment',
}

const HINT =
  "Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it."

/** The buttons a verdict puts on an ask: one for each option of a decision. */
const buttonsFor = (d: Drawing, ask: Ask, verdict: Verdict) => {
  const { Button } = d.els
  const reply = (fields: Omit<SitrepQueued, 'work' | 'item'>) =>
    d.act.reply({ work: d.scene.work.id, item: ask.id, ...fields })

  switch (verdict) {
    case 'choose':
      return (ask.options ?? []).map((option, i) => (
        <Button
          key={`choose:${ask.id}:${i}`}
          variant={i === 0 ? 'primary' : undefined}
          label={option}
          onPress={() => reply({ verdict, option })}
        />
      ))
    case 'yes':
      return [
        <Button
          key={`yes:${ask.id}`}
          variant="primary"
          label={YES[ask.kind]}
          onPress={() => reply({ verdict })}
        />,
      ]
    case 'comment':
      return canType(d)
        ? [
            <Button
              key={`comment:${ask.id}`}
              label={COMMENT[ask.kind]}
              onPress={() => d.act.comment(ask.id)}
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

const drawButtons = (d: Drawing, ask: Ask) => {
  const { Box, Text } = d.els

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        {VERDICTS[ask.kind].flatMap(verdict => buttonsFor(d, ask, verdict))}
      </Box>
      <Text color={C.grey} italic wrap="wrap">
        {HINT}
      </Text>
    </Box>
  )
}

/** What hangs under an ask: where to look, what Lee replied, its buttons or its field. */
const drawUnder = (d: Drawing, ask: Ask) => {
  const { Box, Text } = d.els
  const { work, queue, pane } = d.scene
  const queued = queuedOn(queue, work.id, ask.id)
  const isClosed = ask.state === 'closed'
  const isSelected = pane.selected === ask.id
  const isCommenting = pane.commenting === ask.id && canType(d)
  const commented = ask.state === 'replied' ? ask.answer?.note : undefined

  return (
    <Box paddingLeft={2} flexDirection="column">
      {ask.where !== undefined && !isClosed && (isSelected || d.isDock) && (
        <Text color={C.soft} wrap="wrap">
          {ask.where}
        </Text>
      )}
      {isClosed && hung(d, `sent:${ask.id}`, 'sent, and Claude has it')}
      {commented !== undefined &&
        queued === undefined &&
        hung(d, `replied:${ask.id}`, `you commented: “${commented}”. Claude has it.`)}
      {queued !== undefined && drawQueued(d, ask, queued)}
      {isSelected && !isClosed && queued === undefined && !isCommenting && drawButtons(d, ask)}
      {isCommenting && drawField(d, ask)}
    </Box>
  )
}

export const drawAsk = (d: Drawing, ask: Ask) => {
  const { Box, Text, Button } = d.els
  const isClosed = ask.state === 'closed'
  const mark = askMark(d.scene, ask)

  return (
    <Box key={`ask:${ask.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Text color={isClosed ? C.ok : mark.color}>{isClosed ? GLYPH.done : mark.glyph}</Text>
        <Box flexGrow={1} flexShrink={1}>
          {isClosed ? (
            <Text color={C.faint} wrap="truncate-end">
              {ask.title}
            </Text>
          ) : (
            <Button
              key={`pick:${ask.id}`}
              plain
              label={clip(ask.title, d.width - 8)}
              onPress={() => d.act.select(ask.id)}
            />
          )}
        </Box>
        <Text color={C.grey}>{ago(d.scene.now, ask.at)}</Text>
      </Box>
      {drawUnder(d, ask)}
    </Box>
  )
}
