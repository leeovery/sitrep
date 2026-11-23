/**
 * What the answering tests share (answering.test.tsx, and
 * answering-image.test.tsx for an answer with an image): the words ask,
 * Lee's Enter at the prompt and an image pasted there, and the board on an
 * ask or a parked item being answered.
 */
import type { PromptSubmitAttachment } from 'claude-code'
import type { Engine } from './kit'
import { LEDGER, MIN, type Asked } from './data'
import { park, wordsAsk, yesAsk } from './lines'
import { asked, toProject, type World } from './world'

/** What the words ask's words are, in Claude's. */
export const OUTPUT = "the command's output"

/** The words ask: a command's output, run where Lee can. */
export const LIST = {
  wants: 'words',
  title: 'Run sitrep list in a shell and paste what it prints',
  where: 'Any terminal: type sitrep list',
  needs: OUTPUT,
} satisfies Asked

/** Lee pressing Enter at the prompt with `text` in it, the box holding what it showed. */
export const entered = (
  w: World,
  engine: Engine,
  text: string,
  extra: {
    attachments?: readonly PromptSubmitAttachment[]
    origin?: { kind: 'composer' | 'bridge' | 'task-notification' }
  } = {},
) => {
  w.box.text = text.includes('<pasted_content') ? '[Pasted text #1 +3 lines]' : text

  return engine.prompt.submit({ text, wait: false, origin: { kind: 'composer' }, ...extra })
}

/** An image Lee pasted with no handle to read its bytes by, so it can't be saved, and rides in with Lee's prompt. */
export const IMAGE: PromptSubmitAttachment = { type: 'image', mediaType: 'image/png' }

/** Where a reply to an ask of the held session goes. */
export const at = (w: World, item: string) => ({
  project: w.state.attachment?.project,
  session: w.state.attachment?.session,
  item,
})

/** The board, opened by /sitrep, on the words ask, answering it. */
export const answering = async (w: World) => {
  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.opened()

  await ui.press({ key: `answer:${w.item(id)}` })

  return { id, ui }
}

/** The ledger's asks, a words ask and a yes ask, as its own window wrote them. */
export const LEDGERS_ASKS = [
  wordsAsk('k3', 'Which fields does the ledger keep?', 'the fields'),
  yesAsk('k4', 'Approve the ledger schema'),
]

/**
 * The board on the project's view, the ledger's asks drawn from its brief,
 * a minute on. Given `isUnread`, the board's reads of other sessions in full
 * never land, as before the look that reads one has: only the briefs have it.
 */
export const onLedgersAsks = async (w: World, isUnread = false) => {
  const ledger = w.elsewhere(LEDGER)

  ledger.write(...LEDGERS_ASKS)

  if (isUnread) {
    w.leaveUnread()
  }

  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await toProject(ui)

  return ui
}

/** The ledger's parked item. */
export const EXPORT = 'Export the ledger as CSV'

/** The board on the project's view, the ledger's parked item drawn there from its brief, opened, picked up, and ✎ comment pressed under the pick-up: the ledger. */
export const onLedgersParked = async (w: World, isUnread = false) => {
  const ledger = w.elsewhere(LEDGER)

  ledger.write(park('p3', EXPORT))

  if (isUnread) {
    w.leaveUnread()
  }

  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()
  const there = w.item('p3', LEDGER.id)

  await toProject(ui)
  await ui.press({ key: `ppick:${there}` })
  await ui.press({ key: `pickup:${there}` })
  await ui.press({ key: `rewrite:${there}` })

  return ledger
}
