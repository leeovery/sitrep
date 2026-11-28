/**
 * The snooze menu `z` opens under the chosen row: Snooze's times as Lee set
 * them in SitRep, those still to come, in their order, each worked out as
 * the menu opens and worded beside its name as the notch's menu words it;
 * then Until it moves, with no time (DESIGN.md, "Snooze"). A choice
 * snoozes to the time it showed, though the clock moved on meanwhile.
 *
 * With a row's asks open, `z` opens it for the ask shown alone, in the
 * foot's place: the same times, and no Until it moves, as the notch's
 * Snooze ▾ offers them.
 */
import { snoozeAt, snoozeChoicesAt, timeBeside, type SnoozeChoice, type SnoozeSettings } from '../../core'

/** A choice on the menu: its name, its time beside it, and when it wakes; none for Until it moves. */
export type SnoozeOption = { title: string; time: string; until?: number }

/**
 * The menu open under the band's row, by its key: the session it snoozes,
 * and what it snoozes: the session, naming the asks that row showed; or, its
 * asks open, the ask shown alone. Then its choices, the one picked, and the
 * first drawn, as the layout last kept it, short of room for them all.
 */
export type Menu = { row: string; session: string; options: readonly SnoozeOption[]; at: number; top: number } & (
  | { asks: readonly string[] }
  | { ask: string }
)

/** Each choice's name, as the notch's menu names it (`SnoozeChoice.title`). */
const TITLES: Record<SnoozeChoice, string> = {
  hour: 'In an hour',
  later: 'Later today',
  tonight: 'Tonight',
  tomorrow: 'Tomorrow',
  weekend: 'This weekend',
  week: 'Next week',
}

const UNTIL_IT_MOVES: SnoozeOption = { title: 'Until it moves', time: '' }

/** Snooze's times at `now`, as `settings` offer them: an ask's menu's choices. */
export const snoozeTimes = (now: number, settings: SnoozeSettings): SnoozeOption[] =>
  snoozeChoicesAt(now, settings).map(choice => {
    const until = snoozeAt(choice, now, settings)

    return { title: TITLES[choice], time: timeBeside(choice, until), until }
  })

/** The row's menu's choices at `now`, as `settings` offer them, then Until it moves. */
export const snoozeOptions = (now: number, settings: SnoozeSettings): SnoozeOption[] => [...snoozeTimes(now, settings), UNTIL_IT_MOVES]
