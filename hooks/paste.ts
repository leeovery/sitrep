/**
 * How a paste arrives in the prompt Lee submits. The prompt box folds a
 * paste of more than 3 lines (or one long line) away, as `[Pasted text #1
 * +3 lines]`, and only the submitted prompt has its text, wrapped in tags
 * of the engine's own: undocumented, as seen live in Claude Code 2.1.295.
 * Should the wrapping change, nothing here matches, and the prompt is taken
 * as it came.
 */

/** A paste in a submitted prompt, with the line breaks the engine puts around it: `<pasted_content id="08fd">`, its text on the lines between, the tag closed with its id. */
const PASTED = /\n*<pasted_content id="([^"]*)">\n([\s\S]*?)\n<\/pasted_content id="\1">\n?/g

/** A submitted prompt as Lee wrote it: each paste's text in its place, on lines of its own, the words typed around it kept. */
export const unwrapPastes = (prompt: string) =>
  prompt.replace(PASTED, (whole: string, _id: string, text: string, at: number) => {
    const before = at === 0 ? '' : '\n'
    const after = at + whole.length === prompt.length ? '' : '\n'

    return `${before}${text}${after}`
  })
