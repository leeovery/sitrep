/**
 * The comment field under an ask: a few rows that grow as Lee types, drawn
 * by the mod's own text area where the surface runs one (Claude Code's own
 * field is one line). Enter saves, shift+Enter starts a new line. A review
 * also takes its approve with the comment.
 */
import type { Ask, AskKind } from '../../core'
import { areaKey } from '../actions'
import { C } from '../look'
import { typingOn, type Drawing } from './kit'

/** The field's title and its save button, by the kind of ask. */
const FIELD: Record<AskKind, { title: string; save: string }> = {
  review: { title: 'Comment', save: 'save comment' },
  decide: { title: 'Your answer', save: 'save answer' },
  try: { title: 'How did it go?', save: 'save comment' },
  do: { title: 'Comment', save: 'save comment' },
}

/** The yes a kind takes with its comment, where it takes one. */
const WITH_COMMENT: Partial<Record<AskKind, string>> = { review: '✓ approve + comment' }

/** Where Lee types: the mod's text area, or the surface's own one-line field. */
const drawArea = (d: Drawing, ask: Ask) => {
  const { els, act } = d
  const work = d.scene.work.id
  const typing = typingOn(d)

  if (typing === 'area' && 'Client' in els) {
    const { Client, Text } = els

    return [
      <Client
        key={areaKey(ask.id)}
        module="./textarea.tsx"
        width="100%"
        props={{ placeholder: 'Click here, then type', minRows: 3 }}
      />,
      <Text key={`hint:${ask.id}`} color={C.grey} italic>
        Enter saves, shift+Enter starts a new line.
      </Text>,
    ]
  }

  if (typing === 'field' && 'Input' in els) {
    const { Input } = els

    return (
      <Input
        key={`field:${ask.id}`}
        placeholder="type here"
        submitLabel="save"
        autoFocus
        onInput={value => act.type(value)}
        onSubmit={value => act.save(work, ask.id, 'comment', value)}
      />
    )
  }

  return null
}

export const drawField = (d: Drawing, ask: Ask) => {
  const { Box, Text, Button } = d.els
  const { title, save } = FIELD[ask.kind]
  const withComment = WITH_COMMENT[ask.kind]
  const work = d.scene.work.id

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={C.parked} paddingX={1}>
      <Text color={C.parked} bold>
        {title}
      </Text>
      {drawArea(d, ask)}
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        <Button
          key={`save:${ask.id}`}
          variant="primary"
          label={save}
          onPress={() => d.act.save(work, ask.id, 'comment')}
        />
        {withComment !== undefined && (
          <Button
            key={`savewith:${ask.id}`}
            label={withComment}
            onPress={() => d.act.save(work, ask.id, 'yes')}
          />
        )}
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
