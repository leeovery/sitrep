/**
 * The sitrep version this window runs: its plugin's manifest's `version`, as
 * the mod loaded it, said in each of its heartbeats so the app can list the
 * windows still to reload.
 */
import { isFilled, isObject } from '../core'
import { logFailure, type Host } from './host'

/** The plugin's manifest, in the plugin's folder. */
export const MANIFEST = '.claude-plugin/plugin.json'

/**
 * The version, read once a load and kept, whether or not it read: a reload
 * loads this module afresh, with the manifest it brought.
 */
let loaded: Promise<string | undefined> | undefined

const versionIn = (text: string) => {
  const manifest: unknown = JSON.parse(text)

  if (!isObject(manifest) || !isFilled(manifest.version)) {
    throw new Error(`${MANIFEST} gives no version`)
  }

  return manifest.version
}

/**
 * The version this window runs, read once, as the mod loads (session.start
 * asks first): a manifest read later may be newer than the code this load
 * runs, SitRep's copy replaced whole at an update, or a checkout under
 * `app/plugin here` checked out anew. Undefined when the manifest does not
 * give one, which the debug log says once; the window then reads as one
 * needing a reload, which is safe, and rare.
 */
export const versionNow = (host: Host) => {
  loaded ??= host.plugin
    .manifest()
    .then(versionIn)
    .catch((error: unknown) => {
      logFailure(host, "reading the plugin's version")(error)

      return undefined
    })

  return loaded
}
