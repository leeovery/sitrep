/**
 * The versions of sitrep's files, side by side. Windows not yet reloaded
 * write as their own release did, so a reader takes every version up to its
 * own: an object of a past version is brought to today's shape as it is
 * read, by one upgrade per past version, chained, while its file keeps the
 * version it was written in. The rest of the code knows only today's shape.
 */

/** An object as a file holds it, before it is checked. */
export type Raw = { [key: string]: unknown }

/** Brings an object of one version to the next one's shape. */
export type Upgrade = (raw: Raw) => Raw

/** A format's version: one past its upgrades, `upgrades[n - 1]` taking version n to n + 1. */
export const versionOf = (upgrades: readonly Upgrade[]) => upgrades.length + 1

/**
 * An object of any version up to its format's in that version's shape, each
 * upgrade from its own on applied in turn, and stamped with the version each
 * reaches; undefined when its version is later than the format's, or is not
 * one.
 */
export const upgraded = (raw: Raw, upgrades: readonly Upgrade[]): Raw | undefined => {
  const { v } = raw

  if (typeof v !== 'number' || !Number.isInteger(v) || v < 1 || v > versionOf(upgrades)) {
    return undefined
  }

  return upgrades
    .slice(v - 1)
    .reduce((each, upgrade, i) => ({ ...upgrade(each), v: v + i + 1 }), raw)
}
