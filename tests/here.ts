/**
 * `here.json` as SitRep writes it, its encoder's output byte for byte: the
 * app's tests hold its encoder to the text between the backticks of
 * `APP_FILE`, read from the source tree, writing `APP_NOT_HERE` at
 * `APP_AT`, and core's tests read it with `notHereOf`, so the file the app
 * writes is the one the panel reads (see "Storage" in DESIGN.md).
 */

/** When the file was written, in milliseconds since the epoch. */
export const APP_AT = 1_763_650_000_123

/** The sessions it names, in the order the app writes them: sorted. */
export const APP_NOT_HERE = ['sr-ct0002', 'sr-nw0001']

export const APP_FILE = `{"at":1763650000123,"notHere":["sr-ct0002","sr-nw0001"],"v":1}`
