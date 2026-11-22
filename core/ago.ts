/** How long ago a time was, as every front end words it. */

const MIN = 60_000

/**
 * Whole minutes in their largest whole unit, rounded down, as the app's
 * `Age` words them: `now` under one, `12m`, `2h`, `3d`. So 90 minutes read
 * `1h` on every surface, the notch's, the pane's and the terminal view's.
 */
export const inUnits = (minutes: number) => {
  const hours = Math.floor(minutes / 60)

  if (minutes < 1) {
    return 'now'
  }

  return minutes < 60 ? `${minutes}m` : hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`
}

/** How long ago `at` was, in the fewest characters: `now`, `12m`, `2h`, `3d`. */
export const ago = (now: number, at: number) => inUnits(Math.floor((now - at) / MIN))
