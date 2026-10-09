/**
 * How a paste shows in Lee's prompt box and in the prompt Lee submits. A
 * paste lands in the prompt box, never in a field of the board's (live), so
 * the field takes it from there. Neither form is documented: both are the
 * engine's, as seen live in Claude Code 2.1.295. Should either change,
 * nothing here matches, the field takes nothing, and the paste goes to
 * Claude as it always did.
 */

/** A paste in a submitted prompt: `<pasted_content id="08fd">`, its text on the lines between, the tag closed with its id. */
const PASTED = /<pasted_content id="([^"]*)">\n([\s\S]*?)\n<\/pasted_content id="\1">/g

/** A paste the prompt box holds folded away, as `[Pasted text #1 +3 lines]`: more than 3 lines, or a long one. */
const FOLDED = /\[Pasted text #\d+/

/** The text of the pastes a prompt is made of, joined by newlines; undefined where anything else is in it, typed words or none pasted. */
export const pastedOnly = (prompt: string) => {
  const pastes = [...prompt.matchAll(PASTED)].map(([, , text]) => text)

  return pastes.length > 0 && prompt.replace(PASTED, '').trim() === ''
    ? pastes.join('\n')
    : undefined
}

/** Whether the prompt box holds a paste folded away, whose text it does not hand over. */
export const holdsFolded = (box: string) => FOLDED.test(box)
