/** How long ago a time was, as every front end words it. */

const MIN = 60_000
const HOUR = 60 * MIN
const DAY = 24 * HOUR

/** How long ago `at` was, in the fewest characters: `now`, `12m`, `2h`, `3d`. */
export const ago = (now: number, at: number) => {
  const elapsed = now - at

  if (elapsed < MIN) {
    return 'now'
  }

  if (elapsed < HOUR) {
    return `${Math.round(elapsed / MIN)}m`
  }

  return elapsed < DAY ? `${Math.round(elapsed / HOUR)}h` : `${Math.round(elapsed / DAY)}d`
}
