/**
 * What an ask wants back from Lee, and how an ask written before asks said
 * so reads now: by the kind its line gave, as the shape that kind maps to.
 */
import type { AskKind, Wants } from './types'

/** Every shape of ask, as Claude names one. */
export const WANTS: readonly Wants[] = ['yes', 'choice', 'words']

/** Every kind an ask was once written with. */
export const ASK_KINDS: readonly AskKind[] = ['review', 'decide', 'try', 'do']

/** The words a yes was given in, by the kind of ask it answered; a decide took none. */
const KIND_YES: Record<AskKind, string | undefined> = {
  review: 'Approve',
  decide: undefined,
  try: 'It works',
  do: 'Done',
}

/**
 * An ask written with a kind, as the shape it reads as now: one that needs
 * something back wants words; else a decide wants a choice, and a review, a
 * try or a do a yes in its own words, which its yes keeps even as words.
 */
export const kindShape = (kind: AskKind, needs?: string): { wants: Wants; yes?: string } => ({
  wants: needs ? 'words' : kind === 'decide' ? 'choice' : 'yes',
  yes: KIND_YES[kind],
})
