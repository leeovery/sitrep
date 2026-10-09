/**
 * The field under an ask, for a comment or for what the ask needs back
 * with Lee's yes or choice: a few rows that grow as Lee types, drawn by the
 * mod's own text area where the surface runs one (Claude Code's own field
 * is one line). Enter saves, shift+Enter starts a new line. A paste lands
 * in Lee's prompt box, so the field takes it from there: Enter sends a paste
 * the box folded away, the take button one it holds as text. A review also
 * takes its approve with the comment.
 */
import type { Ask, AskKind } from '../../core'
import type { SitrepAnswer, SitrepField } from '../../types'
import { areaKey, savedFrom, type Saved } from '../actions'
import { C } from '../look'
import { typingOn, YES, type Drawing } from './kit'

/** The field's title and its save button, by the kind of ask, for a comment. */
const FIELD: Record<AskKind, { title: string; save: string }> = {
  review: { title: 'Comment', save: 'save comment' },
  decide: { title: 'Your answer', save: 'save answer' },
  try: { title: 'How did it go?', save: 'save comment' },
  do: { title: 'Comment', save: 'save comment' },
}

/** The yes a kind takes with its comment, where it takes one. */
const WITH_COMMENT: Partial<Record<AskKind, string>> = { review: '✓ approve + comment' }

/** The field's title and save button: a comment's; or what the ask needs back, saved by the answer it goes with. */
const labelsOf = (ask: Ask, answer: SitrepAnswer | undefined) => {
  if (answer === undefined) {
    return FIELD[ask.kind]
  }

  return {
    title: `${ask.needs}:`,
    save: answer.verdict === 'yes' ? YES[ask.kind] : answer.option,
  }
}

/** A review's yes with its comment, which needs words where the ask needs something back. */
const withCommentOf = (ask: Ask): Saved => ({
  verdict: 'yes',
  isNoteNeeded: ask.needs !== undefined,
})

/** Where Lee types: the mod's text area, or the surface's own one-line field. */
const drawArea = (d: Drawing, at: SitrepField) => {
  const { els, act } = d
  const typing = typingOn(d)

  if (typing === 'area' && 'Client' in els) {
    const { Client, Text } = els

    return [
      <Client
        key={areaKey(at.item)}
        module="./textarea.tsx"
        width="100%"
        props={{ placeholder: 'Click here, then type', minRows: 3, filled: at.filled ?? null }}
      />,
      <Text key={`hint:${at.item}`} color={C.grey} italic>
        Enter saves, shift+Enter starts a new line.
      </Text>,
      <Text key={`pastehint:${at.item}`} color={C.grey} italic>
        Paste into the prompt and press Enter there: it comes here, not to Claude.
      </Text>,
    ]
  }

  if (typing === 'field' && 'Input' in els) {
    const { Input } = els

    return (
      <Input
        key={`field:${at.item}`}
        placeholder="type here"
        value={at.filled?.text}
        submitLabel="save"
        autoFocus
        onInput={value => act.type(value)}
        onSubmit={value => act.save(at, savedFrom(at), value)}
      />
    )
  }

  return null
}

export const drawField = (d: Drawing, at: SitrepField, ask: Ask) => {
  const { Box, Text, Button } = d.els
  const { title, save } = labelsOf(ask, at.answer)
  const withComment = at.answer === undefined ? WITH_COMMENT[ask.kind] : undefined

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={C.parked} paddingX={1}>
      <Text color={C.parked} bold>
        {title}
      </Text>
      {drawArea(d, at)}
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        <Button
          key={`save:${ask.id}`}
          variant="primary"
          label={save}
          onPress={() => d.act.save(at, savedFrom(at))}
        />
        {withComment !== undefined && (
          <Button
            key={`savewith:${ask.id}`}
            label={withComment}
            onPress={() => d.act.save(at, withCommentOf(ask))}
          />
        )}
        <Button
          key={`take:${ask.id}`}
          label="⤓ take what's in the prompt"
          onPress={() => d.act.take(at)}
        />
        <Button
          key={`cancel:${ask.id}`}
          dimColor
          label="✕ cancel"
          onPress={() => d.act.cancelComment()}
        />
      </Box>
    </Box>
  )
}
